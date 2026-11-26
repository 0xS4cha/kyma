local Config = require("src.config.game")
local Player = require("src.game.player")
local Weapons = require("src.game.weapons")
local Vision = require("src.game.vision")
local Random = require("src.core.random")
local Nav = require("src.game.nav")

local Bot = {}
Bot.__index = Bot

local atan2, sqrt, abs, pi = math.atan2, math.sqrt, math.abs, math.pi

local function wrap(a)
    return (a + pi) % (2 * pi) - pi
end

local function distance(ax, ay, bx, by)
    return sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

--- @param slot number
--- @param level string
--- @param seed number?
--- @return table
function Bot.new(slot, level, seed)
    return setmetatable({
        slot = slot,
        level = Config.bots[level] and level or "medium",
        rng = Random.new(seed or slot * 7919),
        sequence = 0,
        aim = nil,
        seenFor = 0,
        lastSeen = nil,
        waypoint = nil,
        stuck = 0,
        lastX = nil,
        lastY = nil,
        strafe = 1,
        strafeTimer = 0,
        aimError = 0,
        errorTimer = 0,
        hp = nil,
        path = nil,
        pathGoal = nil,
        pathAge = 0
    }, Bot)
end

--- @return string
function Bot:name()
    return "Bot " .. Config.bots[self.level].name
end

