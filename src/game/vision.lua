local Config = require("src.config.game")

local Vision = {}

local cos, sin, sqrt, atan2, abs, pi = math.cos, math.sin, math.sqrt, math.atan2, math.abs, math.pi

local function angleBetween(a, b)
    return abs((b - a + pi) % (2 * pi) - pi)
end

local function clear(arena, x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local d = sqrt(dx * dx + dy * dy)
    if d < 1e-6 then return true end
    return arena:raycast(x1, y1, dx / d, dy / d, d, "vision") >= d - 1e-6
end

--- @param arena table
--- @param viewer table
--- @param x number
--- @param y number
--- @param radius number
--- @param margin number?
--- @param near number?
--- @return boolean
function Vision.sees(arena, viewer, x, y, radius, margin, near)
    local def = Config.vision
    local dx, dy = x - viewer.x, y - viewer.y
    local d = sqrt(dx * dx + dy * dy)
    if d > (viewer.range or def.range) then return false end
    local inCone = d <= (near or def.nearRadius) + radius
        or angleBetween(viewer.angle, atan2(dy, dx)) <= def.halfAngle + (margin or 0) + (d > 0 and radius / d or 0)
    if not inCone then return false end
    if clear(arena, viewer.x, viewer.y, x, y) then return true end
    if d < 1e-6 then return true end
    local nx, ny = -dy / d * radius, dx / d * radius
    return clear(arena, viewer.x, viewer.y, x + nx, y + ny) or clear(arena, viewer.x, viewer.y, x - nx, y - ny)
end

--- @param arena table
--- @param x number
--- @param y number
--- @param angle number
--- @param range number? view distance, the configured one when nil
--- @return number[], number[]
function Vision.fans(arena, x, y, angle, range)
    local def = Config.vision
    range = range or def.range
    local cone = { x, y }
    local steps = 120
    for k = 0, steps do
        local a = angle - def.halfAngle + 2 * def.halfAngle * k / steps
        local dx, dy = cos(a), sin(a)
        local length = arena:raycast(x, y, dx, dy, range, "vision")
        cone[#cone + 1] = x + dx * length
        cone[#cone + 1] = y + dy * length
    end
    local near = { x, y }
    for k = 0, 48 do
        local a = k / 48 * 2 * pi
        local dx, dy = cos(a), sin(a)
        local length = arena:raycast(x, y, dx, dy, def.nearRadius, "vision")
        near[#near + 1] = x + dx * length
        near[#near + 1] = y + dy * length
    end
    return cone, near
end

return Vision
