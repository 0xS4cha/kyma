local enet = require("enet")
local Class = require("src.core.class")
local Protocol = require("src.net.protocol")
local NetConfig = require("src.net.config")
local Address = require("src.net.address")

--- Keeps a small connection to one server open and asks it for the games it
--- runs every few seconds, for the server browser of the Multiplayer menu.
local Browser = Class()

function Browser:init()
    self.address = nil
    self.host = nil
    self.peer = nil
    self.connected = false
    self.games = {}
    self.server = nil
    self.error = nil
    self.loaded = false
    self.askedAt = -math.huge
    self.retryAt = nil
end

--- Starts browsing a server, or stops with nil. Browsing the same address again keeps the list.
--- @param address string?
function Browser:Watch(address)
    address = Address.normalize(address)
    if address == self.address then return end
    self:Close()
    self.address = address
    if address then self:open() end
end

function Browser:open()
    self.retryAt = nil
    self.host = enet.host_create()
    local ok, peer = pcall(self.host.connect, self.host, self.address, NetConfig.channels)
    if not ok or not peer then
        self.host = nil
        self.error = "Invalid server address"
        return
    end
    self.peer = peer
end

function Browser:Close()
    if self.peer then
        self.peer:disconnect_now()
        self.host:flush()
    end
    self.host, self.peer = nil, nil
    self.connected = false
    self.address = nil
    self.games = {}
    self.server = nil
    self.error = nil
    self.loaded = false
    self.askedAt = -math.huge
    self.retryAt = nil
    self.since = nil
end

--- Asks for the list again at once.
function Browser:Refresh()
    self.askedAt = -math.huge
end

function Browser:ask()
    local now = love.timer.getTime()
    if not self.connected then return end
    self.since = self.since or now
    if not self.loaded and not self.error and now - self.since > 5 then
        self.error = "This server does not list its games, it may need an update"
    end
    if now - self.askedAt < NetConfig.browseInterval then return end
    self.askedAt = now
    self.peer:send(Protocol.Encode("rooms", { v = NetConfig.version }), NetConfig.reliable, "reliable")
end

--- @param data table
function Browser:receive(data)
    if type(data.error) == "string" then
        self.error = data.error
        self.games = {}
        return
    end
    self.error = nil
    self.loaded = true
    self.server = type(data.server) == "table" and data.server or nil
    local games = {}
    for _, game in ipairs(type(data.list) == "table" and data.list or {}) do
        if type(game) == "table" and tonumber(game.id) then
            games[#games + 1] = {
                address = self.address, room = tonumber(game.id),
                name = type(game.t) == "string" and game.t or ("Game " .. game.id),
                mode = game.m, map = game.map, locked = game.lk == true, phase = game.ph,
                players = tonumber(game.p) or 0, max = tonumber(game.x) or 0, watchers = tonumber(game.w) or 0
            }
        end
    end
    self.games = games
end

function Browser:Update()
    if not self.host then
        if self.retryAt and love.timer.getTime() >= self.retryAt then self:open() end
        return
    end
    local ok, event = pcall(self.host.service, self.host, 0)
    while ok and event do
        if event.type == "connect" then
            self.connected = true
            self.error = nil
        elseif event.type == "receive" then
            local kind, data = Protocol.Decode(event.data)
            if kind == "rooms" and type(data) == "table" then self:receive(data) end
        elseif event.type == "disconnect" then
            local address = self.address
            self:Close()
            self.address = address
            self.error = "Could not reach " .. tostring(address)
            self.retryAt = love.timer.getTime() + 3
            return
        end
        ok, event = pcall(self.host.service, self.host, 0)
    end
    self:ask()
end

--- @return table[]
function Browser:List()
    return self.games
end

return Browser