function Bot:pickWaypoint(world)
    local objectives = world.arena.objectives
    local me = world.players[self.slot]
    local role = me and world.rounds and world.rounds.role(world, me)
    if role and #objectives > 0 then
        local objective = objectives[(self.slot + (world.round and world.round.number or 0)) % #objectives + 1]
        if role == "attack" then
            self.waypoint = { x = objective.x, y = objective.y }
        else
            local a = self.rng:random() * 2 * math.pi
            local r = 80 + self.rng:random() * 220
            local x, y = world.arena:resolve(objective.x + math.cos(a) * r, objective.y + math.sin(a) * r, 20)
            self.waypoint = { x = x, y = y }
        end
        return
    end
    local pads = world.arena.loot
    if #pads > 0 and self.rng:random() < 0.7 then
        local pad = pads[self.rng:random(#pads)]
        self.waypoint = { x = pad.x, y = pad.y }
        return
    end
    local grid = Nav.grid(world.arena)
    for _ = 1, 40 do
        local col, row = self.rng:random(grid.cols) - 1, self.rng:random(grid.rows) - 1
        if grid.open[row * grid.cols + col] then
            self.waypoint = { x = (col + 0.5) * Nav.CELL, y = (row + 0.5) * Nav.CELL }
            return
        end
    end
    self.waypoint = { x = world.arena.width / 2, y = world.arena.height / 2 }
end

function Bot:steer(world, me, gx, gy)
    local arena = world.arena
    if Nav.clear(arena, me.x, me.y, gx, gy) then
        self.path = nil
        return atan2(gy - me.y, gx - me.x)
    end
    self.pathAge = self.pathAge - 1
    local goal = self.pathGoal
    if not self.path or self.pathAge <= 0 or not goal or distance(goal.x, goal.y, gx, gy) > 60 then
        self.path = Nav.path(arena, me.x, me.y, gx, gy)
        self.pathGoal = { x = gx, y = gy }
        self.pathAge = 45
    end
    local path = self.path
    if not path or #path == 0 then
        return atan2(gy - me.y, gx - me.x)
    end
    while #path > 1 and (distance(me.x, me.y, path[1].x, path[1].y) < 24 or Nav.clear(arena, me.x, me.y, path[2].x, path[2].y)) do
        table.remove(path, 1)
    end
    return atan2(path[1].y - me.y, path[1].x - me.x)
end

function Bot:target(world, me)
    local best, bestDistance
    for slot, p in pairs(world.players) do
        if slot ~= self.slot and p.hp > 0 and p.dead == 0 and world:enemies(self.slot, slot) then
            local d = distance(me.x, me.y, p.x, p.y)
            if not bestDistance or d < bestDistance then
                best, bestDistance = p, d
            end
        end
    end
    return best, bestDistance
end

function Bot:nearestWeapon(world, me)
    local best, bestDistance
    for _, item in ipairs(world.items) do
        if item.kind ~= "ammo" and not item.flying then
            local d = distance(me.x, me.y, item.x, item.y)
            if not bestDistance or d < bestDistance then
                best, bestDistance = item, d
            end
        end
    end
    return best
end

--- @param world table
--- @return table
function Bot:command(world)
    self.sequence = self.sequence + 1
    local skill = Config.bots[self.level]
    local me = world.players[self.slot]
    local command = { s = self.sequence, f = 0, r = 0, a = 0, d = 0, b = 0, l = 0, t = 0, e = 0, k = 0 }
    if not me then return command end
    self.aim = self.aim or me.angle
    if me.dead > 0 then
        self.seenFor, self.lastSeen, self.hp = 0, nil, nil
        command.a = Player.packAngle(self.aim)
        return command
    end

    local hurt = self.hp and me.hp < self.hp
    self.hp = me.hp
    self.errorTimer = self.errorTimer - 1
    if self.errorTimer <= 0 then
        self.errorTimer = 30
        self.aimError = (self.rng:random() * 2 - 1) * skill.aimError
    end
    self.strafeTimer = self.strafeTimer - 1
    if self.strafeTimer <= 0 then
        self.strafeTimer = 40 + self.rng:random(50)
        self.strafe = self.rng:random() < 0.5 and -1 or 1
    end

    local target, range = self:target(world, me)
    local sees = target and (me.blind or 0) <= 0 and Vision.sees(world.arena, me, target.x, target.y, Config.player.radius)
    if sees then
        self.seenFor = self.seenFor + 1
        self.lastSeen = { x = target.x, y = target.y }
    else
        self.seenFor = 0
    end

    local desired
    local def = Weapons.def(me.weapon)
    if not def then
        local item = self:nearestWeapon(world, me)
        if sees and range < 160 then
            desired = atan2(target.y - me.y, target.x - me.x)
            command.f = range > 40 and 1 or 0
            if range < 60 and abs(wrap(desired - self.aim)) < 0.5 and self.sequence % 2 == 0 then
                command.b = 1
            end
        elseif item then
            desired = self:steer(world, me, item.x, item.y)
            command.f = 1
        end
    elseif sees then
        desired = atan2(target.y - me.y, target.x - me.x) + self.aimError
        command.f = range > 420 and 1 or (range < 180 and -1 or 0)
        command.r = self.strafe
        local facing = abs(wrap(desired - self.aim)) < skill.fireCone
        if self.seenFor >= skill.reaction and facing and me.ammo > 0 and me.reload == 0 then
            command.b = (def.auto or self.sequence % 2 == 0) and 1 or 0
        end
        if hurt and me.cooldown == 0 and self.rng:random() < skill.dashChance then
            command.d = 1
        end
        if self.seenFor == skill.reaction and (me.gadgets or 0) > 0 and (me.gadget == "smoke" or me.gadget == "flash") and self.rng:random() < 0.6 then
            command.x = 1
        end
        if self.seenFor == skill.reaction and (me.gadgets or 0) > 0 and me.gadget == "shock" and range < 260 and self.rng:random() < 0.6 then
            command.x = 1
        end
    elseif self.lastSeen then
        if distance(me.x, me.y, self.lastSeen.x, self.lastSeen.y) < 40 then
            self.lastSeen = nil
        else
            desired = self:steer(world, me, self.lastSeen.x, self.lastSeen.y)
            command.f = 1
        end
    end

    if not sees and me.gadget == "stim" and (me.gadgets or 0) > 0 and me.hp <= 55 then
        command.x = 1
    end

    if not desired then
        if not self.waypoint or distance(me.x, me.y, self.waypoint.x, self.waypoint.y) < 40 then
            self:pickWaypoint(world)
        end
        desired = self:steer(world, me, self.waypoint.x, self.waypoint.y)
        command.f = 1
        if def and me.ammo < Weapons.stat(me, "magazine") / 2 and me.reserve > 0 then
            command.l = 1
        end
    end

    if self.lastX and command.f ~= 0 and distance(me.x, me.y, self.lastX, self.lastY) < 0.5 then
        self.stuck = self.stuck + 1
        if self.stuck > 30 then
            self.stuck = 0
            self.lastSeen = nil
            self:pickWaypoint(world)
            self.strafe = -self.strafe
        end
    else
        self.stuck = 0
    end
    self.lastX, self.lastY = me.x, me.y

    local turn = wrap(desired - self.aim)
    if abs(turn) > skill.turn then
        turn = turn > 0 and skill.turn or -skill.turn
    end
    self.aim = self.aim + turn
    command.a = Player.packAngle(self.aim)
    return command
end

return Bot
