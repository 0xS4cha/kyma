local enet = require("enet")
local Protocol = require("src.net.protocol")
local NetConfig = require("src.net.config")
local Inputs = require("src.net.inputs")
local World = require("src.game.world")
local Arena = require("src.game.arena")
local Player = require("src.game.player")
local Host = require("src.server.host")

local DT = 1 / NetConfig.tickRate

local function commands(count, f, r, angle)
    local list = {}
    for s = 1, count do
        list[s] = { s = s, f = f, r = r, a = Player.packAngle(angle) }
    end
    return list
end

local function connect(host, port)
    local client = { host = enet.host_create(), inbox = {} }
    client.peer = client.host:connect("127.0.0.1:" .. port, NetConfig.channels)
    return client
end

local function pump(server, clients, seconds)
    local deadline = love.timer.getTime() + seconds
    while love.timer.getTime() < deadline do
        server:Think(0.004)
        for _, client in ipairs(clients) do
            local event = client.host:service(0)
            while event do
                if event.type == "connect" then
                    client.peer:send(Protocol.Encode("hello", { name = client.name, version = NetConfig.version }), 0, "reliable")
                elseif event.type == "receive" then
                    local kind, data = Protocol.Decode(event.data)
                    client.inbox[#client.inbox + 1] = { kind = kind, data = data }
                    if kind == "welcome" then
                        client.peer:send(Protocol.Encode("queue"), 0, "reliable")
                    elseif kind == "joined" then
                        client.slot = data.slot
                    elseif kind == "state" then
                        client.state = data
                    end
                end
                event = client.host:service(0)
            end
        end
        love.timer.sleep(0.004)
    end
end

return {
    {
        name = "codec round-trips a state message",
        run = function()
            local kind, data = Protocol.Decode(Protocol.Encode("state", { t = 42, k = 7, p = { { i = 1, x = 10.5, y = -3, a = 1234, u = 0, v = 1.25 } } }))
            assert(kind == "state" and data.t == 42 and data.k == 7)
            assert(data.p[1].x == 10.5 and data.p[1].y == -3 and data.p[1].a == 1234 and data.p[1].v == 1.25)
        end
    },
    {
        name = "inputs reject malformed commands",
        run = function()
            assert(Inputs.sanitize({ s = 1, f = 1, r = 0, a = 10 }))
            assert(Inputs.sanitize({ s = 0, f = 1, r = 0, a = 10 }) == nil, "sequence must start at 1")
            assert(Inputs.sanitize({ s = 1.5, a = 10 }) == nil, "sequence must be an integer")
            assert(Inputs.sanitize({ s = 1, a = Player.ANGLE_STEPS }) == nil, "angle out of range")
            local command = Inputs.sanitize({ s = 2, f = 5, r = "x", a = 0 })
            assert(command.f == 0 and command.r == 0, "axes are clamped to -1, 0, 1")
            local batch = Inputs.batch({ c = { { s = 3, a = 0 }, { s = 1, a = 0 }, "junk", { s = 2, a = 0 } } })
            assert(#batch == 3 and batch[1].s == 1 and batch[3].s == 2 + 1)
        end
    },
    {
        name = "player stays out of walls",
        run = function()
            local arena = Arena.new()
            local p = Player.new(1, "a", arena:spawn(1))
            for _ = 1, 600 do
                Player.step(p, { f = 1, r = 0, a = Player.packAngle(math.pi) }, arena, DT)
            end
            assert(p.x >= 40 + 14 - 1e-6, "pushed out of the left wall, x = " .. p.x)
            assert(math.abs(p.vx) < 1, "velocity into the wall is cancelled")
        end
    },
    {
        name = "client prediction matches the server simulation",
        run = function()
            local world = World.new()
            world:add(1, "a")
            local predicted = Player.new(1, "a", world.arena:spawn(1))
            local list = {}
            for s = 1, 240 do
                list[s] = { s = s, f = s % 90 < 60 and 1 or -1, r = s % 50 < 25 and 1 or 0, a = Player.packAngle(s * 0.02) }
            end
            for _, command in ipairs(list) do
                Player.step(predicted, command, world.arena, DT)
                world:queue(1, { command })
                world:step()
            end
            local server = world.players[1]
            assert(world:ack(1) == 240)
            assert(server.x == predicted.x and server.y == predicted.y, "positions diverged")
        end
    },
    {
        name = "server caps inputs to one per tick",
        run = function()
            local world = World.new()
            world:add(1, "a")
            world:queue(1, commands(100, 1, 0, 0))
            for _ = 1, 10 do world:step() end
            local dropped = 100 - NetConfig.inputQueue
            local applied = world:ack(1) - dropped
            assert(applied == 10, "applied " .. applied .. " inputs in 10 ticks")
        end
    },
    {
        name = "two clients are matched in one duel and see each other move",
        run = function()
            local port = 6850
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 4 })
            assert(server:Start(), "server failed to bind")
            local a, b = connect(nil, port), connect(nil, port)
            a.name, b.name = "Alice", "Bob"
            local ok, err = pcall(function()
                pump(server, { a, b }, 0.5)
                assert(a.slot == 1 and b.slot == 2, "slots " .. tostring(a.slot) .. " " .. tostring(b.slot))

                local spawn = Arena.new():spawn(1)
                local batch = commands(30, 1, 0, 0)
                for k = 1, 30 do
                    a.peer:send(Protocol.Encode("input", { c = { batch[math.max(1, k - 1)], batch[k] } }), 1, "unreliable")
                    pump(server, { a, b }, DT)
                end
                pump(server, { a, b }, 0.3)

                assert(a.state and a.state.k == 30, "server acked " .. tostring(a.state and a.state.k))
                local seen
                for _, entry in ipairs(b.state.p) do
                    if entry.i == 1 then seen = entry end
                end
                assert(seen and seen.x > spawn.x + 50, "Bob sees Alice at x = " .. tostring(seen and seen.x) .. " from " .. spawn.x)
                assert(#b.state.p == 2, "both players in the snapshot")
            end)
            a.peer:disconnect_now()
            b.peer:disconnect_now()
            server:Stop()
            assert(ok, err)
        end
    }
}
