local Arena = {}
Arena.__index = Arena

local max, min, sqrt, abs = math.max, math.min, math.sqrt, math.abs

local DEFAULT = {
    width = 1800,
    height = 1200,
    walls = {
        { x = 0, y = 0, w = 1800, h = 40 },
        { x = 0, y = 1160, w = 1800, h = 40 },
        { x = 0, y = 40, w = 40, h = 1120 },
        { x = 1760, y = 40, w = 40, h = 1120 },

        { x = 380, y = 40, w = 30, h = 360 },
        { x = 380, y = 800, w = 30, h = 360 },
        { x = 1390, y = 40, w = 30, h = 360 },
        { x = 1390, y = 800, w = 30, h = 360 },

        { x = 860, y = 250, w = 80, h = 80 },
        { x = 860, y = 870, w = 80, h = 80 },
        { x = 640, y = 560, w = 80, h = 80 },
        { x = 1080, y = 560, w = 80, h = 80 },
        { x = 200, y = 560, w = 60, h = 60 },
        { x = 1540, y = 580, w = 60, h = 60 },

        { x = 600, y = 180, w = 160, h = 24 },
        { x = 1040, y = 996, w = 160, h = 24 }
    },
    spawns = {
        { x = 160, y = 380, angle = 0 },
        { x = 1640, y = 820, angle = math.pi }
    },
    loot = {
        { x = 900, y = 600, kind = "rifle" },
        { x = 900, y = 120, kind = "shotgun" },
        { x = 900, y = 1080, kind = "shotgun" }
    }
}

--- @param def table?
--- @return table
function Arena.new(def)
    def = def or DEFAULT
    return setmetatable({ width = def.width, height = def.height, walls = def.walls, spawns = def.spawns, loot = def.loot or {} }, Arena)
end

--- @param slot number
--- @return table
function Arena:spawn(slot)
    return self.spawns[(slot - 1) % #self.spawns + 1]
end

--- @return number, number, number, number
function Arena:resolve(x, y, radius)
    local nx, ny = 0, 0
    for _ = 1, 2 do
        local hit = false
        for _, wall in ipairs(self.walls) do
            local cx = max(wall.x, min(x, wall.x + wall.w))
            local cy = max(wall.y, min(y, wall.y + wall.h))
            local dx, dy = x - cx, y - cy
            local d2 = dx * dx + dy * dy
            if d2 < radius * radius then
                hit = true
                if d2 > 1e-9 then
                    local d = sqrt(d2)
                    nx, ny = dx / d, dy / d
                    x, y = cx + nx * radius, cy + ny * radius
                else
                    local left, right = x - wall.x, wall.x + wall.w - x
                    local top, bottom = y - wall.y, wall.y + wall.h - y
                    local best = min(left, right, top, bottom)
                    if best == left then
                        nx, ny, x = -1, 0, wall.x - radius
                    elseif best == right then
                        nx, ny, x = 1, 0, wall.x + wall.w + radius
                    elseif best == top then
                        nx, ny, y = 0, -1, wall.y - radius
                    else
                        nx, ny, y = 0, 1, wall.y + wall.h + radius
                    end
                end
            end
        end
        if not hit then break end
    end
    return x, y, nx, ny
end

--- @return number
function Arena:raycast(x, y, dx, dy, maxLength)
    local best = maxLength
    for _, wall in ipairs(self.walls) do
        local tmin, tmax = 0, best
        local hit = true
        for axis = 1, 2 do
            local origin = axis == 1 and x or y
            local dir = axis == 1 and dx or dy
            local lo = axis == 1 and wall.x or wall.y
            local hi = lo + (axis == 1 and wall.w or wall.h)
            if abs(dir) < 1e-9 then
                if origin < lo or origin > hi then hit = false break end
            else
                local t1, t2 = (lo - origin) / dir, (hi - origin) / dir
                if t1 > t2 then t1, t2 = t2, t1 end
                tmin, tmax = max(tmin, t1), min(tmax, t2)
                if tmin > tmax then hit = false break end
            end
        end
        if hit and tmin < best then best = tmin end
    end
    return best
end

return Arena
