local Config = require("src.config.game")

local Character = {}

local cos, sin, sqrt, min, atan2, pi = math.cos, math.sin, math.sqrt, math.min, math.atan2, math.pi

local LIGHT = -2.4
local LINE = 2.4
local STRIDE = 2 * pi / 34
local SWAY = 0.08

local GUN = { 0.09, 0.09, 0.1 }
local SCOPE = { 0.22, 0.23, 0.26 }

Character.PALETTES = {
    self = { body = { 0.24, 0.25, 0.28 } },
    opponent = { body = { 0.88, 0.14, 0.12 } },
    ally = { body = { 0.24, 0.42, 0.62 } }
}

Character.LIGHT = LIGHT

local states = {}
local opacity = 1

local function shade(c, normal, tilt, angle)
    local k = 1 + 0.45 * tilt * cos(normal + angle - LIGHT)
    return min(1, c[1] * k), min(1, c[2] * k), min(1, c[3] * k)
end

local function facets(c, outline, ax, ay, tilt, angle)
    local lg = love.graphics
    local n = #outline
    for k = 1, n do
        local a, b = outline[k], outline[k % n + 1]
        local mx, my = (a[1] + b[1]) / 2 - ax, (a[2] + b[2]) / 2 - ay
        local r, g, b2 = shade(c, atan2(my, mx), tilt, angle)
        lg.setColor(r, g, b2, opacity)
        lg.polygon("fill", ax, ay, a[1], a[2], b[1], b[2])
    end
end

local function segment(c, x1, y1, x2, y2, w1, w2, angle)
    local dx, dy = x2 - x1, y2 - y1
    local len = sqrt(dx * dx + dy * dy)
    local nx, ny = -dy / len * 0.5, dx / len * 0.5
    local outline = {
        { x1 + nx * w1, y1 + ny * w1 },
        { x2 + nx * w2, y2 + ny * w2 },
        { x2 + dx / len * w2 * 0.4, y2 + dy / len * w2 * 0.4 },
        { x2 - nx * w2, y2 - ny * w2 },
        { x1 - nx * w1, y1 - ny * w1 },
        { x1 - dx / len * w1 * 0.4, y1 - dy / len * w1 * 0.4 }
    }
    facets(c, outline, (x1 + x2) / 2, (y1 + y2) / 2, 0.9, angle)
end

