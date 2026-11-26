local Config = require("src.config.game")
local WeaponConfig = require("src.config.weapons")
local Weapons = require("src.game.weapons")
local Player = require("src.game.player")
local Loadout = require("src.config.loadout")

local Combat = {}

local sqrt, cos, sin, max, min = math.sqrt, math.cos, math.sin, math.max, math.min

local HISTORY = 180

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
--- @param angle number?
--- @param side number?
function Combat.noise(world, kind, x, y, source, angle, side)
    world.noises[#world.noises + 1] = {
        kind = kind, x = x, y = y, source = source, radius = Config.noise[kind], angle = angle, side = side
    }
end

--- @param world table
function Combat.setup(world)
    world.history = {}
    world.items = {}
    world.pads = {}
    world.events = {}
    world.shots = {}
    world.shotLog = {}
    world.noises = {}
    world.score = {}
    world.nextItem = 1
    local noWeapons = world.options and world.options.loot == false
    local noShields = world.options and world.options.shields == false
    for _, pad in ipairs(world.arena.loot) do
        if not (noWeapons and Weapons.def(pad.kind)) and not (noShields and pad.kind == "plate") then
            world.pads[#world.pads + 1] = { x = pad.x, y = pad.y, kind = pad.kind, timer = 0, item = nil }
        end
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
    if not p.weapon or world.rules.ladder then return nil end
    if Weapons.sidearm(p.weapon) then
        -- un petit flingue ne tombe pas par terre : il disparaît (le suivant est redonné automatiquement)
        Weapons.give(p, nil)
        return nil
    end
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
    if not world.rules.ladder then
        Combat.spawnItem(world, "ammo", nil, nil, world.arena:resolve(victim.x + 12, victim.y + 8, WeaponConfig.throw.radius))
    end
    if world.round and world.phase == "playing" then
        victim.out = true
    end
    local winner = killer and killer ~= victim.slot and world:enemies(killer, victim.slot) and world.players[killer]
    if winner and world.options and world.options.heal and winner.hp > 0 then
        winner.hp = math.min(Config.health, winner.hp + Loadout.killHeal)
    end
    if killer and killer ~= victim.slot and world:enemies(killer, victim.slot) and world.phase == "playing" then
        world.score[killer] = (world.score[killer] or 0) + 1
        local rules = world.rules
        if rules.rounds then
            event(world, { kind = "kill", k = killer, v = victim.slot })
            return
        end
        local team = rules.teams and world.players[killer] and world.players[killer].team
        if team then
            world.teamScore[team] = world.teamScore[team] + 1
        end
        event(world, { kind = "kill", k = killer, v = victim.slot })
        if rules.ladder and world.score[killer] < #rules.ladder then
            world:loadout(world.players[killer])
            event(world, { kind = "level", p = killer, l = world.score[killer] + 1 })
        end
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
--- @param shieldMult number? multiplicateur de dégâts contre les plaques (ex: Breaker)
function Combat.damage(world, target, amount, attacker, x, y, shieldMult)
    if target.hp <= 0 or target.dead > 0 or world.over then return end
    if attacker and not world:enemies(attacker, target.slot) then return end
    local total = amount
    local absorbed, broken = 0, 0
    local armor = target.armor or 0
    if armor > 0 then
        -- les plaques encaissent d'abord ; l'excédent passe sur la vie
        local mult = shieldMult or 1
        absorbed = min(armor, amount * mult)
        local plateHp = Config.shield.plateHp
        local before = math.ceil(armor / plateHp)
        target.armor = armor - absorbed
        broken = before - math.ceil(target.armor / plateHp)
        amount = amount - absorbed / mult
    end
    target.hp = max(0, target.hp - amount)
    event(world, {
        kind = "hit", a = attacker, t = target.slot, d = total, x = x, y = y,
        h = math.floor(amount + 0.5),                          -- dégâts réellement pris par la vie
        s = absorbed > 0 and math.floor(absorbed + 0.5) or nil, -- dégâts pris par les plaques
        b = broken > 0 and broken or nil,                      -- plaques cassées
        ar = math.floor((target.armor or 0) + 0.5)             -- armure restante
    })
    if target.hp <= 0 then
        Combat.kill(world, target, attacker)
    end
end

--- @param world table
function Combat.record(world)
    local snapshot = {}
    for slot, p in pairs(world.players) do
        snapshot[slot] = {
            x = p.x, y = p.y, angle = p.angle, weapon = p.weapon,
            evading = Player.evading(p), alive = p.hp > 0 and p.dead == 0
        }
    end
    world.history[world.tick % HISTORY] = { tick = world.tick, players = snapshot }
    local log = world.shotLog
    while log[1] and world.tick - log[1].tick > HISTORY do
        table.remove(log, 1)
    end
end

--- @param world table
--- @param killer number
--- @param victim number
--- @return table?
function Combat.killcam(world, killer, victim)
    local ticks = Config.killcamTicks
    local frames = {}
    for tick = world.tick - ticks, world.tick, 2 do
        local entry = world.history[tick % HISTORY]
        if entry and entry.tick == tick then
            local k, v = entry.players[killer], entry.players[victim]
            if k and v then
                frames[#frames + 1] = {
                    t = tick,
                    kx = math.floor(k.x + 0.5), ky = math.floor(k.y + 0.5), ka = Player.packAngle(k.angle), kg = Weapons.pack(k.weapon),
                    vx = math.floor(v.x + 0.5), vy = math.floor(v.y + 0.5), va = Player.packAngle(v.angle), vg = Weapons.pack(v.weapon),
                    al = v.alive and 1 or 0
                }
            end
        end
    end
    if #frames < 4 then return nil end
    local shots = {}
    for _, shot in ipairs(world.shotLog) do
        if shot.o == killer and shot.tick >= world.tick - ticks then
            shots[#shots + 1] = { t = shot.tick, x = math.floor(shot.x), y = math.floor(shot.y), X = math.floor(shot.X), Y = math.floor(shot.Y) }
        end
    end
    return { k = killer, f = frames, s = shots }
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
            hits[victim] = (hits[victim] or 0) + Weapons.stat(shooter, "damage")
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
            q = def.silent and 1 or nil, g = Weapons.pack(shooter.weapon)
        }
        world.shotLog[#world.shotLog + 1] = { tick = world.tick, o = shooter.slot, x = ray.x, y = ray.y, X = ray.x + ray.dx * length, Y = ray.y + ray.dy * length }
    end
    for slot, amount in pairs(hits) do
        Combat.damage(world, world.players[slot], amount, shooter.slot, shooter.x, shooter.y, def.shieldMult)
    end
end

--- @param world table
--- @param striker table
--- @param command table
function Combat.melee(world, striker, command)
    local def = WeaponConfig.melee
    local view = command.v or world.tick
    view = max(world.tick - Config.rewindTicks, min(world.tick, view))
    Combat.noise(world, "melee", striker.x, striker.y, striker.slot)
    local best, bestDistance
    for slot, target in pairs(world.players) do
        if slot ~= striker.slot and world:enemies(striker.slot, slot) then
            local past = rewound(world, slot, view)
            if past.alive and not past.evading then
                local dx, dy = past.x - striker.x, past.y - striker.y
                local d = sqrt(dx * dx + dy * dy)
                local facing = math.abs((math.atan2(dy, dx) - striker.angle + math.pi) % (2 * math.pi) - math.pi)
                local reach = def.range + Config.player.radius
                if d <= reach and facing <= def.arc and (not bestDistance or d < bestDistance) then
                    if world.arena:raycast(striker.x, striker.y, dx / math.max(d, 1e-6), dy / math.max(d, 1e-6), d, "bullet") >= d - 1 then
                        best, bestDistance = target, d
                    end
                end
            end
        end
    end
    event(world, { kind = "melee", o = striker.slot, t = best and best.slot or nil })
    if not best then return end
    if best.weapon and not world.rules.ladder and not Weapons.sidearm(best.weapon) then
        local ca, sa = cos(striker.angle), sin(striker.angle)
        local x, y = world.arena:resolve(best.x + ca * 60, best.y + sa * 60, WeaponConfig.throw.radius)
        local item = Combat.drop(world, best, x, y)
        if item then item.angle = striker.angle end
    end
    best.stun = def.stun
    best.reload = 0
    Combat.damage(world, best, def.damage, striker.slot, striker.x, striker.y)
end

--- @param world table
--- @param p table
function Combat.throw(world, p)
    if world.rules.ladder then return end
    if not p.weapon or p.dead > 0 or p.dash > 0 then return end
    if Weapons.sidearm(p.weapon) then return end
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
    if kind == "ammo" or kind == "health" or kind == "plate" then return kind end
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
    if world.rules.ladder then return false end
    if p.dead > 0 or p.stun > 0 then return false end
    local item = nearest(world, p, false)
    if not item then return false end
    removeItem(world, item)
    Combat.drop(world, p)
    Weapons.give(p, item.kind, item.ammo, item.reserve)
    Weapons.fit(p)
    return true
end

--- @param world table
--- @param p table
--- @return boolean
function Combat.refill(world, p)
    local def = Weapons.def(p.weapon)
    if not def then return false end
    local cap = Weapons.reserveCap(def, p)
    if p.reserve >= cap then return false end
    local item = nearest(world, p, false, "ammo")
    if not item then return false end
    removeItem(world, item)
    p.reserve = math.min(cap, p.reserve + Weapons.stat(p, "magazine"))
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

--- Ramasse une plaque de bouclier (jusqu'à Config.shield.plates).
--- @param world table
--- @param p table
--- @return boolean
function Combat.plate(world, p)
    if world.options and world.options.shields == false then return false end
    local shield = Config.shield
    local cap = shield.plates * shield.plateHp
    if (p.armor or 0) >= cap then return false end
    local item = nearest(world, p, false, "plate")
    if not item then return false end
    removeItem(world, item)
    p.armor = min(cap, (p.armor or 0) + shield.plateHp)
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
        if not pad.item and (not world.rules.ladder or pad.kind == "health") then
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
            world:loadout(p)
        elseif not p.weapon and p.dead == 0 then
            Combat.pickup(world, p)
            if not p.weapon and not world.rules.ladder then
                Weapons.give(p, WeaponConfig.fallback)
            end
        elseif p.dead == 0 then
            Combat.refill(world, p)
        end
        if p.dead == 0 and p.hp > 0 then
            Combat.heal(world, p)
            Combat.plate(world, p)
        end
    end
    for _, door in ipairs(world.arena:updateDoors(world.players)) do
        Combat.noise(world, "door", door.x + door.w / 2, door.y + door.h / 2, door.opener)
    end
    world.arena:updateGlass(world.players)
end

return Combat
