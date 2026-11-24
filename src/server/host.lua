local Class = require("src.core.class")
local Server = require("src.server.server")
local Room = require("src.server.room")
local Config = require("src.net.config")

local Host = Class()

function Host:init(options)
    options = options or {}
    self.server = Server({ address = options.address, port = options.port, maxPeers = options.maxPeers, channels = Config.channels })
    self.rooms = {}
    self.nextRoomId = 1
    self:bind()
end

function Host:Start()
    return self.server:Start()
end

function Host:Stop()
    self.server:Stop()
end

function Host:Think(dt)
    self.server:Think(dt)
end

function Host:leaveRoom(client)
    local room = client.room
    if not room then return end
    room:Remove(client)
    if room:Empty() then
        self.rooms[room.id] = nil
        Logger:info("server", "Room closed", room.id)
    end
end

function Host:matchmake(client, options)
    options = type(options) == "table" and options or {}
    local practice = type(options.bot) == "string" and options.bot or nil
    local mode = type(options.mode) == "string" and options.mode or nil
    local map = type(options.map) == "string" and options.map or nil
    local best
    for _, room in pairs(self.rooms) do
        local fits = (not mode or room.mode == mode) and (not map or room.map == map)
        if not practice and not room.practice and fits and not room:Full() and (not best or room.id < best.id) then
            best = room
        end
    end
    if not best then
        best = Room(self.nextRoomId, { bot = practice, mode = mode, map = map })
        self.nextRoomId = self.nextRoomId + 1
        self.rooms[best.id] = best
        Logger:info("server", "Room created", best.id)
    end
    local ok, err = best:Add(client)
    if not ok then
        client:Send("error", { message = err })
    end
end

function Host:bind()
    local server = self.server

    server:On("hello", function(client, data)
        data = type(data) == "table" and data or {}
        if data.version ~= Config.version then
            client:Send("error", { message = "Version mismatch: server is v" .. Config.version, fatal = true })
            client:Disconnect()
            return
        end
        local name = type(data.name) == "string" and data.name:gsub("[%c]", ""):sub(1, 24) or ""
        client.name = name ~= "" and name or "Player"
        client:Send("welcome", { id = client.id })
    end)

    server:On("queue", function(client, data)
        if not client.name or client.room then return end
        self:matchmake(client, data)
    end)

    server:On("ready", function(client, data)
        if client.room then
            client.room:Ready(client, data)
        end
    end)

    server:On("leave", function(client)
        self:leaveRoom(client)
    end)

    server:On("input", function(client, data)
        if client.room then
            client.room:Input(client, data)
        end
    end)

    server:On("update", function(_, dt)
        for _, room in pairs(self.rooms) do
            room:Update(dt)
        end
    end)

    server:On("disconnect", function(client)
        self:leaveRoom(client)
    end)
end

return Host
