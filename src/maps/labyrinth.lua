local B = require("src.maps.builder")
local Random = require("src.core.random")

local m = B.new("labyrinth", "Labyrinth", 1600, 1600, "Tight corridors, blind corners and a few doors. Shotgun territory, listen before you turn.")
B.border(m)

local N, CELL, T, ORIGIN = 8, 190, 24, 40
local rng = Random.new(1337)
local visited, east, south = {}, {}, {}
local function key(c, r) return r * N + c end
for c = 0, N - 1 do
    for r = 0, N - 1 do
        east[key(c, r)] = c < N - 1
        south[key(c, r)] = r < N - 1
    end
end
local stack = { { 0, 0 } }
visited[key(0, 0)] = true
while #stack > 0 do
    local c, r = stack[#stack][1], stack[#stack][2]
    local options = {}
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local nc, nr = c + d[1], r + d[2]
        if nc >= 0 and nr >= 0 and nc < N and nr < N and not visited[key(nc, nr)] then
            options[#options + 1] = { nc, nr, d }
        end
    end
    if #options == 0 then
        table.remove(stack)
    else
        local pick = options[rng:random(#options)]
        local nc, nr, d = pick[1], pick[2], pick[3]
        if d[1] == 1 then east[key(c, r)] = false
        elseif d[1] == -1 then east[key(nc, nr)] = false
        elseif d[2] == 1 then south[key(c, r)] = false
        else south[key(nc, nr)] = false end
        visited[key(nc, nr)] = true
        stack[#stack + 1] = { nc, nr }
    end
end
for _ = 1, 12 do
    local c, r = rng:random(N) - 1, rng:random(N) - 1
    if rng:random() < 0.5 then east[key(c, r)] = false else south[key(c, r)] = false end
end
local doors = 0
for c = 0, N - 1 do
    for r = 0, N - 1 do
        local x, y = ORIGIN + c * CELL, ORIGIN + r * CELL
        if east[key(c, r)] then
            local wx = x + CELL - T / 2
            if doors < 6 and (c + r * 3) % 9 == 4 then
                doors = doors + 1
                B.box(m, wx, y + T / 2, T, CELL - T, "door")
                B.box(m, wx, y - T / 2, T, T)
                B.box(m, wx, y + CELL - T / 2, T, T)
            else
                B.box(m, wx, y - T / 2, T, CELL + T)
            end
        end
        if south[key(c, r)] then
            B.box(m, x - T / 2, y + CELL - T / 2, CELL + T, T)
        end
    end
end
local function center(c, r) return ORIGIN + c * CELL + CELL / 2, ORIGIN + r * CELL + CELL / 2 end
for _, cell in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
    local x, y = center(cell[1], cell[2])
    B.spawn(m, x, y, 0, 1)
    x, y = center(N - 1 - cell[1], N - 1 - cell[2])
    B.spawn(m, x, y, math.pi, 2)
end
for _, spot in ipairs({
    { 3, 3, "shotgun" }, { 4, 4, "shotgun" }, { 2, 5, "rifle" }, { 5, 2, "rifle" }, { 0, 7, "health" }, { 7, 0, "health" },
    { 3, 6, "ammo" }, { 4, 1, "ammo" }, { 6, 4, "silencer" }, { 1, 3, "silencer" }, { 3, 4, "lmg" }, { 6, 6, "shotgun" }, { 1, 1, "shotgun" }
}) do
    local x, y = center(spot[1], spot[2])
    B.loot(m, x, y, spot[3])
end
return m
