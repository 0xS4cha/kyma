local GM = require("src.core.index")
local enet = require("enet")
local Protocol = require("src.net.protocol")
local NetConfig = require("src.net.config")
local LocalServer = require("src.modules.multiplayer.localserver")

GM.Multiplayer = {}

GM.Modules:Register("Multiplayer", 20)

function GM.Multiplayer:Initialize()
    self.host = nil
    self.peer = nil
    self.connected = false
    self.state = "offline"
    self.address = nil
    self.name = "Player"
    self.id = nil
    self.error = nil
    self.handlers = {}
    self.localServer = LocalServer()
    self.isLocal = false
    self.pending = nil

    self:On("welcome", function(data)
        self.id = data.id
        self.state = "online"
        self.error = nil
        self:Send("queue")
    end)
    self:On("error", function(data)
        self.error = tostring(data.message)
        Logger:warn("multiplayer", self.error)
    end)
end

function GM.Multiplayer:On(kind, handler)
    self.handlers[kind] = self.handlers[kind] or {}
    table.insert(self.handlers[kind], handler)
end

function GM.Multiplayer:Connect(address, name, isLocal)
    self:Disconnect()
    self.name = name or self.name
    self.isLocal = isLocal == true
    self.address = address and address ~= "" and address or ("localhost:" .. NetConfig.port)
    if not self.address:find(":", 1, true) then
        self.address = self.address .. ":" .. NetConfig.port
    end
    self.error = nil
    self.host = enet.host_create()
    local ok, peer = pcall(self.host.connect, self.host, self.address, NetConfig.channels)
    if not ok or not peer then
        self.host = nil
        self.error = "Invalid server address"
        return false
    end
    self.peer = peer
    self.state = "connecting"
    Logger:info("multiplayer", "Connecting to " .. self.address)
    return true
end

function GM.Multiplayer:Disconnect()
    if self.peer then
        self.peer:disconnect_now()
        self.host:flush()
    end
    self.host = nil
    self.peer = nil
    self.connected = false
    self.state = "offline"
    self.id = nil
end

function GM.Multiplayer:PlayLocal(name, lan)
    self.error = nil
    self.pending = { name = name }
    self.localServer:Start(function(port)
        if not self.pending then return end
        self.pending = nil
        self:Connect(NetConfig.localAddress .. ":" .. port, name, true)
    end, lan)
end

function GM.Multiplayer:Send(kind, data)
    if not self.connected then return false end
    local ok, raw = pcall(Protocol.Encode, kind, data)
    if not ok then
        Logger:warn("multiplayer", "Failed to encode " .. kind .. ": " .. tostring(raw))
        return false
    end
    self.peer:send(raw, NetConfig.reliable, "reliable")
    return true
end

function GM.Multiplayer:Stream(kind, data)
    if not self.connected then return false end
    self.peer:send(Protocol.Encode(kind, data), NetConfig.unreliable, "unreliable")
    return true
end

function GM.Multiplayer:Ping()
    if not self.peer or self.state ~= "online" then return nil end
    return self.peer:round_trip_time()
end

function GM.Multiplayer:Flush()
    if self.host then
        self.host:flush()
    end
end

function GM.Multiplayer:dispatch(kind, data)
    local handlers = self.handlers[kind]
    if not handlers then
        Logger:trace("multiplayer", "Unhandled message " .. kind)
        return
    end
    for _, handler in ipairs(handlers) do
        handler(data or {})
    end
end

function GM.Multiplayer:onConnectionLost()
    local wasOnline = self.state == "online"
    local address = self.address
    self:Disconnect()
    if not self.error then
        self.error = wasOnline and "Connection to the server lost" or "Could not reach " .. tostring(address)
    end
    Logger:warn("multiplayer", self.error)
    self:dispatch("disconnected", { message = self.error })
end

function GM.Multiplayer:Think()
    self.localServer:Update()
    if self.pending and self.localServer.state == "failed" then
        self.pending = nil
        self.error = self.localServer.error or "The local game server failed to start"
    end
    self:Poll()
end

function GM.Multiplayer:Poll()
    if not self.host then return end
    local event = self.host:service(0)
    while event do
        if event.type == "connect" then
            self.connected = true
            Logger:info("multiplayer", "Connected to " .. tostring(event.peer))
            self:Send("hello", { name = self.name, version = NetConfig.version })
        elseif event.type == "receive" then
            local kind, data = Protocol.Decode(event.data)
            if kind then
                self:dispatch(kind, data)
            end
        elseif event.type == "disconnect" then
            self:onConnectionLost()
            return
        end
        if not self.host then return end
        event = self.host:service(0)
    end
end

function GM.Multiplayer:Shutdown()
    self:Send("leave")
    self:Flush()
    self:Disconnect()
    self.localServer:Stop()
end

return GM.Multiplayer
