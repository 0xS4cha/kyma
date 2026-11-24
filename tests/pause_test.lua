local Room = require("src.server.room")
local Config = require("src.net.config")

local Client = {}
Client.__index = Client
function Client:Send() end
function Client:SendRaw() end
function Client:Stream() end

local function client(id)
    return setmetatable({ id = id, name = id }, Client)
end

local function run(room, ticks)
    for _ = 1, ticks do room:Update(1 / Config.tickRate) end
end

return {
    {
        name = "pausing a solo practice freezes the game until you resume",
        run = function()
            local room = Room(1, { mode = "duel", bot = "easy" })
            local me = client("me")
            room:Add(me)
            run(room, 10)
            local tick = room.world.tick
            assert(room:Hold(me, { on = true }))
            run(room, 60)
            assert(room.world.tick == tick, "frozen")
            room:Hold(me, { on = false })
            run(room, 10)
            assert(room.world.tick > tick, "running again")
        end
    },
    {
        name = "a match with other people keeps running",
        run = function()
            local room = Room(1, { mode = "duel" })
            local a, b = client("a"), client("b")
            room:Add(a)
            room:Add(b)
            assert(not room:Hold(a, { on = true }))
            local tick = room.world.tick
            run(room, 5)
            assert(room.world.tick > tick)
        end
    },
    {
        name = "a practice with someone watching keeps running",
        run = function()
            local room = Room(1, { mode = "duel", bot = "easy" })
            local me, watcher = client("me"), client("w")
            room:Add(me)
            room:Watch(watcher)
            assert(not room:Hold(me, { on = true }))
            assert(not room:Hold(watcher, { on = true }), "spectators can't pause")
        end
    },
    {
        name = "leaving a paused practice unfreezes the room",
        run = function()
            local room = Room(1, { mode = "duel", bot = "easy" })
            local me = client("me")
            room:Add(me)
            room:Hold(me, { on = true })
            room:Remove(me)
            assert(not room.held)
        end
    }
}
