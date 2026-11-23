local Config = require("src.config.game")
local WeaponConfig = require("src.config.weapons")
local Weapons = require("src.game.weapons")
local Player = require("src.game.player")

local Combat = {}

local sqrt, cos, sin, max, min = math.sqrt, math.cos, math.sin, math.max, math.min

local HISTORY = 64

local function rayCircle(x, y, dx, dy, cx, cy, radius)
    local fx, fy = x - cx, y - cy
    local b = fx * dx + fy * dy
    local c = fx * fx + fy * fy - radius * radius
    local disc = b * b - c
    if disc < 0 then return nil end
    local t = -b - sqrt(disc)
    if t < 0 then
        t = -b + sqrt(disc)
        if t < 0 then return nil end
        return 0
    end
    return t
end

local function event(world, data)
    world.events[#world.events + 1] = data
end

--- @param world table
--- @param kind string
--- @param x number
--- @param y number
--- @param source number?
function Combat.noise(world, kind, x, y, source)
    world.noises[#world.noises + 1] = { kind = kind, x = x, y = y, source = source, radius = Config.noise[kind] }
end

--- @param world table
function Combat.setup(world)
    world.history = {}
    world.items = {}
    world.pads = {}
    world.events = {}
    world.shots = {}
    world.noises = {}
    world.score = {}
    world.nextItem = 1
    for k, pad in ipairs(world.arena.loot) do
        world.pads[k] = { x = pad.x, y = pad.y, kind = pad.kind, timer = 0, item = nil }
    end
end

--- @param world table
--- @param kind string
--- @param ammo number?
--- @param reserve number?
--- @param x number
--- @param y number
--- @return table
function Combat.spawnItem(world, kind, ammo, reserve, x, y)
    local def = Weapons.def(kind)
    local item = {
        id = world.nextItem,
        kind = kind,
        ammo = ammo or (def and def.magazine or 0),
        reserve = reserve or (def and def.reserve or 0),
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        angle = 0,
        flying = false,
        owner = nil,
        age = 0
    }
    world.nextItem = world.nextItem + 1
    world.items[#world.items + 1] = item
    local limit = WeaponConfig.maxItems
    if #world.items > limit then
        for k, old in ipairs(world.items) do
            if not old.pad then
                table.remove(world.items, k)
                break
            end
        end
    end
    return item
end

local function removeItem(world, item)
    for k, other in ipairs(world.items) do
        if other == item then
            table.remove(world.items, k)
            break
        end
    end
    if item.pad then
        local pad = world.pads[item.pad]
        pad.item = nil
        pad.timer = WeaponConfig.padRespawn
    end
end

--- @param world table
--- @param p table
--- @param x number?
--- @param y number?
--- @return table?
function Combat.drop(world, p, x, y)
    if not p.weapon then return nil end
    local item = Combat.spawnItem(world, p.weapon, p.ammo, p.reserve, x or p.x, y or p.y)
    item.angle = p.angle
    Weapons.give(p, nil)
    return item
end

--- @param world table
--- @param victim table
--- @param killer number?
function Combat.kill(world, victim, killer)
    victim.hp = 0
    victim.dead = Config.respawnTicks
    victim.dash, victim.slide, victim.vx, victim.vy = 0, 0, 0, 0
    Combat.drop(world, victim)
    Combat.spawnItem(world, "ammo", nil, nil, world.arena:resolve(victim.x + 12, victim.y + 8, WeaponConfig.throw.radius))
    if killer and killer ~= victim.slot and world:enemies(killer, victim.slot) then
        world.score[killer] = (world.score[killer] or 0) + 1
        local rules = world.rules
        local team = rules.teams and world.players[killer] and world.players[killer].team
        if team then
            world.teamScore[team] = world.teamScore[team] + 1
        end
        event(world, { kind = "kill", k = killer, v = victim.slot })
        if not world.over then
            if team and world.teamScore[team] >= rules.scoreLimit then
                world:finish(team, true)
            elseif not team and world.score[killer] >= rules.scoreLimit then
                world:finish(killer, false)
            end
        end
        return
    end
    event(world, { kind = "kill", k = killer, v = victim.slot })
end

--- @param world table
--- @param target table
--- @param amount number
--- @param attacker number?
--- @param x number?
--- @param y number?
function Combat.damage(world, target, amount, attacker, x, y)
    if target.hp <= 0 or target.dead > 0 or world.over then return end
    if attacker and not world:enemies(attacker, target.slot) then return end
    target.hp = max(0, target.hp - amount)
    event(world, { kind = "hit", a = attacker, t = target.slot, d = amount, x = x, y = y })
    if target.hp <= 0 then
        Combat.kill(world, target, attacker)
    end
end

--- @param world table
function Combat.record(world)
    local snapshot = {}
    for slot, p in pairs(world.players) do
        snapshot[slot] = { x = p.x, y = p.y, evading = Player.evading(p), alive = p.hp > 0 and p.dead == 0 }
    end
    world.history[world.tick % HISTORY] = { tick = world.tick, players = snapshot }
end

local function rewound(world, slot, tick)
    local entry = world.history[tick % HISTORY]
    if entry and entry.tick == tick and entry.players[slot] then
        return entry.players[slot]
    end
    local p = world.players[slot]
    return { x = p.x, y = p.y, evading = Player.evading(p), alive = p.hp > 0 and p.dead == 0 }
end

--- @param world table
--- @param shooter table
--- @param command table
function Combat.fire(world, shooter, command)
    local def = Weapons.def(shooter.weapon)
    local view = command.v or world.tick
    view = max(world.tick - Config.rewindTicks, min(world.tick, view))
    local radius = Config.player.radius
    local hits = {}
    if not def.silent then
        Combat.noise(world, "shot", shooter.x, shooter.y, shooter.slot)
    end
    for _, ray in ipairs(Weapons.rays(shooter, command.s)) do
        local length, obstacle = world.arena:raycast(ray.x, ray.y, ray.dx, ray.dy, ray.range)
        local victim
        for slot in pairs(world.players) do
            if slot ~= shooter.slot and world:enemies(shooter.slot, slot) then
                local past = rewound(world, slot, view)
                if past.alive and not past.evading then
                    local t = rayCircle(ray.x, ray.y, ray.dx, ray.dy, past.x, past.y, radius)
                    if t and t < length then
                        length, victim = t, slot
                    end
                end
            end
        end
        if victim then
            hits[victim] = (hits[victim] or 0) + def.damage
        end
        local hit = victim and 2 or (length < ray.range - 1e-6 and 1 or 0)
        if not victim and obstacle and obstacle.kind == "glass" then
            hit = 3
            world.arena:breakGlass(obstacle)
            Combat.noise(world, "glass", ray.x + ray.dx * length, ray.y + ray.dy * length, shooter.slot)
        end
        world.shots[#world.shots + 1] = {
            o = shooter.slot, x = ray.x, y = ray.y,
            X = ray.x + ray.dx * length, Y = ray.y + ray.dy * length, h = hit,
            q = def.silent and 1 or nil
        }
    end
    for slot, amount in pairs(hits) do
        Combat.damage(world, world.players[slot], amount, shooter.slot, shooter.x, shooter.y)
    end
end

--- @param world table
--- @param p table
function Combat.throw(world, p)
    if not p.weapon or p.dead > 0 or p.dash > 0 then return end
    local def = WeaponConfig.throw
    local ca, sa = cos(p.angle), sin(p.angle)
    local x, y = world.arena:resolve(p.x + ca * 16, p.y + sa * 16, def.radius)
    local item = Combat.drop(world, p, x, y)
    Combat.noise(world, "throw", p.x, p.y, p.slot)
    item.flying = true
    item.owner = p.slot
    item.vx = ca * def.speed + p.vx * def.inherit
    item.vy = sa * def.speed + p.vy * def.inherit
end

local function category(kind)
    if kind == "ammo" or kind == "health" then return kind end
    return "weapon"
end

local function nearest(world, p, flying, wanted)
    local best, bestDistance = nil, WeaponConfig.pickupRadius
    for _, item in ipairs(world.items) do
        if item.flying == flying and category(item.kind) == (wanted or "weapon") then
            local d = sqrt((item.x - p.x) ^ 2 + (item.y - p.y) ^ 2)
            if d <= bestDistance then
                best, bestDistance = item, d
            end
        end
    end
    return best
end

--- @param world table
--- @param p table
--- @return boolean
function Combat.pickup(world, p)
    if p.dead > 0 then return false end
    local item = nearest(world, p, false)
    if not item then return false end
    removeItem(world, item)
    Combat.drop(world, p)
    Weapons.give(p, item.kind, item.ammo, item.reserve)
    return true
end

--- @param world table
--- @param p table
--- @return boolean
function Combat.refill(world, p)
    local def = Weapons.def(p.weapon)
    if not def then return false end
    local cap = Weapons.reserveCap(def)
    if p.reserve >= cap then return false end
    local item = nearest(world, p, false, "ammo")
    if not item then return false end
    removeItem(world, item)
    p.reserve = math.min(cap, p.reserve + def.magazine)
    return true
end

--- @param world table
--- @param p table
--- @return boolean
function Combat.heal(world, p)
    if p.hp >= Config.health then return false end
    local item = nearest(world, p, false, "health")
    if not item then return false end
    removeItem(world, item)
    p.hp = math.min(Config.health, p.hp + WeaponConfig.healAmount)
    return true
end

local function updateItem(world, item)
    local def = WeaponConfig.throw
    item.age = item.age + 1
    if not item.flying then return end
    local dt = world.dt
    local x, y, nx, ny = world.arena:resolve(item.x + item.vx * dt, item.y + item.vy * dt, def.radius)
    local into = item.vx * nx + item.vy * ny
    if into < 0 then
        item.vx, item.vy = (item.vx - 1.6 * into * nx) * 0.4, (item.vy - 1.6 * into * ny) * 0.4
        Combat.noise(world, "clank", x, y, item.owner)
    end
    item.x, item.y = x, y
    item.vx, item.vy = item.vx * def.friction, item.vy * def.friction
    item.angle = item.angle + 0.35

    for slot, p in pairs(world.players) do
        if slot ~= item.owner and p.hp > 0 and p.dead == 0 and not Player.evading(p) and (not item.owner or world:enemies(item.owner, slot)) then
            local d = sqrt((p.x - item.x) ^ 2 + (p.y - item.y) ^ 2)
            if d < Config.player.radius + def.radius then
                Combat.damage(world, p, def.damage, item.owner, item.x - item.vx * 0.05, item.y - item.vy * 0.05)
                item.vx, item.vy = -item.vx * 0.25, -item.vy * 0.25
                item.flying = false
                break
            end
        end
    end
    if item.flying and sqrt(item.vx * item.vx + item.vy * item.vy) < def.landSpeed then
        item.flying = false
    end
    if not item.flying then
        item.vx, item.vy = 0, 0
    end
end

--- @param world table
function Combat.update(world)
    for _, item in ipairs(world.items) do
        updateItem(world, item)
    end
    for k = #world.items, 1, -1 do
        local item = world.items[k]
        if not item.pad and not item.flying and item.age > WeaponConfig.itemLifetime then
            table.remove(world.items, k)
        end
    end
    for k, pad in ipairs(world.pads) do
        if not pad.item then
            if pad.timer > 0 then
                pad.timer = pad.timer - 1
            else
                local item = Combat.spawnItem(world, pad.kind, nil, nil, pad.x, pad.y)
                item.pad = k
                pad.item = item.id
            end
        end
    end
    for slot, p in pairs(world.players) do
        if p.hp <= 0 and p.dead == 0 then
            Player.respawn(p, world:spawnPoint(p))
        elseif not p.weapon and p.dead == 0 then
            Combat.pickup(world, p)
        elseif p.dead == 0 then
            Combat.refill(world, p)
        end
        if p.dead == 0 and p.hp > 0 then
            Combat.heal(world, p)
        end
    end
    for _, door in ipairs(world.arena:updateDoors(world.players)) do
        Combat.noise(world, "door", door.x + door.w / 2, door.y + door.h / 2, door.opener)
    end
    world.arena:updateGlass(world.players)
end

return Combat
