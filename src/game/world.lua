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
function World.new(arena, mode)
    mode = Config.modes[mode or ""] and mode or "duel"
    local world = setmetatable({
        arena = arena or Arena.new(),
        mode = mode,
        rules = Config.modes[mode],
        tick = 0,
        dt = 1 / NetConfig.tickRate,
        players = {},
        inputs = {},
        teamScore = { 0, 0 },
        over = nil
    }, World)
    Combat.setup(world)
    return world
end

--- @param a number
--- @param b number
--- @return boolean
function World:enemies(a, b)
    if a == b then return false end
    if not self.rules.teams then return true end
    local pa, pb = self.players[a], self.players[b]
    return not pa or not pb or pa.team ~= pb.team
end

--- @param player table
--- @return table
function World:spawnPoint(player)
    local candidates = {}
    for _, spawn in ipairs(self.arena.spawns) do
        if not self.rules.teams or not spawn.team or spawn.team == player.team then
            candidates[#candidates + 1] = spawn
        end
    end
    if #candidates == 0 then candidates = self.arena.spawns end
    local best, bestScore
    local count = #candidates
    for k = 1, count do
        local spawn = candidates[(k + player.slot - 2) % count + 1]
        local nearest = math.huge
        for slot, other in pairs(self.players) do
            if other ~= player and other.hp > 0 and other.dead == 0 and self:enemies(player.slot, slot) then
                nearest = math.min(nearest, (other.x - spawn.x) ^ 2 + (other.y - spawn.y) ^ 2)
            end
        end
        if not bestScore or nearest > bestScore then
            best, bestScore = spawn, nearest
        end
    end
    return best
end

--- @param slot number
--- @param name string
--- @param team number?
--- @return table
function World:add(slot, name, team)
    local player = Player.new(slot, name, { x = 0, y = 0, angle = 0 })
    player.team = self.rules.teams and team or nil
    self.players[slot] = player
    Player.respawn(player, self:spawnPoint(player))
    self.inputs[slot] = { queue = {}, last = 0, acked = 0, credit = 0 }
    self.score[slot] = 0
    return player
end

--- @param winner number
--- @param team boolean
function World:finish(winner, team)
    self.over = { winner = winner, team = team, timer = Config.matchEndTicks }
    self.events[#self.events + 1] = { kind = "over", w = winner, tm = team and 1 or 0 }
end

function World:restart()
    self.over = nil
    self.teamScore = { 0, 0 }
    for slot in pairs(self.score) do self.score[slot] = 0 end
    for k = #self.items, 1, -1 do
        if not self.items[k].pad then table.remove(self.items, k) end
    end
    for _, p in pairs(self.players) do
        Player.respawn(p, self:spawnPoint(p))
    end
    self.events[#self.events + 1] = { kind = "restart" }
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
        if player.weapon then
            Combat.fire(self, player, command)
        else
            Combat.melee(self, player, command)
        end
    end
    self:footsteps(player, command)
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
    if self.over then
        self.over.timer = self.over.timer - 1
        if self.over.timer <= 0 then
            self:restart()
        end
    end
end

--- @param player table
--- @param command table
function World:footsteps(player, command)
    local noise = Config.noise
    if player.dead > 0 then return end
    if player.dash == Config.dash.ticks - 1 then
        Combat.noise(self, "dash", player.x, player.y, player.slot)
        return
    end
    if player.slide == Config.slide.ticks - 1 then
        Combat.noise(self, "slide", player.x, player.y, player.slot)
        return
    end
    if command.k == 1 then return end
    player.stride = (player.stride or 0) + 1
    local speed = math.sqrt(player.vx * player.vx + player.vy * player.vy)
    if speed < noise.stepSpeed then
        player.stride = 0
    elseif player.stride >= noise.stepTicks then
        player.stride = 0
        Combat.noise(self, "step", player.x, player.y, player.slot)
    end
end

--- @param listener number
--- @param noise table
--- @return boolean
function World:hears(listener, noise)
    if noise.source == listener then return false end
    if noise.source and not self:enemies(listener, noise.source) then return false end
    local p = self.players[listener]
    if not p or p.dead > 0 then return false end
    local dx, dy = noise.x - p.x, noise.y - p.y
    if dx * dx + dy * dy > noise.radius * noise.radius then return false end
    if noise.source and self.players[noise.source] and self:visible(listener, noise.source) then return false end
    return true
end

--- @param viewer number
--- @param shot table
--- @return boolean
function World:shows(viewer, shot)
    if shot.q ~= 1 or shot.o == viewer then return true end
    return self.players[shot.o] ~= nil and self:visible(viewer, shot.o)
end

--- @return table[], table[], table[]
function World:drain()
    local events, shots, noises = self.events, self.shots, self.noises
    self.events, self.shots, self.noises = {}, {}, {}
    return events, shots, noises
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
function World:sees(viewer, slot)
    local from, target = self.players[viewer], self.players[slot]
    if not from or not target or from.dead > 0 then return false end
    local vision = Config.vision
    return Vision.sees(self.arena, from, target.x, target.y, Config.player.radius, vision.serverMargin, vision.serverNearRadius)
end

--- @param viewer number?
--- @param slot number
--- @return boolean, boolean
function World:visible(viewer, slot)
    if not viewer or viewer == slot then return true, false end
    if not self:enemies(viewer, slot) then return true, false end
    if self:sees(viewer, slot) then return true, false end
    if self.rules.teams then
        for ally in pairs(self.players) do
            if ally ~= viewer and not self:enemies(viewer, ally) and self:sees(ally, slot) then
                return true, true
            end
        end
    end
    return false, false
end

--- @param viewer number?
--- @return table
function World:snapshot(viewer)
    local players = {}
    for slot, p in pairs(self.players) do
        local seen, shared = self:visible(viewer, slot)
        if seen then
            local entry = {
                i = slot, x = p.x, y = p.y, a = Player.packAngle(p.angle), u = p.vx, v = p.vy,
                e = p.dash, j = p.slide, o = p.dead, g = Weapons.pack(p.weapon), h = p.hp, t = p.team, st = p.stun,
                sp = shared and 1 or nil
            }
            if slot == viewer then
                entry.w, entry.m, entry.n = p.cooldown, p.dashX, p.dashY
                entry.sx, entry.sy = p.slideX, p.slideY
                entry.mc = p.meleeCooldown
                entry.q, entry.r, entry.l, entry.c = p.ammo, p.reserve, p.reload, p.fireCooldown
                entry.z = p.trigger and 1 or 0
            end
            players[#players + 1] = entry
        end
    end
    table.sort(players, function(a, b) return a.i < b.i end)

    local aims = {}
    for slot, p in pairs(self.players) do
        local def = Weapons.def(p.weapon)
        if viewer and slot ~= viewer and def and def.exposed and p.dead == 0 and not self:visible(viewer, slot) then
            aims[#aims + 1] = { i = slot, x = p.x, y = p.y, a = Player.packAngle(p.angle), g = Weapons.pack(p.weapon) }
        end
    end

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

    local doors, glass = self.arena:state()
    local over = self.over and { w = self.over.winner, tm = self.over.team and 1 or 0, c = self.over.timer } or nil
    return {
        players = players, items = items, score = score, aims = aims, doors = doors, glass = glass,
        teams = self.rules.teams and self.teamScore or nil, over = over
    }
end

return World
