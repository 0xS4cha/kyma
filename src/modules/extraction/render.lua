--- Draws the extraction world around the camera. Only what is near the view is
--- visited (the spatial index of the terrain), so the size of the map does not
--- matter for the frame rate.
local Kit = require("src.ui.kit")
local Renderer = require("src.modules.session.renderer")
local Character = require("src.modules.session.character")
local Vision = require("src.game.vision")
local Worldgen = require("src.game.extraction.worldgen")
local MonsterConfig = require("src.config.monsters")
local ItemConfig = require("src.config.items")
local Items = require("src.game.extraction.items")
local Config = require("src.config.extraction")
local GameConfig = require("src.config.game")
local Theme = require("src.ui.theme")

local Render = {}

local lg = love.graphics
local cos, sin, floor, min, max, pi = math.cos, math.sin, math.floor, math.min, math.max, math.pi
local T = Theme.colors

local function mix(a, b, t)
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

--- The world uses the arenas' palette: cool greys from the theme (light or dark),
--- white tops, blue-grey shadows, and red only as an accent.
--- @param t number 0 is the light top of a block, 1 its dark side, past 1 darker still
local function grey(t)
    if t <= 1 then return mix(T.coverTop, T.coverSide, t) end
    return mix(T.coverSide, T.pitRim, min(1, t - 1))
end

--- How dark a loot container is (see grey), red for the few that matter.
local CONTAINER_SHADES = {
    crate = 0.55, locker = 0.8, cabinet = 0.65, fridge = 0.05, drawer = 0.7, medbox = 0, weapon_case = 1.4,
    ammo_crate = 1.15, stash = 1.25
}

local function containerColor(kind)
    if kind == "toolbox" then return Kit.RED end
    return grey(CONTAINER_SHADES[kind] or 0.55)
end

--- The world box that covers the screen around the camera.
--- @return number, number, number, number
function Render.bounds(camera)
    local W, H = lg.getDimensions()
    local reach = math.sqrt((W * 0.5) ^ 2 + (H * 0.7) ^ 2) / camera.scale + 120
    return camera.x - reach, camera.y - reach, camera.x + reach, camera.y + reach
end

--- The colour of every corner of the biome grid: the average of the cells around
--- it, so the ground fades from one biome to the next instead of showing squares.
local corners = setmetatable({}, { __mode = "k" })

local function cornerColors(def)
    local cached = corners[def]
    if cached and cached.version == Theme.version then return cached end
    local n = def.count
    local colors = {}
    local function cell(cx, cy)
        cx, cy = max(0, min(n - 1, cx)), max(0, min(n - 1, cy))
        local info = def.chunks[cy * n + cx + 1]
        return Worldgen.BIOMES[info.biome].shade or 0, info.tier
    end
    for gy = 0, n do
        for gx = 0, n do
            local shade, danger = 0, 0
            for _, o in ipairs({ { -1, -1 }, { 0, -1 }, { -1, 0 }, { 0, 0 } }) do
                local s, tier = cell(gx + o[1], gy + o[2])
                shade = shade + s
                danger = danger + (tier - 1) / 3
            end
            -- the arena floor, a touch darker in dense areas; the deeper the
            -- danger, the darker and the redder, so you see where it gets hard
            local base = mix(T.floor, T.pitRim, shade / 4 * 0.14 + danger / 4 * 0.5)
            colors[gy * (n + 1) + gx + 1] = mix(base, Kit.RED, danger / 4 * 0.24)
        end
    end
    colors.version = Theme.version
    corners[def] = colors
    return colors
end

local lampsNear, lampPool

--- Where the danger goes up, a red dashed line on the ground, with chevrons
--- pointing into the harder side.
local function drawBorders(def, cx0, cy0, cx1, cy1)
    local n, cell = def.count, def.chunk
    local function tier(cx, cy)
        if cx < 0 or cy < 0 or cx >= n or cy >= n then return nil end
        return def.chunks[cy * n + cx + 1].tier
    end
    lg.setLineWidth(10)
    local dash = 80
    local function edge(x1, y1, x2, y2, harder, nx, ny)
        Kit.color(Kit.RED, 0.35 + 0.12 * harder)
        local len = math.abs(x2 - x1) + math.abs(y2 - y1)
        local ux, uy = (x2 - x1) / len, (y2 - y1) / len
        for t = 0, len - dash, dash * 2 do
            lg.line(x1 + ux * t, y1 + uy * t, x1 + ux * (t + dash), y1 + uy * (t + dash))
        end
        for t = dash * 3, len - dash, dash * 6 do
            local px, py = x1 + ux * t + nx * 40, y1 + uy * t + ny * 40
            lg.line(px - ux * 18 - nx * 14, py - uy * 18 - ny * 14, px, py, px + ux * 18 - nx * 14, py + uy * 18 - ny * 14)
        end
    end
    for cy = cy0 - 1, cy1 do
        for cx = cx0 - 1, cx1 do
            local here = tier(cx, cy)
            if here then
                local right, below = tier(cx + 1, cy), tier(cx, cy + 1)
                local x, y = (cx + 1) * cell, (cy + 1) * cell
                if right and right ~= here then
                    local dir = right > here and 1 or -1
                    edge(x, cy * cell, x, y, max(right, here), dir, 0)
                end
                if below and below ~= here then
                    local dir = below > here and 1 or -1
                    edge(cx * cell, y, x, y, max(below, here), 0, dir)
                end
            end
        end
    end
    lg.setLineWidth(1)
