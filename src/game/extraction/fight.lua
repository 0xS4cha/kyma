--- Combat of the extraction mode: bullets with every round trait (ricochets, piercing,
--- explosions, fire, poison, frost, chain lightning...), armor, deaths and corpses,
--- grenades, mines, smoke, fire and gas.
local Weapons = require("src.game.weapons")
local Items = require("src.game.extraction.items")
local Inventory = require("src.game.extraction.inventory")
local GameConfig = require("src.config.game")
local WeaponConfig = require("src.config.weapons")

local Fight = {}

local floor, sqrt, min, max, abs, cos, sin, atan2, pi = math.floor, math.sqrt, math.min, math.max, math.abs, math.cos, math.sin, math.atan2, math.pi

local RADIUS = GameConfig.player.radius
local NOISES = { blast = 1600, scream = 700 }

local THROWN = {
    frag = { fuse = 96, speed = 560 },
    sticky = { fuse = 90, speed = 600, sticky = true },
    smoke = { fuse = 40, speed = 560 },
    flash = { fuse = 48, speed = 560 },
    fire = { fuse = 70, speed = 560, impact = true },
    cryo = { fuse = 60, speed = 560 },
    gas = { fuse = 50, speed = 520 },
    decoy = { fuse = 30, speed = 480 }
}

function Fight.setup(w)
    w.projectiles, w.fires, w.clouds, w.smokes, w.mines, w.booms, w.lures = {}, {}, {}, {}, {}, {}, {}
    w.nextProjectile, w.nextBoom = 1, 1
    w.terrain.smokes = w.smokes
end

