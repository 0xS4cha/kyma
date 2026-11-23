local Arena = require("src.game.arena")
local Player = require("src.game.player")
local World = require("src.game.world")
local Inputs = require("src.net.inputs")
local Config = require("src.config.game")
local NetConfig = require("src.net.config")

local DT = 1 / NetConfig.tickRate

local function open()
    return Arena.new({ width = 4000, height = 4000, walls = {}, spawns = { { x = 2000, y = 2000, angle = 0 } } })
end

local function run(p, arena, ticks, dashAt, f, r)
    for t = 1, ticks do
        Player.step(p, { f = f or 1, r = r or 0, a = 0, d = t == dashAt and 1 or 0 }, arena, DT)
    end
end

return {
    {
        name = "dash covers more ground than running",
        run = function()
            local arena = open()
            local walker, dasher = Player.new(1, "a", arena:spawn(1)), Player.new(1, "a", arena:spawn(1))
            run(walker, arena, 20)
            run(dasher, arena, 20, 1)
            local expected = Config.dash.speed * Config.dash.ticks * DT
            assert(dasher.x - walker.x > expected * 0.6, "dash gained " .. (dasher.x - walker.x))
        end
    },
    {
        name = "dash goes where you move, or forward when standing still",
        run = function()
            local arena = open()
            local strafer = Player.new(1, "a", arena:spawn(1))
            run(strafer, arena, Config.dash.ticks, 1, 0, 1)
            assert(strafer.y - 2000 > 100 and math.abs(strafer.x - 2000) < 1, "strafe dash goes right")
            local idle = Player.new(1, "a", arena:spawn(1))
            run(idle, arena, Config.dash.ticks, 1, 0, 0)
            assert(idle.x - 2000 > 100, "idle dash goes forward")
        end
    },
    {
        name = "dash waits for its cooldown",
        run = function()
            local arena = open()
            local p = Player.new(1, "a", arena:spawn(1))
            Player.step(p, { f = 0, r = 0, a = 0, d = 1 }, arena, DT)
            assert(p.dash > 0 and p.cooldown == Config.dash.cooldown)
            for _ = 1, Config.dash.ticks + 5 do
                Player.step(p, { f = 0, r = 0, a = 0, d = 1 }, arena, DT)
            end
            assert(p.cooldown > 0 and p.dash == 0, "no second dash during the cooldown")
            for _ = 1, Config.dash.cooldown do
                Player.step(p, { f = 0, r = 0, a = 0, d = 0 }, arena, DT)
            end
            Player.step(p, { f = 0, r = 0, a = 0, d = 1 }, arena, DT)
            assert(p.dash > 0, "dash is available again after the cooldown")
        end
    },
    {
        name = "dash stops at walls",
        run = function()
            local arena = Arena.new()
            local p = Player.new(1, "a", { x = 60, y = 480, angle = math.pi })
            run(p, arena, Config.dash.ticks, 1, 1, 0)
            assert(p.x >= 40 + Config.player.radius - 1e-6, "x = " .. p.x)
        end
    },
    {
        name = "prediction matches the server with dashes",
        run = function()
            local world = World.new()
            world:add(1, "a")
            local predicted = Player.new(1, "a", world.arena:spawn(1))
            for s = 1, 300 do
                local command = { s = s, f = 1, r = s % 40 < 20 and 1 or -1, a = Player.packAngle(s * 0.015), d = s % 70 == 0 and 1 or 0 }
                Player.step(predicted, command, world.arena, DT)
                world:queue(1, { command })
                world:step()
            end
            local server = world.players[1]
            assert(server.x == predicted.x and server.y == predicted.y, "positions diverged")
            assert(server.cooldown == predicted.cooldown and server.dash == predicted.dash, "dash state diverged")
        end
    },
    {
        name = "inputs keep only a boolean dash flag",
        run = function()
            assert(Inputs.sanitize({ s = 1, a = 0, d = 1 }).d == 1)
            assert(Inputs.sanitize({ s = 1, a = 0, d = 5 }).d == 0)
            assert(Inputs.sanitize({ s = 1, a = 0 }).d == 0)
        end
    }
}
