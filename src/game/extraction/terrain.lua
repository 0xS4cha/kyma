--- An Arena for very large maps: rectangles are bucketed in a grid of cells so that
--- collisions, raycasts and vision only look at what is near. Doors and glass keep
--- the sets of open doors and broken panes instead of scanning all of them.
local Arena = require("src.game.arena")

local Terrain = setmetatable({}, { __index = Arena })
Terrain.__index = Terrain

local floor, max, min = math.floor, math.max, math.min

local DOOR_RADIUS = 78
local DOOR_CLOSE_TICKS = 45
local GLASS_RESPAWN_TICKS = 60 * 25
local LISTS = { "walls", "doors", "glass", "cover", "pits" }

--- @param def table map definition (see src/game/extraction/worldgen.lua)
--- @param cell number? cell size
--- @return table
function Terrain.new(def, cell)
    local t = Arena.new(def)
    setmetatable(t, Terrain)
    t.cell = cell or 256
    t.cols = math.ceil(t.width / t.cell)
    t.rows = math.ceil(t.height / t.cell)
    t.cells = {}
    t.stamp = 0
    t.open = {}
    t.broken = {}
    t.tick = 0
    for _, list in ipairs(LISTS) do
        for _, rect in ipairs(t[list]) do
            rect.list = list
            t:insert(list, rect)
        end
    end
    return t
end

