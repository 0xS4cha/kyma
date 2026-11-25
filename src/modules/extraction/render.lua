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
local Assets = require("src.modules.extraction.assets")
local Icons = require("src.modules.extraction.icons")

local Render = {}

local lg = love.graphics
local cos, sin, floor, min, max, pi = math.cos, math.sin, math.floor, math.min, math.max, math.pi
local T = Theme.colors

local CONTAINER_COLORS = {
    crate = { 0.6, 0.46, 0.3 }, locker = { 0.46, 0.5, 0.56 }, cabinet = { 0.56, 0.44, 0.34 }, fridge = { 0.82, 0.84, 0.86 },
    drawer = { 0.5, 0.4, 0.32 }, medbox = { 0.9, 0.9, 0.9 }, toolbox = { 0.78, 0.3, 0.2 }, weapon_case = { 0.3, 0.34, 0.3 },
    ammo_crate = { 0.4, 0.44, 0.3 }, stash = { 0.42, 0.36, 0.26 }
}

--- The world box that covers the screen around the camera.
--- @return number, number, number, number
function Render.bounds(camera)
    local W, H = lg.getDimensions()
    local reach = math.sqrt((W * 0.5) ^ 2 + (H * 0.7) ^ 2) / camera.scale + 120
    return camera.x - reach, camera.y - reach, camera.x + reach, camera.y + reach
end

local function mix(a, b, t)
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

local FLOOR_TILE = { wood = Assets.GROUND.wood, planks = Assets.GROUND.planks, concrete = Assets.GROUND.concrete, tiles = Assets.GROUND.tiles }

local function drawFloor(raid, x0, y0, x1, y1)
    local def = raid.def
    local chunk = def.chunk
    local road = Config.road
    local bx0, by0 = math.max(0, x0), math.max(0, y0)
    local bx1, by1 = math.min(def.width, x1), math.min(def.height, y1)
    lg.setColor(1, 1, 1, 1)
    if not Assets.fill(Assets.GROUND.road, bx0, by0, bx1 - bx0, by1 - by0, 1) then
        lg.setColor(0.29, 0.29, 0.29)
        lg.rectangle("fill", bx0, by0, bx1 - bx0, by1 - by0)
    end
    for cy = math.max(0, floor(y0 / chunk)), math.min(def.count - 1, floor(y1 / chunk)) do
        for cx = math.max(0, floor(x0 / chunk)), math.min(def.count - 1, floor(x1 / chunk)) do
            local info = def.chunks[cy * def.count + cx + 1]
            local gx, gy, gs = cx * chunk + road, cy * chunk + road, chunk - road * 2
            lg.setColor(0.6, 0.6, 0.6, 1)
            lg.rectangle("fill", gx - 6, gy - 6, gs + 12, gs + 12, 8, 8)
            local tint = info.tier >= 4 and { 0.9, 0.84, 0.84 } or (info.tier == 3 and { 0.95, 0.93, 0.9 } or { 1, 1, 1 })
            lg.setColor(tint[1], tint[2], tint[3], 1)
            if not Assets.fill(Assets.GROUND[info.biome] or 1, gx, gy, gs, gs, 1.5) then
                local color = Worldgen.BIOMES[info.biome].color
                lg.setColor(color)
                lg.rectangle("fill", gx, gy, gs, gs)
            end
        end
    end
    -- Dashed centre lines on the roads.
    lg.setColor(0.98, 0.82, 0.2, 0.8)
    for cx = math.max(1, floor(x0 / chunk)), math.min(def.count - 1, floor(x1 / chunk) + 1) do
        local x = cx * chunk
        for y = math.max(0, floor(y0 / 120) * 120), by1, 120 do lg.rectangle("fill", x - 3, y, 6, 60) end
    end
    for cy = math.max(1, floor(y0 / chunk)), math.min(def.count - 1, floor(y1 / chunk) + 1) do
        local y = cy * chunk
        for x = math.max(0, floor(x0 / 120) * 120), bx1, 120 do lg.rectangle("fill", x, y - 3, 60, 6) end
    end
    raid.terrain:query("floors", x0, y0, x1, y1, function(f)
        lg.setColor(1, 1, 1, 1)
        if not Assets.fill(FLOOR_TILE[f.kind] or Assets.GROUND.wood, f.x, f.y, f.w, f.h, 0.75) then
            lg.setColor(0.7, 0.6, 0.48)
            lg.rectangle("fill", f.x, f.y, f.w, f.h)
        end
    end)
    raid.terrain:query("pits", x0, y0, x1, y1, function(pit)
        lg.setColor(0.86, 0.8, 0.62)
        lg.rectangle("fill", pit.x - 10, pit.y - 10, pit.w + 20, pit.h + 20, 14, 14)
    end)
    raid.terrain:query("pits", x0, y0, x1, y1, function(pit)
        lg.setColor(1, 1, 1, 1)
        if not Assets.fill(Assets.GROUND.water, pit.x, pit.y, pit.w, pit.h, 1.5) then
            lg.setColor(0.36, 0.5, 0.62)
            lg.rectangle("fill", pit.x, pit.y, pit.w, pit.h)
        end
    end)
