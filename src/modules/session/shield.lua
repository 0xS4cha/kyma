local Config = require("src.config.game")

--- Plaques de bouclier autour du personnage : fissures animées, flash à l'impact,
--- éclats quand une plaque casse.
local Shield = {}

local cos, sin, pi, min, max, floor, ceil, exp, random = math.cos, math.sin, math.pi, math.min, math.max, math.floor, math.ceil, math.exp, love.math.random

local COLOR = { 0.3, 0.72, 0.95 }
local R = 19                 -- rayon des plaques
local HALF = 0.95            -- demi-ouverture d'une plaque (rad)
local CRACKS = 3             -- fissures par plaque
local SEGMENTS = 6           -- segments par fissure
local FLASH = 0.18
local FRAGMENT_LIFE = 0.75
local RING_LIFE = 0.3

Shield.COLOR = COLOR

local states = {}
local fragments = {}
local rings = {}

local function state(slot)
    local s = states[slot]
    if not s then
        s = { crack = { 0, 0, 0 }, flash = { -9, -9, -9 } }
        states[slot] = s
    end
    return s
end

-- angle (relatif au regard) du centre de la plaque i : la plaque 3 (la 1re touchée) est devant
local function plateOffset(i)
    return ({ -2 * pi / 3, 2 * pi / 3, 0 })[i] or 0
end

local function noise(i, n, j)
    local v = sin(i * 12.9898 + n * 78.233 + j * 37.719) * 43758.5453
    return v - floor(v) - 0.5
end

local function plateHp(armor, i)
    local per = Config.shield.plateHp
    return max(0, min(1, (armor - (i - 1) * per) / per))
end

function Shield.reset()
    states, fragments, rings = {}, {}, {}
end

