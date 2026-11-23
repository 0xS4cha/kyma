local Class = require("src.core.class")
local Protocol = require("src.net.protocol")
local Config = require("src.net.config")
local World = require("src.game.world")
local Inputs = require("src.net.inputs")

local Room = Class()

function Room:init(id)
    self.id = id
    self.members = {}
    self.world = World.new()
    self.accumulator = 0
    self.shots = {}
    self.noises = {}
    self.state = "waiting"
end

function Room:Full()
    return #self.members >= Config.roomPlayers
end

function Room:Empty()
    return #self.members == 0
end

function Room:freeSlot()
    for slot = 1, Config.roomPlayers do
        local taken = false
        for _, member in ipairs(self.members) do
            if member.slot == slot then taken = true break end
        end
        if not taken then return slot end
    end
end

function Room:Info()
    local players = {}
    for _, member in ipairs(self.members) do
        players[#players + 1] = { id = member.id, slot = member.slot, name = member.name }
    end
    table.sort(players, function(a, b) return a.slot < b.slot end)
    return { id = self.id, state = self.state, players = players }
end

function Room:Broadcast(kind, data)
    local raw = Protocol.Encode(kind, data)
    for _, member in ipairs(self.members) do
        member:SendRaw(raw)
    end
end

function Room:refresh()
    self.state = self:Full() and "duel" or "waiting"
    self:Broadcast("room", self:Info())
end

function Room:Add(client)
    if self:Full() then
        return false, "Room is full"
    end
    local slot = self:freeSlot()
    client.room = self
    client.slot = slot
    self.members[#self.members + 1] = client
    self.world:add(slot, client.name)
    client:Send("joined", { room = self.id, slot = slot, tick = self.world.tick, tickRate = Config.tickRate })
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
    Logger:info("room", string.format("%s left room %d", tostring(client.name), self.id))
    client.room = nil
    client.slot = nil
    self:refresh()
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
            p = view.players, d = view.items, sc = view.score, s = seen, n = heard, l = view.aims
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
    end
end

function Room:Update(dt)
    local step = 1 / Config.tickRate
    self.accumulator = math.min(self.accumulator + dt, step * 8)
    while self.accumulator >= step do
        self.accumulator = self.accumulator - step
        self.world:step()
        self:flushEvents()
        if self.world.tick % Config.snapshotTicks == 0 then
            self:sendState()
        end
    end
end

return Room
