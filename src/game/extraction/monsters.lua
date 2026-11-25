--- Monsters of the extraction mode: nests wake up when a player comes close and go
--- back to sleep when the area is empty. Monsters see in a circle, hear noises,
--- chase with a local A* and attack in melee, with projectiles or with bursts.
local MonsterConfig = require("src.config.monsters")
local Config = require("src.config.extraction")
local GameConfig = require("src.config.game")
local Pathing = require("src.game.extraction.pathing")
local Loot = require("src.game.extraction.loot")

local Monsters = {}

local floor, sqrt, min, max, cos, sin, atan2 = math.floor, math.sqrt, math.min, math.max, math.cos, math.sin, math.atan2

local CELL = 500
local THINK = 6
-- Monsters leave a player alone for a while after they arrive in the world.
local SPAWN_GRACE = 60 * 10

function Monsters.setup(w)
    w.monsters, w.nextMonster, w.monsterCells, w.nests = {}, 1, {}, {}
    w.monsterCount = 0
    for _, nest in ipairs(w.def.nests) do
        w.nests[nest.id] = { id = nest.id, x = nest.x, y = nest.y, tier = nest.tier, biome = nest.biome, awake = false, alive = 0, cooldown = 0, idle = 0 }
    end
end

local function rebuild(w)
    local cells = {}
    for _, m in pairs(w.monsters) do
        local key = floor(m.y / CELL) * 1000 + floor(m.x / CELL)
        local list = cells[key]
        if not list then
            list = {}
            cells[key] = list
        end
        list[#list + 1] = m
    end
    w.monsterCells = cells
end

--- Monsters in a box.
--- @return table[]
function Monsters.near(w, x0, y0, x1, y1)
    local out = {}
    for cy = floor(y0 / CELL), floor(y1 / CELL) do
        for cx = floor(x0 / CELL), floor(x1 / CELL) do
            for _, m in ipairs(w.monsterCells[cy * 1000 + cx] or {}) do
                if m.hp > 0 and m.x >= x0 and m.x <= x1 and m.y >= y0 and m.y <= y1 then out[#out + 1] = m end
            end
        end
    end
    return out
end

--- @param w table
--- @param kind string
--- @param tier number
--- @param options table? { nest, event, home }
--- @return table?
function Monsters.spawn(w, kind, x, y, tier, options)
    options = options or {}
    local def = MonsterConfig[kind]
    if not def or (w.monsterCount >= Config.monsterCap and not options.force) then return nil end
    for _ = 1, 10 do
        if w.terrain:clear(x, y, def.radius + 2) then break end
        x, y = x + w.rng:random(-160, 160), y + w.rng:random(-160, 160)
    end
    local scale = 1 + (tier - 1) * 0.25
    local m = {
        id = w.nextMonster, kind = kind, def = def, tier = tier, x = x, y = y, vx = 0, vy = 0, angle = w.rng:random() * math.pi * 2,
        hp = floor(def.hp * scale), max = floor(def.hp * scale), damage = def.damage * (1 + (tier - 1) * 0.15),
        homeX = options.home and options.home.x or x, homeY = options.home and options.home.y or y,
        nest = options.nest, event = options.event, cooldown = 0, stun = 0, chill = 0, burn = 0, poison = 0,
        think = w.nextMonster % THINK, summon = def.summonEvery
    }
    w.nextMonster = w.nextMonster + 1
    w.monsters[m.id] = m
    w.monsterCount = w.monsterCount + 1
    local key = floor(m.y / CELL) * 1000 + floor(m.x / CELL)
    w.monsterCells[key] = w.monsterCells[key] or {}
    table.insert(w.monsterCells[key], m)
    return m
end

--- @param w table
--- @param m table
--- @param remains boolean drop loot
function Monsters.remove(w, m)
    if not w.monsters[m.id] then return end
    w.monsters[m.id] = nil
    w.monsterCount = w.monsterCount - 1
    local nest = m.nest and w.nests[m.nest]
    if nest then nest.alive = max(0, nest.alive - 1) end
end

--- @param w table
--- @param m table
--- @param attacker table?
function Monsters.kill(w, m, attacker)
    m.hp = 0
    Monsters.remove(w, m)
    local nest = m.nest and w.nests[m.nest]
    if nest and nest.alive == 0 then
        nest.cooldown = w.tick + MonsterConfig.respawn
        nest.awake = false
    end
    local items, gw, gh = Loot.drop(m.def, m.tier, w.rng, w.alloc)
    if #items > 0 then
        w:drop(m.x, m.y, "remains", m.def.name, items, gw, gh, 60 * 60 * 5)
    end
    if attacker and attacker.slot and not attacker.kind then
        attacker.monsterKills = (attacker.monsterKills or 0) + 1
    end
    local Fight = require("src.game.extraction.fight")
    Fight.boom(w, "death", m.x, m.y, m.def.radius)
    if m.event then
        local Events = require("src.game.extraction.events")
        Events.onDeath(w, m, attacker)
    end
end

--- @param w table
--- @param m table
--- @param amount number
--- @param attacker table?
--- @param opts table?
--- @return number dealt
function Monsters.hurt(w, m, amount, attacker, opts)
    if m.hp <= 0 then return 0 end
    opts = opts or {}
    if m.def.armored and not opts.status then
        amount = amount * (1 - m.def.armored * (1 - min(1, max(0, opts.armorPierce or 0))))
    end
    local dealt = min(m.hp, amount)
    m.hp = m.hp - amount
    if attacker and attacker.slot and not attacker.kind and attacker.hp and attacker.hp > 0 then
        m.aggro = attacker
        if not opts.status then
            w:send(attacker.slot, "xhit", { x = floor(m.x), y = floor(m.y), d = floor(amount + 0.5), k = m.hp <= 0 and 1 or nil, m = 1 })
        end
    end
    if m.hp <= 0 then Monsters.kill(w, m, attacker) end
    return dealt
end

local function los(w, x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local d = sqrt(dx * dx + dy * dy)
    if d < 1 then return true end
    return w.terrain:raycast(x1, y1, dx / d, dy / d, d, "vision") >= d - 2
end

--- Picks a goal: a visible player, the one that hurt it, a noise, or a stroll around home.
local function think(w, m, budget)
    local def = m.def
    local best, bestD
    for _, p in pairs(w.players) do
        if p.dead == 0 and p.hp > 0 and (w.tick - (p.joinedAt or -1e9) >= SPAWN_GRACE or p == m.aggro) then
            local d = sqrt((p.x - m.x) ^ 2 + (p.y - m.y) ^ 2)
            local sight = def.sight
            if p == m.aggro then sight = sight * 2 end
            if d < sight and (not bestD or d < bestD) and los(w, m.x, m.y, p.x, p.y) then best, bestD = p, d end
        end
    end
    if best then
        m.target, m.seen = best, w.tick
        m.goalX, m.goalY = best.x, best.y
        m.state = "chase"
    elseif m.target and w.tick - (m.seen or 0) < 360 and m.target.dead == 0 then
        m.state = "hunt"
    else
        m.target = nil
        if m.heardX then
            m.goalX, m.goalY, m.state = m.heardX, m.heardY, "alert"
            m.heardX, m.heardY = nil, nil
        elseif m.state ~= "wander" or not m.goalX or (m.goalX - m.x) ^ 2 + (m.goalY - m.y) ^ 2 < 40 * 40 or w.rng:random() < 0.02 then
            local far = (m.x - m.homeX) ^ 2 + (m.y - m.homeY) ^ 2 > 2500 * 2500
            local a, r = w.rng:random() * math.pi * 2, w.rng:random(60, far and 120 or 380)
            m.goalX, m.goalY = m.homeX + cos(a) * r, m.homeY + sin(a) * r
            m.state = "wander"
        end
    end
    m.path, m.pathIndex = nil, 1
    if m.goalX and budget.left > 0 and not Pathing.line(w.terrain, m.x, m.y, m.goalX, m.goalY, def.radius) then
        budget.left = budget.left - 1
        m.path = Pathing.find(w.terrain, m.x, m.y, m.goalX, m.goalY, def.radius + 2)
        m.pathIndex = 1
        if not m.path and m.state == "wander" then m.goalX = nil end
    end
end

local function burst(w, m)
    local Fight = require("src.game.extraction.fight")
    local target = m.target
    if not target then return end
    local a = atan2(target.y - m.y, target.x - m.x) + (w.rng:random() - 0.5) * 2 * m.def.spread
    local dx, dy = cos(a), sin(a)
    local sx, sy = m.x + dx * (m.def.radius + 4), m.y + dy * (m.def.radius + 4)
    local length = w.terrain:raycast(sx, sy, dx, dy, m.def.range, "bullet")
    local hit = 0
    for _, p in pairs(w.players) do
        if p.dead == 0 then
            local fx, fy = sx - p.x, sy - p.y
            local b = fx * dx + fy * dy
            local c = fx * fx + fy * fy - GameConfig.player.radius ^ 2
            local disc = b * b - c
            if disc >= 0 then
                local t = -b - sqrt(disc)
                if t >= 0 and t < length and not (p.dash > 0) then
                    length, hit = t, p
                end
            end
        end
    end
    w.shots[#w.shots + 1] = { x = sx, y = sy, X = sx + dx * length, Y = sy + dy * length, h = hit ~= 0 and 2 or 1, g = m.def.boss and "lmg" or "rifle", mo = m.id }
    Fight.noise(w, "shot", m.x, m.y, nil, 900)
    if hit ~= 0 then Fight.hurtPlayer(w, hit, m.damage, m) end
end

local function attack(w, m)
    local Fight = require("src.game.extraction.fight")
    local def, target = m.def, m.target
    if m.bursting then
        m.burstTimer = m.burstTimer - 1
        if m.burstTimer <= 0 then
            burst(w, m)
            m.bursting = m.bursting - 1
            m.burstTimer = def.burstTicks
            if m.bursting <= 0 then m.bursting = nil end
        end
        return
    end
    if not target or target.dead > 0 or m.cooldown > 0 or m.stun > 0 then return end
    local d = sqrt((target.x - m.x) ^ 2 + (target.y - m.y) ^ 2)
    if def.attack == "melee" then
        if d < def.reach + def.radius + GameConfig.player.radius then
            m.cooldown, m.swing = def.cooldown, 10
            Fight.hurtPlayer(w, target, m.damage, m)
            if def.knock and d > 0 then
                target.vx = target.vx + (target.x - m.x) / d * def.knock
                target.vy = target.vy + (target.y - m.y) / d * def.knock
            end
            Fight.noise(w, "melee", m.x, m.y, nil)
        end
    elseif d < def.range and los(w, m.x, m.y, target.x, target.y) then
        m.cooldown = def.cooldown
        if def.attack == "spit" then
            Fight.spit(w, m, target.x, target.y)
            m.swing = 8
        else
            m.bursting, m.burstTimer = def.burst, 0
        end
    end
end

local function move(w, m)
    local def = m.def
    local speed = def.speed * ((m.chill or 0) > 0 and 0.55 or 1)
    if m.stun > 0 then speed = 0 end
    local wx, wy = 0, 0
    local gx, gy = m.goalX, m.goalY
    if m.path and m.path[m.pathIndex] then
        local point = m.path[m.pathIndex]
        gx, gy = point.x, point.y
        if (gx - m.x) ^ 2 + (gy - m.y) ^ 2 < 24 * 24 then
            m.pathIndex = m.pathIndex + 1
        end
    end
    if gx then
        local dx, dy = gx - m.x, gy - m.y
        local d = sqrt(dx * dx + dy * dy)
        if d > 6 then wx, wy = dx / d, dy / d end
    end
    local target = m.target
    if target and def.keep and w.tick - (m.seen or 0) < 10 then
        local dx, dy = target.x - m.x, target.y - m.y
        local d = max(1, sqrt(dx * dx + dy * dy))
        if d < def.keep then
            wx, wy = -dx / d, -dy / d
        elseif d < def.range * 0.9 then
            local side = (m.id % 2 == 0) and 1 or -1
            wx, wy = -dy / d * side * 0.6, dx / d * side * 0.6
        end
    end
    if m.state == "wander" then speed = speed * 0.45 end
    for _, other in ipairs(Monsters.near(w, m.x - 60, m.y - 60, m.x + 60, m.y + 60)) do
        if other ~= m then
            local dx, dy = m.x - other.x, m.y - other.y
            local d = sqrt(dx * dx + dy * dy)
            local reach = def.radius + other.def.radius
            if d > 0 and d < reach then
                wx, wy = wx + dx / d * 0.8, wy + dy / d * 0.8
            end
        end
    end
    local blend = min(1, 10 * w.dt)
    m.vx = m.vx + (wx * speed - m.vx) * blend
    m.vy = m.vy + (wy * speed - m.vy) * blend
    if m.knockX then
        m.vx, m.vy = m.vx + m.knockX, m.vy + m.knockY
        m.knockX, m.knockY = nil, nil
    end
    local ox, oy = m.x, m.y
    local x, y = w.terrain:resolve(m.x + m.vx * w.dt, m.y + m.vy * w.dt, def.radius)
    m.x, m.y = x, y
    if target and w.tick - (m.seen or 0) < 10 then
        m.angle = atan2(target.y - m.y, target.x - m.x)
    elseif m.vx * m.vx + m.vy * m.vy > 100 then
        m.angle = atan2(m.vy, m.vx)
    end
    if speed > 0 and (x - ox) ^ 2 + (y - oy) ^ 2 < 0.25 and (wx ~= 0 or wy ~= 0) then
        m.stuck = (m.stuck or 0) + 1
        if m.stuck > 40 then
            m.stuck = 0
            m.goalX, m.goalY = m.x + w.rng:random(-200, 200), m.y + w.rng:random(-200, 200)
            m.path = nil
        end
    else
        m.stuck = 0
    end
end

local function nests(w)
    local r2 = Config.activation ^ 2
    for _, nest in pairs(w.nests) do
        local near = false
        for _, p in pairs(w.players) do
            if p.dead == 0 and (p.x - nest.x) ^ 2 + (p.y - nest.y) ^ 2 < r2 then
                near = true
                break
            end
        end
        if near then
            nest.idle = 0
            if not nest.awake and nest.cooldown <= w.tick then
                nest.awake = true
                local pool = MonsterConfig.nests[nest.biome] or MonsterConfig.nests.forest
                for _ = 1, MonsterConfig.nestSize[nest.tier] or 2 do
                    local kind = pool[w.rng:random(#pool)]
                    if (kind == "brute" or kind == "sentinel") and nest.tier < 2 then kind = "crawler" end
                    local a, r = w.rng:random() * math.pi * 2, w.rng:random(20, 220)
                    if Monsters.spawn(w, kind, nest.x + cos(a) * r, nest.y + sin(a) * r, nest.tier, { nest = nest.id }) then
                        nest.alive = nest.alive + 1
                    end
                end
            end
        elseif nest.awake then
            nest.idle = nest.idle + 30
            if nest.idle >= Config.sleepTicks then
                for _, m in pairs(w.monsters) do
                    if m.nest == nest.id and not m.target then Monsters.remove(w, m) end
                end
                nest.awake = nest.alive > 0
            end
        end
    end
end

--- @param w table
function Monsters.update(w)
    if w.tick % 30 == 0 then nests(w) end
    rebuild(w)
    for _, noise in ipairs(w.noises) do
        local reach = noise.radius * 1.5
        for _, m in ipairs(Monsters.near(w, noise.x - reach, noise.y - reach, noise.x + reach, noise.y + reach)) do
            if not m.target and (m.x - noise.x) ^ 2 + (m.y - noise.y) ^ 2 < (noise.radius * m.def.hearing) ^ 2 then
                m.heardX, m.heardY = noise.x, noise.y
            end
        end
    end
    local budget = { left = Config.aiBudget }
    local phase = w.tick % THINK
    local summons = {}
    for _, m in pairs(w.monsters) do
        if m.hp > 0 then
            if m.cooldown > 0 then m.cooldown = m.cooldown - 1 end
            if m.stun > 0 then m.stun = m.stun - 1 end
            if (m.chill or 0) > 0 then m.chill = m.chill - 1 end
            if m.swing then
                m.swing = m.swing - 1
                if m.swing <= 0 then m.swing = nil end
            end
            if (m.burn or 0) > 0 then
                m.burn = m.burn - 1
                if m.burn % 30 == 0 then Monsters.hurt(w, m, m.burnDamage or 3, m.burnBy, { status = true }) end
            end
            if (m.poison or 0) > 0 and m.hp > 0 then
                m.poison = m.poison - 1
                if m.poison % 45 == 0 then Monsters.hurt(w, m, m.poisonDamage or 4, m.poisonBy, { status = true }) end
            end
            if m.hp > 0 then
                if m.think == phase then think(w, m, budget) end
                if m.target and m.target.dead == 0 and w.tick - (m.seen or 0) < 360 and m.state == "chase" and m.think == phase then
                    m.goalX, m.goalY = m.target.x, m.target.y
                end
                move(w, m)
                attack(w, m)
                if m.summon then
                    m.summon = m.summon - 1
                    if m.summon <= 0 and m.target then
                        m.summon = m.def.summonEvery
                        summons[#summons + 1] = m
                    end
                end
            end
        end
    end
    for _, m in ipairs(summons) do
        for _ = 1, 3 do
            Monsters.spawn(w, m.def.summon, m.x + w.rng:random(-120, 120), m.y + w.rng:random(-120, 120), m.tier, { event = m.event, force = true })
        end
    end
end

return Monsters