local function gem(c, x, y, rx, ry, sides, tilt, angle)
    local outline = {}
    for k = 0, sides - 1 do
        local a = k / sides * 2 * pi
        outline[#outline + 1] = { x + cos(a) * rx, y + sin(a) * ry }
    end
    facets(c, outline, x + rx * 0.12, y, tilt, angle)
end

local TORSO = {
    { 5, 0 }, { 4.2, -6.5 }, { 1.5, -11.5 }, { -2.5, -11.8 }, { -5.5, -7 },
    { -6.2, 0 }, { -5.5, 7 }, { -2.5, 11.8 }, { 1.5, 11.5 }, { 4.2, 6.5 }
}

local HEAD = {
    { 5.4, 0 }, { 3, -3.6 }, { -1.2, -4.6 }, { -4.4, -2.2 },
    { -4.4, 2.2 }, { -1.2, 4.6 }, { 3, 3.6 }
}

local GUNS = {
    rifle = {
        body = { { 20, 0.6 }, { 20, 4.2 }, { 6.5, 4.6 }, { 4, 2.4 }, { 6.5, 0.2 } },
        center = 12,
        barrel = { 19.5, 28, 2.2, 1.6 },
        mag = { 12.5, 4.2, 13.5, 8.5, 3, 2.6 },
        left = { 16.5, 1.6 },
        right = { 9, 4.2 }
    },
    pistol = {
        body = { { 16, 1.2 }, { 16, 3.6 }, { 9, 4 }, { 8, 2.4 }, { 9, 0.8 } },
        center = 12,
        barrel = { 15.5, 21, 1.8, 1.4 },
        mag = { 10, 3.6, 10.5, 6.5, 2.4, 2.2 },
        left = { 11, 1.2 },
        right = { 9.6, 3.8 }
    },
    sniper = {
        body = { { 20, 0.8 }, { 20, 4 }, { 5, 4.6 }, { 2.5, 2.4 }, { 5, 0.2 } },
        center = 12,
        barrel = { 19.5, 36, 1.8, 1.3 },
        mag = { 11.5, 4, 12, 6.5, 2.4, 2.2 },
        scope = { 9, 15.5 },
        left = { 17.5, 1.6 },
        right = { 9, 4.2 }
    },
    silencer = {
        body = { { 16, 1.2 }, { 16, 3.6 }, { 9, 4 }, { 8, 2.4 }, { 9, 0.8 } },
        center = 12,
        barrel = { 15.5, 26, 3.2, 3.2 },
        mag = { 10, 3.6, 10.5, 6.5, 2.4, 2.2 },
        left = { 11, 1.2 },
        right = { 9.6, 3.8 }
    },
    lmg = {
        body = { { 22, -0.6 }, { 22, 5.4 }, { 5, 5.8 }, { 2, 2.4 }, { 5, -1 } },
        center = 12,
        barrel = { 21.5, 32, 2.6, 2 },
        mag = { 11, 5, 15, 10, 6, 6 },
        left = { 19, 1.2 },
        right = { 9, 4.8 }
    },
    shotgun = {
        body = { { 17, 0.2 }, { 17, 4.6 }, { 5.5, 5 }, { 3, 2.4 }, { 5.5, -0.2 } },
        center = 10,
        barrel = { 16.5, 25, 3.4, 3 },
        mag = { 13.5, 4.4, 14, 6, 3.6, 3.2 },
        left = { 15, 1.2 },
        right = { 8.5, 4.4 }
    }
}

local function animate(p)
    local state = states[p.slot]
    if not state then
        state = { phase = 0, x = p.x, y = p.y }
        states[p.slot] = state
    end
    local dx, dy = p.x - state.x, p.y - state.y
    local moved = sqrt(dx * dx + dy * dy)
    if moved < 60 then
        state.phase = state.phase + moved * STRIDE
    end
    state.x, state.y = p.x, p.y
    return state.phase
end

local function drawFeet(c, phase, p, speed)
    local ca, sa = cos(p.angle), sin(p.angle)
    local vx, vy = p.vx or 0, p.vy or 0
    local lx, ly = vx * ca + vy * sa, -vx * sa + vy * ca
    if speed > 1e-3 then
        lx, ly = lx / speed, ly / speed
    else
        lx, ly = 1, 0
    end
    local amplitude = 7 * min(1, speed / Config.player.speed)
    local dark = { c[1] * 0.75, c[2] * 0.75, c[3] * 0.75 }
    for side = -1, 1, 2 do
        local stride = side * sin(phase) * amplitude
        gem(dark, stride * lx + 1, side * 5 + stride * ly, 5, 2.4, 6, 0.6, p.angle)
    end
end

local function drawGun(gun, angle)
    local b, m = gun.barrel, gun.mag
    facets(GUN, gun.body, gun.center, LINE, 0.8, angle)
    segment(GUN, b[1], LINE, b[2], LINE, b[3], b[4], angle)
    segment(GUN, m[1], m[2], m[3], m[4], m[5], m[6], angle)
    if gun.scope then
        segment(SCOPE, gun.scope[1], LINE - 1.6, gun.scope[2], LINE - 1.6, 2.6, 2.6, angle)
    end
end

local function drawArms(c, gun, angle)
    if not gun then
        segment(c, 0.5, 10, 3.5, 11.5, 5, 4.4, angle)
        segment(c, 3.5, 11.5, 7, 9, 4.4, 3.6, angle)
        segment(c, 0.5, -10, 3.5, -11.5, 5, 4.4, angle)
        segment(c, 3.5, -11.5, 7, -9, 4.4, 3.6, angle)
        gem(c, 7.4, 8.6, 2.4, 2.2, 5, 0.7, angle)
        gem(c, 7.4, -8.6, 2.4, 2.2, 5, 0.7, angle)
        return
    end
    local l, r = gun.left, gun.right
    local elbow = (l[1] + 0.5) / 2
    segment(c, 0.5, 10, 5.5, 9.4, 5, 4.4, angle)
    segment(c, 5.5, 9.4, r[1], r[2], 4.4, 3.6, angle)
    segment(c, 0.5, -10, elbow, -7.2, 5, 4.4, angle)
    segment(c, elbow, -7.2, l[1], l[2], 4.4, 3.6, angle)
    gem(c, r[1] + 0.2, r[2] - 0.6, 2.4, 2.2, 5, 0.7, angle)
    gem(c, l[1] + 0.3, l[2] + 0.4, 2.4, 2.2, 5, 0.7, angle)
end

function Character.reset()
    states = {}
end

local AMMO_BOX = { { 5, -3.5 }, { 5, 3.5 }, { -5, 3.5 }, { -5, -3.5 } }
local AMMO_COLOR = { 0.3, 0.32, 0.36 }
local BULLET = { 0.72, 0.6, 0.32 }

--- @param x number
--- @param y number
--- @param angle number
function Character.drawAmmo(x, y, angle)
    local lg = love.graphics
    lg.push()
    lg.translate(x, y)
    lg.rotate(angle)
    facets(AMMO_COLOR, AMMO_BOX, 0, 0, 0.6, angle)
    for k = -1, 1 do
        segment(BULLET, -3, k * 2.2, 2.6, k * 2.2, 1.4, 1.1, angle)
    end
    lg.pop()
end

--- @param kind string
--- @param x number
--- @param y number
--- @param angle number
--- @param alpha number?
function Character.drawWeapon(kind, x, y, angle, alpha)
    local gun = GUNS[kind]
    if not gun then return end
    local lg = love.graphics
    opacity = alpha or 1
    lg.push()
    lg.translate(x, y)
    lg.rotate(angle)
    lg.translate(-gun.center, -LINE)
    drawGun(gun, angle)
    lg.pop()
    opacity = 1
end

--- @param slot number
--- @return number
function Character.phase(slot)
    local state = states[slot]
    return state and state.phase or 0
end

--- @param p table
--- @param palette table
--- @param ghost table?
function Character.draw(p, palette, ghost)
    local lg = love.graphics
    local c = palette.body
    local phase = ghost and ghost.phase or animate(p)
    local speed = sqrt((p.vx or 0) ^ 2 + (p.vy or 0) ^ 2)
    local sway = sin(phase) * SWAY * min(1, speed / Config.player.speed)
    opacity = ghost and ghost.alpha or 1

    if not ghost then
        lg.setColor(0.2, 0.22, 0.26, 0.12)
        lg.ellipse("fill", p.x - cos(LIGHT) * 4, p.y - sin(LIGHT) * 4, 12, 12)
    end

    lg.push()
    lg.translate(p.x, p.y)
    lg.rotate(p.angle)
    if p.sliding then
        local dark = { c[1] * 0.75, c[2] * 0.75, c[3] * 0.75 }
        gem(dark, 11, -5.5, 5, 2.4, 6, 0.6, p.angle)
        gem(dark, 13, 4.5, 5, 2.4, 6, 0.6, p.angle)
        lg.translate(-3.5, 0)
        lg.scale(0.94, 0.94)
        sway = -0.12
    else
        drawFeet(c, phase, p, speed)
    end
    lg.rotate(sway)
    local angle = p.angle + sway
    local gun = GUNS[p.weapon or ""]
    facets(c, TORSO, -0.5, 0, 0.8, angle)
    if gun then drawGun(gun, angle) end
    drawArms(c, gun, angle)
    lg.setColor(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 0.55 * opacity)
    lg.ellipse("fill", 0.2, 0, 6.6, 6.2)
    facets({ c[1] * 1.12, c[2] * 1.12, c[3] * 1.12 }, HEAD, 0.8, 0, 1, angle)
    lg.pop()
    opacity = 1
end

return Character
