local Nav = {}

local floor, sqrt, abs, max, min = math.floor, math.sqrt, math.abs, math.max, math.min

local CELL = 30
local CLEARANCE = 17
local SQRT2 = sqrt(2)

local function blocked(rects, x, y)
    for _, r in ipairs(rects) do
        local cx = max(r.x, min(x, r.x + r.w))
        local cy = max(r.y, min(y, r.y + r.h))
        if (x - cx) ^ 2 + (y - cy) ^ 2 < CLEARANCE * CLEARANCE then return true end
    end
    return false
end

--- @param arena table
--- @return table
function Nav.grid(arena)
    if arena.nav then return arena.nav end
    local rects = {}
    for _, list in ipairs({ arena.walls, arena.cover, arena.glass }) do
        for _, r in ipairs(list) do rects[#rects + 1] = r end
    end
    local cols, rows = math.ceil(arena.width / CELL), math.ceil(arena.height / CELL)
    local open = {}
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            open[row * cols + col] = not blocked(rects, (col + 0.5) * CELL, (row + 0.5) * CELL)
        end
    end
    arena.nav = { cols = cols, rows = rows, open = open }
    return arena.nav
end

local function cellOf(grid, x, y)
    local col = max(0, min(grid.cols - 1, floor(x / CELL)))
    local row = max(0, min(grid.rows - 1, floor(y / CELL)))
    return row * grid.cols + col
end

local function nearestOpen(grid, index)
    if grid.open[index] then return index end
    local col, row = index % grid.cols, floor(index / grid.cols)
    for radius = 1, 6 do
        for dr = -radius, radius do
            for dc = -radius, radius do
                local c, r = col + dc, row + dr
                if c >= 0 and r >= 0 and c < grid.cols and r < grid.rows and grid.open[r * grid.cols + c] then
                    return r * grid.cols + c
                end
            end
        end
    end
    return nil
end

local function push(heap, node, score)
    heap[#heap + 1] = { node, score }
    local k = #heap
    while k > 1 do
        local parent = floor(k / 2)
        if heap[parent][2] <= heap[k][2] then break end
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
            local l, r = k * 2, k * 2 + 1
            local smallest = k
            if heap[l] and heap[l][2] < heap[smallest][2] then smallest = l end
            if heap[r] and heap[r][2] < heap[smallest][2] then smallest = r end
            if smallest == k then break end
            heap[smallest], heap[k] = heap[k], heap[smallest]
            k = smallest
        end
    end
    return top[1]
end

--- @param arena table
--- @param fx number
--- @param fy number
--- @param tx number
--- @param ty number
--- @return table[]?
function Nav.path(arena, fx, fy, tx, ty)
    local grid = Nav.grid(arena)
    local start = nearestOpen(grid, cellOf(grid, fx, fy))
    local goal = nearestOpen(grid, cellOf(grid, tx, ty))
    if not start or not goal then return nil end
    local cols = grid.cols
    local gc, gr = goal % cols, floor(goal / cols)
    local function h(index)
        local dc, dr = abs(index % cols - gc), abs(floor(index / cols) - gr)
        return (dc + dr) + (SQRT2 - 2) * min(dc, dr)
    end
    local cost, from, closed = { [start] = 0 }, {}, {}
    local heap = {}
    push(heap, start, h(start))
    local found = false
    while #heap > 0 do
        local node = pop(heap)
        if node == goal then found = true break end
        if not closed[node] then
            closed[node] = true
            local col, row = node % cols, floor(node / cols)
            for dr = -1, 1 do
                for dc = -1, 1 do
                    if dr ~= 0 or dc ~= 0 then
                        local c, r = col + dc, row + dr
                        if c >= 0 and r >= 0 and c < cols and r < grid.rows then
                            local next = r * cols + c
                            local diagonal = dr ~= 0 and dc ~= 0
                            local passable = grid.open[next]
                                and (not diagonal or (grid.open[row * cols + c] and grid.open[r * cols + col]))
                            if passable and not closed[next] then
                                local g = cost[node] + (diagonal and SQRT2 or 1)
                                if not cost[next] or g < cost[next] then
                                    cost[next] = g
                                    from[next] = node
                                    push(heap, next, g + h(next))
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if not found then return nil end
    local points = {}
    local node = goal
    while node do
        table.insert(points, 1, { x = (node % cols + 0.5) * CELL, y = (floor(node / cols) + 0.5) * CELL })
        node = from[node]
    end
    points[#points] = { x = tx, y = ty }
    return points
end

--- @param arena table
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return boolean
function Nav.clear(arena, x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local d = sqrt(dx * dx + dy * dy)
    if d < 1 then return true end
    local nx, ny = -dy / d * CLEARANCE * 0.8, dx / d * CLEARANCE * 0.8
    for _, side in ipairs({ 0, 1, -1 }) do
        local ox, oy = x1 + nx * side, y1 + ny * side
        if arena:raycast(ox, oy, dx / d, dy / d, d, "nav") < d - 1 then return false end
    end
    return true
end

Nav.CELL = CELL

return Nav
