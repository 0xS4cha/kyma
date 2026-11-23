local Class = require("src.core.class")
local UUID = require("src.core.uuid")
local Protocol = require("src.net.protocol")
local Config = require("src.net.config")

local Client = Class()

function Client:init(peer)
    self.peer = peer
    self.id = UUID.getUUID()
    self.name = nil
    self.room = nil
    self.slot = nil
    self.connectedAt = love.timer.getTime()
end

function Client:Send(kind, data)
    self.peer:send(Protocol.Encode(kind, data), Config.reliable, "reliable")
end

function Client:SendRaw(raw)
    self.peer:send(raw, Config.reliable, "reliable")
end

function Client:Stream(kind, data)
    self.peer:send(Protocol.Encode(kind, data), Config.unreliable, "unreliable")
end

function Client:Disconnect()
    self.peer:disconnect_later()
end

function Client:Address()
    return tostring(self.peer)
end

function Client:Ping()
    return self.peer:round_trip_time()
end

return Client