end

-- Street lamps stand along the roads, alternating sides. They are only drawn,
-- worked out from the roads, so the server knows nothing of them.
local LAMP_STEP = 460
local lampCache = setmetatable({}, { __mode = "k" })

local function roadLamps(r)
    local list = lampCache[r]
    if list then return list end
    list = {}
    local dx, dy = r[3] - r[1], r[4] - r[2]
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 1 then
        local ux, uy = dx / len, dy / len
        local seed = floor(r[1] * 7 + r[2] * 13) % 1000
        local side = (seed % 2 == 0) and 1 or -1
        local off = r[5] / 2 + 26
        -- roads are cut in short pieces: a piece shorter than the step gets a
        -- lamp now and then, in proportion to its length, so they stay evenly spread
        local start = (seed / 1000) * LAMP_STEP
        for t = start, len - 1, LAMP_STEP do
            local x, y = r[1] + ux * t - uy * off * side, r[2] + uy * t + ux * off * side
            list[#list + 1] = { x = x, y = y, ax = uy * side, ay = -ux * side }
            side = -side
        end
    end
    lampCache[r] = list
    return list
end

lampsNear = function(def, roads, x0, y0, x1, y1)
    local out = {}
    for _, r in ipairs(roads) do
        for _, lamp in ipairs(roadLamps(r)) do
            if lamp.x > x0 - 200 and lamp.x < x1 + 200 and lamp.y > y0 - 200 and lamp.y < y1 + 200 then out[#out + 1] = lamp end
        end
    end
    return out
end

--- The pool of light a lamp casts on the ground.
local poolMesh
lampPool = function(lamp)
    if not poolMesh then
        -- a soft disc: bright in the middle, fading to nothing at the edge
        local vertices = { { 0, 0, 0, 0, 1, 1, 1, 1 } }
        for k = 0, 32 do
            local a = k / 32 * 2 * pi
            vertices[#vertices + 1] = { cos(a), sin(a), 0, 0, 1, 1, 1, 0 }
        end
        poolMesh = lg.newMesh(vertices, "fan", "static")
    end
    local cx, cy = lamp.x + lamp.ax * 34, lamp.y + lamp.ay * 34
    lg.setColor(T.wallTop[1], T.wallTop[2], T.wallTop[3], 0.32)
    lg.draw(poolMesh, cx, cy, 0, 140, 140)
end

-- The warm white of a lamp, a little warmer than the arenas' cool greys.
local LAMP_LIGHT = { 1, 0.94, 0.8 }

--- The light of the lamps, drawn over the fog and added to what is under it:
--- a lit street shows from afar, even where you can't see, but the fog still
--- hides who stands in it. Each lamp breathes a little, and now and then one
--- flickers.
local function drawLampLights(lamps)
    if #lamps == 0 then return end
    lampPool({ x = 0, y = 0, ax = 0, ay = 0 }) -- builds the mesh on first use
    local now = love.timer.getTime()
    local mode, alphaMode = lg.getBlendMode()
    lg.setBlendMode("add")
    for _, lamp in ipairs(lamps) do
        local seed = (lamp.x * 0.37 + lamp.y * 0.11) % 100
        local glow = 0.92 + 0.08 * sin(now * 1.3 + seed)
        if seed < 6 and sin(now * 23 + seed) > 0.55 then glow = glow * 0.35 end
        local cx, cy = lamp.x + lamp.ax * 34, lamp.y + lamp.ay * 34
        lg.setColor(LAMP_LIGHT[1], LAMP_LIGHT[2], LAMP_LIGHT[3], 0.22 * glow)
        lg.draw(poolMesh, cx, cy, 0, 190, 190)
        lg.setColor(LAMP_LIGHT[1], LAMP_LIGHT[2], LAMP_LIGHT[3], 0.18 * glow)
        lg.draw(poolMesh, cx, cy, 0, 70, 70)
    end
    lg.setBlendMode(mode, alphaMode)
end

--- The lamp itself, above the fog like the trees: a pole, an arm and a head.
local function lampPost(lamp)
    local hx, hy = lamp.x + lamp.ax * 34, lamp.y + lamp.ay * 34
    lg.setColor(T.wallShadow)
    lg.circle("fill", lamp.x + 5, lamp.y + 6, 7)
    lg.setColor(mix(T.coverSide, T.pitRim, 0.5))
    lg.setLineWidth(4)
    lg.line(lamp.x, lamp.y, hx, hy)
    lg.setLineWidth(1)
    lg.circle("fill", lamp.x, lamp.y, 6)
    lg.setColor(T.wallTop)
    lg.circle("fill", hx, hy, 8)
    lg.setColor(T.coverSide)
    lg.circle("line", hx, hy, 8)
    -- the bulb shines
    local mode, alphaMode = lg.getBlendMode()
    lg.setBlendMode("add")
    lg.setColor(LAMP_LIGHT[1], LAMP_LIGHT[2], LAMP_LIGHT[3], 0.5)
    lg.circle("fill", hx, hy, 5)
    lg.setColor(LAMP_LIGHT[1], LAMP_LIGHT[2], LAMP_LIGHT[3], 0.15)
    lg.circle("fill", hx, hy, 14)
    lg.setBlendMode(mode, alphaMode)
end

local groundMesh
local groundVertices = {}

local function drawFloor(raid, x0, y0, x1, y1)
    local def = raid.def
    local cell, n = def.chunk, def.count
    local colors = cornerColors(def)
    local cx0, cy0 = max(0, floor(x0 / cell)), max(0, floor(y0 / cell))
    local cx1, cy1 = min(n - 1, floor(x1 / cell)), min(n - 1, floor(y1 / cell))
    local count = 0
    local verts = groundVertices
    local function vertex(gx, gy)
        local c = colors[gy * (n + 1) + gx + 1]
        count = count + 1
        local v = verts[count]
        if not v then
            v = {}
            verts[count] = v
        end
        v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8] = gx * cell, gy * cell, 0, 0, c[1], c[2], c[3], 1
    end
    for gy = cy0, cy1 do
        for gx = cx0, cx1 do
            vertex(gx, gy) vertex(gx + 1, gy) vertex(gx + 1, gy + 1)
            vertex(gx, gy) vertex(gx + 1, gy + 1) vertex(gx, gy + 1)
        end
    end
    for k = #verts, count + 1, -1 do verts[k] = nil end
    if count > 0 then
        if not groundMesh or groundMesh:getVertexCount() < count then
            groundMesh = lg.newMesh(math.max(count, 6 * 40 * 40), "triangles", "stream")
        end
        groundMesh:setVertices(verts)
        groundMesh:setDrawRange(1, count)
        lg.setColor(1, 1, 1, 1)
        lg.draw(groundMesh)
    end
    lg.setColor(T.grid)
    lg.setLineWidth(1)
    local step = 80
    for x = floor(x0 / step) * step, x1, step do lg.line(x, max(0, y0), x, min(def.height, y1)) end
    for y = floor(y0 / step) * step, y1, step do lg.line(max(0, x0), y, min(def.width, x1), y) end
    -- Lakes: a sandy shore, then the water.
    raid.terrain:query("pits", x0 - 30, y0 - 30, x1 + 30, y1 + 30, function(pit)
        lg.setColor(mix(T.floor, T.wallTop, 0.55))
        lg.rectangle("fill", pit.x - 24, pit.y - 24, pit.w + 48, pit.h + 48, 30, 30)
    end)
    raid.terrain:query("pits", x0, y0, x1, y1, function(pit)
        lg.setColor(mix(mix(T.floor, T.glassSide, 0.7), T.pitRim, 0.25))
        lg.rectangle("fill", pit.x - 6, pit.y - 6, pit.w + 12, pit.h + 12, 18, 18)
    end)
    -- Roads: a shoulder, the asphalt, a dashed centre line.
    local roads = {}
    Worldgen.roadsNear(def, x0, y0, x1, y1, function(r) roads[#roads + 1] = r end)
    lg.setColor(mix(T.floor, T.wallSide, 0.8))
    for _, r in ipairs(roads) do
        lg.setLineWidth(r[5] + 22)
        lg.line(r[1], r[2], r[3], r[4])
        lg.circle("fill", r[1], r[2], (r[5] + 22) / 2)
    end
    lg.setColor(mix(T.floor, T.pitRim, 0.4))
    for _, r in ipairs(roads) do
        lg.setLineWidth(r[5])
        lg.line(r[1], r[2], r[3], r[4])
        lg.circle("fill", r[1], r[2], r[5] / 2)
        lg.circle("fill", r[3], r[4], r[5] / 2)
    end
    lg.setColor(T.wallTop[1], T.wallTop[2], T.wallTop[3], 0.7)
    lg.setLineWidth(5)
    for _, r in ipairs(roads) do
        local dx, dy = r[3] - r[1], r[4] - r[2]
        local len = math.sqrt(dx * dx + dy * dy)
        for t = 0, len - 50, 130 do
            local a, b = t / len, math.min(1, (t + 60) / len)
            lg.line(r[1] + dx * a, r[2] + dy * a, r[1] + dx * b, r[2] + dy * b)
        end
    end
    lg.setLineWidth(1)
    drawBorders(def, cx0, cy0, cx1, cy1)
    for _, lamp in ipairs(lampsNear(def, roads, x0, y0, x1, y1)) do lampPool(lamp) end
end

local function shadow(rect, ox, oy)
    lg.polygon("fill",
        rect.x, rect.y, rect.x + rect.w, rect.y, rect.x + rect.w + ox, rect.y + oy,
        rect.x + rect.w + ox, rect.y + rect.h + oy, rect.x + ox, rect.y + rect.h + oy, rect.x, rect.y + rect.h)
end

--- The rectangles near the view: plain ones as a small arena for the session
--- renderer, decorated ones (trees, rocks, cars...) apart, drawn as shapes.
local function nearby(raid, x0, y0, x1, y1)
    local proxy = { walls = {}, doors = {}, glass = {}, cover = {}, decor = {}, lamps = {} }
    local roads = {}
    Worldgen.roadsNear(raid.def, x0, y0, x1, y1, function(r) roads[#roads + 1] = r end)
    proxy.lamps = lampsNear(raid.def, roads, x0, y0, x1, y1)
    for _, list in ipairs({ "walls", "doors", "glass", "cover" }) do
        local out = proxy[list]
        raid.terrain:query(list, x0, y0, x1, y1, function(rect)
            if rect.deco then proxy.decor[#proxy.decor + 1] = rect else out[#out + 1] = rect end
        end)
    end
    return proxy
end

local function hash(rect)
    return floor(rect.x * 7 + rect.y * 13) % 997
end

-- shades for grey(): trees and the like vary a little, cars and shipping
-- containers are mostly white and grey with now and then a red one
local TREE_SHADES = { 0.55, 0.65, 0.75, 0.6 }
local CAR_SHADES = { 0, 0.5, 1.3, 0.2, "red", 0.9 }
local CONTAINER_TINTS = { 0.4, 0.8, 1.2, "red" }

local function tint(shade)
    return shade == "red" and Kit.RED or grey(shade)
end

local function blob(cx, cy, r, sides, seed, jitter)
    local points = {}
    for k = 0, sides - 1 do
        local a = k / sides * 2 * pi
        local rr = r * (1 - jitter + jitter * (((seed * 31 + k * 17) % 13) / 12))
        points[#points + 1] = cx + cos(a) * rr
        points[#points + 1] = cy + sin(a) * rr
    end
    return points
end

local function tree(rect)
    local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2
    local r = math.max(rect.w, rect.h) * 0.95
    local h = hash(rect)
    local s = TREE_SHADES[h % #TREE_SHADES + 1]
    lg.setColor(T.wallShadow)
    lg.circle("fill", cx + 9, cy + 11, r)
    lg.setColor(grey(s + 0.45))
    lg.polygon("fill", blob(cx, cy, r, 9, h, 0.18))
    lg.setColor(grey(s))
    lg.polygon("fill", blob(cx - r * 0.12, cy - r * 0.14, r * 0.72, 8, h + 3, 0.2))
    lg.setColor(grey(s * 0.3))
    lg.circle("fill", cx - r * 0.28, cy - r * 0.3, r * 0.28)
end

local function rock(rect, big)
    local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2
    local r = math.max(rect.w, rect.h) * (big and 0.62 or 0.6)
    local h = hash(rect)
    lg.setColor(T.wallShadow)
    lg.polygon("fill", blob(cx + 6, cy + 8, r, 7, h, 0.3))
    local shade = 0.7 + (h % 5) * 0.1
    lg.setColor(grey(shade))
    lg.polygon("fill", blob(cx, cy, r, 7, h, 0.3))
    lg.setColor(grey(shade - 0.6))
    lg.polygon("fill", blob(cx - r * 0.18, cy - r * 0.2, r * 0.55, 6, h + 1, 0.25))
end

local function car(rect)
    local horizontal = rect.w >= rect.h
    local col = tint(CAR_SHADES[hash(rect) % #CAR_SHADES + 1])
    lg.push()
    lg.translate(rect.x + rect.w / 2, rect.y + rect.h / 2)
    if not horizontal then lg.rotate(pi / 2) end
    local l, w = math.max(rect.w, rect.h), math.min(rect.w, rect.h)
    lg.setColor(T.wallShadow)
    lg.rectangle("fill", -l / 2 + 4, -w / 2 + 5, l, w, 10, 10)
    lg.setColor(col)
    lg.rectangle("fill", -l / 2, -w / 2, l, w, 10, 10)
    local glass = mix(T.glassSide, T.pitRim, 0.55)
    lg.setColor(glass[1], glass[2], glass[3], 0.9)
    lg.rectangle("fill", -l * 0.18, -w / 2 + 4, l * 0.42, w - 8, 6, 6)
    lg.setColor(col[1] * 0.85, col[2] * 0.85, col[3] * 0.85)
    lg.rectangle("fill", -l * 0.08, -w / 2 + 6, l * 0.24, w - 12, 4, 4)
    lg.pop()
end

local function container(rect)
    local col = tint(CONTAINER_TINTS[hash(rect) % #CONTAINER_TINTS + 1])
    lg.setColor(T.wallShadow)
    lg.rectangle("fill", rect.x + 6, rect.y + 8, rect.w, rect.h)
    lg.setColor(col)
    lg.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 3, 3)
    lg.setColor(col[1] * 0.78, col[2] * 0.78, col[3] * 0.78)
    if rect.w >= rect.h then
        for x = rect.x + 10, rect.x + rect.w - 10, 14 do lg.rectangle("fill", x, rect.y + 4, 5, rect.h - 8) end
    else
        for y = rect.y + 10, rect.y + rect.h - 10, 14 do lg.rectangle("fill", rect.x + 4, y, rect.w - 8, 5) end
    end
end

local function strip(rect, base, line, step)
    lg.setColor(base)
    lg.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
    lg.setColor(line)
    local horizontal = rect.w >= rect.h
    local length = horizontal and rect.w or rect.h
    for k = 1, floor(length / step) do
        if horizontal then lg.line(rect.x + k * step, rect.y + 3, rect.x + k * step, rect.y + rect.h - 3)
        else lg.line(rect.x + 3, rect.y + k * step, rect.x + rect.w - 3, rect.y + k * step) end
    end
end

--- Trees, rocks and the like, drawn above the fog like walls: you always see the
--- land, the fog only hides who is there.
local function drawDecor(proxy)
    for _, lamp in ipairs(proxy.lamps) do lampPost(lamp) end
    for _, rect in ipairs(proxy.decor) do
        local deco = rect.deco
        if deco == "tree" then
            tree(rect)
        elseif deco == "rock" then
            rock(rect, false)
        elseif deco == "boulder" then
            rock(rect, true)
        elseif deco == "car" then
            car(rect)
        elseif deco == "container" then
            container(rect)
        elseif deco == "bale" then
            strip(rect, grey(0.2), grey(0.7), rect.w / 4)
        elseif deco == "sandbag" then
            strip(rect, grey(0.6), grey(1.1), 24)
        elseif deco == "shelf" then
            strip(rect, grey(0.9), grey(1.5), 40)
        else
            strip(rect, T.coverTop, T.coverSide, 1e9)
        end
    end
end

local function drawShadows(proxy)
    local ox, oy = -cos(Character.LIGHT) * 18, -sin(Character.LIGHT) * 18
    lg.setColor(T.wallShadow)
    for _, wall in ipairs(proxy.walls) do shadow(wall, ox, oy) end
    for _, door in ipairs(proxy.doors) do
        if not door.open then shadow(door, ox, oy) end
    end
    lg.setColor(T.wallShadow[1], T.wallShadow[2], T.wallShadow[3], T.wallShadow[4] * 0.6)
    for _, block in ipairs(proxy.cover) do shadow(block, ox * 0.4, oy * 0.4) end
end

local function drawContainers(raid, x0, y0, x1, y1)
    local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    raid:eachContainer(cx, cy, (x1 - x0) / 2, function(c)
        local color = containerColor(c.kind)
        local empty = raid.empty[c.id]
        local w, h = c.kind == "weapon_case" and 44 or 32, c.kind == "locker" and 36 or 24
        lg.setColor(0, 0, 0, 0.12)
        lg.rectangle("fill", c.x - w / 2 + 3, c.y - h / 2 + 4, w, h, 4, 4)
        lg.setColor(color[1], color[2], color[3], empty and 0.45 or 1)
        lg.rectangle("fill", c.x - w / 2, c.y - h / 2, w, h, 4, 4)
        lg.setColor(0, 0, 0, empty and 0.1 or 0.25)
        lg.rectangle("line", c.x - w / 2 + 0.5, c.y - h / 2 + 0.5, w - 1, h - 1, 4, 4)
        if not empty then
            lg.setColor(1, 1, 1, 0.5)
            lg.rectangle("fill", c.x - 4, c.y - 2, 8, 4, 1, 1)
        end
    end)
end

local function drawDrops(raid)
    local now = love.timer.getTime()
    for _, drop in ipairs(raid.drops) do
        local alpha = drop.e == 1 and 0.45 or 1
        if drop.k == "corpse" then
            lg.setColor(0.42, 0.44, 0.5, 0.85 * alpha)
            lg.ellipse("fill", drop.x, drop.y, 18, 11)
            lg.setColor(0.3, 0.32, 0.36, alpha)
            lg.circle("fill", drop.x + 14, drop.y - 3, 6)
            Kit.color(Kit.RED, 0.5 * alpha)
            lg.circle("fill", drop.x - 4, drop.y + 4, 9)
        elseif drop.k == "supply" or drop.k == "cache" then
            local pulse = 0.5 + 0.5 * sin(now * 4)
            Kit.color(Kit.AMBER, (0.15 + 0.15 * pulse) * alpha)
            lg.circle("fill", drop.x, drop.y, 60)
            local box = grey(1.2)
            lg.setColor(box[1], box[2], box[3], alpha)
            lg.rectangle("fill", drop.x - 28, drop.y - 22, 56, 44, 5, 5)
            Kit.color(Kit.AMBER, alpha)
            lg.rectangle("fill", drop.x - 28, drop.y - 4, 56, 8)
        else
            lg.setColor(0.38, 0.3, 0.32, 0.8 * alpha)
            lg.circle("fill", drop.x, drop.y, 12)
            lg.setColor(0.25, 0.2, 0.2, alpha)
            lg.circle("fill", drop.x + 5, drop.y - 4, 5)
        end
    end
end

local function drawGround(raid)
    local now = love.timer.getTime()
    for _, item in ipairs(raid.items) do
        local def = ItemConfig.all[item.d]
        if def then
            local c = Items.rarity({ r = item.r }).color
            lg.setColor(c[1], c[2], c[3], 0.25 + 0.1 * sin(now * 3 + item.i))
            lg.circle("fill", item.x, item.y, 16)
            if def.kind == "weapon" then
                Character.drawWeapon(def.look, item.x, item.y, (item.i % 6) * 0.5, 1)
            else
                lg.setColor(c[1], c[2], c[3], 1)
                lg.rectangle("fill", item.x - 6, item.y - 6, 12, 12, 3, 3)
                lg.setColor(1, 1, 1, 0.6)
                lg.rectangle("line", item.x - 6, item.y - 6, 12, 12, 3, 3)
            end
        end
    end
end

local function drawExtracts(raid)
    local now = love.timer.getTime()
    for _, e in ipairs(raid.extracts) do
        local ready = not e.r or e.r <= 0
        local c = ready and Kit.GREEN or Kit.AMBER
        local r = Config.extractRadius
        Kit.color(c, 0.12 + 0.05 * sin(now * 2))
        lg.circle("fill", e.x, e.y, r)
        Kit.color(c, 0.7)
        lg.setLineWidth(3)
        local spin = now * 0.6
        for k = 0, 7 do
            local a = spin + k * pi / 4
            lg.arc("line", "open", e.x, e.y, r, a, a + pi / 8)
        end
        lg.setLineWidth(1)
    end
end

-- Monsters are drawn like the players: the same faceted body, head and feet,
-- in their own colour, bigger or smaller, with their eyes as the accent.
local MONSTER_LOOKS = {
    crawler = { h = 2, a = 7 }, stalker = { h = 4, a = 8 }, brute = { h = 3, a = 6 },
    spitter = { h = 2, a = 7 }, sentinel = { h = 4, a = 5 }, warden = { h = 3, a = 2 }
}
local MONSTER_GUNS = { sentinel = "rifle", warden = "lmg" }
local monsterBodies = {}
local playerRadius = require("src.config.game").player.radius

--- @param m table interpolated monster
function Render.monster(m)
    local def = MonsterConfig[m.kind]
    if not def then return end
    local now = love.timer.getTime()
    local r = def.radius
    local body = monsterBodies[m.kind]
    if not body then
        -- the Warden in a dark crimson, so it never passes for an enemy player
        body = { body = m.kind == "warden" and { 0.34, 0.1, 0.14 } or def.color }
        monsterBodies[m.kind] = body
    end
    -- the interpolated monster carries what the character drawing reads
    local p = m
    p.slot = "monster" .. m.id
    p.weapon = MONSTER_GUNS[m.kind]
    p.look = MONSTER_LOOKS[m.kind]
    p.punch = m.swing and 0.6 or nil
    local k = r / playerRadius
    lg.push()
    lg.translate(m.x, m.y)
    lg.scale(k, k)
    lg.translate(-m.x, -m.y)
    Character.draw(p, body)
    lg.pop()
    if m.burn then
        Kit.color(Kit.AMBER, 0.6 + 0.3 * sin(now * 20))
        lg.circle("fill", m.x + sin(now * 9) * 4, m.y - r * 0.6, 4)
    end
    if m.chill then
        lg.setColor(0.6, 0.85, 1, 0.5)
        lg.circle("line", m.x, m.y, r + 4)
    end
    if m.hp < 100 then
        Kit.bar(m.x - r, m.y - r - 10, r * 2, 3, m.hp / 100, Kit.RED, 0.9)
    end
end

local function drawZones(raid)
    local now = love.timer.getTime()
    local fx = raid.fx
    for _, f in ipairs(fx.fi or {}) do
        for k = 0, 5 do
            local a = now * 2 + k
            Kit.color(Kit.AMBER, 0.18)
            lg.circle("fill", f.x + cos(a) * f.r * 0.4, f.y + sin(a * 1.3) * f.r * 0.4, f.r * 0.5)
        end
        Kit.color(Kit.RED, 0.15)
        lg.circle("fill", f.x, f.y, f.r)
    end
    for _, g in ipairs(fx.gs or {}) do
        lg.setColor(0.5, 0.72, 0.2, 0.22)
        lg.circle("fill", g.x, g.y, g.r)
        lg.setColor(0.5, 0.72, 0.2, 0.15)
        lg.circle("fill", g.x + sin(now) * 20, g.y + cos(now) * 20, g.r * 0.7)
    end
    for _, m in ipairs(fx.mn or {}) do
        lg.setColor(0.3, 0.32, 0.3, 1)
        lg.rectangle("fill", m.x - 10, m.y - 5, 20, 10, 2, 2)
        Kit.color(Kit.RED, 0.5 + 0.5 * sin(now * 6))
        lg.circle("fill", m.x, m.y, 2.5)
    end
    for _, p in ipairs(fx.pj or {}) do
        if p.k == "spit" then
            lg.setColor(0.6, 0.85, 0.2, 0.9)
            lg.circle("fill", p.x, p.y, 6)
        else
            lg.setColor(0.25, 0.28, 0.24, 1)
            lg.circle("fill", p.x, p.y, 5)
        end
    end
end

local function drawSmokes(raid)
    for _, s in ipairs(raid.terrain.smokes or {}) do
        lg.setColor(T.background[1] * 0.9, T.background[2] * 0.9, T.background[3] * 0.9, 0.9)
        lg.circle("fill", s.x, s.y, s.r)
    end
end

local function drawBooms(raid)
    local now = love.timer.getTime()
    for k = #raid.booms, 1, -1 do
        local b = raid.booms[k]
        local t = (now - b.time) / 0.5
        if t > 1 then
            table.remove(raid.booms, k)
        else
            local colors = { blast = Kit.AMBER, flash = { 1, 1, 0.9 }, fire = Kit.RED, cryo = { 0.6, 0.85, 1 }, arc = { 0.6, 0.8, 1 }, death = { 0.5, 0.2, 0.2 }, spit = { 0.6, 0.85, 0.2 } }
            local c = colors[b.k] or Kit.AMBER
            lg.setColor(c[1], c[2], c[3], (1 - t) * 0.6)
            lg.circle("fill", b.x, b.y, max(8, b.r) * (0.4 + 0.6 * t))
            lg.setColor(c[1], c[2], c[3], (1 - t))
            lg.setLineWidth(3)
            lg.circle("line", b.x, b.y, max(10, b.r) * (0.5 + 0.7 * t))
            lg.setLineWidth(1)
        end
    end
end

local fadeMeshes = {}

local function fadeMesh(range)
    local key = floor(range)
    if fadeMeshes[key] then return fadeMeshes[key] end
    local inner, outer = range * GameConfig.vision.fade, range + 2
    local vertices = {}
    for k = 0, 96 do
        local a = k / 96 * 2 * pi
        vertices[#vertices + 1] = { cos(a) * inner, sin(a) * inner, 0, 0, 1, 1, 1, 0 }
        vertices[#vertices + 1] = { cos(a) * outer, sin(a) * outer, 0, 0, 1, 1, 1, 1 }
    end
    fadeMeshes[key] = lg.newMesh(vertices, "strip", "static")
    return fadeMeshes[key]
end

--- The fog of war: what the player cannot see is greyed out.
local function drawFog(raid, me, x0, y0, x1, y1)
    local range = me.range or Config.vision.range
    lg.stencil(function()
        if me.dead > 0 or (raid.me.blind or 0) > 0 then return end
        local cone, near = Vision.fans(raid.terrain, me.x, me.y, me.angle, range)
        for k = 3, #cone - 3, 2 do
            lg.polygon("fill", cone[1], cone[2], cone[k], cone[k + 1], cone[k + 2], cone[k + 3])
        end
        for k = 3, #near - 3, 2 do
            lg.polygon("fill", near[1], near[2], near[k], near[k + 1], near[k + 2], near[k + 3])
        end
        if me.thermal then
            lg.circle("fill", me.x, me.y, me.thermal)
        end
    end, "replace", 1)
    lg.setStencilTest("equal", 0)
    lg.setColor(T.fog)
    lg.rectangle("fill", x0, y0, x1 - x0, y1 - y0)
    if me.dead == 0 then
        lg.setStencilTest("equal", 1)
        lg.setColor(T.fog)
        lg.draw(fadeMesh(range), me.x, me.y)
    end
    lg.setStencilTest()
end

local function palette()
    return Character.PALETTES.opponent
end

--- @param ext table the extraction module
function Render.draw(ext)
    local raid, camera = ext.raid, ext.camera
    lg.clear(T.background)
    local me = raid:view()
    local players, monsters = raid:interpolated()
    local x0, y0, x1, y1 = Render.bounds(camera)
    camera:apply()
    drawFloor(raid, x0, y0, x1, y1)
    local proxy = nearby(raid, x0, y0, x1, y1)
    drawShadows(proxy)
    drawExtracts(raid)
    drawContainers(raid, x0, y0, x1, y1)
    drawDrops(raid)
    drawGround(raid)
    drawZones(raid)
    for _, p in ipairs(players) do
        if p.dead == 0 then
            p.weapon = ItemConfig.all[p.weapon or ""] and ItemConfig.all[p.weapon].look or nil
            Character.draw(p, palette(p))
        end
    end
    for _, m in ipairs(monsters) do Render.monster(m) end
    drawFog(raid, me, x0, y0, x1, y1)
    drawLampLights(proxy.lamps)
    for _, p in ipairs(players) do
        if p.marked then
            Kit.color(Kit.RED, 0.8)
            lg.circle("line", p.x, p.y, 20)
        end
    end
    for _, m in ipairs(monsters) do
        if m.marked then
            Kit.color(Kit.RED, 0.8)
            lg.circle("line", m.x, m.y, MonsterConfig[m.kind].radius + 6)
        end
    end
    drawSmokes(raid)
    ext.effects:drawWorld()
    drawBooms(raid)
    drawDecor(proxy)
    Renderer.drawWalls(proxy, camera)
    ext.effects:drawImpacts()
    if me.dead == 0 then
        Character.draw(me, Renderer.selfPalette())
    end
    camera:clear()
    for _, p in ipairs(players) do
        if p.dead == 0 and p.name then
            local sx, sy = camera:toScreen(p.x, p.y)
            Kit.text(p.name, 14, sx - 100, sy - 30 * camera.scale - 18, Kit.RED, 0.85, "center", 200)
        end
    end
    for _, e in ipairs(raid.extracts) do
        local sx, sy = camera:toScreen(e.x, e.y)
        local W, H = lg.getDimensions()
        if sx > -50 and sx < W + 50 and sy > -50 and sy < H + 50 then
            local label = e.n .. ((e.r and e.r > 0) and string.format(" (%d s)", math.ceil(e.r / 60)) or "")
            Kit.text(label, 14, sx - 120, sy - 12, Kit.GREEN, 0.9, "center", 240)
        end
    end
end

return Render
