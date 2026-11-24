local Arena = {}
Arena.__index = Arena

local max, min, sqrt, abs = math.max, math.min, math.sqrt, math.abs

local DOOR_RADIUS = 78
local DOOR_CLOSE_TICKS = 45
local GLASS_RESPAWN_TICKS = 60 * 25

local DEFAULT = {
    name = "Atrium",
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
        { x = 900, y = 1080, kind = "shotgun" },
        { x = 560, y = 300, kind = "ammo" },
        { x = 1240, y = 900, kind = "ammo" },
        { x = 200, y = 1000, kind = "sniper" },
        { x = 1600, y = 200, kind = "sniper" },
        { x = 520, y = 560, kind = "silencer" },
        { x = 1280, y = 640, kind = "silencer" },
        { x = 640, y = 900, kind = "lmg" },
        { x = 1160, y = 300, kind = "lmg" }
    }
}

Arena.DEFAULT = DEFAULT

local function copy(list, extra)
    local out = {}
    for k, r in ipairs(list or {}) do
        local item = { x = r.x, y = r.y, w = r.w, h = r.h, index = k }
        for key, value in pairs(extra or {}) do item[key] = value end
        out[k] = item
    end
    return out
end

--- @param def table?
--- @return table
function Arena.new(def)
    def = def or DEFAULT
    return setmetatable({
        id = def.id,
        name = def.name,
        width = def.width,
        height = def.height,
        walls = def.walls,
        cover = def.cover or {},
        pits = def.pits or {},
        doors = copy(def.doors, { open = false, timer = 0, kind = "door" }),
        glass = copy(def.glass, { broken = false, timer = 0, kind = "glass" }),
        spawns = def.spawns,
        loot = def.loot or {},
        objectives = def.objectives or {},
        smokes = {}
    }, Arena)
end

--- @param slot number
--- @return table
function Arena:spawn(slot)
    return self.spawns[(slot - 1) % #self.spawns + 1]
end

--- @param mode string
--- @param fn function
function Arena:each(mode, fn)
    for _, wall in ipairs(self.walls) do
        if fn(wall) then return end
    end
    if mode ~= "nav" then
        for _, door in ipairs(self.doors) do
            if not door.open and fn(door) then return end
        end
    end
    if mode ~= "vision" then
        for _, pane in ipairs(self.glass) do
            if not pane.broken and fn(pane) then return end
        end
    end
    if mode == "move" or mode == "nav" then
        for _, block in ipairs(self.cover) do
            if fn(block) then return end
        end
        for _, pit in ipairs(self.pits) do
            if fn(pit) then return end
        end
    end
end

--- @return number, number, number, number
function Arena:resolve(x, y, radius)
    local nx, ny = 0, 0
    for _ = 1, 2 do
        local hit = false
        self:each("move", function(wall)
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
        end)
        if not hit then break end
    end
    return x, y, nx, ny
end

local function slab(x, y, dx, dy, rect, best)
    local tmin, tmax = 0, best
    for axis = 1, 2 do
        local origin = axis == 1 and x or y
        local dir = axis == 1 and dx or dy
        local lo = axis == 1 and rect.x or rect.y
        local hi = lo + (axis == 1 and rect.w or rect.h)
        if abs(dir) < 1e-9 then
            if origin < lo or origin > hi then return nil end
        else
            local t1, t2 = (lo - origin) / dir, (hi - origin) / dir
            if t1 > t2 then t1, t2 = t2, t1 end
            tmin, tmax = max(tmin, t1), min(tmax, t2)
            if tmin > tmax then return nil end
        end
    end
    return tmin
end

--- @param mode string?
--- @return number, table?
function Arena:raycast(x, y, dx, dy, maxLength, mode)
    local best, target = maxLength, nil
    self:each(mode or "bullet", function(rect)
        local t = slab(x, y, dx, dy, rect, best)
        if t and t < best then
            best, target = t, rect
        end
    end)
    if mode == "vision" then
        for _, smoke in ipairs(self.smokes) do
            local t = Arena.circle(x, y, dx, dy, smoke.x, smoke.y, smoke.r)
            if t and t < best then
                best, target = t, smoke
            end
        end
    end
    return best, target
end

--- @return number?
function Arena.circle(x, y, dx, dy, cx, cy, r)
    local fx, fy = x - cx, y - cy
    local c = fx * fx + fy * fy - r * r
    if c <= 0 then return 0 end
    local b = fx * dx + fy * dy
    if b > 0 then return nil end
    local disc = b * b - c
    if disc < 0 then return nil end
    return -b - sqrt(disc)
end

local function overlaps(rect, players, radius)
    for _, p in pairs(players) do
        if p.hp > 0 and p.dead == 0 then
            local cx = max(rect.x, min(p.x, rect.x + rect.w))
            local cy = max(rect.y, min(p.y, rect.y + rect.h))
            if (p.x - cx) ^ 2 + (p.y - cy) ^ 2 < radius * radius then return p end
        end
    end
    return nil
end

--- @param players table
--- @return table[]
function Arena:updateDoors(players)
    local opened = {}
    for _, door in ipairs(self.doors) do
        local near = overlaps(door, players, DOOR_RADIUS)
        if near then
            if not door.open then
                door.opener = near.slot
                opened[#opened + 1] = door
            end
            door.open = true
            door.timer = DOOR_CLOSE_TICKS
        elseif door.open then
            door.timer = door.timer - 1
            if door.timer <= 0 and not overlaps(door, players, 20) then
                door.open = false
            end
        end
    end
    return opened
end

--- @param pane table
function Arena:breakGlass(pane)
    pane.broken = true
    pane.timer = GLASS_RESPAWN_TICKS
end

--- @param players table
function Arena:updateGlass(players)
    for _, pane in ipairs(self.glass) do
        if pane.broken then
            pane.timer = pane.timer - 1
            if pane.timer <= 0 and not overlaps(pane, players, 20) then
                pane.broken = false
            end
        end
    end
end

--- @return string?, string?
function Arena:state()
    if #self.doors == 0 and #self.glass == 0 then return nil, nil end
    local doors, glass = {}, {}
    for k, door in ipairs(self.doors) do doors[k] = door.open and "1" or "0" end
    for k, pane in ipairs(self.glass) do glass[k] = pane.broken and "0" or "1" end
    return table.concat(doors), table.concat(glass)
end

--- @param doors string?
--- @param glass string?
function Arena:applyState(doors, glass)
    if type(doors) == "string" then
        for k, door in ipairs(self.doors) do door.open = doors:sub(k, k) == "1" end
    end
    if type(glass) == "string" then
        for k, pane in ipairs(self.glass) do pane.broken = glass:sub(k, k) == "0" end
    end
end

return Arena
