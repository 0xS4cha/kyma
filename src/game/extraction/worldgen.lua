--- Builds the extraction world from a seed. The server and every client run the same
--- generation, so only the seed goes over the network.
---
--- The land is shaped by noise: elevation makes lakes in the hollows and rocky
--- highlands on the heights, moisture splits forests from open fields. Settlements
--- (villages, towns, industrial zones, military camps and the citadel in the centre)
--- are scattered over the land and joined by winding roads. Danger goes up from the
--- edges (tier 1) to the centre (tier 4) and picks the monsters and the loot.
local B = require("src.maps.builder")
local Random = require("src.core.random")
local Hash = require("src.core.hash")
local Config = require("src.config.extraction")

local Worldgen = {}

local floor, sqrt, min, max, abs, cos, sin, pi = math.floor, math.sqrt, math.min, math.max, math.abs, math.cos, math.sin, math.pi

Worldgen.BIOMES = {
    forest = { name = "Forest", color = { 0.55, 0.66, 0.5 } },
    field = { name = "Fields", color = { 0.78, 0.76, 0.58 } },
    highlands = { name = "Highlands", color = { 0.66, 0.64, 0.6 } },
    lake = { name = "Lake", color = { 0.5, 0.64, 0.76 } },
    town = { name = "Town", color = { 0.74, 0.7, 0.66 } },
    industrial = { name = "Industrial", color = { 0.62, 0.6, 0.6 } },
    military = { name = "Military", color = { 0.58, 0.6, 0.48 } },
    citadel = { name = "Citadel", color = { 0.56, 0.44, 0.44 } }
}

local EXTRACT_NAMES = {
    "Pine pass", "Old bridge", "Radio mast", "Rail yard", "Fishing pier", "Quarry road", "Toll gate",
    "Dam tunnel", "Cliff stairs", "Checkpoint", "Helipad", "Sewer outlet"
}

local CELL = 200
local OCC = 50
local ROAD = 130

--- Smooth noise in [0, 1] from a lattice of hashed values.
local function noise(seed, x, y, scale)
    local gx, gy = x / scale, y / scale
    local ix, iy = floor(gx), floor(gy)
    local fx, fy = gx - ix, gy - iy
    local combine = Hash.combine
    local left, right = combine(seed, ix + 1000), combine(seed, ix + 1001)
    local v00, v10 = combine(left, iy + 1000) / 4294967296, combine(right, iy + 1000) / 4294967296
    local v01, v11 = combine(left, iy + 1001) / 4294967296, combine(right, iy + 1001) / 4294967296
    local sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    local top = v00 + (v10 - v00) * sx
    local bottom = v01 + (v11 - v01) * sx
    return top + (bottom - top) * sy
end

Worldgen.noise = noise

local function fbm(seed, x, y, scale)
    return noise(seed, x, y, scale) * 0.55 + noise(seed + 101, x, y, scale / 2.3) * 0.3 + noise(seed + 211, x, y, scale / 5.1) * 0.15
end

--- @param x number
--- @param y number
--- @param half number
--- @return number distance from the centre, 0 in the middle, about 1 at the edges
local function radial(x, y, half)
    local dx, dy = (x - half) / half, (y - half) / half
    return sqrt(dx * dx + dy * dy)
end

