local Room = require("src.server.room")
local Host = require("src.server.host")
local Config = require("src.config.game")

local Client = {}
Client.__index = Client
function Client:Send(kind, data) self.inbox[#self.inbox + 1] = { kind = kind, data = data } end
function Client:SendRaw() end
function Client:Stream(kind, data) if kind == "state" then self.state = data end end

local function client(id, name)
    return setmetatable({ id = id, name = name, inbox = {} }, Client)
end

local function joined(c)
    for _, m in ipairs(c.inbox) do
        if m.kind == "joined" then return m.data end
    end
end

return {
    {
        name = "spectators take no slot and are not counted as players",
        run = function()
            local room = Room(1, { mode = "duel" })
            local a, w = client("a", "Alice"), client("w", "Watcher")
            room:Add(a)
            room:Watch(w)
            assert(w.slot == nil and w.spectator and joined(w).spectator)
            assert(room:Count() == 1 and not room:Full(), "the second duel slot is still free")
            local info = room:Info()
            assert(#info.players == 1 and info.watchers == 1)
        end
    },
    {
        name = "spectators see every player, even hidden ones",
        run = function()
            local room = Room(1, { mode = "ffa" })
            local a, b, w = client("a", "Alice"), client("b", "Bob"), client("w", "Watcher")
            room:Add(a)
            room:Add(b)
            room:Watch(w)
            room:Update(0.1)
            assert(w.state and #w.state.p == 2, "both players are sent")
        end
    },
    {
        name = "watching bots fills every slot with bots and the match starts by itself",
        run = function()
            local host = Host({ address = "127.0.0.1", port = 6853 })
            local w = client("w", "Watcher")
            host:matchmake(w, { spectate = true, bot = "easy", mode = "teams" })
            local room = w.room
            assert(room and room.practice and #room.bots == Config.modes.teams.players)
            for _ = 1, Config.countdownTicks + 10 do room:Update(1 / Config.tickRate) end
            assert(room.world.phase == "playing", "phase " .. room.world.phase)
        end
    },
    {
        name = "watching without a game tells the client there is nothing to watch",
        run = function()
            local host = Host({ address = "127.0.0.1", port = 6854 })
            local w = client("w", "Watcher")
            host:matchmake(w, { spectate = true })
            assert(not w.room and w.inbox[1].kind == "error")
        end
    },
    {
        name = "spectators can leave without touching the game",
        run = function()
            local room = Room(1, { mode = "duel" })
            local a, w = client("a", "Alice"), client("w", "Watcher")
            room:Add(a)
            room:Watch(w)
            room:Remove(w)
            assert(not w.room and not w.spectator and room.world.players[a.slot] and room:Info().watchers == 0)
        end
    }
}
