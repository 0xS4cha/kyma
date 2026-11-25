--- Local A* for monsters on a world far too big for a precomputed grid: the search
--- runs in a window around the monster and the goal, and each cell is tested against
--- the terrain only when the search reaches it. Doors count as open (monsters push
--- them open like players do).
local Pathing = {}

local floor, abs, sqrt, min, max = math.floor, math.abs, math.sqrt, math.min, math.max

local CELL = 40
local WINDOW = 1400
local MAX_EXPANSIONS = 2200

--- @param terrain table
--- @param x number
--- @param y number
--- @param radius number
--- @return boolean
local function passable(terrain, x, y, radius)
    if x - radius < 0 or y - radius < 0 or x + radius > terrain.width or y + radius > terrain.height then return false end
    local hit = false
    terrain:each("nav", function(rect)
        local cx = max(rect.x, min(x, rect.x + rect.w))
        local cy = max(rect.y, min(y, rect.y + rect.h))
        if (x - cx) ^ 2 + (y - cy) ^ 2 < radius * radius then
            hit = true
            return true
        end
    end, x - radius, y - radius, x + radius, y + radius)
    return not hit
end

Pathing.passable = passable

--- Is the straight line between two points free for a body of this radius?
--- @return boolean
function Pathing.line(terrain, x1, y1, x2, y2, radius)
    local dx, dy = x2 - x1, y2 - y1
    local d = sqrt(dx * dx + dy * dy)
    if d < 1 then return true end
    dx, dy = dx / d, dy / d
    local nx, ny = -dy * radius * 0.8, dx * radius * 0.8
    for _, side in ipairs({ 0, 1, -1 }) do
        local ox, oy = x1 + nx * side, y1 + ny * side
        if terrain:raycast(ox, oy, dx, dy, d, "nav") < d - 1 then return false end
    end
    return true
end

local function push(heap, node)
    heap[#heap + 1] = node
    local k = #heap
    while k > 1 do
        local parent = floor(k / 2)
        if heap[parent].f <= heap[k].f then break end
        heap[parent], heap[k] = heap[k], heap[parent]
        k = parent
    end
end

local function pop(heap)
    local top = heap[1]
    local last = table.remove(heap)
    if #heap > 0 then
        heap[1] = last
        local k = 1
        while true do
            local l, r, s = k * 2, k * 2 + 1, k
            if heap[l] and heap[l].f < heap[s].f then s = l end
            if heap[r] and heap[r].f < heap[s].f then s = r end
            if s == k then break end
            heap[s], heap[k] = heap[k], heap[s]
            k = s
        end
    end
    return top
end

--- Finds a path. A goal beyond the window is pulled back toward the start, so the
--- monster still makes progress and searches again later.
--- @param terrain table
--- @return table[]? points { x, y } from the first step to the goal
function Pathing.find(terrain, sx, sy, gx, gy, radius)
    local dx, dy = gx - sx, gy - sy
    local d = sqrt(dx * dx + dy * dy)
    local reach = WINDOW / 2 - CELL * 2
    if d > reach then
        gx, gy = sx + dx / d * reach, sy + dy / d * reach
    end
    local ox, oy = floor((min(sx, gx) - 400) / CELL) * CELL, floor((min(sy, gy) - 400) / CELL) * CELL
    local cols = floor((max(sx, gx) + 400 - ox) / CELL) + 1
    local rows = floor((max(sy, gy) + 400 - oy) / CELL) + 1
    local function key(cx, cy) return cy * cols + cx end
    local function center(cx, cy) return ox + cx * CELL + CELL / 2, oy + cy * CELL + CELL / 2 end
    local blocked = {}
    local function free(cx, cy)
        if cx < 0 or cy < 0 or cx >= cols or cy >= rows then return false end
        local k = key(cx, cy)
        if blocked[k] == nil then
            local x, y = center(cx, cy)
            blocked[k] = not passable(terrain, x, y, radius)
        end
        return not blocked[k]
    end
    local scx, scy = floor((sx - ox) / CELL), floor((sy - oy) / CELL)
    local gcx, gcy = floor((gx - ox) / CELL), floor((gy - oy) / CELL)
    if not free(gcx, gcy) then
        local found = false
        for ring = 1, 4 do
            for ddy = -ring, ring do
                for ddx = -ring, ring do
                    if not found and free(gcx + ddx, gcy + ddy) then
                        gcx, gcy, found = gcx + ddx, gcy + ddy, true
                    end
                end
            end
            if found then break end
        end
        if not found then return nil end
    end
    local heap, g, came, closed = {}, {}, {}, {}
    local start = key(scx, scy)
    g[start] = 0
    push(heap, { k = start, x = scx, y = scy, f = 0 })
    local expansions = 0
    local goal = key(gcx, gcy)
    while #heap > 0 and expansions < MAX_EXPANSIONS do
        local node = pop(heap)
        if node.k == goal then
            local points = {}
            local k = goal
            while k and k ~= start do
                local cx, cy = k % cols, floor(k / cols)
                local x, y = center(cx, cy)
                table.insert(points, 1, { x = x, y = y })
                k = came[k]
            end
            return points
        end
        if not closed[node.k] then
            closed[node.k] = true
            expansions = expansions + 1
            for ddy = -1, 1 do
                for ddx = -1, 1 do
                    if ddx ~= 0 or ddy ~= 0 then
                        local nx, ny = node.x + ddx, node.y + ddy
                        if free(nx, ny) and (ddx == 0 or ddy == 0 or (free(node.x + ddx, node.y) and free(node.x, node.y + ddy))) then
                            local nk = key(nx, ny)
                            local cost = g[node.k] + ((ddx ~= 0 and ddy ~= 0) and 1.414 or 1)
                            if not g[nk] or cost < g[nk] then
                                g[nk] = cost
                                came[nk] = node.k
                                local hx, hy = abs(nx - gcx), abs(ny - gcy)
                                push(heap, { k = nk, x = nx, y = ny, f = cost + max(hx, hy) + 0.414 * min(hx, hy) })
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

return Pathing