--- Appelé à chaque impact sur des plaques (event "hit" avec s ~= nil).
--- @param slot number
--- @param armorAfter number  armure restante
--- @param absorbed number    dégâts pris par les plaques
--- @param x number
--- @param y number
--- @param angle number       regard de la cible
function Shield.hit(slot, armorAfter, absorbed, x, y, angle)
    local per, now = Config.shield.plateHp, love.timer.getTime()
    local s = state(slot)
    local top = ceil((armorAfter + absorbed) / per)
    local low = max(1, ceil(armorAfter / per))
    for i = low, top do s.flash[i] = now end
    for i = ceil(armorAfter / per) + 1, top do
        -- plaque cassée : éclats + onde de choc
        local a = angle + plateOffset(i)
        for _ = 1, 9 do
            local fa = a + (random() - 0.5) * 2 * HALF
            local speed = 70 + random() * 150
            fragments[#fragments + 1] = {
                x = x + cos(fa) * R, y = y + sin(fa) * R,
                vx = cos(fa) * speed + (random() - 0.5) * 40, vy = sin(fa) * speed + (random() - 0.5) * 40,
                angle = random() * 2 * pi, spin = (random() - 0.5) * 18, size = 2 + random() * 3.5, time = now
            }
        end
        rings[#rings + 1] = { x = x, y = y, a = a, time = now }
        s.crack[i] = 0
    end
end

local function arcPoint(x, y, a, r)
    return x + cos(a) * r, y + sin(a) * r
end

local function drawCracks(x, y, center, i, progress, alpha)
    local lg = love.graphics
    local visible = progress * SEGMENTS
    for n = 1, CRACKS do
        local u = 0.5 + (n - 2) * 0.32 + noise(i, n, 0) * 0.15
        local a = center - HALF + 2 * HALF * u
        local dir = noise(i, n, 1) > 0 and 1 or -1
        local px, py = arcPoint(x, y, a, R - 3.5)
        for j = 1, SEGMENTS do
            if visible <= j - 1 then break end
            local t = min(1, visible - (j - 1))
            local r = R + (j % 2 == 1 and 3.2 or -3.2) + noise(i, n, j) * 2
            local aj = a + dir * j * 0.1 + noise(i, n, j + 9) * 0.1
            local tx, ty = arcPoint(x, y, aj, r)
            local qx, qy = px + (tx - px) * t, py + (ty - py) * t
            lg.setColor(0.04, 0.09, 0.14, 0.95 * alpha)
            lg.setLineWidth(1.8)
            lg.line(px, py, qx, qy)
            lg.setColor(0.85, 0.97, 1, 0.55 * alpha)
            lg.setLineWidth(0.7)
            lg.line(px + 0.6, py - 0.6, qx + 0.6, qy - 0.6)
            px, py = tx, ty
        end
    end
end

--- Dessine les plaques d'un joueur (monde, autour de x,y).
--- @param p table  { slot, x, y, angle, armor }
--- @param alpha number?
function Shield.draw(p, alpha)
    local armor = p.armor or 0
    if armor <= 0 then return end
    alpha = alpha or 1
    local lg = love.graphics
    local now, dt = love.timer.getTime(), love.timer.getDelta()
    local s = state(p.slot)
    local plates = Config.shield.plates
    for i = 1, plates do
        local hp = plateHp(armor, i)
        if hp > 0 then
            -- les fissures grandissent progressivement vers leur valeur cible
            local target = 1 - hp
            if target < s.crack[i] then
                s.crack[i] = target
            else
                s.crack[i] = s.crack[i] + (target - s.crack[i]) * min(1, dt * 6)
            end
            local since = now - s.flash[i]
            local flash = since < FLASH and (1 - since / FLASH) or 0
            local center = p.angle + plateOffset(i)
            local r = R + flash * 2.5                                  -- la plaque "encaisse" : léger recul
            local shake = flash * 1.2 * sin(now * 90)
            local cx, cy = p.x + cos(center) * shake, p.y + sin(center) * shake
            local a1, a2 = center - HALF, center + HALF
            local dim = 1 - 0.35 * s.crack[i]
            lg.setLineWidth(7)
            lg.setColor(0.05, 0.1, 0.16, 0.22 * alpha)
            lg.arc("line", "open", cx, cy, r, a1, a2, 16)
            lg.setLineWidth(4.4)
            lg.setColor(COLOR[1] * dim + flash * (1 - COLOR[1] * dim), COLOR[2] * dim + flash * (1 - COLOR[2] * dim), COLOR[3] * dim + flash * (1 - COLOR[3] * dim), 0.92 * alpha)
            lg.arc("line", "open", cx, cy, r, a1, a2, 16)
            lg.setLineWidth(1.4)
            lg.setColor(0.9, 0.98, 1, 0.7 * alpha)
            lg.arc("line", "open", cx, cy, r - 1.2, a1 + 0.12, a2 - 0.12, 16)
            if s.crack[i] > 0.02 then drawCracks(cx, cy, center, i, s.crack[i], alpha) end
        else
            s.crack[i] = 0
        end
    end
    lg.setLineWidth(1)
end

--- Éclats et ondes de choc des plaques cassées (à appeler depuis le dessin des effets du monde).
function Shield.drawEffects()
    if #fragments == 0 and #rings == 0 then return end
    local lg = love.graphics
    local now = love.timer.getTime()
    for k = #fragments, 1, -1 do
        local f = fragments[k]
        local age = now - f.time
        if age > FRAGMENT_LIFE then
            table.remove(fragments, k)
        else
            local travel = (1 - exp(-4 * age)) / 4          -- déplacement avec frottement
            local fx, fy = f.x + f.vx * travel, f.y + f.vy * travel
            local ang = f.angle + f.spin * age
            local ca, sa, sz = cos(ang), sin(ang), f.size
            local fade = 1 - age / FRAGMENT_LIFE
            lg.setColor(COLOR[1], COLOR[2], COLOR[3], fade)
            lg.polygon("fill", fx + ca * sz, fy + sa * sz, fx - sa * sz * 0.6, fy + ca * sz * 0.6, fx - ca * sz * 0.8, fy - sa * sz * 0.8)
            lg.setColor(1, 1, 1, fade * 0.8)
            lg.setLineWidth(0.8)
            lg.polygon("line", fx + ca * sz, fy + sa * sz, fx - sa * sz * 0.6, fy + ca * sz * 0.6, fx - ca * sz * 0.8, fy - sa * sz * 0.8)
        end
    end
    for k = #rings, 1, -1 do
        local ring = rings[k]
        local t = (now - ring.time) / RING_LIFE
        if t >= 1 then
            table.remove(rings, k)
        else
            lg.setColor(0.8, 0.96, 1, 0.9 * (1 - t))
            lg.setLineWidth(3 - 2 * t)
            lg.arc("line", "open", ring.x, ring.y, R + 4 + 16 * t, ring.a - HALF, ring.a + HALF, 16)
        end
    end
    lg.setLineWidth(1)
end

return Shield
