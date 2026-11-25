--- Builds the extraction world from a seed. The server and every client run the same
--- generation, so only the seed goes over the network. The world is a grid of chunks
--- separated by roads; each chunk gets a biome and a danger tier (1 at the edges, 4 in
--- the centre) that pick its buildings, loot containers and monster nests.
local B = require("src.maps.builder")
local Random = require("src.core.random")
local Hash = require("src.core.hash")
local Config = require("src.config.extraction")

local Worldgen = {}

local floor, sqrt, min, max = math.floor, math.sqrt, math.min, math.max

Worldgen.BIOMES = {
    forest = { name = "Forest", color = { 0.55, 0.66, 0.5 } },
    field = { name = "Fields", color = { 0.78, 0.76, 0.58 } },
    lake = { name = "Lake", color = { 0.5, 0.64, 0.76 } },
    town = { name = "Town", color = { 0.72, 0.7, 0.68 } },
    industrial = { name = "Industrial", color = { 0.62, 0.6, 0.6 } },
    military = { name = "Military", color = { 0.58, 0.6, 0.48 } },
    citadel = { name = "Citadel", color = { 0.56, 0.44, 0.44 } }
}

local EXTRACT_NAMES = {
    "Pine pass", "Old bridge", "Radio mast", "Rail yard", "Fishing pier", "Quarry road", "Toll gate",
    "Dam tunnel", "Cliff stairs", "Checkpoint", "Helipad", "Sewer outlet"
}

--- Smooth noise in [0, 1] from a lattice of hashed values.
--- @param seed number
--- @param x number
--- @param y number
--- @param scale number lattice spacing
--- @return number
local function noise(seed, x, y, scale)
    local gx, gy = x / scale, y / scale
    local ix, iy = floor(gx), floor(gy)
    local fx, fy = gx - ix, gy - iy
    local function at(a, b)
        return Hash.combine(Hash.combine(seed, a + 1000), b + 1000) / 4294967296
    end
    local sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    local top = at(ix, iy) + (at(ix + 1, iy) - at(ix, iy)) * sx
    local bottom = at(ix, iy + 1) + (at(ix + 1, iy + 1) - at(ix, iy + 1)) * sx
    return top + (bottom - top) * sy
end

Worldgen.noise = noise

--- @param seed number
--- @param cx number
--- @param cy number
--- @param count number chunks per side
--- @return string biome, number tier
function Worldgen.classify(seed, cx, cy, count)
    local half = count / 2
    local dx, dy = (cx + 0.5 - half) / half, (cy + 0.5 - half) / half
    local base = sqrt(dx * dx + dy * dy)
    if base < 0.1 then return "citadel", 4 end
    local d = base + (noise(seed + 3, cx, cy, 3) - 0.5) * 0.18
    local tier = d < 0.22 and 4 or d < 0.48 and 3 or d < 0.74 and 2 or 1
    local v = noise(seed, cx, cy, 4.5)
    local w = noise(seed + 17, cx, cy, 3.2)
    if tier >= 3 and w > 0.64 then return "military", tier end
    if v < 0.16 and tier <= 3 then return "lake", tier end
    if v < 0.42 then return "forest", tier end
    if v < 0.54 then return "field", tier end
    if v < 0.8 then return "town", tier end
    return "industrial", tier
end

--- A world under construction: the map lists plus the containers and nests.
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

--- Is a rectangle free of every rectangle placed in this chunk so far?
function Ctx:free(x, y, w, h, pad)
    pad = pad or 0
    for _, r in ipairs(self.placed) do
        if x - pad < r.x + r.w and r.x < x + w + pad and y - pad < r.y + r.h and r.y < y + h + pad then return false end
    end
    return true
end

