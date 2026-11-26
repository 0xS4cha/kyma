--- The raid HUD: health, armor, weapon and ammo, quick slots, statuses, prompts,
--- extraction progress, event banners, the kill feed, the minimap and the full map.
local GM = require("src.core.index")
local Kit = require("src.ui.kit")
local Keys = require("src.input.keybinds")
local Icons = require("src.modules.extraction.icons")
local Items = require("src.game.extraction.items")
local Inventory = require("src.game.extraction.inventory")
local Worldgen = require("src.game.extraction.worldgen")
local Loot = require("src.game.extraction.loot")
local Events = require("src.game.extraction.events")
local ItemConfig = require("src.config.items")
local Config = require("src.config.extraction")
local GameConfig = require("src.config.game")

local Hud = {}

local lg = love.graphics
local floor, min, max, pi, cos, sin = math.floor, math.min, math.max, math.pi, math.cos, math.sin

local MAP_SIZE = 1024
local MARGIN = 24
local maps = {}

--- A picture of the whole world, drawn once per seed.
--- @param def table
--- @return love.Canvas
function Hud.mapCanvas(def)
    if maps[def.seed] then return maps[def.seed] end
    local canvas = lg.newCanvas(MAP_SIZE, MAP_SIZE)
    local s = MAP_SIZE / def.width
    lg.push("all")
    lg.setCanvas(canvas)
    lg.clear(0.5, 0.5, 0.48, 1)
    lg.scale(s, s)
    for k, chunk in ipairs(def.chunks) do
        local cx, cy = (k - 1) % def.count, floor((k - 1) / def.count)
        local c = Worldgen.BIOMES[chunk.biome].color
        -- darker and redder the deeper the danger, like the ground in the world
        local d = (chunk.tier - 1) / 3
        local red = Kit.RED
        lg.setColor(c[1] * (1 - 0.3 * d) + red[1] * 0.2 * d, c[2] * (1 - 0.3 * d) + red[2] * 0.2 * d, c[3] * (1 - 0.3 * d) + red[3] * 0.2 * d)
        lg.rectangle("fill", cx * def.chunk, cy * def.chunk, def.chunk + 1, def.chunk + 1)
    end
    lg.setColor(0.6, 0.63, 0.68)
    lg.setLineWidth(260)
    for _, r in ipairs(def.roads) do
        lg.line(r[1], r[2], r[3], r[4])
        lg.circle("fill", r[1], r[2], 130)
    end
    lg.setLineWidth(1)
    lg.setColor(0.5, 0.6, 0.72)
    for _, pit in ipairs(def.pits) do lg.rectangle("fill", pit.x, pit.y, pit.w, pit.h) end
    lg.setColor(0.24, 0.25, 0.28)
    for _, wall in ipairs(def.walls) do lg.rectangle("fill", wall.x, wall.y, max(wall.w, 30), max(wall.h, 30)) end
    lg.setColor(0.5, 0.53, 0.58)
    for _, cover in ipairs(def.cover) do lg.rectangle("fill", cover.x, cover.y, max(cover.w, 30), max(cover.h, 30)) end
    lg.pop()
    maps[def.seed] = canvas
    return canvas
end

local EVENT_COLORS = { airdrop = Kit.AMBER, horde = Kit.RED, boss = { 0.62, 0.12, 0.16 }, rift = { 0.6, 0.3, 0.9 }, heli = Kit.GREEN }

--- Draws markers (extracts, events, you) on a map transform.
local function markers(raid, toMap, scale)
    local now = love.timer.getTime()
    for _, e in ipairs(raid.extracts) do
        local x, y = toMap(e.x, e.y)
        Kit.color((e.r and e.r > 0) and Kit.AMBER or Kit.GREEN, 1)
        lg.circle("fill", x, y, 5)
        lg.setColor(1, 1, 1, 0.9)
        lg.circle("line", x, y, 6)
        if scale > 0.5 then Kit.text(e.n, 11, x - 60, y + 7, Kit.INK, 0.9, "center", 120) end
    end
    for _, ev in ipairs(raid.events) do
        local x, y = toMap(ev.x, ev.y)
        local c = EVENT_COLORS[ev.k] or Kit.AMBER
        local pulse = 0.5 + 0.5 * sin(now * 4)
        lg.setColor(c[1], c[2], c[3], 0.3 + 0.3 * pulse)
        lg.circle("fill", x, y, 10 + pulse * 6)
        lg.setColor(c[1], c[2], c[3], 1)
        lg.circle("fill", x, y, 5)
        if scale > 0.5 then Kit.text(Events.KINDS[ev.k].name, 12, x - 70, y - 24, Kit.INK, 1, "center", 140) end
    end