--- @param list string
--- @param rect table
function Terrain:insert(list, rect)
    local c = self.cell
    local x0, y0 = max(0, floor(rect.x / c)), max(0, floor(rect.y / c))
    local x1, y1 = min(self.cols - 1, floor((rect.x + rect.w) / c)), min(self.rows - 1, floor((rect.y + rect.h) / c))
    for cy = y0, y1 do
        for cx = x0, x1 do
            local key = cy * self.cols + cx
            local bucket = self.cells[key]
            if not bucket then
                bucket = {}
                self.cells[key] = bucket
            end
            local entries = bucket[list]
            if not entries then
                entries = {}
                bucket[list] = entries
            end
            entries[#entries + 1] = rect
        end
    end
end

local MODES = {
    move = { walls = true, doors = true, glass = true, cover = true, pits = true },
    nav = { walls = true, glass = true, cover = true, pits = true },
    bullet = { walls = true, doors = true, glass = true },
    vision = { walls = true, doors = true }
}

--- Visits rectangles of the given lists in a box, each once.
--- @param lists table set of list names
--- @param fn function returns true to stop
--- @return boolean stopped
function Terrain:visit(lists, fn, x0, y0, x1, y1, filter)
    local c = self.cell
    self.stamp = self.stamp + 1
    local stamp = self.stamp
    local cx0, cy0 = max(0, floor(x0 / c)), max(0, floor(y0 / c))
    local cx1, cy1 = min(self.cols - 1, floor(x1 / c)), min(self.rows - 1, floor(y1 / c))
    for cy = cy0, cy1 do
        for cx = cx0, cx1 do
            local bucket = self.cells[cy * self.cols + cx]
            if bucket then
                for list in pairs(lists) do
                    local entries = bucket[list]
                    if entries then
                        for k = 1, #entries do
                            local rect = entries[k]
                            if rect.mark ~= stamp then
                                rect.mark = stamp
                                if (not filter or filter(rect)) and fn(rect) then return true end
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

local function blocking(rect)
    if rect.list == "doors" then return not rect.open end
    if rect.list == "glass" then return not rect.broken end
    return true
end

--- @param mode string
--- @param fn function
function Terrain:each(mode, fn, x0, y0, x1, y1)
    if not x0 then return Arena.each(self, mode, fn) end
    local lists = MODES[mode] or MODES.bullet
    if mode == "nav" then
        self:visit(lists, fn, x0, y0, x1, y1, function(rect) return rect.list ~= "glass" or not rect.broken end)
        return
    end
    self:visit(lists, fn, x0, y0, x1, y1, blocking)
end

--- Calls fn on every rectangle of one list in a box.
--- @param list string
function Terrain:query(list, x0, y0, x1, y1, fn)
    self:visit({ [list] = true }, fn, x0, y0, x1, y1)
end

--- @param rect table
--- @param x number
--- @param y number
--- @return number squared distance from a point to a rectangle
local function distance2(rect, x, y)
    local cx = max(rect.x, min(x, rect.x + rect.w))
    local cy = max(rect.y, min(y, rect.y + rect.h))
    return (x - cx) ^ 2 + (y - cy) ^ 2
end

--- Opens doors near living actors (players and monsters) and closes them once they
--- have been left alone for a while.
--- @param actors table[] { x, y, hp, dead }
--- @return table[] doors opened this tick
function Terrain:updateDoors(actors)
    self.tick = self.tick + 1
    local tick = self.tick
    local opened = {}
    for _, a in ipairs(actors) do
        if a.hp > 0 and (a.dead or 0) == 0 then
            self:query("doors", a.x - DOOR_RADIUS, a.y - DOOR_RADIUS, a.x + DOOR_RADIUS, a.y + DOOR_RADIUS, function(door)
                local d2 = distance2(door, a.x, a.y)
                if d2 < DOOR_RADIUS * DOOR_RADIUS then
                    door.near = tick
                    if d2 < 400 then door.inside = tick end
                    if not door.open then
                        door.open = true
                        door.opener = a.slot
                        self.open[door] = true
                        opened[#opened + 1] = door
                    end
                    door.timer = DOOR_CLOSE_TICKS
                end
            end)
        end
    end
    for door in pairs(self.open) do
        if door.near ~= tick then
            door.timer = door.timer - 1
            if door.timer <= 0 and door.inside ~= tick then
                door.open = false
                self.open[door] = nil
            end
        end
    end
    return opened
end

--- @param pane table
function Terrain:breakGlass(pane)
    pane.broken = true
    pane.timer = GLASS_RESPAWN_TICKS
    self.broken[pane] = true
end

--- @param actors table[]
function Terrain:updateGlass(actors)
    for pane in pairs(self.broken) do
        pane.timer = pane.timer - 1
        if pane.timer <= 0 then
            local blocked = false
            for _, a in ipairs(actors) do
                if a.hp > 0 and distance2(pane, a.x, a.y) < 400 then blocked = true break end
            end
            if not blocked then
                pane.broken = false
                self.broken[pane] = nil
            end
        end
    end
end

--- Indices of the open doors and broken panes within a radius, for a snapshot.
--- @return number[], number[]
function Terrain:stateNear(x, y, radius)
    local doors, panes = {}, {}
    local r2 = radius * radius
    for door in pairs(self.open) do
        if (door.x - x) ^ 2 + (door.y - y) ^ 2 < r2 then doors[#doors + 1] = door.index end
    end
    for pane in pairs(self.broken) do
        if (pane.x - x) ^ 2 + (pane.y - y) ^ 2 < r2 then panes[#panes + 1] = pane.index end
    end
    table.sort(doors)
    table.sort(panes)
    return doors, panes
end

--- Applies a snapshot's door and glass state for the area it covers: listed doors are
--- open, every other door in the radius is closed.
function Terrain:applyNear(x, y, radius, doors, panes)
    local openSet, brokenSet = {}, {}
    for _, k in ipairs(doors or {}) do openSet[k] = true end
    for _, k in ipairs(panes or {}) do brokenSet[k] = true end
    local inner = radius - 60
    self:query("doors", x - inner, y - inner, x + inner, y + inner, function(door)
        if (door.x - x) ^ 2 + (door.y - y) ^ 2 < inner * inner then
            door.open = openSet[door.index] == true
        end
    end)
    self:query("glass", x - inner, y - inner, x + inner, y + inner, function(pane)
        if (pane.x - x) ^ 2 + (pane.y - y) ^ 2 < inner * inner then
            pane.broken = brokenSet[pane.index] == true
        end
    end)
    for _, k in ipairs(doors or {}) do
        local door = self.doors[k]
        if door then door.open = true end
    end
    for _, k in ipairs(panes or {}) do
        local pane = self.glass[k]
        if pane then pane.broken = true end
    end
end

--- @param x number
--- @param y number
--- @param radius number
--- @return boolean true when a circle overlaps nothing that blocks movement
function Terrain:clear(x, y, radius)
    if x - radius < 0 or y - radius < 0 or x + radius > self.width or y + radius > self.height then return false end
    local hit = false
    self:each("move", function(rect)
        if distance2(rect, x, y) < radius * radius then
            hit = true
            return true
        end
    end, x - radius, y - radius, x + radius, y + radius)
    return not hit
end

return Terrain
