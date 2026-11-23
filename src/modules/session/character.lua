local Config = require("src.config.game")

local Character = {}

local cos, sin, sqrt, min, atan2, pi = math.cos, math.sin, math.sqrt, math.min, math.atan2, math.pi

local LIGHT = -2.4
local MUZZLE_X, MUZZLE_Y = 28, 2.4
local STRIDE = 2 * pi / 34
local SWAY = 0.08

local GUN = { 0.09, 0.09, 0.1 }

Character.PALETTES = {
    self = { body = { 0.24, 0.25, 0.28 } },
    opponent = { body = { 0.88, 0.14, 0.12 } }
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

local GUN_BODY = { { 20, 0.6 }, { 20, 4.2 }, { 6.5, 4.6 }, { 4, 2.4 }, { 6.5, 0.2 } }

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

local function drawGun(angle)
    facets(GUN, GUN_BODY, 12, 2.4, 0.8, angle)
    segment(GUN, 19.5, 2.4, MUZZLE_X, MUZZLE_Y, 2.2, 1.6, angle)
    segment(GUN, 12.5, 4.2, 13.5, 8.5, 3, 2.6, angle)
end

local function drawArms(c, angle)
    segment(c, 0.5, 10, 5.5, 9.4, 5, 4.4, angle)
    segment(c, 5.5, 9.4, 9, 4.2, 4.4, 3.6, angle)
    segment(c, 0.5, -10, 8.5, -7.2, 5, 4.4, angle)
    segment(c, 8.5, -7.2, 16.5, 1.6, 4.4, 3.6, angle)
    gem(c, 9.2, 3.6, 2.4, 2.2, 5, 0.7, angle)
    gem(c, 16.8, 2, 2.4, 2.2, 5, 0.7, angle)
end

function Character.reset()
    states = {}
end

--- @param p table
--- @return number, number
function Character.muzzle(p)
    local ca, sa = cos(p.angle), sin(p.angle)
    return p.x + ca * MUZZLE_X - sa * MUZZLE_Y, p.y + sa * MUZZLE_X + ca * MUZZLE_Y
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
    drawFeet(c, phase, p, speed)
    lg.rotate(sway)
    local angle = p.angle + sway
    facets(c, TORSO, -0.5, 0, 0.8, angle)
    drawGun(angle)
    drawArms(c, angle)
    lg.setColor(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 0.55 * opacity)
    lg.ellipse("fill", 0.2, 0, 6.6, 6.2)
    facets({ c[1] * 1.12, c[2] * 1.12, c[3] * 1.12 }, HEAD, 0.8, 0, 1, angle)
    lg.pop()
    opacity = 1
end

return Character
