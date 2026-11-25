local Arena = require("src.game.arena")
local World = require("src.game.world")
local Bot = require("src.game.bot")
local Room = require("src.server.room")
local Config = require("src.config.game")

local function open(walls, target)
    local world = World.new(Arena.new({
        width = 3000, height = 3000, walls = walls or {},
        spawns = { target or { x = 1500, y = 1500, angle = 0 }, { x = 1200, y = 1500, angle = 0 } }
    }))
    world:add(1, "target")
    world:add(2, "bot")
    return world
end

local function run(world, bot, ticks)
    for _ = 1, ticks do
        world:queue(bot.slot, { bot:command(world) })
        world:step()
    end
end

local fakeClient = {}
fakeClient.__index = fakeClient
function fakeClient:Send() end
function fakeClient:SendRaw() end
function fakeClient:Stream() end

return {
    {
        name = "each bot level eventually kills a target standing in the open",
        run = function()
            for _, level in ipairs(Config.bots.order) do
                local world = open()
                local bot = Bot.new(2, level, 1)
                run(world, bot, 60 * 20)
                assert((world.score[2] or 0) >= 1, level .. " bot never scored")
            end
        end
    },
    {
        name = "harder bots kill faster",
        run = function()
            local times = {}
            for _, level in ipairs({ "easy", "hard" }) do
                local world = open()
                local bot = Bot.new(2, level, 3)
                local ticks = 0
                while (world.score[2] or 0) == 0 and ticks < 60 * 30 do
                    run(world, bot, 1)
                    ticks = ticks + 1
                end
                times[level] = ticks
            end
            assert(times.hard < times.easy, "hard " .. times.hard .. " easy " .. times.easy)
        end
    },
    {
        name = "a bot does not shoot through walls",
        run = function()
            local world = open({ { x = 1300, y = 0, w = 40, h = 3000 } })
            local bot = Bot.new(2, "hard", 1)
            for _ = 1, 300 do
                local command = bot:command(world)
                assert(command.b == 0, "fired without seeing the target")
                world:queue(2, { command })
                world:step()
            end
        end
    },
    {
        name = "a bot walks to a weapon when it is unarmed",
        run = function()
            local world = open(nil, { x = 2900, y = 2900, angle = 0 })
            local Combat = require("src.game.combat")
            local bot = Bot.new(2, "medium", 1)
            Combat.spawnItem(world, "rifle", nil, nil, 1350, 1500)
            for _ = 1, 120 do
                -- le pistolet de secours est redonné à chaque tick : on le retire pour tester la recherche d'arme
                world.players[2].weapon = nil
                run(world, bot, 1)
                if world.players[2].weapon == "rifle" then break end
            end
            assert(world.players[2].weapon == "rifle")
        end
    },
    {
        name = "practice rooms hold the player and the bot, and drive the bot",
        run = function()
            local room = Room(1, { bot = "hard" })
            local client = setmetatable({ id = "c", name = "Alice" }, fakeClient)
            assert(room:Add(client))
            assert(client.slot == 1 and room:Full() and room.state == "playing")
            local info = room:Info()
            assert(#info.players == 2 and info.players[2].bot and info.practice)
            local start = room.world.players[2]
            local x, y = start.x, start.y
            room:Update(2)
            local bot = room.world.players[2]
            assert(bot.x ~= x or bot.y ~= y, "the bot moves")
        end
    },
    {
        name = "matchmaking keeps practice rooms private",
        run = function()
            local Host = require("src.server.host")
            local host = Host({ address = "127.0.0.1", port = 6851 })
            local alice = setmetatable({ id = "a", name = "Alice" }, fakeClient)
            local bob = setmetatable({ id = "b", name = "Bob" }, fakeClient)
            local carol = setmetatable({ id = "c", name = "Carol" }, fakeClient)
            host:matchmake(alice, { bot = "easy" })
            host:matchmake(bob, {})
            host:matchmake(carol)
            assert(alice.room.practice and alice.room ~= bob.room, "practice room stays private")
            assert(bob.room == carol.room, "duelists still meet")
        end
    }
}
