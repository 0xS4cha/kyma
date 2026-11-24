local GM = require("src.core.index")
local enet = require("enet")
local Protocol = require("src.net.protocol")
local NetConfig = require("src.net.config")
local LocalServer = require("src.modules.multiplayer.localserver")
local Lan = require("src.modules.multiplayer.lan")
local Address = require("src.net.address")

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
    self.queueOptions = nil
    self.lan = Lan()
    self.lanHost = false
    self.lanAddress = nil
    self.listening = false
    self.announceAt = 0

    self:On("welcome", function(data)
        self.id = data.id
        self.state = "online"
        self.error = nil
        self:Send("queue", self.queueOptions)
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

function GM.Multiplayer:PlayLocal(name, lan, options)
    self.error = nil
    self.queueOptions = options
    self.lanHost = lan == true
    self.lanAddress = self.lanHost and Address.lan() or nil
    self.pending = { name = name }
    self.localServer:Start(function(port)
        if not self.pending then return end
        self.pending = nil
        self:Connect(NetConfig.localAddress .. ":" .. port, name, true)
    end, lan)
end

--- @param address string
--- @param name string
function GM.Multiplayer:Join(address, name)
    self.queueOptions = nil
    self.lanHost = false
    return self:Connect(address, name)
end

function GM.Multiplayer:Leave()
    self:Send("leave")
    self:Flush()
    self:Disconnect()
    self.localServer:Stop()
    self.pending = nil
    self.isLocal = false
    self.lanHost = false
    self.error = nil
end

--- @param enabled boolean
function GM.Multiplayer:Browse(enabled)
    self.listening = enabled == true
end

--- @return table[]
function GM.Multiplayer:LanGames()
    return self.lan:List()
end

--- @return string?
function GM.Multiplayer:LanEndpoint()
    if not self.lanHost or not self.localServer:Running() then return nil end
    return (self.lanAddress or "?") .. ":" .. tostring(self.localServer.port)
end

function GM.Multiplayer:announce()
    local room = GM.Session and GM.Session.room
    if not self.lanHost or not room or room.practice or not self.localServer:Running() then return end
    local now = love.timer.getTime()
    if now - self.announceAt < NetConfig.discoveryInterval then return end
    self.announceAt = now
    self.lan:Announce({
        port = self.localServer.port,
        room = room.id,
        players = #(room.players or {}),
        max = room.max or NetConfig.roomPlayers,
        name = self.name .. " - " .. ((require("src.config.game").modes[room.mode or ""] or {}).name or "Duel")
            .. " - " .. require("src.maps.index").get(room.map).name,
        address = self.lanAddress
    })
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
    self.lan:Listen(self.listening)
    self.lan:Poll()
    self:announce()
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
            local settings = GM.Menu and GM.Menu.settings or {}
            self:Send("hello", { name = self.name, version = NetConfig.version, look = { h = settings.head, a = settings.accent } })
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
    self:Leave()
    self.lan:Close()
end

return GM.Multiplayer