--- @param w table
--- @param kind string
--- @param source number? player slot
function Fight.noise(w, kind, x, y, source, radius)
    w.noises[#w.noises + 1] = { kind = kind, x = x, y = y, source = source, radius = radius or GameConfig.noise[kind] or NOISES[kind] or 400 }
end

local function boom(w, kind, x, y, r)
    w.booms[#w.booms + 1] = { i = w.nextBoom, k = kind, x = floor(x), y = floor(y), r = floor(r or 0), tick = w.tick }
    w.nextBoom = w.nextBoom + 1
end

Fight.boom = boom

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

local function clear(w, x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local d = sqrt(dx * dx + dy * dy)
    if d < 1 then return true end
    return w.terrain:raycast(x1, y1, dx / d, dy / d, d, "bullet") >= d - 2
end

--- @param attacker table? player or monster
--- @return string
local function nameOf(attacker)
    if not attacker then return "the wilds" end
    if attacker.def and attacker.kind then return attacker.def.name end
    return attacker.name or "someone"
end

--- A player is hit. Armor takes a share and wears down; statuses stack up.
--- @param w table
--- @param p table
--- @param amount number
--- @param attacker table? player or monster
--- @param opts table?
--- @return number damage dealt
function Fight.hurtPlayer(w, p, amount, attacker, opts)
    opts = opts or {}
    if p.dead > 0 or p.hp <= 0 or w.over then return 0 end
    if not opts.status then
        local reduce = 0
        for _, slot in ipairs({ "vest", "helmet" }) do
            local inst = p.gear[slot]
            if inst and (inst.u or 0) > 0 then
                local stats = Items.armorStats(inst)
                local r = stats.reduce * (slot == "helmet" and 0.6 or 1) * (1 - min(1, opts.armorPierce or 0))
                reduce = 1 - (1 - reduce) * (1 - max(0, min(0.9, r)))
                inst.u = max(0, inst.u - amount * 0.35)
                p.invDirty = p.invDirty or inst.u == 0
            end
        end
        amount = amount * (1 - reduce)
    end
    if (p.effects.fortify or 0) > 0 then amount = amount * 0.75 end
    local dealt = min(p.hp, amount)
    p.hp = p.hp - amount
    p.use = nil
    local attackerSlot = attacker and attacker.slot and not attacker.kind and attacker.slot or nil
    if not opts.status then
        w:send(p.slot, "xhurt", { x = attacker and floor(attacker.x) or nil, y = attacker and floor(attacker.y) or nil, d = floor(amount + 0.5) })
        if attackerSlot then
            w:send(attackerSlot, "xhit", { x = floor(p.x), y = floor(p.y), d = floor(amount + 0.5), k = p.hp <= 0 and 1 or nil })
        end
    end
    if p.hp <= 0 then Fight.killPlayer(w, p, attacker) end
    return dealt
end

--- @param w table
--- @param p table
--- @param attacker table?
function Fight.killPlayer(w, p, attacker)
    p.hp, p.dead, p.out = 0, 1, true
    p.use = nil
    if p.open then w:close(p) end
    local items = Inventory.empty(p.gear)
    local list = {}
    local place = { kind = "grid", w = 10, h = 18, list = list }
    for _, inst in ipairs(items) do
        if not Inventory.give({ g = place }, inst, { "g" }) then
            place.h = place.h + 4
            Inventory.give({ g = place }, inst, { "g" })
        end
    end
    local drop = w:drop(p.x, p.y, "corpse", p.name, list, place.w, place.h)
    local killer = nameOf(attacker)
    local weapon = attacker and attacker.def and attacker.def.name or nil
    if attacker and attacker.slot and not attacker.kind and attacker ~= p then
        attacker.kills = (attacker.kills or 0) + 1
    end
    p.invDirty = true
    w:send(p.slot, "xdied", { k = killer, w = (attacker and not attacker.kind) and weapon or nil, d = drop.id })
    w:send(nil, "xfeed", { k = killer, v = p.name, m = attacker and attacker.kind and 1 or nil })
    Fight.noise(w, "scream", p.x, p.y, p.slot)
end

--- Applies one bullet hit on a target with every trait of the weapon.
--- @param w table
--- @param shooter table player
--- @param target table { player = p } or { monster = m }
--- @param def table weapon stats
--- @param damage number
function Fight.hit(w, shooter, target, def, damage)
    local Monsters = require("src.game.extraction.monsters")
    local victim = target.player or target.monster
    local wounded = victim.hp / (target.player and GameConfig.health or victim.max)
    if def.execute and wounded < def.execute then damage = damage * 1.6 end
    local dealt
    local opts = { armorPierce = def.armorPierce }
    if target.player then
        dealt = Fight.hurtPlayer(w, victim, damage, shooter, opts)
    else
        dealt = Monsters.hurt(w, victim, damage * (def.flesh or 1), shooter, opts)
    end
    local e = target.player and victim.effects or victim
    local immune = target.player and Items.def(victim.gear.helmet) and Items.def(victim.gear.helmet).immune
    local vestImmune = target.player and Items.def(victim.gear.vest) and Items.def(victim.gear.vest).immune
    if def.burn and immune ~= "burn" and vestImmune ~= "burn" then
        e.burn, e.burnDamage, e.burnBy = 180, max(1, floor(def.burn + 0.5)), shooter
    end
    if def.poison and immune ~= "poison" then
        e.poison, e.poisonDamage, e.poisonBy = 360, max(1, floor(def.poison + 0.5)), shooter
    end
    if def.chill then e.chill = max(e.chill or 0, floor(def.chill)) end
    if def.daze and not target.player then victim.stun = max(victim.stun or 0, floor(def.daze)) end
    if def.knock and victim.hp > 0 then
        local dx, dy = victim.x - shooter.x, victim.y - shooter.y
        local d = max(1, sqrt(dx * dx + dy * dy))
        local push = def.knock * (target.monster and victim.def.boss and 0.2 or 1)
        victim.vx, victim.vy = (victim.vx or 0) + dx / d * push, (victim.vy or 0) + dy / d * push
        if target.monster then victim.knockX, victim.knockY = dx / d * push, dy / d * push end
    end
    if def.mark then
        local key = target.player and ("p" .. victim.slot) or ("m" .. victim.id)
        shooter.marks[key] = max(shooter.marks[key] or 0, floor(def.mark))
    end
    if def.leech and dealt and dealt > 0 then
        shooter.hp = min(GameConfig.health, shooter.hp + dealt * def.leech)
    end
    if def.chain and not target.chained then
        local best, bestD
        local function consider(kind, other, x, y)
            if other == victim or other == shooter then return end
            local d = (x - victim.x) ^ 2 + (y - victim.y) ^ 2
            if d < 180 * 180 and (not bestD or d < bestD) and clear(w, victim.x, victim.y, x, y) then best, bestD = { [kind] = other, chained = true }, d end
        end
        for _, m in pairs(Monsters.near(w, victim.x - 180, victim.y - 180, victim.x + 180, victim.y + 180)) do consider("monster", m, m.x, m.y) end
        for _, p in pairs(w.players) do
            if p.dead == 0 and p.hp > 0 then consider("player", p, p.x, p.y) end
        end
        if best then
            local other = best.player or best.monster
            boom(w, "arc", victim.x, victim.y, 0)
            w.shots[#w.shots + 1] = { o = shooter.slot, x = victim.x, y = victim.y, X = other.x, Y = other.y, h = 4, g = "arc" }
            local chainDef = setmetatable({ chain = nil, knock = nil }, { __index = def })
            Fight.hit(w, shooter, best, chainDef, damage * min(1, def.chain / 100))
        end
    end
end

--- An explosion: damage falls off with distance and walls block it.
--- @param w table
--- @param attacker table?
function Fight.blast(w, x, y, radius, damage, attacker, kind)
    local Monsters = require("src.game.extraction.monsters")
    boom(w, kind or "blast", x, y, radius)
    Fight.noise(w, "blast", x, y, attacker and not attacker.kind and attacker.slot or nil)
    for _, p in pairs(w.players) do
        local d = sqrt((p.x - x) ^ 2 + (p.y - y) ^ 2)
        if p.dead == 0 and d < radius + RADIUS and clear(w, x, y, p.x, p.y) then
            local factor = 1 - min(1, d / (radius + RADIUS)) * 0.6
            if p == attacker then factor = factor * 0.5 end
            Fight.hurtPlayer(w, p, damage * factor, attacker, { armorPierce = 0.3 })
        end
    end
    for _, m in pairs(Monsters.near(w, x - radius - 40, y - radius - 40, x + radius + 40, y + radius + 40)) do
        local d = sqrt((m.x - x) ^ 2 + (m.y - y) ^ 2)
        if d < radius + m.def.radius and clear(w, x, y, m.x, m.y) then
            Monsters.hurt(w, m, damage * (1 - min(1, d / (radius + m.def.radius)) * 0.6), attacker, { armorPierce = 0.3 })
        end
    end
end

local function reflect(rect, hx, hy, dx, dy)
    local dl, dr = abs(hx - rect.x), abs(hx - rect.x - rect.w)
    local dt, db = abs(hy - rect.y), abs(hy - rect.y - rect.h)
    local best = min(dl, dr, dt, db)
    if best == dl or best == dr then
        return -dx, dy, best == dl and -1 or 1, 0
    end
    return dx, -dy, 0, best == dt and -1 or 1
end

--- Follows one bullet through ricochets and pierced targets.
local function trace(w, p, ray, def, view, damage)
    local Monsters = require("src.game.extraction.monsters")
    local x, y, dx, dy, range = ray.x, ray.y, ray.dx, ray.dy, ray.range
    local bounces, pierce = def.bounce or 0, def.pierce or 0
    local done = {}
    for _ = 1, 8 do
        local wallT, rect = w.terrain:raycast(x, y, dx, dy, range, "bullet")
        local list = {}
        for slot, other in pairs(w.players) do
            if slot ~= p.slot and not done[other] then
                local past = w:rewound(slot, view)
                if past.alive and not past.evading then
                    local t = rayCircle(x, y, dx, dy, past.x, past.y, RADIUS)
                    if t and t < wallT then list[#list + 1] = { t = t, player = other } end
                end
            end
        end
        local ex, ey = x + dx * wallT, y + dy * wallT
        for _, m in pairs(Monsters.near(w, min(x, ex) - 40, min(y, ey) - 40, max(x, ex) + 40, max(y, ey) + 40)) do
            if not done[m] and m.hp > 0 then
                local t = rayCircle(x, y, dx, dy, m.x, m.y, m.def.radius)
                if t and t < wallT then list[#list + 1] = { t = t, monster = m } end
            end
        end
        table.sort(list, function(a, b) return a.t < b.t end)
        local stopT, kind = wallT, rect and 1 or 0
        for _, target in ipairs(list) do
            done[target.player or target.monster] = true
            Fight.hit(w, p, target, def, damage)
            if pierce > 0 then
                pierce = pierce - 1
            else
                stopT, kind = target.t, 2
                break
            end
        end
        local hx, hy = x + dx * stopT, y + dy * stopT
        w.shots[#w.shots + 1] = {
            o = p.slot, x = x, y = y, X = hx, Y = hy, h = kind, q = def.silent and 1 or nil, hd = def.hidden and 1 or nil, g = def.look
        }
        if kind == 2 then
            if def.blast then Fight.blast(w, hx, hy, def.blast, damage * 0.8, p) end
            return
        end
        if rect and rect.list == "glass" then
            w.terrain:breakGlass(rect)
            Fight.noise(w, "glass", hx, hy, p.slot)
            w.shots[#w.shots].h = 3
            return
        end
        if rect and bounces > 0 then
            bounces = bounces - 1
            local nx, ny
            dx, dy, nx, ny = reflect(rect, hx, hy, dx, dy)
            x, y = hx + nx * 0.6, hy + ny * 0.6
            range = range - stopT
            damage = damage * 0.85
            if range <= 20 then return end
        else
            if def.blast and rect then Fight.blast(w, hx - dx * 4, hy - dy * 4, def.blast, damage * 0.8, p) end
            return
        end
    end
end

--- A player fires their weapon.
--- @param w table
--- @param p table
--- @param command table
function Fight.fire(w, p, command)
    local def = p.def
    local view = max(w.tick - GameConfig.rewindTicks, min(w.tick, command.v or w.tick))
    if not def.silent then Fight.noise(w, "shot", p.x, p.y, p.slot) end
    for _, ray in ipairs(Weapons.rays(p, command.s)) do
        trace(w, p, ray, def, view, def.damage)
    end
end

--- An unarmed strike.
function Fight.melee(w, p, command)
    local Monsters = require("src.game.extraction.monsters")
    local def = WeaponConfig.melee
    local view = max(w.tick - GameConfig.rewindTicks, min(w.tick, command.v or w.tick))
    Fight.noise(w, "melee", p.x, p.y, p.slot)
    local best, bestD
    local function consider(target, x, y, radius)
        local dx, dy = x - p.x, y - p.y
        local d = sqrt(dx * dx + dy * dy)
        local facing = abs((atan2(dy, dx) - p.angle + pi) % (2 * pi) - pi)
        if d <= def.range + radius and facing <= def.arc and (not bestD or d < bestD) and clear(w, p.x, p.y, x, y) then
            best, bestD = target, d
        end
    end
    for slot, other in pairs(w.players) do
        if slot ~= p.slot then
            local past = w:rewound(slot, view)
            if past.alive and not past.evading then consider({ player = other }, past.x, past.y, RADIUS) end
        end
    end
    for _, m in pairs(Monsters.near(w, p.x - 120, p.y - 120, p.x + 120, p.y + 120)) do
        consider({ monster = m }, m.x, m.y, m.def.radius)
    end
    if not best then return end
    if best.player then
        Fight.hurtPlayer(w, best.player, def.damage, p)
        best.player.stun = def.stun
    else
        Monsters.hurt(w, best.monster, def.damage, p)
        best.monster.stun = max(best.monster.stun or 0, 20)
    end
end

--- Throws a grenade or places a mine.
--- @param w table
--- @param p table
--- @param def table utility definition
--- @param inst table
function Fight.throw(w, p, def, inst)
    local power = Items.rarity(inst).power
    if def.place == "mine" then
        w.mines[#w.mines + 1] = { x = p.x, y = p.y, owner = p, arm = 60, power = power }
        return
    end
    local spec = THROWN[def.throw]
    local ca, sa = cos(p.angle), sin(p.angle)
    local x, y = w.terrain:resolve(p.x + ca * 16, p.y + sa * 16, 5)
    w.projectiles[#w.projectiles + 1] = {
        id = w.nextProjectile, kind = def.throw, owner = p, x = x, y = y,
        vx = ca * spec.speed + p.vx * 0.5, vy = sa * spec.speed + p.vy * 0.5, fuse = spec.fuse, power = power
    }
    w.nextProjectile = w.nextProjectile + 1
    Fight.noise(w, "throw", p.x, p.y, p.slot)
end

--- A monster's projectile.
function Fight.spit(w, m, tx, ty)
    local dx, dy = tx - m.x, ty - m.y
    local d = max(1, sqrt(dx * dx + dy * dy))
    local speed = m.def.projectile or 420
    w.projectiles[#w.projectiles + 1] = {
        id = w.nextProjectile, kind = "spit", monster = m, x = m.x + dx / d * (m.def.radius + 6), y = m.y + dy / d * (m.def.radius + 6),
        vx = dx / d * speed, vy = dy / d * speed, fuse = 120, damage = m.def.damage
    }
    w.nextProjectile = w.nextProjectile + 1
end

local function flash(w, x, y, power)
    local Monsters = require("src.game.extraction.monsters")
    for _, p in pairs(w.players) do
        local dx, dy = x - p.x, y - p.y
        local d = sqrt(dx * dx + dy * dy)
        if p.dead == 0 and d < 430 and clear(w, p.x, p.y, x, y) then
            local facing = abs((atan2(dy, dx) - p.angle + pi) % (2 * pi) - pi) <= GameConfig.vision.halfAngle + 0.3 and 1 or 0.35
            local helmet = Items.def(p.gear.helmet)
            local ticks = floor(180 * facing * (1 - 0.6 * d / 430) * (helmet and helmet.flash or 1) * power)
            p.blind = max(p.blind or 0, ticks)
        end
    end
    for _, m in pairs(Monsters.near(w, x - 430, y - 430, x + 430, y + 430)) do
        if (m.x - x) ^ 2 + (m.y - y) ^ 2 < 430 * 430 and clear(w, m.x, m.y, x, y) then
            m.stun = max(m.stun or 0, floor(150 * power))
        end
    end
    boom(w, "flash", x, y, 430)
    Fight.noise(w, "shot", x, y, nil)
end

local function detonate(w, g)
    local Monsters = require("src.game.extraction.monsters")
    local owner = g.owner
    local power = g.power or 1
    if g.kind == "frag" or g.kind == "sticky" then
        Fight.blast(w, g.x, g.y, 170 * power, 95 * power, owner)
    elseif g.kind == "smoke" then
        w.smokes[#w.smokes + 1] = { x = g.x, y = g.y, r = 0, ticks = floor(540 * power), max = 130 * power }
        Fight.noise(w, "throw", g.x, g.y, nil)
    elseif g.kind == "flash" then
        flash(w, g.x, g.y, power)
    elseif g.kind == "fire" then
        w.fires[#w.fires + 1] = { x = g.x, y = g.y, r = 110 * power, ticks = floor(420 * power), by = owner }
        boom(w, "fire", g.x, g.y, 110 * power)
    elseif g.kind == "cryo" then
        boom(w, "cryo", g.x, g.y, 190 * power)
        for _, p in pairs(w.players) do
            if (p.x - g.x) ^ 2 + (p.y - g.y) ^ 2 < (190 * power) ^ 2 then p.effects.chill = floor(240 * power) end
        end
        for _, m in pairs(Monsters.near(w, g.x - 200, g.y - 200, g.x + 200, g.y + 200)) do
            if (m.x - g.x) ^ 2 + (m.y - g.y) ^ 2 < (190 * power) ^ 2 then
                m.chill = floor(300 * power)
                m.stun = max(m.stun or 0, 60)
            end
        end
    elseif g.kind == "gas" then
        w.clouds[#w.clouds + 1] = { x = g.x, y = g.y, r = 150 * power, ticks = floor(480 * power), by = owner }
    elseif g.kind == "decoy" then
        w.lures[#w.lures + 1] = { x = g.x, y = g.y, ticks = 300, timer = 0 }
    end
end

--- @param w table
function Fight.update(w)
    local Monsters = require("src.game.extraction.monsters")
    local dt, terrain = w.dt, w.terrain
    for k = #w.projectiles, 1, -1 do
        local g = w.projectiles[k]
        local remove = false
        if g.kind == "spit" then
            g.x, g.y = g.x + g.vx * dt, g.y + g.vy * dt
            g.fuse = g.fuse - 1
            if not terrain:clear(g.x, g.y, 4) or g.fuse <= 0 then remove = true end
            for _, p in pairs(w.players) do
                if not remove and p.dead == 0 and (p.x - g.x) ^ 2 + (p.y - g.y) ^ 2 < (RADIUS + 6) ^ 2 then
                    Fight.hurtPlayer(w, p, g.damage, g.monster)
                    p.effects.poison, p.effects.poisonDamage = max(p.effects.poison or 0, 135), 2
                    remove = true
                end
            end
            if remove then boom(w, "spit", g.x, g.y, 20) end
        else
            if not g.stuck then
                local x, y, nx, ny = terrain:resolve(g.x + g.vx * dt, g.y + g.vy * dt, 5)
                local into = g.vx * nx + g.vy * ny
                if into < 0 then
                    if THROWN[g.kind].sticky then
                        g.stuck, g.vx, g.vy = true, 0, 0
                    elseif THROWN[g.kind].impact then
                        g.fuse = 0
                    else
                        g.vx, g.vy = (g.vx - 1.6 * into * nx) * 0.5, (g.vy - 1.6 * into * ny) * 0.5
                    end
                end
                g.x, g.y = x, y
                g.vx, g.vy = g.vx * 0.9, g.vy * 0.9
                if THROWN[g.kind].sticky and not g.stuck then
                    for _, m in pairs(Monsters.near(w, g.x - 40, g.y - 40, g.x + 40, g.y + 40)) do
                        if (m.x - g.x) ^ 2 + (m.y - g.y) ^ 2 < (m.def.radius + 5) ^ 2 then g.stuck, g.on = true, m end
                    end
                end
            elseif g.on then
                g.x, g.y = g.on.x, g.on.y
            end
            g.fuse = g.fuse - 1
            if g.fuse <= 0 then
                remove = true
                detonate(w, g)
            end
        end
        if remove then table.remove(w.projectiles, k) end
    end
    for k = #w.smokes, 1, -1 do
        local s = w.smokes[k]
        s.ticks = s.ticks - 1
        s.r = s.max * min(1, (540 - s.ticks) / 24) * (0.4 + 0.6 * min(1, s.ticks / 60))
        if s.ticks <= 0 then table.remove(w.smokes, k) end
    end
    for _, list in ipairs({ w.fires, w.clouds }) do
        for k = #list, 1, -1 do
            local zone = list[k]
            zone.ticks = zone.ticks - 1
            if zone.ticks % 20 == 0 then
                local fire = list == w.fires
                for _, p in pairs(w.players) do
                    if p.dead == 0 and (p.x - zone.x) ^ 2 + (p.y - zone.y) ^ 2 < zone.r * zone.r then
                        local helmet, vest = Items.def(p.gear.helmet), Items.def(p.gear.vest)
                        local immune = (fire and vest and vest.immune == "burn") or (not fire and helmet and helmet.immune == "poison")
                        if not immune then
                            Fight.hurtPlayer(w, p, fire and 5 or 3, zone.by, { status = true })
                            if fire then p.effects.burn = max(p.effects.burn or 0, 90) else p.effects.poison = max(p.effects.poison or 0, 180) end
                        end
                    end
                end
                for _, m in pairs(Monsters.near(w, zone.x - zone.r, zone.y - zone.r, zone.x + zone.r, zone.y + zone.r)) do
                    if (m.x - zone.x) ^ 2 + (m.y - zone.y) ^ 2 < zone.r * zone.r then
                        Monsters.hurt(w, m, fire and 9 or 6, zone.by, { status = true })
                    end
                end
            end
            if zone.ticks <= 0 then table.remove(list, k) end
        end
    end
    for k = #w.mines, 1, -1 do
        local mine = w.mines[k]
        if mine.arm > 0 then
            mine.arm = mine.arm - 1
        else
            local trigger = false
            for _, p in pairs(w.players) do
                if p ~= mine.owner and p.dead == 0 and (p.x - mine.x) ^ 2 + (p.y - mine.y) ^ 2 < 70 * 70 then trigger = true end
            end
            for _, m in pairs(Monsters.near(w, mine.x - 80, mine.y - 80, mine.x + 80, mine.y + 80)) do
                if (m.x - mine.x) ^ 2 + (m.y - mine.y) ^ 2 < (70 + m.def.radius) ^ 2 then trigger = true end
            end
            if trigger then
                table.remove(w.mines, k)
                Fight.blast(w, mine.x, mine.y, 160 * mine.power, 115 * mine.power, mine.owner)
            end
        end
    end
    for k = #w.lures, 1, -1 do
        local lure = w.lures[k]
        lure.ticks, lure.timer = lure.ticks - 1, lure.timer - 1
        if lure.timer <= 0 then
            lure.timer = 14 + lure.ticks % 9
            Fight.noise(w, "shot", lure.x, lure.y, nil)
            local a = (lure.ticks * 2.39) % (2 * pi)
            w.shots[#w.shots + 1] = { x = lure.x, y = lure.y, X = lure.x + cos(a) * 300, Y = lure.y + sin(a) * 300, h = 0, g = "pistol" }
        end
        if lure.ticks <= 0 then table.remove(w.lures, k) end
    end
    for k = #w.booms, 1, -1 do
        if w.tick - w.booms[k].tick > 6 then table.remove(w.booms, k) end
    end
end

--- Effects near a player for their snapshot.
--- @param w table
--- @param me table
--- @return table
function Fight.snapshot(w, me)
    local r2 = 1500 * 1500
    local function near(x, y) return (x - me.x) ^ 2 + (y - me.y) ^ 2 < r2 end
    local out = { pj = {}, sm = {}, fi = {}, gs = {}, mn = {}, bx = {} }
    for _, g in ipairs(w.projectiles) do
        if near(g.x, g.y) then out.pj[#out.pj + 1] = { x = floor(g.x), y = floor(g.y), k = g.kind } end
    end
    for _, s in ipairs(w.smokes) do
        if near(s.x, s.y) then out.sm[#out.sm + 1] = { x = floor(s.x), y = floor(s.y), r = floor(s.r) } end
    end
    for _, f in ipairs(w.fires) do
        if near(f.x, f.y) then out.fi[#out.fi + 1] = { x = floor(f.x), y = floor(f.y), r = floor(f.r) } end
    end
    for _, c in ipairs(w.clouds) do
        if near(c.x, c.y) then out.gs[#out.gs + 1] = { x = floor(c.x), y = floor(c.y), r = floor(c.r) } end
    end
    for _, mine in ipairs(w.mines) do
        if mine.owner == me then out.mn[#out.mn + 1] = { x = floor(mine.x), y = floor(mine.y) } end
    end
    for _, b in ipairs(w.booms) do
        if near(b.x, b.y) then out.bx[#out.bx + 1] = b end
    end
    return out
end

return Fight