end

--- A triangle pointing along a screen angle, with its points computed directly.
local function pointer(x, y, angle, length)
    local ca, sa = cos(angle), sin(angle)
    local function at(f, side)
        return x + ca * length * f - sa * length * side, y + sa * length * f + ca * length * side
    end
    local tx, ty = at(1, 0)
    local lx, ly = at(-0.75, 0.5)
    local nx, ny = at(-0.35, 0)
    local rx, ry = at(-0.75, -0.5)
    lg.polygon("fill", tx, ty, lx, ly, nx, ny)
    lg.polygon("fill", tx, ty, nx, ny, rx, ry)
end

Hud.pointer = pointer

local function arrow(x, y, angle, size)
    Kit.color(Kit.RED, 1)
    lg.polygon("fill", x + cos(angle) * size, y + sin(angle) * size,
        x + cos(angle + 2.5) * size * 0.7, y + sin(angle + 2.5) * size * 0.7,
        x + cos(angle - 2.5) * size * 0.7, y + sin(angle - 2.5) * size * 0.7)
end

-- The minimap is the duel modes' one: a card in the corner chosen in
-- Settings > Mini-map, with its size, opacity and rotation. The world is far
-- too big to show whole, so it always follows you.
local MAP_BASE_W, MAP_BASE_H = 240, 170
local MAP_SIZE_FACTOR = { 0.6, 0.8, 1, 1.3, 1.65 }
local MAP_SPANS = { 7200, 4800, 3000 }
local MAP_PAD = 8
local CARD_H = 112
local QUICK_H = 66 + 12
local PILL_H = 36

local function mapOptions()
    local Settings = require("src.modules.menu.settings")
    return (GM.Menu and GM.Menu.settings) or Settings.defaults(), Settings
end

--- Where the minimap card sits, nil when it is turned off.
--- @return number? x, number? y, number? w, number? h
function Hud.mapBox()
    local opt = mapOptions()
    if opt.minimap == false then return nil end
    local f = MAP_SIZE_FACTOR[opt.minimapSize] or 1
    local w, h = MAP_BASE_W * f + MAP_PAD * 2, MAP_BASE_H * f + MAP_PAD * 2
    local W, H = lg.getDimensions()
    local pos = opt.minimapPos or 1
    local left = pos == 1 or pos == 2
    local top = pos == 1 or pos == 3
    local x = left and MARGIN or (W - MARGIN - w)
    local y
    if top then
        -- on the left it pushes the status pill aside, on the right it sits under the ping
        y = left and MARGIN or MARGIN + 30 + 10
    else
        y = H - MARGIN - CARD_H - 12 - h
        if not left then y = y - QUICK_H end
    end
    return x, y, w, h
end

--- How far the top left status has to move right to clear the minimap.
function Hud.leftShift()
    local x, y, w = Hud.mapBox()
    if not x or x > MARGIN + 1 or y > lg.getHeight() / 2 then return 0 end
    return w + 16
end

function Hud.minimap(ext)
    local raid, camera = ext.raid, ext.camera
    local x, y, w, h = Hud.mapBox()
    if not x then return end
    local opt, Settings = mapOptions()
    local alpha = Settings.MAP_OPACITY[opt.minimapOpacity] or 1
    local mw, mh = w - MAP_PAD * 2, h - MAP_PAD * 2
    local ox, oy = x + MAP_PAD, y + MAP_PAD
    local cx, cy = ox + mw / 2, oy + mh / 2
    local canvas = Hud.mapCanvas(raid.def)
    local me = raid:view()
    local span = MAP_SPANS[opt.minimapZoom] or 4800
    local s = mw / span
    local px = MAP_SIZE / raid.def.width
    -- like the duel modes: north up, or turned so you always face up
    local rotation = opt.minimapRotate and camera:rotation() or 0
    Kit.card(x, y, w, h, alpha, 10)
    lg.setScissor(ox, oy, mw, mh)
    lg.setColor(1, 1, 1, alpha)
    lg.push()
    lg.translate(cx, cy)
    lg.rotate(rotation)
    lg.scale(s / px, s / px)
    lg.translate(-me.x * px, -me.y * px)
    lg.draw(canvas)
    lg.pop()
    local c, sn = cos(rotation), sin(rotation)
    markers(raid, function(wx, wy)
        local dx, dy = (wx - me.x) * s, (wy - me.y) * s
        return cx + dx * c - dy * sn, cy + dx * sn + dy * c
    end, 0.4)
    lg.setScissor()
    -- you, as the arrow of the duel modes
    local a = rotation + me.angle
    local ca, sa = cos(a), sin(a)
    Kit.color(Kit.INK, alpha)
    lg.polygon("fill", cx + ca * 7, cy + sa * 7, cx - ca * 4.2 - sa * 4.9, cy - sa * 4.2 + ca * 4.9, cx - ca * 4.2 + sa * 4.9, cy - sa * 4.2 - ca * 4.9)
    if opt.minimapRotate then
        -- a turned map needs to say where north is
        local na = rotation - pi / 2
        local r = min(mw, mh) / 2 - 10
        local nx, ny = cx + cos(na) * r, cy + sin(na) * r
        Kit.dot(nx, ny, 8, Kit.RED, alpha)
        Kit.text("N", 10, nx - 10, ny - 7, { 1, 1, 1 }, alpha, "center", 20)
    end