local function pointSegment(px, py, x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local l2 = dx * dx + dy * dy
    local t = l2 > 0 and max(0, min(1, ((px - x1) * dx + (py - y1) * dy) / l2)) or 0
    local cx, cy = x1 + dx * t, y1 + dy * t
    return sqrt((px - cx) ^ 2 + (py - cy) ^ 2)
end

--- A world under construction: the map lists, the land fields and what is taken.
local Ctx = {}
Ctx.__index = Ctx

function Ctx:container(x, y, kind, tier)
    local list = self.m.containers
    list[#list + 1] = { id = #list + 1, x = floor(x), y = floor(y), kind = kind, tier = tier }
end

function Ctx:nest(x, y, tier, biome)
    local list = self.m.nests
    list[#list + 1] = { id = #list + 1, x = floor(x), y = floor(y), tier = tier, biome = biome }
end

--- Elevation at a point, interpolated from the grid.
function Ctx:elevation(x, y)
    local n = self.n
    local gx, gy = max(0, min(n - 1.001, x / CELL)), max(0, min(n - 1.001, y / CELL))
    local ix, iy = floor(gx), floor(gy)
    local fx, fy = gx - ix, gy - iy
    local e = self.elev
    local w = n + 1
    local a, b = e[iy * w + ix + 1], e[iy * w + ix + 2]
    local c, d = e[(iy + 1) * w + ix + 1], e[(iy + 1) * w + ix + 2]
    return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy
end

function Ctx:water(x, y)
    return self:elevation(x, y) < self.waterLevel
end

--- Is a point within `margin` of a road?
function Ctx:nearRoad(x, y, margin)
    local key0x, key0y = floor((x - margin - ROAD) / 1000), floor((y - margin - ROAD) / 1000)
    local key1x, key1y = floor((x + margin + ROAD) / 1000), floor((y + margin + ROAD) / 1000)
    local roads = self.m.roads
    for ky = key0y, key1y do
        for kx = key0x, key1x do
            for _, k in ipairs(self.roadCells[ky * 1000 + kx] or {}) do
                local r = roads[k]
                if pointSegment(x, y, r[1], r[2], r[3], r[4]) < r[5] / 2 + margin then return true end
            end
        end
    end
    return false
end

--- Is a rectangle free of everything placed so far, of roads and of water?
function Ctx:free(x, y, w, h, pad)
    pad = pad or 0
    local size = self.m.width
    if x - pad < 100 or y - pad < 100 or x + w + pad > size - 100 or y + h + pad > size - 100 then return false end
    for cy = floor((y - pad) / OCC), floor((y + h + pad) / OCC) do
        for cx = floor((x - pad) / OCC), floor((x + w + pad) / OCC) do
            if self.occ[cy * 1000 + cx] then return false end
        end
    end
    local cx, cy = x + w / 2, y + h / 2
    if self:nearRoad(cx, cy, sqrt(w * w + h * h) / 2 + pad) then return false end
    if self:water(cx, cy) or self:water(x, y) or self:water(x + w, y + h) or self:water(x + w, y) or self:water(x, y + h) then return false end
    return true
end

function Ctx:claim(x, y, w, h)
    for cy = floor(y / OCC), floor((y + h) / OCC) do
        for cx = floor(x / OCC), floor((x + w) / OCC) do
            self.occ[cy * 1000 + cx] = true
        end
    end
end

--- @param deco string? how the client draws it (tree, rock, bale, furniture...)
function Ctx:box(x, y, w, h, kind, deco)
    B.box(self.m, floor(x), floor(y), floor(w), floor(h), kind)
    if deco then
        local list = self.m[kind == "cover" and "cover" or (kind == "pit" and "pits" or "walls")]
        list[#list].deco = deco
    end
    self:claim(x, y, w, h)
end

local DOOR, WINDOW, T = 74, 110, 24

--- Gaps for one wall of a building: an optional door and optional windows.
local function gaps(rng, from, to, door, windows)
    local list = {}
    local length = to - from
    local used = {}
    local function place(size, kind)
        for _ = 1, 6 do
            local at = from + 50 + rng:random() * (length - 100 - size)
            local ok = length > size + 100
            for _, g in ipairs(used) do
                if at < g[2] + 30 and g[1] < at + size + 30 then ok = false end
            end
            if ok then
                local gap = { floor(at), floor(at + size), kind }
                used[#used + 1] = gap
                list[#list + 1] = gap
                return
            end
        end
    end
    if door then place(DOOR, "door") end
    for _ = 1, windows or 0 do place(WINDOW, "glass") end
    return list
end

--- A building with rooms, doors, windows, furniture and containers.
--- @param kinds string[] container kinds to pick from
function Ctx:building(x, y, w, h, tier, kinds, options)
    options = options or {}
    local rng, m = self.rng, self.m
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    self:claim(x - 20, y - 20, w + 40, h + 40)
    local floors = self.m.floors
    floors[#floors + 1] = { x = x, y = y, w = w, h = h, kind = options.floor or "wood" }
    local sides = { "n", "s", "w", "e" }
    local doorSides = { [sides[rng:random(4)]] = true }
    if rng:random() < 0.6 then doorSides[sides[rng:random(4)]] = true end
    local windows = options.windows or 1
    B.h(m, x, x + w, y, T, gaps(rng, x, x + w, doorSides.n, rng:random(0, windows)))
    B.h(m, x, x + w, y + h - T, T, gaps(rng, x, x + w, doorSides.s, rng:random(0, windows)))
    B.v(m, y + T, y + h - T, x, T, gaps(rng, y + T, y + h - T, doorSides.w, rng:random(0, windows)))
    B.v(m, y + T, y + h - T, x + w - T, T, gaps(rng, y + T, y + h - T, doorSides.e, rng:random(0, windows)))
    local rooms = { { x = x + T, y = y + T, w = w - 2 * T, h = h - 2 * T } }
    local splits = 0
    while splits < (options.rooms or 3) do
        local index, best = nil, 0
        for k, room in ipairs(rooms) do
            local area = room.w * room.h
            if area > best and (room.w > 420 or room.h > 380) then index, best = k, area end
        end
        if not index then break end
        local room = table.remove(rooms, index)
        if room.w >= room.h then
            local at = floor(room.x + room.w * (0.35 + rng:random() * 0.3))
            B.v(m, room.y, room.y + room.h, at, 20, gaps(rng, room.y, room.y + room.h, true, rng:random() < 0.3 and 1 or 0))
            rooms[#rooms + 1] = { x = room.x, y = room.y, w = at - room.x, h = room.h }
            rooms[#rooms + 1] = { x = at + 20, y = room.y, w = room.x + room.w - at - 20, h = room.h }
        else
            local at = floor(room.y + room.h * (0.35 + rng:random() * 0.3))
            B.h(m, room.x, room.x + room.w, at, 20, gaps(rng, room.x, room.x + room.w, true, rng:random() < 0.3 and 1 or 0))
            rooms[#rooms + 1] = { x = room.x, y = room.y, w = room.w, h = at - room.y }
            rooms[#rooms + 1] = { x = room.x, y = at + 20, w = room.w, h = room.y + room.h - at - 20 }
        end
        splits = splits + 1
    end
    for _, room in ipairs(rooms) do
        local corners = {
            { room.x + 46, room.y + 46 }, { room.x + room.w - 46, room.y + 46 },
            { room.x + 46, room.y + room.h - 46 }, { room.x + room.w - 46, room.y + room.h - 46 }
        }
        local count = rng:random() < (options.loot or 0.75) and (rng:random() < 0.35 and 2 or 1) or 0
        for k = 1, count do
            local corner = table.remove(corners, rng:random(#corners))
            self:container(corner[1], corner[2], kinds[rng:random(#kinds)], tier)
            if k >= #corners then break end
        end
        if room.w > 220 and room.h > 200 and rng:random() < 0.55 then
            local fw, fh = rng:random(70, 140), rng:random(36, 60)
            if rng:random() < 0.5 then fw, fh = fh, fw end
            B.box(m, floor(room.x + room.w / 2 - fw / 2), floor(room.y + room.h / 2 - fh / 2), fw, fh, "cover")
            m.cover[#m.cover].deco = "furniture"
        end
    end
end


local TOWN = { "crate", "cabinet", "fridge", "locker", "drawer", "medbox" }
local INDUSTRIAL = { "toolbox", "crate", "locker", "crate", "cabinet" }
local MILITARY = { "weapon_case", "ammo_crate", "crate", "medbox", "weapon_case" }
local WILD = { "stash", "crate" }

--- Tries to place a building somewhere in a disc.
local function placeBuilding(ctx, cx, cy, radius, w, h, tier, kinds, options)
    local rng = ctx.rng
    for _ = 1, 24 do
        local a, r = rng:random() * 2 * pi, sqrt(rng:random()) * radius
        local x, y = cx + cos(a) * r - w / 2, cy + sin(a) * r - h / 2
        if ctx:free(x, y, w, h, 60) then
            ctx:building(x, y, w, h, tier, kinds, options)
            return true
        end
    end
    return false
end

local function scatter(ctx, cx, cy, radius, count, make)
    local rng = ctx.rng
    for _ = 1, count do
        local a, r = rng:random() * 2 * pi, rng:random() * radius
        make(cx + cos(a) * r, cy + sin(a) * r)
    end
end

local Settlement = {}

function Settlement.village(ctx, s)
    local rng = ctx.rng
    for _ = 1, rng:random(4, 8) do
        local w, h = rng:random(240, 400), rng:random(200, 320)
        placeBuilding(ctx, s.x, s.y, s.r, w, h, s.tier, TOWN, { rooms = 2, windows = 1 })
    end
    scatter(ctx, s.x, s.y, s.r, rng:random(2, 5), function(x, y)
        local horizontal = rng:random() < 0.5
        local length = rng:random(160, 360)
        local w, h = horizontal and length or 16, horizontal and 16 or length
        if ctx:free(x, y, w, h, 40) then ctx:box(x, y, w, h, "cover") end
    end)
    ctx:nest(s.x + rng:random(-200, 200), s.y + rng:random(-200, 200), s.tier, "town")
end

function Settlement.town(ctx, s)
    local rng = ctx.rng
    for _ = 1, rng:random(14, 22) do
        local w, h = rng:random(280, 560), rng:random(240, 440)
        placeBuilding(ctx, s.x, s.y, s.r, w, h, s.tier, TOWN, { rooms = 3, windows = 2 })
    end
    scatter(ctx, s.x, s.y, s.r, rng:random(5, 10), function(x, y)
        local horizontal = rng:random() < 0.5
        local w, h = horizontal and 96 or 46, horizontal and 46 or 96
        if ctx:free(x, y, w, h, 30) then ctx:box(x, y, w, h, "cover", "car") end
    end)
    scatter(ctx, s.x, s.y, s.r, rng:random(4, 9), function(x, y)
        local size = rng:random(34, 54)
        if ctx:free(x, y, size, size, 40) then ctx:box(x, y, size, size, nil, "tree") end
    end)
    ctx:nest(s.x + rng:random(-300, 300), s.y + rng:random(-300, 300), s.tier, "town")
    ctx:nest(s.x + rng:random(-300, 300), s.y + rng:random(-300, 300), s.tier, "town")
end

function Settlement.industrial(ctx, s)
    local rng = ctx.rng
    for _ = 1, rng:random(1, 3) do
        local w, h = rng:random(600, 900), rng:random(380, 560)
        for _ = 1, 10 do
            local a, r = rng:random() * 2 * pi, rng:random() * s.r * 0.6
            local x, y = s.x + cos(a) * r - w / 2, s.y + sin(a) * r - h / 2
            if ctx:free(x, y, w, h, 60) then
                ctx:building(x, y, w, h, s.tier, INDUSTRIAL, { rooms = 1, windows = 2, loot = 0.9, floor = "concrete" })
                for k = 1, 3 do
                    local sx = x + 60 + (w - 120) * k / 4
                    B.box(ctx.m, floor(sx - 14), floor(y + 80), 28, floor(h - 160), "cover")
                    ctx.m.cover[#ctx.m.cover].deco = "shelf"
                end
                break
            end
        end
    end
    scatter(ctx, s.x, s.y, s.r, rng:random(10, 18), function(x, y)
        local horizontal = rng:random() < 0.6
        local w, h = horizontal and 240 or 80, horizontal and 80 or 240
        if ctx:free(x, y, w, h, 70) then
            ctx:box(x, y, w, h, nil, "container")
            if rng:random() < 0.3 then ctx:container(x + w / 2, y + h + 40, "crate", s.tier) end
        end
    end)
    ctx:nest(s.x + s.r * 0.5, s.y, s.tier, "industrial")
    ctx:nest(s.x - s.r * 0.5, s.y, s.tier, "industrial")
end

--- A square fenced camp around the settlement centre, with a gate on each side.
local function compound(ctx, s, inner)
    local rng, m = ctx.rng, ctx.m
    local half = floor(s.r * 0.72)
    local fx, fy, fs = floor(s.x - half), floor(s.y - half), half * 2
    if not ctx:free(fx, fy, fs, fs, 20) then return false end
    local function gate(from, to)
        local at = floor(from + (to - from) * (0.3 + rng:random() * 0.4))
        return { { at, at + 160, "open" } }
    end
    B.h(m, fx, fx + fs, fy, 20, gate(fx, fx + fs))
    B.h(m, fx, fx + fs, fy + fs - 20, 20, gate(fx, fx + fs))
    B.v(m, fy + 20, fy + fs - 20, fx, 20, gate(fy, fy + fs))
    B.v(m, fy + 20, fy + fs - 20, fx + fs - 20, 20, gate(fy, fy + fs))
    ctx:claim(fx - 30, fy - 30, fs + 60, 80)
    ctx:claim(fx - 30, fy + fs - 50, fs + 60, 80)
    ctx:claim(fx - 30, fy - 30, 80, fs + 60)
    ctx:claim(fx + fs - 50, fy - 30, 80, fs + 60)
    inner(fx + 80, fy + 80, fs - 160)
    return true
end

function Settlement.military(ctx, s)
    local rng = ctx.rng
    compound(ctx, s, function(ix, iy, is)
        for k = 1, rng:random(2, 4) do
            local w, h = rng:random(300, 440), rng:random(240, 320)
            for _ = 1, 8 do
                local bx, by = ix + rng:random() * (is - w), iy + rng:random() * (is - h)
                if ctx:free(bx, by, w, h, 60) then
                    ctx:building(bx, by, w, h, s.tier, MILITARY, { rooms = k == 1 and 2 or 1, windows = 0, loot = 1, floor = "concrete" })
                    break
                end
            end
        end
        for _ = 1, rng:random(6, 12) do
            local horizontal = rng:random() < 0.5
            local w, h = horizontal and 130 or 34, horizontal and 34 or 130
            local sx, sy = ix + rng:random() * (is - w), iy + rng:random() * (is - h)
            if ctx:free(sx, sy, w, h, 40) then ctx:box(sx, sy, w, h, "cover", "sandbag") end
        end
    end)
    ctx:nest(s.x, s.y, s.tier, "military")
    ctx:nest(s.x + s.r * 0.4, s.y - s.r * 0.4, s.tier, "military")
end

function Settlement.citadel(ctx, s)
    local rng = ctx.rng
    compound(ctx, s, function(ix, iy, is)
        local w, h = floor(is * 0.55), floor(is * 0.45)
        local bx, by = ix + (is - w) / 2, iy + (is - h) / 2
        if ctx:free(bx, by, w, h, 20) then
            ctx:building(bx, by, w, h, 4, MILITARY, { rooms = 5, windows = 1, loot = 1, floor = "tiles" })
        end
        for _ = 1, 10 do
            local horizontal = rng:random() < 0.5
            local cw, ch = horizontal and 140 or 34, horizontal and 34 or 140
            local sx, sy = ix + rng:random() * (is - cw), iy + rng:random() * (is - ch)
            if ctx:free(sx, sy, cw, ch, 40) then ctx:box(sx, sy, cw, ch, "cover", "sandbag") end
        end
        ctx.m.citadel = { x = floor(ix + is / 2), y = floor(iy + is * 0.9) }
    end)
    ctx:nest(s.x - s.r * 0.5, s.y - s.r * 0.5, 4, "military")
    ctx:nest(s.x + s.r * 0.5, s.y + s.r * 0.5, 4, "military")
end

--- A winding road between two points, as segments added to the map.
local function road(ctx, x1, y1, x2, y2, width)
    local rng = ctx.rng
    local points = { { x1, y1 }, { x2, y2 } }
    for _ = 1, 4 do
        local out = { points[1] }
        for k = 1, #points - 1 do
            local a, b = points[k], points[k + 1]
            local dx, dy = b[1] - a[1], b[2] - a[2]
            local len = sqrt(dx * dx + dy * dy)
            local push = (rng:random() - 0.5) * len * 0.35
            out[#out + 1] = { (a[1] + b[1]) / 2 - dy / max(1, len) * push, (a[2] + b[2]) / 2 + dx / max(1, len) * push }
            out[#out + 1] = b
        end
        points = out
    end
    local m = ctx.m
    for k = 1, #points - 1 do
        local a, b = points[k], points[k + 1]
        local ax = max(300, min(m.width - 300, a[1]))
        local ay = max(300, min(m.height - 300, a[2]))
        local bx = max(300, min(m.width - 300, b[1]))
        local by = max(300, min(m.height - 300, b[2]))
        local seg = { floor(ax), floor(ay), floor(bx), floor(by), width }
        m.roads[#m.roads + 1] = seg
        local index = #m.roads
        for ky = floor((min(ay, by) - width) / 1000), floor((max(ay, by) + width) / 1000) do
            for kx = floor((min(ax, bx) - width) / 1000), floor((max(ax, bx) + width) / 1000) do
                local key = ky * 1000 + kx
                ctx.roadCells[key] = ctx.roadCells[key] or {}
                table.insert(ctx.roadCells[key], index)
            end
        end
    end
end

--- Generates the whole world.
--- @param seed number?
--- @return table map definition for Terrain.new, plus containers, nests, spawns, extracts, roads, chunks
function Worldgen.generate(seed)
    seed = seed or Config.seed
    local size = Config.size
    local half = size / 2
    local n = floor(size / CELL)
    local m = B.new("wilds", "The Wilds", size, size, "A vast persistent world. Loot, survive, extract.")
    m.containers, m.nests, m.extracts, m.chunks, m.floors, m.roads = {}, {}, {}, {}, {}, {}
    m.seed, m.count, m.chunk = seed, n, CELL
    B.border(m, 60)
    local rng = Random.new(Hash.combine(seed, 4242))
    local ctx = setmetatable({ m = m, rng = rng, occ = {}, roadCells = {}, n = n }, Ctx)

    -- Land fields on the grid corners.
    local elev, moist, sorted, wet = {}, {}, {}, {}
    for gy = 0, n do
        for gx = 0, n do
            local x, y = gx * CELL, gy * CELL
            local e = fbm(seed + 1, x, y, 9000)
            local d = radial(x, y, half)
            if d < 0.14 then e = e + (0.14 - d) * 3 end
            elev[#elev + 1] = e
            sorted[#sorted + 1] = e
            local wetness = fbm(seed + 5, x, y, 6500)
            moist[#moist + 1] = wetness
            wet[#wet + 1] = wetness
        end
    end
    table.sort(sorted)
    table.sort(wet)
    ctx.elev = elev
    ctx.waterLevel = sorted[floor(#sorted * 0.09)]
    ctx.highLevel = sorted[floor(#sorted * 0.86)]
    local forestLevel = wet[floor(#wet * 0.5)]

    local function tierAt(x, y)
        local d = radial(x, y, half) + (noise(seed + 3, x, y, 6000) - 0.5) * 0.16
        return d < 0.22 and 4 or d < 0.48 and 3 or d < 0.74 and 2 or 1
    end
    Worldgen.tierAt = tierAt

    -- Settlements, the citadel first.
    local settlements = { { x = half, y = half, r = 1300, kind = "citadel", tier = 4 } }
    for _ = 1, 5000 do
        if #settlements >= 160 then break end
        local x, y = rng:random(1600, size - 1600), rng:random(1600, size - 1600)
        local tier = tierAt(x, y)
        local roll = rng:random()
        local kind, r
        if tier >= 3 and roll < 0.42 then
            kind, r = "military", rng:random(700, 900)
        elseif tier >= 2 and roll < 0.5 then
            kind, r = "industrial", rng:random(700, 1000)
        elseif roll < 0.8 then
            kind, r = "town", rng:random(850, 1200)
        else
            kind, r = "village", rng:random(450, 650)
        end
        local ok = not ctx:water(x, y) and ctx:elevation(x, y) > ctx.waterLevel + 0.03
        for _, s in ipairs(settlements) do
            if ok and (s.x - x) ^ 2 + (s.y - y) ^ 2 < (s.r + r + 900) ^ 2 then ok = false end
        end
        if ok then settlements[#settlements + 1] = { x = x, y = y, r = r, kind = kind, tier = tier } end
    end
    m.settlements = settlements

    -- Gates on the edges of the map: roads leave there, players arrive there.
    local gates = {}
    for k = 0, 15 do
        local t = (k + 0.5) / 16 + (rng:random() - 0.5) * 0.03
        local side = floor(t * 4)
        local u = (t * 4 - side) * (size - 3000) + 1500
        local x, y
        if side == 0 then x, y = u, 700 elseif side == 1 then x, y = size - 700, u elseif side == 2 then x, y = size - u, size - 700 else x, y = 700, size - u end
        gates[#gates + 1] = { x = floor(x), y = floor(y) }
    end

    -- Roads: a spanning tree over the settlements plus a few loops, and every gate.
    local function edge(a, b)
        local dx, dy = b.x - a.x, b.y - a.y
        local d = max(1, sqrt(dx * dx + dy * dy))
        local ar, br = (a.r or 0) * 0.95, (b.r or 0) * 0.95
        road(ctx, a.x + dx / d * ar, a.y + dy / d * ar, b.x - dx / d * br, b.y - dy / d * br, ROAD)
    end
    local inTree, best, from = { [1] = true }, {}, {}
    for k = 2, #settlements do
        best[k] = (settlements[k].x - half) ^ 2 + (settlements[k].y - half) ^ 2
        from[k] = 1
    end
    for _ = 2, #settlements do
        local pick, pickD
        for k = 2, #settlements do
            if not inTree[k] and (not pickD or best[k] < pickD) then pick, pickD = k, best[k] end
        end
        inTree[pick] = true
        edge(settlements[from[pick]], settlements[pick])
        for k = 2, #settlements do
            if not inTree[k] then
                local d = (settlements[k].x - settlements[pick].x) ^ 2 + (settlements[k].y - settlements[pick].y) ^ 2
                if d < best[k] then best[k], from[k] = d, pick end
            end
        end
    end
    for k, s in ipairs(settlements) do
        local second, secondD
        for j, o in ipairs(settlements) do
            if j ~= k and from[k] ~= j and from[j] ~= k then
                local d = (o.x - s.x) ^ 2 + (o.y - s.y) ^ 2
                if not secondD or d < secondD then second, secondD = o, d end
            end
        end
        if second and rng:random() < 0.35 then edge(s, second) end
    end
    for _, g in ipairs(gates) do
        local nearest, nearestD
        for _, s in ipairs(settlements) do
            local d = (s.x - g.x) ^ 2 + (s.y - g.y) ^ 2
            if not nearestD or d < nearestD then nearest, nearestD = s, d end
        end
        edge(g, nearest)
    end

    -- Water: rows of the elevation field below the water line, except where a road
    -- crosses (bridges) and inside settlements.
    local SETTLEMENT_CELL, SETTLEMENT_PAD = 2000, 300
    local settlementGrid = {}
    for _, s in ipairs(settlements) do
        local reach = s.r + SETTLEMENT_PAD
        for gy = floor((s.y - reach) / SETTLEMENT_CELL), floor((s.y + reach) / SETTLEMENT_CELL) do
            for gx = floor((s.x - reach) / SETTLEMENT_CELL), floor((s.x + reach) / SETTLEMENT_CELL) do
                local key = gy * 100000 + gx
                local bucket = settlementGrid[key]
                if not bucket then
                    bucket = {}
                    settlementGrid[key] = bucket
                end
                bucket[#bucket + 1] = s
            end
        end
    end
    local function inSettlement(x, y, pad)
        local candidates = settlements
        if pad <= SETTLEMENT_PAD then
            candidates = settlementGrid[floor(y / SETTLEMENT_CELL) * 100000 + floor(x / SETTLEMENT_CELL)]
            if not candidates then return nil end
        end
        for _, s in ipairs(candidates) do
            if (s.x - x) ^ 2 + (s.y - y) ^ 2 < (s.r + pad) ^ 2 then return s end
        end
    end
    local step = 100
    for y = 100, size - 200, step do
        local start
        for x = 100, size - 100, step do
            local cx, cy = x + step / 2, y + step / 2
            local water = x < size - 200 and ctx:water(cx, cy) and not ctx:nearRoad(cx, cy, 60) and not inSettlement(cx, cy, 150)
            if water and not start then start = x end
            if not water and start then
                ctx:box(start, y, x - start, step, "pit")
                start = nil
            end
        end
    end

    -- Settlement contents.
    for _, s in ipairs(settlements) do
        local sub = Random.new(Hash.combine(seed, floor(s.x) * 7 + floor(s.y)))
        ctx.rng = sub
        Settlement[s.kind](ctx, s)
    end
    ctx.rng = rng

    -- The land between settlements, cell by cell.
    local nestGrid = {}
    for _, nest in ipairs(m.nests) do nestGrid[floor(nest.y / 1500) * 100 + floor(nest.x / 1500)] = true end
    for gy = 0, n - 1 do
        for gx = 0, n - 1 do
            local x, y = gx * CELL, gy * CELL
            local cx, cy = x + CELL / 2, y + CELL / 2
            local tier = tierAt(cx, cy)
            local s = inSettlement(cx, cy, 0)
            local biome
            if s then
                biome = s.kind == "village" and "town" or s.kind
            elseif ctx:water(cx, cy) then
                biome = "lake"
            elseif ctx:elevation(cx, cy) > ctx.highLevel then
                biome = "highlands"
            elseif moist[gy * (n + 1) + gx + 1] > forestLevel then
                biome = "forest"
            else
                biome = "field"
            end
            m.chunks[gy * n + gx + 1] = { biome = biome, tier = tier }
            if not s and biome ~= "lake" then
                local r = rng:random()
                if biome == "forest" then
                    for _ = 1, 2 do
                        if rng:random() < 0.5 then
                            local size2 = rng:random(30, 64)
                            local tx, ty = x + rng:random() * (CELL - size2), y + rng:random() * (CELL - size2)
                            if ctx:free(tx, ty, size2, size2, 36) then ctx:box(tx, ty, size2, size2, nil, "tree") end
                        end
                    end
                    if r < 0.008 then
                        local w, h = rng:random(260, 340), rng:random(200, 260)
                        if ctx:free(x, y, w, h, 40) then ctx:building(x, y, w, h, tier, WILD, { rooms = 1, windows = 1, loot = 1 }) end
                    elseif r < 0.012 and ctx:free(cx - 20, cy - 20, 40, 40, 20) then
                        ctx:container(cx, cy, "stash", tier)
                    end
                elseif biome == "highlands" then
                    if r < 0.3 then
                        local w, h = rng:random(50, 140), rng:random(40, 110)
                        local tx, ty = x + rng:random() * (CELL - w), y + rng:random() * (CELL - h)
                        if ctx:free(tx, ty, w, h, 40) then ctx:box(tx, ty, w, h, "cover", "rock") end
                    elseif r < 0.38 then
                        local s2 = rng:random(80, 170)
                        local tx, ty = x + rng:random() * (CELL - s2 / 2), y + rng:random() * (CELL - s2 / 2)
                        if ctx:free(tx, ty, s2, s2, 50) then ctx:box(tx, ty, s2, s2, nil, "boulder") end
                    elseif r < 0.39 and ctx:free(cx - 20, cy - 20, 40, 40, 20) then
                        ctx:container(cx, cy, "stash", tier)
                    end
                else
                    if r < 0.025 then
                        if ctx:free(cx, cy, 80, 44, 40) then ctx:box(cx, cy, 80, 44, "cover", "bale") end
                    elseif r < 0.035 then
                        local horizontal = rng:random() < 0.5
                        local length = rng:random(240, 600)
                        local w, h = horizontal and length or 16, horizontal and 16 or length
                        if ctx:free(cx, cy, w, h, 50) then ctx:box(cx, cy, w, h, "cover") end
                    elseif r < 0.042 then
                        local w, h = rng:random(420, 540), rng:random(300, 360)
                        if ctx:free(x, y, w, h, 50) then
                            ctx:building(x, y, w, h, tier, { "crate", "toolbox" }, { rooms = 1, windows = 0, loot = 0.9, floor = "planks" })
                        end
                    end
                end
                local key = floor(cy / 1500) * 100 + floor(cx / 1500)
                if not nestGrid[key] and rng:random() < 0.06 and ctx:free(cx - 40, cy - 40, 80, 80, 0) then
                    nestGrid[key] = true
                    ctx:nest(cx, cy, tier, biome)
                end
            end
        end
    end

    -- Spawns along roads near the edges, extraction points at the gates and inside.
    local roadPoints = {}
    for _, r in ipairs(m.roads) do
        local len = sqrt((r[3] - r[1]) ^ 2 + (r[4] - r[2]) ^ 2)
        for t = 0, len, 450 do
            local x, y = r[1] + (r[3] - r[1]) * t / max(1, len), r[2] + (r[4] - r[2]) * t / max(1, len)
            roadPoints[#roadPoints + 1] = { x = floor(x), y = floor(y), tier = tierAt(x, y) }
        end
    end
    m.roadPoints = roadPoints
    local function spaced(list, x, y, gap)
        for _, p in ipairs(list) do
            if (p.x - x) ^ 2 + (p.y - y) ^ 2 < gap * gap then return false end
        end
        return true
    end
    -- Odd gates are extraction points, even gates are where players arrive; spawns
    -- along roads keep away from every extraction point.
    local names = 1
    for k = 1, #gates, 2 do
        m.extracts[#m.extracts + 1] = { id = #m.extracts + 1, name = EXTRACT_NAMES[names], x = gates[k].x, y = gates[k].y }
        names = names + 1
    end
    for _, p in ipairs(roadPoints) do
        if #m.extracts >= 10 then break end
        if p.tier == 3 and not inSettlement(p.x, p.y, 300) and spaced(m.extracts, p.x, p.y, 9000) then
            m.extracts[#m.extracts + 1] = { id = #m.extracts + 1, name = EXTRACT_NAMES[names], x = p.x, y = p.y }
            names = names + 1
        end
    end
    for k = 2, #gates, 2 do
        local g = gates[k]
        B.spawn(m, g.x, g.y, math.atan2(half - g.y, half - g.x))
    end
    for _, p in ipairs(roadPoints) do
        local edgeDistance = min(p.x, p.y, size - p.x, size - p.y)
        if p.tier <= 2 and edgeDistance < 7000 and not inSettlement(p.x, p.y, 200)
            and spaced(m.spawns, p.x, p.y, 1200) and spaced(m.extracts, p.x, p.y, 2500) then
            B.spawn(m, p.x, p.y, math.atan2(half - p.y, half - p.x))
        end
    end
    m.roadCells = ctx.roadCells
    m.spawnRng = rng
    return m
end

--- Calls fn on every road segment in a box ({ x1, y1, x2, y2, width }).
function Worldgen.roadsNear(m, x0, y0, x1, y1, fn)
    local seen = {}
    for ky = floor(y0 / 1000), floor(y1 / 1000) do
        for kx = floor(x0 / 1000), floor(x1 / 1000) do
            for _, k in ipairs(m.roadCells[ky * 1000 + kx] or {}) do
                if not seen[k] then
                    seen[k] = true
                    fn(m.roads[k])
                end
            end
        end
    end
end

--- @param m table generated map
--- @param x number
--- @param y number
--- @return table cell { biome, tier }
function Worldgen.chunkAt(m, x, y)
    local cx = max(0, min(m.count - 1, floor(x / m.chunk)))
    local cy = max(0, min(m.count - 1, floor(y / m.chunk)))
    return m.chunks[cy * m.count + cx + 1], cx, cy
end

return Worldgen
