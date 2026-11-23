local Arena = require("src.game.arena")
local Player = require("src.game.player")
local Weapons = require("src.game.weapons")
local Combat = require("src.game.combat")
local Vision = require("src.game.vision")
local Config = require("src.config.game")
local NetConfig = require("src.net.config")

local World = {}
World.__index = World

--- @param arena table?
--- @return table
function World.new(arena)
    local world = setmetatable({
        arena = arena or Arena.new(),
        tick = 0,
        dt = 1 / NetConfig.tickRate,
        players = {},
        inputs = {}
    }, World)
    Combat.setup(world)
    return world
end

--- @param slot number
--- @param name string
--- @return table
function World:add(slot, name)
    local player = Player.new(slot, name, self.arena:spawn(slot))
    self.players[slot] = player
    self.inputs[slot] = { queue = {}, last = 0, acked = 0, credit = 0 }
    self.score[slot] = 0
    return player
end

--- @param slot number
function World:remove(slot)
    local player = self.players[slot]
    if player and player.dead == 0 then
        Combat.drop(self, player)
    end
    self.players[slot] = nil
    self.inputs[slot] = nil
    self.score[slot] = nil
end

--- @param player table
--- @param command table
function World:apply(player, command)
    if Player.step(player, command, self.arena, self.dt) then
        Combat.fire(self, player, command)
    end
    if command.t == 1 then
        Combat.throw(self, player)
    elseif command.e == 1 then
        Combat.pickup(self, player)
    end
end

--- @param slot number
--- @param commands table[]
function World:queue(slot, commands)
    local state = self.inputs[slot]
    if not state then return end
    for _, command in ipairs(commands) do
        if command.s > state.last then
            state.last = command.s
            state.queue[#state.queue + 1] = command
        end
    end
    while #state.queue > NetConfig.inputQueue do
        local dropped = table.remove(state.queue, 1)
        state.acked = dropped.s
    end
end

function World:step()
    self.tick = self.tick + 1
    local slots = {}
    for slot in pairs(self.players) do slots[#slots + 1] = slot end
    table.sort(slots)
    for _, slot in ipairs(slots) do
        local player = self.players[slot]
        local state = self.inputs[slot]
        state.credit = math.min(state.credit + 1, NetConfig.inputCredit)
        while state.credit >= 1 and #state.queue > 0 and self.players[slot] do
            local command = table.remove(state.queue, 1)
            self:apply(player, command)
            state.acked = command.s
            state.credit = state.credit - 1
        end
    end
    Combat.update(self)
    Combat.record(self)
end

--- @return table[]
function World:drain()
    local events, shots = self.events, self.shots
    self.events, self.shots = {}, {}
    return events, shots
end

--- @param slot number
--- @return number
function World:ack(slot)
    local state = self.inputs[slot]
    return state and state.acked or 0
end

--- @param viewer number?
--- @param slot number
--- @return boolean
function World:visible(viewer, slot)
    if not viewer or viewer == slot then return true end
    local from, target = self.players[viewer], self.players[slot]
    if not from or not target then return false end
    local vision = Config.vision
    return Vision.sees(self.arena, from, target.x, target.y, Config.player.radius, vision.serverMargin, vision.serverNearRadius)
end

--- @param viewer number?
--- @return table
function World:snapshot(viewer)
    local players = {}
    for slot, p in pairs(self.players) do
        if self:visible(viewer, slot) then
            local entry = {
                i = slot, x = p.x, y = p.y, a = Player.packAngle(p.angle), u = p.vx, v = p.vy,
                e = p.dash, o = p.dead, g = Weapons.pack(p.weapon), h = p.hp
            }
            if slot == viewer then
                entry.w, entry.m, entry.n = p.cooldown, p.dashX, p.dashY
                entry.q, entry.r, entry.l, entry.c = p.ammo, p.reserve, p.reload, p.fireCooldown
                entry.z = p.trigger and 1 or 0
            end
            players[#players + 1] = entry
        end
    end
    table.sort(players, function(a, b) return a.i < b.i end)

    local items = {}
    for _, item in ipairs(self.items) do
        items[#items + 1] = {
            i = item.id, k = Weapons.pack(item.kind), x = item.x, y = item.y,
            a = item.angle, f = item.flying and 1 or 0
        }
    end

    local score = {}
    for slot, kills in pairs(self.score) do
        score[#score + 1] = { i = slot, k = kills }
    end
    table.sort(score, function(a, b) return a.i < b.i end)

    return { players = players, items = items, score = score }
end

return World