end

--- The status pill of the duel modes, top left: where you are and how
--- dangerous it is, then the keys of the inventory and the map.
function Hud.status(ext)
    local raid = ext.raid
    local me = raid:view()
    local chunk = Worldgen.chunkAt(raid.def, me.x, me.y)
    local label = Worldgen.BIOMES[chunk.biome].name .. "  -  danger " .. chunk.tier
    local x = MARGIN + Hud.leftShift()
    local w = Kit.font(16):getWidth(label) + 46
    Kit.card(x, MARGIN, w, PILL_H, 1, 18)
    Kit.dot(x + 20, MARGIN + 18, 5, chunk.tier >= 3 and Kit.RED or Kit.AMBER, 1)
    Kit.text(label, 16, x + 34, MARGIN + 8, Kit.INK, 1)
    local hint = { Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.6 }
    Kit.hint(Keys.label("inventory"), "Inventory", x, MARGIN + 46, 0.75, 14, hint)
    local hw = Kit.measureHint(Keys.label("inventory"), "Inventory", 14)
    Kit.hint(Keys.label("map"), "Map", x + hw + 18, MARGIN + 46, 0.75, 14, hint)
    local ping = GM.Multiplayer and GM.Multiplayer:Ping()
    if ping then
        local W = lg.getWidth()
        local quality = ping < 60 and Kit.GREEN or ping < 130 and Kit.AMBER or Kit.RED
        local str = floor(ping) .. " ms"
        local pw = Kit.font(14):getWidth(str) + 40
        Kit.card(W - MARGIN - pw, MARGIN, pw, 30, 1, 15)
        Kit.dot(W - MARGIN - pw + 16, MARGIN + 15, 4, quality, 1)
        Kit.text(str, 14, W - MARGIN - pw + 28, MARGIN + 7, Kit.INK, 0.8)
    end
end

local function wrap(a)
    return (a + pi) % (2 * pi) - pi
end

local CARDINALS = { { 0, "N" }, { 45, "NE" }, { 90, "E" }, { 135, "SE" }, { 180, "S" }, { 225, "SW" }, { 270, "W" }, { 315, "NW" } }

