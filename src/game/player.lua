local Config = require("src.config.game")

local Player = {}

local cos, sin, sqrt, floor, pi = math.cos, math.sin, math.sqrt, math.floor, math.pi

local TAU = 2 * pi
local ANGLE_STEPS = 65536

Player.ANGLE_STEPS = ANGLE_STEPS

--- @param angle number
--- @return number
function Player.packAngle(angle)
    return floor((angle % TAU) / TAU * ANGLE_STEPS + 0.5) % ANGLE_STEPS
end

--- @param value number
--- @return number
function Player.unpackAngle(value)
    return value / ANGLE_STEPS * TAU
end

--- @param slot number
--- @param name string
--- @param spawn table
--- @return table
function Player.new(slot, name, spawn)
    return {
        slot = slot,
        name = name,
        x = spawn.x,
        y = spawn.y,
        angle = Player.unpackAngle(Player.packAngle(spawn.angle)),
        vx = 0,
        vy = 0
    }
end

--- @param from table
--- @param to table?
--- @return table
function Player.copy(from, to)
    to = to or {}
    to.slot, to.name = from.slot, from.name
    to.x, to.y, to.angle, to.vx, to.vy = from.x, from.y, from.angle, from.vx, from.vy
    return to
end

--- @param p table
--- @param input table
--- @param arena table
--- @param dt number
function Player.step(p, input, arena, dt)
    local def = Config.player
    local angle = Player.unpackAngle(input.a)
    p.angle = angle

    local ca, sa = cos(angle), sin(angle)
    local forward = input.f
    if forward < 0 then forward = forward * def.backSpeed end
    local wx = ca * forward - sa * input.r
    local wy = sa * forward + ca * input.r
    local len = sqrt(wx * wx + wy * wy)
    if len > 1 then
        wx, wy = wx / len, wy / len
    end

    local blend = def.acceleration * dt
    if blend > 1 then blend = 1 end
    p.vx = p.vx + (wx * def.speed - p.vx) * blend
    p.vy = p.vy + (wy * def.speed - p.vy) * blend

    local x, y, nx, ny = arena:resolve(p.x + p.vx * dt, p.y + p.vy * dt, def.radius)
    local into = p.vx * nx + p.vy * ny
    if into < 0 then
        p.vx, p.vy = p.vx - nx * into, p.vy - ny * into
    end
    p.x, p.y = x, y
end

return Player
