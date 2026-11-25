local Room = require("src.server.room")
local Protocol = require("src.net.protocol")
local NetConfig = require("src.net.config")

local Client = {}
Client.__index = Client
function Client:Send(kind, data) self.inbox[#self.inbox + 1] = { kind = kind, data = data } end
function Client:SendRaw(raw)
    local kind, data = Protocol.Decode(raw)
    self.inbox[#self.inbox + 1] = { kind = kind, data = data }
end
function Client:Stream() end

local function client(id, name)
    return setmetatable({ id = id, name = name, inbox = {} }, Client)
end

local function received(c, kind)
    local list = {}
    for _, m in ipairs(c.inbox) do
        if m.kind == kind then list[#list + 1] = m.data end
    end
    return list
end

return {
    {
        name = "chat messages are cleaned, trimmed and sent to everyone",
        run = function()
            local room = Room(1, { mode = "ffa" })
            local a, b = client("a", "Alice"), client("b", "Bob")
            room:Add(a)
            room:Add(b)
            room:Chat(a, { text = "  hello\nthere  " .. string.rep("x", 300) })
            local got = received(b, "chat")
            assert(#got == 1 and got[1].n == "Alice")
            assert(not got[1].x:find("\n") and #got[1].x <= NetConfig.chatLength and got[1].x:sub(1, 5) == "hello")
            assert(not room:Chat(a, { text = "   " }), "blank messages are dropped")
        end
    },
    {
        name = "senders are limited to a burst of messages",
        run = function()
            local room = Room(1, { mode = "ffa" })
            local a = client("a", "Alice")
            room:Add(a)
            local sent = 0
            for k = 1, NetConfig.chatBurst + 3 do
                if room:Chat(a, { text = "spam " .. k }) then sent = sent + 1 end
            end
            assert(sent == NetConfig.chatBurst)
            assert(#received(a, "error") >= 1, "the sender is told to slow down")
        end
    },
    {
        name = "team messages only reach teammates",
        run = function()
            local room = Room(1, { mode = "teams" })
            local a, b, c = client("a", "Alice"), client("b", "Bob"), client("c", "Carol")
            room:Add(a)
            room:Add(b)
            room:Add(c)
            local teams = {}
            for _, m in ipairs({ a, b, c }) do teams[m.id] = room.world.players[m.slot].team end
            local mate, enemy
            for _, m in ipairs({ b, c }) do
                if teams[m.id] == teams.a then mate = m else enemy = m end
            end
            room:Chat(a, { text = "push left", team = true })
            assert(#received(mate, "chat") == 1 and received(mate, "chat")[1].tm == 1)
            assert(#received(enemy, "chat") == 0, "the enemy team doesn't see it")
        end
    },
    {
        name = "players joining later get the public history",
        run = function()
            local room = Room(1, { mode = "ffa" })
            local a = client("a", "Alice")
            room:Add(a)
            room:Chat(a, { text = "first" })
            local b = client("b", "Bob")
            room:Add(b)
            local log = received(b, "chatlog")[1]
            assert(log and #log.messages == 1 and log.messages[1].x == "first")
        end
    }
}