end

local function shadow(rect, ox, oy)
    lg.polygon("fill",
        rect.x, rect.y, rect.x + rect.w, rect.y, rect.x + rect.w + ox, rect.y + oy,
        rect.x + rect.w + ox, rect.y + rect.h + oy, rect.x + ox, rect.y + rect.h + oy, rect.x, rect.y + rect.h)
end

--- The rectangles near the view, as a small arena for the session renderer.
--- The rectangles near the view: plain ones as a small arena for the session
--- renderer, decorated ones (trees, rocks, cars...) apart, drawn as sprites.
local function nearby(raid, x0, y0, x1, y1)
    local proxy = { walls = {}, doors = {}, glass = {}, cover = {}, decor = {} }
    for _, list in ipairs({ "walls", "doors", "glass", "cover" }) do
        local out = proxy[list]
        raid.terrain:query(list, x0, y0, x1, y1, function(rect)
            if rect.deco then proxy.decor[#proxy.decor + 1] = rect else out[#out + 1] = rect end
        end)
    end
    return proxy
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

local TREES = { 183, 183, 186, 181 }
local ROCKS = { 237, 238, 239 }
local CAR_COLORS = { { 0.85, 0.24, 0.2 }, { 0.2, 0.45, 0.8 }, { 0.92, 0.78, 0.2 }, { 0.3, 0.62, 0.38 }, { 0.85, 0.86, 0.88 }, { 0.25, 0.26, 0.3 } }
local CONTAINER_COLORS = { { 0.8, 0.36, 0.18 }, { 0.2, 0.46, 0.62 }, { 0.36, 0.52, 0.3 }, { 0.7, 0.18, 0.16 } }

local function hash(rect)
    return floor(rect.x * 7 + rect.y * 13) % 997
end

local function car(rect)
    local horizontal = rect.w >= rect.h
    local col = CAR_COLORS[hash(rect) % #CAR_COLORS + 1]
    lg.push()
    lg.translate(rect.x + rect.w / 2, rect.y + rect.h / 2)
    if not horizontal then lg.rotate(pi / 2) end
    local l, w = math.max(rect.w, rect.h), math.min(rect.w, rect.h)
    lg.setColor(0, 0, 0, 0.2)
    lg.rectangle("fill", -l / 2 + 4, -w / 2 + 5, l, w, 10, 10)
    lg.setColor(col)
    lg.rectangle("fill", -l / 2, -w / 2, l, w, 10, 10)
    lg.setColor(0.2, 0.26, 0.32, 0.9)
    lg.rectangle("fill", -l * 0.18, -w / 2 + 4, l * 0.42, w - 8, 6, 6)
    lg.setColor(col[1] * 0.85, col[2] * 0.85, col[3] * 0.85)
    lg.rectangle("fill", -l * 0.08, -w / 2 + 6, l * 0.24, w - 12, 4, 4)
    lg.setColor(1, 0.95, 0.7, 0.9)
    lg.rectangle("fill", l / 2 - 5, -w / 2 + 4, 3, 7)
    lg.rectangle("fill", l / 2 - 5, w / 2 - 11, 3, 7)
    lg.pop()
end

local function container(rect)
    local col = CONTAINER_COLORS[hash(rect) % #CONTAINER_COLORS + 1]
    lg.setColor(0, 0, 0, 0.22)
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

--- Trees and rocks are drawn above the fog like walls: you always see the land, the
--- fog only hides who is there.
local function drawDecor(proxy)
    for _, rect in ipairs(proxy.decor) do
        local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2
        local size = math.max(rect.w, rect.h)
        local deco = rect.deco
        if deco == "tree" then
            lg.setColor(0, 0, 0, 0.16)
            lg.circle("fill", cx + 10, cy + 12, size * 0.95)
            lg.setColor(1, 1, 1, 1)
            Assets.centered(Assets.tile(TREES[hash(rect) % #TREES + 1]), cx, cy, size * 2.2, (hash(rect) % 4) * pi / 2)
        elseif deco == "rock" then
            lg.setColor(1, 1, 1, 1)
            Assets.centered(Assets.tile(ROCKS[hash(rect) % #ROCKS + 1]), cx, cy, size * 1.35, (hash(rect) % 8) * pi / 4)
        elseif deco == "car" then
            car(rect)
        elseif deco == "container" then
            container(rect)
        elseif deco == "bale" then
            lg.setColor(0, 0, 0, 0.18)
            lg.rectangle("fill", rect.x + 4, rect.y + 6, rect.w, rect.h, 6, 6)
            lg.setColor(0.86, 0.74, 0.36)
            lg.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
            lg.setColor(0.72, 0.6, 0.26)
            for k = 1, 3 do lg.line(rect.x + rect.w * k / 4, rect.y + 3, rect.x + rect.w * k / 4, rect.y + rect.h - 3) end
        elseif deco == "furniture" then
            lg.setColor(1, 1, 1, 1)
            local horizontal = rect.w >= rect.h
            local tile = (hash(rect) % 2 == 0) and 453 or 448
            Assets.stretch(tile, rect.x, rect.y, rect.w, rect.h, horizontal and 0 or nil)
        elseif deco == "sandbag" then
            lg.setColor(0.66, 0.6, 0.44)
            lg.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
            lg.setColor(0.56, 0.5, 0.34)
            local horizontal = rect.w >= rect.h
            local length = horizontal and rect.w or rect.h
            for k = 1, floor(length / 24) do
                if horizontal then lg.line(rect.x + k * 24, rect.y + 3, rect.x + k * 24, rect.y + rect.h - 3)
                else lg.line(rect.x + 3, rect.y + k * 24, rect.x + rect.w - 3, rect.y + k * 24) end
            end
        elseif deco == "shelf" then
            lg.setColor(0.55, 0.42, 0.3)
            lg.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 3, 3)
            lg.setColor(0.45, 0.33, 0.22)
            local horizontal = rect.w >= rect.h
            local length = horizontal and rect.w or rect.h
            for k = 0, floor(length / 40) - 1 do
                local p = (k + 0.5) * 40 - 12
                if horizontal then Assets.stretch(130, rect.x + p, rect.y + 2, 24, rect.h - 4)
                else Assets.stretch(130, rect.x + 2, rect.y + p, rect.w - 4, 24) end
            end
        end
    end
end

local CONTAINER_LOOK = {
    crate = { 129 }, ammo_crate = { 129, { 0.7, 0.78, 0.6 } }, weapon_case = { 156, { 0.55, 0.62, 0.5 } }, stash = { 130 },
    toolbox = { 130, { 1, 0.6, 0.5 } }, locker = { 157, { 0.7, 0.76, 0.85 } }, cabinet = { 157 }, drawer = { 130, { 0.85, 0.75, 0.65 } },
    fridge = { 321 }, medbox = { "medkit" }
}

local function drawContainers(raid, x0, y0, x1, y1)
    local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    raid:eachContainer(cx, cy, (x1 - x0) / 2, function(c)
        local look = CONTAINER_LOOK[c.kind] or CONTAINER_LOOK.crate
        local empty = raid.empty[c.id]
        local size = c.kind == "weapon_case" and 46 or (c.kind == "drawer" and 30 or 38)
        lg.setColor(0, 0, 0, 0.2)
        lg.rectangle("fill", c.x - size / 2 + 4, c.y - size / 2 + 5, size, size, 4, 4)
        local tint = look[2] or { 1, 1, 1 }
        local a = empty and 0.5 or 1
        lg.setColor(tint[1] * (empty and 0.7 or 1), tint[2] * (empty and 0.7 or 1), tint[3] * (empty and 0.7 or 1), a)
        if look[1] == "medkit" then
            Assets.centered(Assets.item("medkit"), c.x, c.y, size)
        else
            Assets.centered(Assets.tile(look[1]), c.x, c.y, size * 1.3)
        end
        if not empty then
            local pulse = 0.5 + 0.5 * sin(love.timer.getTime() * 3 + c.id)
            lg.setColor(1, 0.86, 0.4, 0.25 + 0.25 * pulse)
            lg.setLineWidth(2)
            lg.rectangle("line", c.x - size / 2 - 3, c.y - size / 2 - 3, size + 6, size + 6, 6, 6)
            lg.setLineWidth(1)
        end
    end)
end

local function drawDrops(raid)
    local now = love.timer.getTime()
    for _, drop in ipairs(raid.drops) do
        local alpha = drop.e == 1 and 0.55 or 1
        if drop.k == "corpse" then
            lg.setColor(0.55, 0.06, 0.06, 0.75 * alpha)
            Assets.centered(Assets.tile(320), drop.x, drop.y, 70, drop.i)
            Assets.drawCharacter(Assets.setOf(drop.i), nil, drop.x, drop.y, drop.i * 1.7, 34, false, { 0.62, 0.62, 0.66 }, alpha)
        elseif drop.k == "supply" or drop.k == "cache" then
            local pulse = 0.5 + 0.5 * sin(now * 4)
            Kit.color(Kit.AMBER, (0.12 + 0.12 * pulse) * alpha)
            lg.circle("fill", drop.x, drop.y, 70)
            lg.setColor(1, 1, 1, alpha)
            Assets.centered(Assets.tile(129), drop.x, drop.y, 78)
            Kit.color(drop.k == "supply" and Kit.AMBER or Kit.RED, alpha)
            lg.rectangle("fill", drop.x - 30, drop.y - 5, 60, 10)
        else
            lg.setColor(0.45, 0.12, 0.1, 0.7 * alpha)
            Assets.centered(Assets.tile(319), drop.x, drop.y, 54, drop.i)
            lg.setColor(1, 1, 1, alpha)
            Assets.centered(Assets.tile(262 + drop.i % 4), drop.x, drop.y, 30, drop.i)
        end
    end
end

local function drawGround(raid)
    local now = love.timer.getTime()
    for _, item in ipairs(raid.items) do
        local def = ItemConfig.all[item.d]
        if def then
            local col = Items.rarity({ r = item.r }).color
            lg.setColor(col[1], col[2], col[3], 0.22 + 0.12 * sin(now * 3 + item.i))
            lg.circle("fill", item.x, item.y, 20)
            lg.setColor(col[1], col[2], col[3], 0.9)
            lg.setLineWidth(2)
            lg.circle("line", item.x, item.y, 20)
            lg.setLineWidth(1)
            local w = def.kind == "weapon" and 46 or 26
            Icons.picture(def, item.x, item.y, w, def.kind == "weapon" and 22 or 26, 1)
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

-- Monsters are Kenney's zombie and robot, tinted and scaled per kind.
local MONSTER_LOOK = {
    crawler = { set = "zoimbie1", tint = { 0.8, 0.95, 0.75 }, scale = 2.3, pose = "hold" },
    stalker = { set = "zoimbie1", tint = { 0.45, 0.38, 0.55 }, scale = 2.4, pose = "hold" },
    brute = { set = "zoimbie1", tint = { 1, 0.7, 0.62 }, scale = 2.1, pose = "hold" },
    spitter = { set = "zoimbie1", tint = { 0.7, 1, 0.45 }, scale = 2.4, pose = "hold" },
    sentinel = { set = "robot1", tint = { 0.85, 0.9, 1 }, scale = 2.3, look = "rifle" },
    warden = { set = "robot1", tint = { 1, 0.45, 0.45 }, scale = 2.0, look = "lmg" }
}

--- @param m table interpolated monster
function Render.monster(m)
    local def = MonsterConfig[m.kind]
    if not def then return end
    local now = love.timer.getTime()
    local look = MONSTER_LOOK[m.kind] or MONSTER_LOOK.crawler
    local r = def.radius
    local lunge = m.swing and 6 or 0
    local x, y = m.x + cos(m.angle) * lunge, m.y + sin(m.angle) * lunge
    if m.kind == "warden" then
        lg.setColor(0.9, 0.1, 0.1, 0.18 + 0.08 * sin(now * 4))
        lg.circle("fill", x, y, r * 1.8)
    end
    local ok = Assets.drawCharacter(look.set, look.look, x, y, m.angle, r * look.scale, false, look.tint)
    if not ok then
        lg.setColor(def.color)
        lg.circle("fill", x, y, r)
    end
    if m.burn then
        Kit.color(Kit.AMBER, 0.6 + 0.3 * sin(now * 20))
        lg.circle("fill", m.x + sin(now * 9) * 4, m.y - r * 0.6, 4)
    end
    if m.chill then
        lg.setColor(0.6, 0.85, 1, 0.6)
        lg.setLineWidth(2)
        lg.circle("line", m.x, m.y, r + 5)
        lg.setLineWidth(1)
    end
end

--- Health bars of hurt monsters, in screen space so they stay level.
local function monsterBars(camera, monsters)
    for _, m in ipairs(monsters) do
        if m.hp < 100 then
            local def = MonsterConfig[m.kind]
            local sx, sy = camera:toScreen(m.x, m.y)
            local w = math.max(30, def.radius * 2.4 * camera.scale * 0.6)
            local top = sy - def.radius * camera.scale - 16
            lg.setColor(0, 0, 0, 0.4)
            lg.rectangle("fill", sx - w / 2 - 1, top - 1, w + 2, 6, 3, 3)
            Kit.color(def.boss and Kit.AMBER or Kit.RED, 1)
            lg.rectangle("fill", sx - w / 2, top, w * m.hp / 100, 4, 2, 2)
            if def.boss then Kit.text(def.name, 13, sx - 80, top - 18, Kit.RED, 1, "center", 160) end
        end
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
            local def = ItemConfig.all[p.weapon or ""]
            Assets.drawCharacter(Assets.setOf(p.slot), def and def.look, p.x, p.y, p.angle, 34, false, nil, 1)
        end
    end
    for _, m in ipairs(monsters) do Render.monster(m) end
    drawFog(raid, me, x0, y0, x1, y1)
    for _, p in ipairs(players) do
        if p.marked then
            Kit.color(Kit.RED, 0.8)
            lg.circle("line", p.x, p.y, 22)
        end
    end
    for _, m in ipairs(monsters) do
        if m.marked then
            Kit.color(Kit.RED, 0.8)
            lg.circle("line", m.x, m.y, MonsterConfig[m.kind].radius + 8)
        end
    end
    drawSmokes(raid)
    ext.effects:drawWorld()
    drawBooms(raid)
    drawDecor(proxy)
    Renderer.drawWalls(proxy, camera)
    ext.effects:drawImpacts()
    if me.dead == 0 then
        Assets.drawCharacter(Assets.setOf(raid.slot), me.weapon, me.x, me.y, me.angle, 34, (raid.me.reload or 0) > 0)
    end
    camera:clear()
    monsterBars(camera, monsters)
    for _, p in ipairs(players) do
        if p.dead == 0 and p.name then
            local sx, sy = camera:toScreen(p.x, p.y)
            Kit.text(p.name, 13, sx - 100, sy - 30 * camera.scale - 18, Kit.RED, 0.9, "center", 200)
        end
    end
    local W, H = lg.getDimensions()
    for _, e in ipairs(raid.extracts) do
        local sx, sy = camera:toScreen(e.x, e.y)
        if sx > -50 and sx < W + 50 and sy > -50 and sy < H + 50 then
            local label = e.n .. ((e.r and e.r > 0) and string.format(" (%d s)", math.ceil(e.r / 60)) or "")
            Kit.text(label, 14, sx - 120, sy - 12, Kit.GREEN, 0.95, "center", 240)
        end
    end
end

return Render
