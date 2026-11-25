local Class = require("src.core.class")
local Protocol = require("src.net.protocol")
local Config = require("src.net.config")
local World = require("src.game.world")
local Inputs = require("src.net.inputs")
local Bot = require("src.game.bot")
local Player = require("src.game.player")
local Combat = require("src.game.combat")
local Text = require("src.core.text")
local GameConfig = require("src.config.game")
local Maps = require("src.maps.index")
local Arena = require("src.game.arena")
local Loadout = require("src.config.loadout")
local WeaponConfig = require("src.config.weapons")

local Room = Class()

local BOT_NAMES = { "Nova", "Echo", "Vega", "Orion", "Lyra", "Atlas", "Iris", "Juno" }

function Room:init(id, options)
    options = type(options) == "table" and options or {}
    self.id = id
    self.mode = GameConfig.modes[options.mode or ""] and options.mode or "duel"
    self.rules = GameConfig.modes[self.mode]
    self.map = Maps.valid(self.rules.map or options.map)
    self.members = {}
    self.world = World.new(Arena.new(Maps.get(self.map)), self.mode, true, options.rules)
    self.bots = {}
    self.practice = type(options.bot) == "string"
    self.matched = options.matched == true
    if self.practice then
        local count = self.rules.players - (options.watch and 0 or 1)
        for k = 1, count do
            local slot = self.rules.players - k + 1
            local bot = Bot.new(slot, options.bot, id * 104729 + os.time() + k)
            bot.label = count == 1 and bot:name() or BOT_NAMES[k] or ("Bot " .. k)
            self.bots[#self.bots + 1] = bot
            local kit = { w = (id * 7 + slot * 3) % #WeaponConfig.order + 1, m = (slot % #Loadout.mods) + 1 }
            self.world:add(slot, bot.label, self:teamFor(), kit).bot = true
        end
    end
    self.accumulator = 0
    self.chat = {}
    self.shots = {}
    self.noises = {}
    self.state = "waiting"
end

function Room:Max()
    return self.rules.players
end

function Room:Count()
    local players = 0
    for _, member in ipairs(self.members) do
        if not member.spectator then players = players + 1 end
    end
    return players + #self.bots
end

--- @return number
function Room:Watchers()
    local count = 0
    for _, member in ipairs(self.members) do
        if member.spectator then count = count + 1 end
    end
    return count
end

--- @param client table
--- @return boolean
function Room:Watch(client)
    client.room = self
    client.slot = nil
    client.spectator = true
    self.members[#self.members + 1] = client
    client:Send("chatlog", { messages = self.chat })
    client:Send("joined", {
        room = self.id, spectator = true, tick = self.world.tick, tickRate = Config.tickRate,
        mode = self.mode, map = self.map, ru = Loadout.pack(self.world.options)
    })
    Logger:info("room", string.format("%s watches room %d", client.name, self.id))
    self:refresh()
    return true
end

function Room:Full()
    return self:Count() >= self:Max()
end

function Room:Empty()
    return #self.members == 0
end

function Room:teamFor()
    if not self.rules.teams then return nil end
    local sizes = { 0, 0 }
    for _, p in pairs(self.world.players) do
        if p.team then sizes[p.team] = sizes[p.team] + 1 end
    end
    return sizes[1] <= sizes[2] and 1 or 2
end

function Room:freeSlot()
    for slot = 1, self:Max() do
        if not self.world.players[slot] then return slot end
    end
end

function Room:Info()
    local players = {}
    for _, member in ipairs(self.members) do
        if not member.spectator then
            local p = self.world.players[member.slot]
            players[#players + 1] = { id = member.id, slot = member.slot, name = member.name, team = p and p.team, look = member.look }
        end
    end
    for _, bot in ipairs(self.bots) do
        local p = self.world.players[bot.slot]
        players[#players + 1] = {
            id = "bot" .. bot.slot, slot = bot.slot, name = bot.label, bot = true, team = p and p.team,
            look = { h = bot.slot % 4 + 1, a = bot.slot % 8 + 1 }
        }
    end
    table.sort(players, function(a, b) return a.slot < b.slot end)
    return {
        id = self.id, state = self.state, players = players, practice = self.practice, matched = self.matched or nil, tl = self.label,
        mode = self.mode, map = self.map, max = self:Max(), watchers = self:Watchers(), ru = Loadout.pack(self.world.options)
    }
end

function Room:Broadcast(kind, data)
    local raw = Protocol.Encode(kind, data)
    for _, member in ipairs(self.members) do
        member:SendRaw(raw)
    end
end

function Room:refresh()
    self.state = self:Count() >= 2 and "playing" or "waiting"
    self:Broadcast("room", self:Info())
end

--- @param client table
--- @param team number? side to put the player on in team modes, the smaller team when nil
function Room:Add(client, team)
    if self:Full() then
        return false, "Room is full"
    end
    local slot = self:freeSlot()
    client.room = self
    client.slot = slot
    self.members[#self.members + 1] = client
    local player = self.world:add(slot, client.name, team or self:teamFor(), client.loadout)
    client:Send("chatlog", { messages = self.chat })
    client:Send("joined", {
        room = self.id, slot = slot, tick = self.world.tick, tickRate = Config.tickRate,
        mode = self.mode, map = self.map, team = player.team, angle = Player.packAngle(player.angle),
        ru = Loadout.pack(self.world.options),
        x = player.x, y = player.y
    })
    Logger:info("room", string.format("%s joined room %d as slot %d", client.name, self.id, slot))
    self:refresh()
    return true
end

function Room:Remove(client)
    for k, member in ipairs(self.members) do
        if member == client then
            table.remove(self.members, k)
            break
        end
    end
    if client.slot then
        self.world:remove(client.slot)
    end
    self.held = nil
    Logger:info("room", string.format("%s left room %d", tostring(client.name), self.id))
    client.room = nil
    client.slot = nil
    client.spectator = nil
    self:refresh()
end

--- @param client table
--- @param data any
--- @return boolean
function Room:Chat(client, data)
    if type(data) ~= "table" then return false end
    local text = Text.clean(data.text, Config.chatLength)
    if not text or text == "" then return false end
    local now = love.timer.getTime()
    local recent = {}
    for _, at in ipairs(client.chatTimes or {}) do
        if now - at < Config.chatWindow then recent[#recent + 1] = at end
    end
    client.chatTimes = recent
    if #recent >= Config.chatBurst then
        client:Send("error", { message = "You are sending messages too fast" })
        return false
    end
    recent[#recent + 1] = now
    local player = client.slot and self.world.players[client.slot]
    local team = data.team == true and self.rules.teams and player and player.team or nil
    local message = { n = client.name, s = client.slot, x = text, tm = team and 1 or nil }
    if not team then
        self.chat[#self.chat + 1] = message
        if #self.chat > Config.chatHistory then table.remove(self.chat, 1) end
        self:Broadcast("chat", message)
        return true
    end
    local raw = Protocol.Encode("chat", message)
    for _, member in ipairs(self.members) do
        local other = member.slot and self.world.players[member.slot]
        if other and other.team == team then member:SendRaw(raw) end
    end
    return true
end

--- @return number
function Room:Humans()
    local count = 0
    for _, member in ipairs(self.members) do
        if not member.spectator then count = count + 1 end
    end
    return count
end

--- @param client table
--- @param data any
--- @return boolean
function Room:Hold(client, data)
    local on = type(data) == "table" and data.on == true
    if on and not (self.practice and client.slot and self:Humans() == 1 and self:Watchers() == 0) then return false end
    self.held = on or nil
    self.accumulator = 0
    return true
end

function Room:Ready(client, data)
    if not client.slot then return end
    self.world:setReady(client.slot, type(data) == "table" and data.ready == true)
end

function Room:Input(client, data)
    if not client.slot then return end
    self.world:queue(client.slot, Inputs.batch(data))
end

function Room:sendState()
    local tick = self.world.tick
    local shots, noises = self.shots, self.noises
    self.shots, self.noises = {}, {}
    for _, member in ipairs(self.members) do
        local view = self.world:snapshot(member.slot)
        local seen = {}
        for _, shot in ipairs(shots) do
            if self.world:shows(member.slot, shot) then
                seen[#seen + 1] = shot
            end
        end
        local heard = {}
        for _, noise in ipairs(noises) do
            if self.world:hears(member.slot, noise) then
                heard[#heard + 1] = { x = noise.x, y = noise.y, k = noise.kind }
            end
        end
        member:Stream("state", {
            t = tick, k = self.world:ack(member.slot),
            p = view.players, d = view.items, sc = view.score, s = seen, n = heard, l = view.aims,
            dd = view.doors, gg = view.glass, ts = view.teams, ov = view.over, ph = view.phase, rd = view.ready,
            gd = view.gadgets, sm = view.smokes, ro = view.round
        })
    end
end

function Room:flushEvents()
    local events, shots, noises = self.world:drain()
    for _, shot in ipairs(shots) do
        self.shots[#self.shots + 1] = shot
    end
    for _, noise in ipairs(noises) do
        self.noises[#self.noises + 1] = noise
    end
    for _, data in ipairs(events) do
        self:Broadcast(data.kind, data)
        if data.kind == "over" and self.onOver then
            self.onOver(self, data)
        end
        if data.kind == "kill" and data.k and data.k ~= data.v then
            for _, member in ipairs(self.members) do
                if member.slot == data.v then
                    local recording = Combat.killcam(self.world, data.k, data.v)
                    if recording then member:Send("killcam", recording) end
                end
            end
        end
    end
end

function Room:Update(dt)
    if self.held then return end
    local step = 1 / Config.tickRate
    self.accumulator = math.min(self.accumulator + dt, step * 8)
    while self.accumulator >= step do
        self.accumulator = self.accumulator - step
        for _, bot in ipairs(self.bots) do
            self.world:queue(bot.slot, { bot:command(self.world) })
        end
        self.world:step()
        self:flushEvents()
        if self.world.tick % Config.snapshotTicks == 0 then
            self:sendState()
        end
    end
end

return Room