function Ctx:box(x, y, w, h, kind)
    B.box(self.m, floor(x), floor(y), floor(w), floor(h), kind)
    self.placed[#self.placed + 1] = { x = x, y = y, w = w, h = h }
end

function Ctx:claim(x, y, w, h)
    self.placed[#self.placed + 1] = { x = x, y = y, w = w, h = h }
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
        end
    end
end

local TOWN = { "crate", "cabinet", "fridge", "locker", "drawer", "medbox" }
local INDUSTRIAL = { "toolbox", "crate", "locker", "crate", "cabinet" }
local MILITARY = { "weapon_case", "ammo_crate", "crate", "medbox", "weapon_case" }
local WILD = { "stash", "crate" }

local Biome = {}

function Biome.town(ctx, x, y, size, tier)
    local rng = ctx.rng
    local blocks = rng:random() < 0.5 and 2 or 3
    local street = 150
    local block = (size - street * (blocks - 1)) / blocks
    for by = 0, blocks - 1 do
        for bx = 0, blocks - 1 do
            local px, py = x + bx * (block + street), y + by * (block + street)
            if rng:random() < 0.82 then
                local w = block * (0.55 + rng:random() * 0.4)
                local h = block * (0.5 + rng:random() * 0.45)
                local ox, oy = rng:random() * (block - w), rng:random() * (block - h)
                ctx:building(px + ox, py + oy, w, h, tier, TOWN, { rooms = 3, windows = 2 })
            else
                for _ = 1, rng:random(4, 9) do
                    local s = rng:random(34, 54)
                    local tx, ty = px + rng:random() * (block - s), py + rng:random() * (block - s)
                    if ctx:free(tx, ty, s, s, 40) then ctx:box(tx, ty, s, s) end
                end
                ctx:nest(px + block / 2, py + block / 2, tier, "town")
            end
        end
    end
    for _ = 1, rng:random(3, 7) do
        local horizontal = rng:random() < 0.5
        local w, h = horizontal and 96 or 46, horizontal and 46 or 96
        local cx, cy = x + rng:random() * (size - w), y + rng:random() * (size - h)
        if ctx:free(cx, cy, w, h, 30) then ctx:box(cx, cy, w, h, "cover") end
    end
    ctx:nest(x + size / 2, y + size / 2, tier, "town")
end

function Biome.industrial(ctx, x, y, size, tier)
    local rng = ctx.rng
    local w, h = size * (0.45 + rng:random() * 0.2), size * (0.3 + rng:random() * 0.15)
    local wx, wy = x + rng:random() * (size - w), y + rng:random() * (size * 0.4)
    ctx:building(wx, wy, w, h, tier, INDUSTRIAL, { rooms = 1, windows = 2, loot = 0.9 })
    for k = 1, 3 do
        local sx = wx + 60 + (w - 120) * k / 4
        B.box(ctx.m, floor(sx - 14), floor(wy + 80), 28, floor(h - 160), "cover")
    end
    for _ = 1, rng:random(8, 16) do
        local horizontal = rng:random() < 0.6
        local cw, ch = horizontal and 240 or 80, horizontal and 80 or 240
        local cx, cy = x + rng:random() * (size - cw), y + rng:random() * (size - ch)
        if ctx:free(cx, cy, cw, ch, 70) then
            ctx:box(cx, cy, cw, ch)
            if rng:random() < 0.3 then ctx:container(cx + cw / 2, cy + ch + 40, "crate", tier) end
        end
    end
    ctx:nest(x + size * 0.5, y + size * 0.8, tier, "industrial")
    ctx:nest(x + size * 0.2, y + size * 0.5, tier, "industrial")
end

function Biome.forest(ctx, x, y, size, tier)
    local rng = ctx.rng
    if rng:random() < 0.4 then
        local cw, ch = rng:random(260, 360), rng:random(220, 300)
        ctx:building(x + rng:random() * (size - cw), y + rng:random() * (size - ch), cw, ch, tier, WILD, { rooms = 1, windows = 1, loot = 1 })
    end
    for _ = 1, rng:random(55, 85) do
        local s = rng:random(30, 64)
        local tx, ty = x + rng:random() * (size - s), y + rng:random() * (size - s)
        if ctx:free(tx, ty, s, s, 50) then
            ctx:box(tx, ty, s, s)
            if rng:random() < 0.04 then ctx:container(tx + s + 30, ty + s / 2, "stash", tier) end
        end
    end
    for _ = 1, rng:random(4, 9) do
        local w, h = rng:random(50, 130), rng:random(40, 90)
        local rx, ry = x + rng:random() * (size - w), y + rng:random() * (size - h)
        if ctx:free(rx, ry, w, h, 40) then ctx:box(rx, ry, w, h, "cover") end
    end
    ctx:nest(x + size * (0.3 + rng:random() * 0.4), y + size * (0.3 + rng:random() * 0.4), tier, "forest")
end

function Biome.field(ctx, x, y, size, tier)
    local rng = ctx.rng
    if rng:random() < 0.55 then
        local bw, bh = rng:random(420, 560), rng:random(300, 380)
        ctx:building(x + rng:random() * (size - bw), y + rng:random() * (size - bh), bw, bh, tier, { "crate", "toolbox" }, { rooms = 1, windows = 0, loot = 0.9 })
    end
    for _ = 1, rng:random(3, 6) do
        local horizontal = rng:random() < 0.5
        local length = rng:random(300, 700)
        local fx, fy = x + rng:random() * (size - length), y + rng:random() * (size - length)
        local w, h = horizontal and length or 16, horizontal and 16 or length
        if ctx:free(fx, fy, w, h, 60) then
            local gap = rng:random(60, length - 160)
            if horizontal then
                ctx:box(fx, fy, gap, 16, "cover")
                ctx:box(fx + gap + 100, fy, length - gap - 100, 16, "cover")
            else
                ctx:box(fx, fy, 16, gap, "cover")
                ctx:box(fx, fy + gap + 100, 16, length - gap - 100, "cover")
            end
        end
    end
    for _ = 1, rng:random(6, 14) do
        local fx, fy = x + rng:random() * (size - 80), y + rng:random() * (size - 44)
        if ctx:free(fx, fy, 80, 44, 50) then ctx:box(fx, fy, 80, 44, "cover") end
    end
    ctx:nest(x + size / 2, y + size / 2, tier, "field")
end

function Biome.lake(ctx, x, y, size, tier)
    local rng = ctx.rng
    local cx, cy = x + size / 2, y + size / 2
    for _ = 1, rng:random(3, 5) do
        local w, h = size * (0.3 + rng:random() * 0.35), size * (0.3 + rng:random() * 0.35)
        local px = cx - w / 2 + (rng:random() - 0.5) * size * 0.3
        local py = cy - h / 2 + (rng:random() - 0.5) * size * 0.3
        px, py = max(x + 60, min(px, x + size - w - 60)), max(y + 60, min(py, y + size - h - 60))
        ctx:box(px, py, w, h, "pit")
    end
    for _ = 1, rng:random(8, 16) do
        local s = rng:random(40, 90)
        local tx, ty = x + rng:random() * (size - s), y + rng:random() * (size - s)
        if ctx:free(tx, ty, s, s, 50) then ctx:box(tx, ty, s, s, "cover") end
    end
    if rng:random() < 0.5 then
        local tx, ty = x + 80, y + 80
        if ctx:free(tx, ty, 240, 200, 20) then
            ctx:building(tx, ty, 240, 200, tier, WILD, { rooms = 1, windows = 1, loot = 1 })
        end
    end
    ctx:nest(x + size * 0.85, y + size * 0.85, tier, "lake")
end

local function compound(ctx, x, y, size, tier, inner)
    local rng, m = ctx.rng, ctx.m
    local fx, fy, fs = x + 60, y + 60, size - 120
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
end

function Biome.military(ctx, x, y, size, tier)
    local rng = ctx.rng
    compound(ctx, x, y, size, tier, function(ix, iy, is)
        for k = 1, rng:random(2, 4) do
            local w, h = rng:random(300, 460), rng:random(240, 340)
            for _ = 1, 8 do
                local bx, by = ix + rng:random() * (is - w), iy + rng:random() * (is - h)
                if ctx:free(bx, by, w, h, 90) then
                    ctx:building(bx, by, w, h, tier, MILITARY, { rooms = k == 1 and 2 or 1, windows = 0, loot = 1 })
                    break
                end
            end
        end
        for _ = 1, rng:random(6, 12) do
            local horizontal = rng:random() < 0.5
            local w, h = horizontal and 130 or 34, horizontal and 34 or 130
            local sx, sy = ix + rng:random() * (is - w), iy + rng:random() * (is - h)
            if ctx:free(sx, sy, w, h, 50) then ctx:box(sx, sy, w, h, "cover") end
        end
        ctx:nest(ix + is / 2, iy + is / 2, tier, "military")
    end)
end

function Biome.citadel(ctx, x, y, size, tier)
    local rng = ctx.rng
    compound(ctx, x, y, size, tier, function(ix, iy, is)
        local w, h = is * 0.55, is * 0.45
        ctx:building(ix + (is - w) / 2, iy + (is - h) / 2, w, h, tier, MILITARY, { rooms = 5, windows = 1, loot = 1 })
        for _ = 1, 10 do
            local horizontal = rng:random() < 0.5
            local cw, ch = horizontal and 140 or 34, horizontal and 34 or 140
            local sx, sy = ix + rng:random() * (is - cw), iy + rng:random() * (is - ch)
            if ctx:free(sx, sy, cw, ch, 50) then ctx:box(sx, sy, cw, ch, "cover") end
        end
        ctx:nest(ix + is * 0.15, iy + is * 0.15, tier, "military")
        ctx:nest(ix + is * 0.85, iy + is * 0.85, tier, "military")
        ctx.m.citadel = { x = ix + is / 2, y = iy + is * 0.9 }
    end)
end

--- Generates the whole world.
--- @param seed number?
--- @return table map definition for Terrain.new, plus containers, nests, spawns, extracts, chunks
function Worldgen.generate(seed)
    seed = seed or Config.seed
    local size, chunk, road = Config.size, Config.chunk, Config.road
    local count = floor(size / chunk)
    local m = B.new("wilds", "The Wilds", size, size, "A vast persistent world. Loot, survive, extract.")
    m.containers, m.nests, m.extracts, m.chunks = {}, {}, {}, {}
    m.seed, m.count, m.chunk = seed, count, chunk
    B.border(m, 60)
    for cy = 0, count - 1 do
        for cx = 0, count - 1 do
            local biome, tier = Worldgen.classify(seed, cx, cy, count)
            m.chunks[cy * count + cx + 1] = { biome = biome, tier = tier }
            local rng = Random.new(Hash.combine(Hash.combine(seed, cx + 7), cy + 13))
            local ctx = setmetatable({ m = m, rng = rng, placed = {} }, Ctx)
            local inset = road + 40
            Biome[biome](ctx, cx * chunk + inset, cy * chunk + inset, chunk - inset * 2, tier)
        end
    end
    -- Road crossings are always clear: players spawn on the outer ones, extracts sit on some.
    local spawnRng = Random.new(Hash.combine(seed, 99))
    for cy = 1, count - 1 do
        for cx = 1, count - 1 do
            local outer = min(cx, cy, count - cx, count - cy)
            if outer <= 3 then
                local angle = math.atan2(size / 2 - cy * chunk, size / 2 - cx * chunk)
                B.spawn(m, cx * chunk, cy * chunk, angle)
            end
        end
    end
    local picks = {
        { 1, 3 }, { 1, count - 4 }, { count - 1, 4 }, { count - 1, count - 3 }, { 5, 1 }, { count - 6, 1 },
        { 4, count - 1 }, { count - 5, count - 1 }, { floor(count / 2) - 3, floor(count / 2) + 3 }, { floor(count / 2) + 3, floor(count / 2) - 3 }
    }
    for k, pick in ipairs(picks) do
        m.extracts[#m.extracts + 1] = { id = k, name = EXTRACT_NAMES[k], x = pick[1] * chunk, y = pick[2] * chunk }
    end
    m.spawnRng = spawnRng
    return m
end

--- @param m table generated map
--- @param x number
--- @param y number
--- @return table chunk { biome, tier }
function Worldgen.chunkAt(m, x, y)
    local cx = max(0, min(m.count - 1, floor(x / m.chunk)))
    local cy = max(0, min(m.count - 1, floor(y / m.chunk)))
    return m.chunks[cy * m.count + cx + 1], cx, cy
end

return Worldgen