--- A heading tape across the top: where you face, the cardinal points, and the
--- extractions and events on the bearing where they lie.
function Hud.compass(ext, nearest, nearestD)
    local raid, camera = ext.raid, ext.camera
    local W = lg.getWidth()
    local w, h = 560, 40
    local x, y = W / 2 - w / 2, 14
    local span = math.rad(80)
    local perRad = (w / 2) / span
    local rotation = camera:rotation()
    Kit.card(x, y, w, h, 1)
    lg.setScissor(x + 8, y, w - 16, h + 30)
    -- the screen angle of a world direction, 0 straight ahead
    local function at(screen)
        local d = wrap(screen + pi / 2)
        if math.abs(d) > span then return nil end
        return W / 2 + d * perRad, 1 - math.abs(d) / span
    end
    for deg = 0, 345, 15 do
        local world = math.rad(deg) - pi / 2
        local sx, fade = at(world + rotation)
        if sx then
            local cardinal
            for _, c in ipairs(CARDINALS) do if c[1] == deg then cardinal = c[2] end end
            if cardinal then
                local big = #cardinal == 1
                Kit.text(cardinal, big and 15 or 12, sx - 20, y + (big and 11 or 13), deg == 0 and Kit.RED or Kit.INK, (big and 0.95 or 0.6) * (0.35 + 0.65 * fade), "center", 40)
            else
                lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.3 * (0.3 + 0.7 * fade))
                lg.rectangle("fill", sx - 0.5, y + h - 12, 1, 7)
            end
        end
    end
    local function mark(wx, wy, color, size)
        local a = Hud.bearing(ext, wx, wy)
        local sx, fade = at(a)
        if not sx then return end
        Kit.dot(sx, y + 8, size * 0.7, color, 0.5 + 0.5 * fade)
    end
    for _, ev in ipairs(raid.events) do mark(ev.x, ev.y, EVENT_COLORS[ev.k] or Kit.AMBER, 5) end
    -- the three closest extractions only, like the arrows on the edges
    local me = raid:view()
    local list = {}
    for _, e in ipairs(raid.extracts) do list[#list + 1] = { e = e, d = (e.x - me.x) ^ 2 + (e.y - me.y) ^ 2 } end
    table.sort(list, function(a, b) return a.d < b.d end)
    for k = 1, math.min(3, #list) do
        local e = list[k].e
        mark(e.x, e.y, (e.r and e.r > 0) and Kit.AMBER or Kit.GREEN, e == nearest and 7 or 5)
    end
    lg.setScissor()
    -- where you face
    Kit.color(Kit.RED, 1)
    lg.polygon("fill", W / 2 - 6, y + h, W / 2 + 6, y + h, W / 2, y + h - 7)
    local heading = floor(math.deg(-rotation) % 360 + 0.5) % 360
    Kit.text(string.format("%03d", heading), 11, W / 2 - 20, y + h + 3, Kit.INK, 0.55, "center", 40)
    if nearest then
        local text = nearest.n .. "  ·  " .. floor(nearestD / 10) .. " m"
        local tw = Kit.font(13):getWidth(text)
        Kit.dot(W / 2 - tw / 2 - 10, y + h + 27, 4, Kit.GREEN, 1)
        Kit.text(text, 13, W / 2 - tw / 2, y + h + 19, Kit.INK, 0.7)
    end
end

--- Screen angle and distance of a world point from the player.
local function bearing(ext, wx, wy)
    local camera, me = ext.camera, ext.raid:view()
    local sx, sy = camera:toScreen(wx, wy)
    local px, py = camera:toScreen(me.x, me.y)
    return math.atan2(sy - py, sx - px), math.sqrt((wx - me.x) ^ 2 + (wy - me.y) ^ 2), sx, sy, px, py
end

Hud.bearing = bearing

--- Arrows on the screen edge for extraction points and events out of view.
local function edgeMarkers(ext)
    local raid = ext.raid
    local W, H = lg.getDimensions()
    -- kept clear of the compass at the top and the panels at the bottom
    local margin, top, bottom = 70, 140, 240
    local function marker(wx, wy, color, label)
        local a, d, sx, sy, px, py = bearing(ext, wx, wy)
        if sx > margin and sx < W - margin and sy > top and sy < H - bottom then return end
        local ca, sa = cos(a), sin(a)
        local t = math.huge
        if ca > 0 then t = math.min(t, (W - margin - px) / ca) elseif ca < 0 then t = math.min(t, (margin - px) / ca) end
        if sa > 0 then t = math.min(t, (H - bottom - py) / sa) elseif sa < 0 then t = math.min(t, (top - py) / sa) end
        local ex, ey = px + ca * t, py + sa * t
        local text = label .. "  " .. floor(d / 10) .. " m"
        local tw = Kit.font(12):getWidth(text) + 14
        local lx = math.max(8, math.min(W - tw - 8, ex - ca * 30 - tw / 2))
        local ly = math.max(top - 30, math.min(H - bottom + 6, ey - sa * 30 - 10))
        -- not under the minimap
        local bx, by, bw, bh = Hud.mapBox()
        if bx and lx + tw > bx and lx < bx + bw and ly + 22 > by and ly < by + bh then
            ly = by < H / 2 and by + bh + 8 or by - 30
            ey = by < H / 2 and math.max(ey, by + bh + 30) or math.min(ey, by - 8)
        end
        lg.setColor(color[1], color[2], color[3], 0.95)
        pointer(ex, ey, a, 16)
        Kit.card(lx, ly, tw, 22, 0.92, 8)
        Kit.text(text, 12, lx + 7, ly + 3, color, 1)
    end
    -- Only the three closest extractions, or the screen fills with arrows.
    local me = raid:view()
    local list = {}
    for _, e in ipairs(raid.extracts) do list[#list + 1] = { e = e, d = (e.x - me.x) ^ 2 + (e.y - me.y) ^ 2 } end
    table.sort(list, function(a, b) return a.d < b.d end)
    for k = 1, math.min(3, #list) do
        local e = list[k].e
        marker(e.x, e.y, (e.r and e.r > 0) and Kit.AMBER or Kit.GREEN, e.n)
    end
    for _, ev in ipairs(raid.events) do marker(ev.x, ev.y, EVENT_COLORS[ev.k] or Kit.AMBER, Events.KINDS[ev.k].name) end
end

--- The full screen map.
function Hud.map(ext)
    local raid = ext.raid
    local W, H = lg.getDimensions()
    lg.setColor(Kit.PAPER[1], Kit.PAPER[2], Kit.PAPER[3], 0.92)
    lg.rectangle("fill", 0, 0, W, H)
    local size = min(W, H) - 80
    local zoom = ext.mapZoom or 1
    local me = raid:view()
    local canvas = Hud.mapCanvas(raid.def)
    local s = size / raid.def.width * zoom
    local cx, cy = W / 2, H / 2
    local ox, oy
    if zoom > 1 then
        ox, oy = cx - me.x * s, cy - me.y * s
    else
        ox, oy = cx - size / 2, cy - size / 2
    end
    local function toMap(wx, wy) return ox + wx * s, oy + wy * s end
    local mx0, my0 = (W - size) / 2, (H - size) / 2
    lg.setScissor(mx0, my0, size, size)
    lg.setColor(1, 1, 1, 1)
    lg.draw(canvas, ox, oy, 0, s * raid.def.width / MAP_SIZE)
    markers(raid, toMap, 1)
    local px, py = toMap(me.x, me.y)
    arrow(px, py, me.angle, 12)
    lg.setScissor()
    Kit.text("Map   ·   wheel to zoom   ·   " .. Keys.label("map") .. " to close", 14, 0, my0 - 26, Kit.INK, 0.7, "center", W)
    local legend = {}
    for _, id in ipairs({ "forest", "field", "highlands", "lake", "town", "industrial", "military", "citadel" }) do legend[#legend + 1] = id end
    local lx = mx0 + size + 16
    if lx + 140 < W then
        for k, id in ipairs(legend) do
            local c = Worldgen.BIOMES[id].color
            lg.setColor(c)
            lg.rectangle("fill", lx, my0 + (k - 1) * 24, 16, 16, 3, 3)
            Kit.text(Worldgen.BIOMES[id].name, 13, lx + 24, my0 + (k - 1) * 24, Kit.INK, 0.8)
        end
        Kit.text("The centre is the most dangerous, and the richest.", 12, lx, my0 + #legend * 24 + 10, Kit.INK, 0.6, "left", 150)
    end
end

local function bar(x, y, w, h, value, color, label)
    lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.12)
    lg.rectangle("fill", x, y, w, h, h / 2, h / 2)
    Kit.color(color, 0.95)
    lg.rectangle("fill", x, y, max(h, w * max(0, min(1, value))), h, h / 2, h / 2)
    if label then Kit.text(label, 12, x + 8, y + h / 2 - 8, { 1, 1, 1 }, 1) end
end

local SHIELD = require("src.modules.session.shield").COLOR

--- Health like in the duel modes, with the vest and helmet wear under it as
--- thin shield bars, and statuses as small cards above.
function Hud.vitals(ext, view, own, now)
    local me = ext.raid.me
    local H = lg.getHeight()
    local w, h = 300, 112
    local x, y = MARGIN, H - MARGIN - h
    Kit.card(x, y, w, h, 1)
    local hp = max(0, me.hp)
    local low = me.hp <= 34
    Kit.text("Health", 13, x + 18, y + 14, Kit.INK, 0.5)
    Kit.text(tostring(math.ceil(hp - 0.01)), 30, x + w - 18, y + 6, low and Kit.RED or Kit.INK, 1, "right")
    local pulse = low and me.hp > 0 and (0.75 + 0.25 * sin(now * 8)) or 1
    Kit.bar(x + 18, y + 44, w - 36, 10, hp / GameConfig.health, low and Kit.RED or Kit.INK, pulse)
    for k, slot in ipairs({ "vest", "helmet" }) do
        local inst = view and view.g[slot]
        local ry = y + 64 + (k - 1) * 22
        if inst then
            local stats = Items.armorStats(inst)
            Kit.text(Items.name(inst), 12, x + 18, ry, Kit.INK, 0.5)
            Kit.bar(x + 120, ry + 5, w - 138, 6, (inst.u or 0) / stats.durability, SHIELD, 1)
        else
            Kit.text("No " .. slot, 12, x + 18, ry, Kit.INK, 0.3)
        end
    end
    local fx = own.fx or {}
    local statuses = {}
    if fx.b then statuses[#statuses + 1] = { "Burning", Kit.AMBER } end
    if fx.p then statuses[#statuses + 1] = { "Poisoned", Kit.GREEN } end
    if fx.c then statuses[#statuses + 1] = { "Frozen", Kit.ALLY } end
    if fx.h then statuses[#statuses + 1] = { "Stim " .. math.ceil(fx.h / 60), Kit.RED } end
    if fx.f then statuses[#statuses + 1] = { "Fortified " .. math.ceil(fx.f / 60), Kit.ALLY } end
    if fx.r then statuses[#statuses + 1] = { "Rush " .. math.ceil(fx.r / 60), Kit.AMBER } end
    local sx = x
    for _, status in ipairs(statuses) do
        local sw = Kit.font(12):getWidth(status[1]) + 20
        Kit.card(sx, y - 32, sw, 24, 1, 12)
        Kit.text(status[1], 12, sx + 10, y - 27, status[2], 1)
        sx = sx + sw + 6
    end
end

--- The weapon card of the duel modes: its name, the ammo in big digits, the
--- magazine as pips and a reload ring. The quick slots and the other weapon sit
--- in a card above, like the gadget card.
function Hud.weapon(ext, view)
    local me = ext.raid.me
    local W, H = lg.getDimensions()
    local w, h = 300, 112
    local x, y = W - MARGIN - w, H - MARGIN - h
    Kit.card(x, y, w, h, 1)
    local held = view.hd == "secondary" and 2 or 1
    local inst = view.g[held == 2 and "secondary" or "primary"]
    local other = view.g[held == 2 and "primary" or "secondary"]
    if not inst or not me.def then
        Kit.text("Unarmed", 22, x + 18, y + 16, Kit.INK, 0.9)
        Kit.text("Pick up a weapon to fight", 13, x + 18, y + 48, Kit.INK, 0.5)
    else
        local r = Items.rarity(inst)
        Kit.text(Items.name(inst), 13, x + 18, y + 14, Kit.INK, 0.5)
        Kit.text(r.name, 11, x + w - 18, y + 16, r.color, 0.9, "right")
        local empty = me.ammo == 0
        local aw = Kit.text(tostring(me.ammo), 34, x + 18, y + 30, empty and Kit.RED or Kit.INK, 1)
        Kit.text("/ " .. me.reserve, 16, x + 26 + aw, y + 46, Kit.INK, me.reserve == 0 and 0.3 or 0.5)
        local count = me.def.magazine or me.ammo
        local area = w - 36
        local gap = count > 12 and 2 or 4
        local pw = min(10, (area - gap * (count - 1)) / max(1, count))
        for k = 1, count do
            lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], k <= me.ammo and 1 or 0.12)
            lg.rectangle("fill", x + 18 + (k - 1) * (pw + gap), y + 86, pw, 12, 2, 2)
        end
        if me.reload > 0 then
            Kit.ring(x + w - 40, y + 46, 18, 1 - me.reload / (me.def.reloadTicks or 60), 4, Kit.INK, 1)
            Kit.text("Reloading", 13, x + w - 68, y + 14, Kit.INK, 0.6, "right")
        elseif empty and me.reserve == 0 then
            Kit.text("Out of ammo", 13, x + w - 18, y + 46, Kit.RED, 1, "right")
        end
    end
    -- quick slots and the other weapon
    local qh = 66
    local qy = y - 12 - qh
    Kit.card(x, qy, w, qh, 1)
    local places = ext.raid.places
    for k = 1, Config.quickSlots do
        local sx = x + 14 + (k - 1) * 46
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.05)
        lg.rectangle("fill", sx, qy + 12, 40, 42, 8, 8)
        local uid = view.g.quick[k]
        local loc = places and uid and uid ~= 0 and Inventory.locate(places, uid)
        if loc then Icons.draw(loc.inst, sx, qy + 12, 40, 42) end
        Kit.keycap(Keys.label("quick" .. k), sx + 2, qy + 36, 0.8, 10)
    end
    local ox = x + 14 + Config.quickSlots * 46 + 6
    local ow = x + w - 14 - ox
    lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.05)
    lg.rectangle("fill", ox, qy + 12, ow, 42, 8, 8)
    if other then Icons.draw(other, ox, qy + 12, ow, 42, 0.5) end
    Kit.keycap(Keys.label("weapon" .. (3 - held)), ox + ow - 22, qy + 16, 0.6, 10)
end

--- The banner of the duel modes: a card with a big title and a line under it.
function Hud.bannerCard(title, subtitle, color, t, life)
    local a = min(1, t / 0.2) * min(1, (life - t) / 0.4)
    if a <= 0 then return end
    local W, H = lg.getDimensions()
    local w = 520
    local x, y = (W - w) / 2, H * 0.24 + (1 - Kit.easeOutCubic(min(1, t / 0.3))) * 16
    Kit.card(x, y, w, 92, a, 18)
    Kit.text(title, 30, x, y + 14, color or Kit.INK, a, "center", w)
    Kit.text(subtitle or "", 15, x, y + 58, Kit.INK, 0.65 * a, "center", w)
end

--- When you arrive in the world: where you are and how dangerous it is.
function Hud.intro(ext, now)
    local start = ext.introAt
    if not start then return end
    local t = now - start
    local life = 4
    if t > life then ext.introAt = nil return end
    local raid = ext.raid
    local chunk = Worldgen.chunkAt(raid.def, raid.me.x, raid.me.y)
    Hud.bannerCard(Worldgen.BIOMES[chunk.biome].name, "Danger " .. chunk.tier .. " of 4  -  loot what you can, then reach an extraction",
        chunk.tier >= 3 and Kit.RED or Kit.INK, t, life)
end

--- @param ext table
function Hud.draw(ext)
    local raid = ext.raid
    local W, H = lg.getDimensions()
    local me = raid.me
    local own = raid.own or {}
    local view = raid.inventory
    local now = love.timer.getTime()

    -- Health and armor
    Hud.vitals(ext, view, own, now)
    -- Weapon and quick slots
    if view then Hud.weapon(ext, view) end

    -- Using an item
    if own.ut then
        local ticks, total, id = own.ut[1], own.ut[2], own.ut[3]
        local w = 260
        bar(W / 2 - w / 2, H * 0.62, w, 14, 1 - ticks / total, Kit.GREEN)
        Kit.text("Using " .. (ItemConfig.all[id] and ItemConfig.all[id].name or ""), 14, 0, H * 0.62 + 18, Kit.INK, 0.8, "center", W)
    end

    -- Extraction progress: the respawn ring of the duel modes, in a card
    if own.ex then
        local t = min(1, own.ex / Config.extractTicks)
        local w, h = 220, 132
        local x, y = (W - w) / 2, H * 0.2
        Kit.card(x, y, w, h, 1, 18)
        Kit.ring(W / 2, y + 48, 26, t, 5, Kit.GREEN, 1)
        Kit.text(tostring(math.ceil((Config.extractTicks - own.ex) / 60)), 22, W / 2 - 40, y + 35, Kit.INK, 1, "center", 80)
        Kit.text("Extracting", 15, x, y + 86, Kit.GREEN, 1, "center", w)
        Kit.text("Stay in the zone", 12, x, y + 106, Kit.INK, 0.5, "center", w)
    end

    -- Prompt
    local prompt
    local target = raid:interactable()
    if raid.inventory and raid.inventory.ct then
        prompt = { Keys.label("inventory"), "Loot " .. raid.inventory.ct.n }
    elseif target then
        local name = target.name or (Loot.containers[target.kind] and Loot.containers[target.kind].name) or "Container"
        if target.kind == "corpse" then name = "Body of " .. (target.name or "?") end
        prompt = { Keys.label("pickup"), "Open " .. name }
    end
    local item = raid:nearbyItem()
    if item and ItemConfig.all[item.d] then
        local r = Items.rarity({ r = item.r })
        local label = ItemConfig.all[item.d].name
        Kit.hint(Keys.label("pickup"), "Pick up " .. label, W / 2 - 100, H * 0.68 + 40, 1, 14, r.color)
    elseif prompt then
        Kit.hint(prompt[1], prompt[2], W / 2 - 100, H * 0.68 + 40, 1, 14)
    end

    -- Nearest extraction, with a compass arrow pointing at it on screen.
    local best, bestD
    for _, e in ipairs(raid.extracts) do
        local d = math.sqrt((e.x - me.x) ^ 2 + (e.y - me.y) ^ 2)
        if (not e.r or e.r <= 0) and (not bestD or d < bestD) then best, bestD = e, d end
    end
    if not ext.showMap then Hud.compass(ext, best, bestD) end
    if not ext.showInventory and not ext.showMap then edgeMarkers(ext) end

    if not ext.showMap and not ext.showInventory then Hud.minimap(ext) end

    -- Damage direction: a red arc on the side the hit came from.
    for k = #ext.hurts, 1, -1 do
        local hurt = ext.hurts[k]
        local t = (now - hurt.time) / 1.2
        if t > 1 then
            table.remove(ext.hurts, k)
        elseif hurt.x then
            local a, _, _, _, px, py = bearing(ext, hurt.x, hurt.y)
            Kit.color(Kit.RED, 0.75 * (1 - t))
            lg.setLineWidth(8)
            lg.arc("line", "open", px, py, 90, a - 0.35, a + 0.35)
            lg.setLineWidth(1)
            pointer(px + cos(a) * 110, py + sin(a) * 110, a, 14)
        end
    end

    -- Kill feed and banners
    local fy = 240
    for k = #ext.feed, 1, -1 do
        local entry = ext.feed[k]
        local age = now - entry.time
        if age > 8 then
            table.remove(ext.feed, k)
        else
            local text = entry.k .. "  ›  " .. entry.v
            Kit.text(text, 13, (W - 420) + (400), fy, entry.m and Kit.INK or Kit.RED, 0.8 * min(1, 8 - age), "right")
            fy = fy + 20
        end
    end
    local banner = ext.banner
    if banner and now - banner.time < 4 then
        Hud.bannerCard(banner.title, banner.text, banner.color, now - banner.time, 4)
    end
    local ty = H * 0.3
    for k = #ext.toasts, 1, -1 do
        local toast = ext.toasts[k]
        if now - toast.time > 3 then
            table.remove(ext.toasts, k)
        else
            Kit.text(toast.text, 15, 0, ty, Kit.RED, min(1, (3 - (now - toast.time)) * 2), "center", W)
            ty = ty + 22
        end
    end

    -- Hit marker
    if now - (ext.hitAt or -10) < 0.2 then
        local cx, cy = W / 2, H * 0.68
        Kit.color(ext.killAt and now - ext.killAt < 0.3 and Kit.RED or Kit.INK, 1)
        lg.setLineWidth(2)
        for _, a in ipairs({ pi / 4, 3 * pi / 4, 5 * pi / 4, 7 * pi / 4 }) do
            lg.line(cx + cos(a) * 8, cy + sin(a) * 8, cx + cos(a) * 16, cy + sin(a) * 16)
        end
        lg.setLineWidth(1)
    end

    if (me.blind or 0) > 0 then
        lg.setColor(1, 1, 1, min(1, me.blind / 60))
        lg.rectangle("fill", 0, 0, W, H)
    end

    if me.dead > 0 then
        ext.diedAt = ext.diedAt or now
        local a = min(1, (now - ext.diedAt) * 3)
        local t = Kit.easeOutBack(a)
        lg.setColor(Kit.PAPER[1], Kit.PAPER[2], Kit.PAPER[3], 0.55 * a)
        lg.rectangle("fill", 0, 0, W, H)
        local y = H * 0.3 + (1 - t) * 20
        Kit.text("Eliminated", 48, 0, y, Kit.RED, a, "center", W)
        Kit.text("Your gear stays on your body for others to loot", 16, 0, y + 80, Kit.INK, 0.65 * a, "center", W)
        if ext.killer then
            local w = 320
            local kx, ky = (W - w) / 2, y + 130
            Kit.card(kx, ky, w, 52, a, 16)
            local nw = Kit.text("Killed by", 13, kx + 20, ky + 17, Kit.INK, 0.5 * a)
            Kit.text(ext.killer, 15, kx + 28 + nw, ky + 15, Kit.RED, a)
        end
    else
        ext.diedAt = nil
    end

    Hud.intro(ext, now)

    if not ext.showMap and not ext.showInventory then Hud.status(ext) end
end

return Hud
