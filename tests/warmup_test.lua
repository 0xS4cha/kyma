local Arena = require("src.game.arena")
local World = require("src.game.world")
local Room = require("src.server.room")
local Combat = require("src.game.combat")
local Config = require("src.config.game")

local function lobby()
    local world = World.new(Arena.new({
        width = 3000, height = 3000, walls = {},
        spawns = { { x = 500, y = 500, angle = 0 }, { x = 2500, y = 2500, angle = 0 } }
    }), "duel", true)
    world:add(1, "a")
    world:add(2, "b")
    return world
end

local function ticks(world, n)
    for _ = 1, n do world:step() end
end

local fakeClient = {}
fakeClient.__index = fakeClient
function fakeClient:Send() end
function fakeClient:SendRaw() end
function fakeClient:Stream() end

return {
    {
        name = "rooms start in warmup where kills don't count",
        run = function()
            local world = lobby()
            assert(world.phase == "warmup")
            Combat.kill(world, world.players[2], 1)
            assert(world.score[1] == 0)
        end
    },
    {
        name = "the match starts after a countdown once every human is ready",
        run = function()
            local world = lobby()
            world:setReady(1, true)
            ticks(world, 2)
            assert(world.phase == "warmup", "one player is not ready")
            world:setReady(2, true)
            ticks(world, 2)
            assert(world.phase == "countdown")
            ticks(world, Config.countdownTicks)
            assert(world.phase == "playing")
            Combat.kill(world, world.players[2], 1)
            assert(world.score[1] == 1, "kills count now")
        end
    },
    {
        name = "unreadying cancels the countdown",
        run = function()
            local world = lobby()
            world:setReady(1, true)
            world:setReady(2, true)
            ticks(world, 10)
            world:setReady(2, false)
            ticks(world, 1)
            assert(world.phase == "warmup")
        end
    },
    {
        name = "a lone player can't start and bots count as ready",
        run = function()
            local world = World.new(Arena.new({ width = 3000, height = 3000, walls = {}, spawns = { { x = 500, y = 500, angle = 0 } } }), "duel", true)
            world:add(1, "a")
            world:setReady(1, true)
            ticks(world, 5)
            assert(world.phase == "warmup", "needs two players")
            world:add(2, "bot").bot = true
            ticks(world, 2)
            assert(world.phase == "countdown")
        end
    },
    {
        name = "after a match everyone goes back to the warmup",
        run = function()
            local world = lobby()
            world:setReady(1, true)
            world:setReady(2, true)
            ticks(world, Config.countdownTicks + 2)
            world.score[1] = Config.modes.duel.scoreLimit - 1
            Combat.kill(world, world.players[2], 1)
            assert(world.over)
            ticks(world, Config.matchEndTicks + 1)
            assert(world.phase == "warmup" and not world.ready[1] and world.score[1] == 0)
        end
    },
    {
        name = "rooms flag their bots and forward ready messages",
        run = function()
            local room = Room(1, { bot = "easy", mode = "duel" })
            local client = setmetatable({ id = "c", name = "Alice" }, fakeClient)
            room:Add(client)
            assert(room.world.players[2].bot and room.world.phase == "warmup")
            room:Ready(client, { ready = true })
            room:Update(0.1)
            assert(room.world.phase == "countdown")
        end
    }
}
