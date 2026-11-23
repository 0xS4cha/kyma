local Arena = require("src.game.arena")
local World = require("src.game.world")
local Room = require("src.server.room")
local Config = require("src.config.game")
local Combat = require("src.game.combat")

local function open(mode, spawns)
    return World.new(Arena.new({
        width = 3000, height = 3000, walls = {},
        spawns = spawns or {
            { x = 300, y = 300, angle = 0, team = 1 }, { x = 400, y = 300, angle = 0, team = 1 },
            { x = 2700, y = 2700, angle = math.pi, team = 2 }, { x = 2600, y = 2700, angle = math.pi, team = 2 }
        }
    }), mode)
end

local fakeClient = {}
fakeClient.__index = fakeClient
function fakeClient:Send() end
function fakeClient:SendRaw() end
function fakeClient:Stream() end

return {
    {
        name = "teammates can't hurt each other, enemies can",
        run = function()
            local world = open("teams")
            local a, b, c = world:add(1, "a", 1), world:add(2, "b", 1), world:add(3, "c", 2)
            Combat.damage(world, b, 50, a.slot)
            assert(b.hp == Config.health, "no friendly fire")
            Combat.damage(world, c, 50, a.slot)
            assert(c.hp == Config.health - 50)
        end
    },
    {
        name = "teammates are always visible and never heard as echoes",
        run = function()
            local world = open("teams")
            world:add(1, "a", 1)
            world:add(2, "b", 1)
            world:add(3, "c", 2)
            world.players[2].x, world.players[2].y = 2900, 100
            assert(world:visible(1, 2), "ally seen anywhere")
            assert(not world:visible(1, 3), "enemy behind is hidden")
            assert(not world:hears(1, { source = 2, x = 2900, y = 100, radius = 5000 }))
        end
    },
    {
        name = "team spawns go to their own side",
        run = function()
            local world = open("teams")
            local a, c = world:add(1, "a", 1), world:add(3, "c", 2)
            assert(a.x < 1000 and c.x > 2000)
        end
    },
    {
        name = "respawns pick the spawn farthest from enemies",
        run = function()
            local world = open("ffa", { { x = 300, y = 300, angle = 0 }, { x = 2700, y = 2700, angle = 0 } })
            local a = world:add(1, "a")
            local b = world:add(2, "b")
            assert(math.abs(a.x - b.x) > 2000, "the second player spawns away from the first")
        end
    },
    {
        name = "reaching the score limit ends the match, which restarts after the countdown",
        run = function()
            local world = open("ffa", { { x = 300, y = 300, angle = 0 }, { x = 2700, y = 2700, angle = 0 } })
            local a, b = world:add(1, "a"), world:add(2, "b")
            world.score[1] = Config.modes.ffa.scoreLimit - 1
            Combat.kill(world, b, 1)
            assert(world.over and world.over.winner == 1 and not world.over.team)
            local events = world:drain()
            local over = false
            for _, e in ipairs(events) do if e.kind == "over" then over = true end end
            assert(over, "an over event is sent")
            Combat.damage(world, a, 50, 2)
            assert(a.hp == Config.health, "no damage after the end")
            for _ = 1, Config.matchEndTicks + 1 do world:step() end
            assert(not world.over and world.score[1] == 0 and b.dead == 0, "restarted")
        end
    },
    {
        name = "team kills add up to the team score",
        run = function()
            local world = open("teams")
            world:add(1, "a", 1)
            local c = world:add(3, "c", 2)
            Combat.kill(world, c, 1)
            assert(world.teamScore[1] == 1 and world.teamScore[2] == 0)
        end
    },
    {
        name = "practice rooms fill every free slot with bots, balanced in teams",
        run = function()
            for _, mode in ipairs(Config.modes.order) do
                local room = Room(1, { bot = "easy", mode = mode })
                local client = setmetatable({ id = "c", name = "Alice" }, fakeClient)
                assert(room:Add(client))
                assert(room:Full() and room:Count() == Config.modes[mode].players, mode)
                if Config.modes[mode].teams then
                    local sizes = { 0, 0 }
                    for _, p in pairs(room.world.players) do sizes[p.team] = sizes[p.team] + 1 end
                    assert(sizes[1] == sizes[2], "balanced teams")
                end
            end
        end
    },
    {
        name = "matchmaking groups players by mode",
        run = function()
            local Host = require("src.server.host")
            local host = Host({ address = "127.0.0.1", port = 6852 })
            local clients = {}
            for k = 1, 4 do clients[k] = setmetatable({ id = "c" .. k, name = "P" .. k }, fakeClient) end
            host:matchmake(clients[1], { mode = "ffa" })
            host:matchmake(clients[2], { mode = "duel" })
            host:matchmake(clients[3], { mode = "ffa" })
            host:matchmake(clients[4])
            assert(clients[1].room == clients[3].room and clients[1].room.mode == "ffa")
            assert(clients[2].room ~= clients[1].room)
            assert(clients[4].room ~= nil, "no mode joins any open room")
        end
    }
}
