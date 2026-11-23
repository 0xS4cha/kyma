local B = {}

--- @return table
function B.new(id, name, width, height, description)
    return {
        id = id, name = name, description = description, width = width, height = height,
        walls = {}, doors = {}, glass = {}, cover = {}, pits = {}, spawns = {}, loot = {}
    }
end

local LISTS = { wall = "walls", door = "doors", glass = "glass", cover = "cover", pit = "pits" }
local GLASS = 12

--- @param m table
--- @param kind string
--- @param x number
--- @param y number
--- @param w number
--- @param h number
function B.box(m, x, y, w, h, kind)
    local list = m[LISTS[kind or "wall"]]
    list[#list + 1] = { x = x, y = y, w = w, h = h }
end

local function piece(m, horizontal, from, to, at, t, kind)
    if to - from <= 0 then return end
    if kind == "glass" then
        local offset = (t - GLASS) / 2
        if horizontal then
            B.box(m, from, at + offset, to - from, GLASS, "glass")
        else
            B.box(m, at + offset, from, GLASS, to - from, "glass")
        end
    elseif horizontal then
        B.box(m, from, at, to - from, t, kind)
    else
        B.box(m, at, from, t, to - from, kind)
    end
end

local function line(m, horizontal, a, b, at, t, gaps, fill)
    table.sort(gaps or {}, function(g1, g2) return g1[1] < g2[1] end)
    local cursor = a
    for _, gap in ipairs(gaps or {}) do
        piece(m, horizontal, cursor, gap[1], at, t, fill or "wall")
        if gap[3] and gap[3] ~= "open" then
            piece(m, horizontal, gap[1], gap[2], at, t, gap[3])
        end
        cursor = gap[2]
    end
    piece(m, horizontal, cursor, b, at, t, fill or "wall")
end

--- @param gaps table[]
function B.h(m, x1, x2, y, t, gaps, fill)
    line(m, true, x1, x2, y, t, gaps, fill)
end

function B.v(m, y1, y2, x, t, gaps, fill)
    line(m, false, y1, y2, x, t, gaps, fill)
end

function B.border(m, t)
    t = t or 40
    B.box(m, 0, 0, m.width, t)
    B.box(m, 0, m.height - t, m.width, t)
    B.box(m, 0, t, t, m.height - 2 * t)
    B.box(m, m.width - t, t, t, m.height - 2 * t)
end

function B.spawn(m, x, y, angle, team)
    m.spawns[#m.spawns + 1] = { x = x, y = y, angle = angle or 0, team = team }
end

function B.loot(m, x, y, kind)
    m.loot[#m.loot + 1] = { x = x, y = y, kind = kind }
end

--- @param m table
function B.mirror(m)
    local W, H = m.width, m.height
    for _, key in ipairs({ "walls", "doors", "glass", "cover", "pits" }) do
        local list = m[key]
        for k = 1, #list do
            local r = list[k]
            list[#list + 1] = { x = W - r.x - r.w, y = H - r.y - r.h, w = r.w, h = r.h }
        end
    end
    for k = 1, #m.loot do
        local item = m.loot[k]
        m.loot[#m.loot + 1] = { x = W - item.x, y = H - item.y, kind = item.kind }
    end
    for k = 1, #m.spawns do
        local s = m.spawns[k]
        m.spawns[#m.spawns + 1] = { x = W - s.x, y = H - s.y, angle = s.angle + math.pi, team = s.team and (3 - s.team) or nil }
    end
end

return B
