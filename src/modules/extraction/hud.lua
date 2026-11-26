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
        local danger = (chunk.tier - 1) * 0.04
        lg.setColor(c[1] - danger, c[2] - danger * 1.4, c[3] - danger * 1.4)
        lg.rectangle("fill", cx * def.chunk, cy * def.chunk, def.chunk + 1, def.chunk + 1)
    end
    lg.setColor(0.42, 0.42, 0.44)
    lg.setLineWidth(260)
    for _, r in ipairs(def.roads) do
        lg.line(r[1], r[2], r[3], r[4])
        lg.circle("fill", r[1], r[2], 130)
    end
    lg.setLineWidth(1)
    lg.setColor(0.3, 0.42, 0.56)
    for _, pit in ipairs(def.pits) do lg.rectangle("fill", pit.x, pit.y, pit.w, pit.h) end
    lg.setColor(0.24, 0.25, 0.28)
    for _, wall in ipairs(def.walls) do lg.rectangle("fill", wall.x, wall.y, max(wall.w, 30), max(wall.h, 30)) end
    lg.setColor(0.42, 0.4, 0.38)
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

--- The minimap in the top right corner. It turns with the camera, so what is
--- ahead of you on screen is ahead of you on the minimap too.
function Hud.minimap(ext)
    local raid, camera = ext.raid, ext.camera
    local W = lg.getWidth()
    local size = 200
    local x, y = W - size - 20, 20
    local cx, cy = x + size / 2, y + size / 2
    local canvas = Hud.mapCanvas(raid.def)
    local reach = 2400
    local me = raid:view()
    local s = size / (reach * 2)
    local px = MAP_SIZE / raid.def.width
    local rotation = camera:rotation()
    Kit.card(x - 6, y - 6, size + 12, size + 12, 0.96, size / 2 + 6)
    lg.stencil(function() lg.circle("fill", cx, cy, size / 2) end, "replace", 1)
    lg.setStencilTest("equal", 1)
    lg.setColor(1, 1, 1, 1)
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
    lg.setStencilTest()
    lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.25)
    lg.setLineWidth(2)
    lg.circle("line", cx, cy, size / 2)
    lg.setLineWidth(1)
    -- North marker on the rim.
    local na = rotation - pi / 2
    local nx, ny = cx + cos(na) * (size / 2 - 10), cy + sin(na) * (size / 2 - 10)
    Kit.color(Kit.RED, 1)
    lg.circle("fill", nx, ny, 9)
    Kit.text("N", 11, nx - 10, ny - 7, { 1, 1, 1 }, 1, "center", 20)
    arrow(cx, cy, -pi / 2, 9)
    local chunk = Worldgen.chunkAt(raid.def, me.x, me.y)
    local name = Worldgen.BIOMES[chunk.biome].name
    local nw = Kit.font(12):getWidth(name)
    local total = nw + 14 + 4 * 14
    local lx = x + (size - total) / 2
    Kit.text(name, 12, lx, y + size + 12, Kit.INK, 0.75)
    Hud.danger(lx + nw + 14, y + size + 15, chunk.tier, 1)
end

--- Danger as four pips, red the deeper you are.
function Hud.danger(x, y, tier, alpha)
    for k = 1, 4 do
        if k <= tier then Kit.color(Kit.RED, (0.45 + 0.15 * k) * alpha) else lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.15 * alpha) end
        lg.rectangle("fill", x + (k - 1) * 14, y, 10, 10, 2, 2)
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
    Kit.card(x, y, w, h, 0.94, 12)
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
        lg.setColor(color[1], color[2], color[3], 0.5 + 0.5 * fade)
        lg.polygon("fill", sx, y + 3, sx + size, y + 3 + size, sx, y + 3 + size * 2, sx - size, y + 3 + size)
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
        Kit.color(Kit.GREEN, 1)
        lg.circle("fill", W / 2 - tw / 2 - 10, y + h + 27, 4)
        Kit.text(text, 13, W / 2 - tw / 2, y + h + 19, Kit.INK, 0.85)
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
    local margin, top, bottom = 70, 140, 170
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
        -- not under the minimap in the top right corner
        if lx + tw > W - 250 and ly < 270 then
            ly = 270
            if ey < 270 then ey = 290 end
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

local HP_SEGMENTS = 10

--- Health as a big number and a segmented bar, armor durability under it,
--- statuses as chips above. Low health pulses the screen edges red.
function Hud.vitals(ext, view, own, now)
    local me = ext.raid.me
    local W, H = lg.getDimensions()
    local x, y, w = 24, H - 118, 320
    local hp = max(0, me.hp)
    local share = hp / GameConfig.health
    local low = me.hp > 0 and me.hp <= 35
    if low then
        local pulse = 0.5 + 0.5 * sin(now * 5)
        Hud.edgeGlow(Kit.RED, 0.18 + 0.14 * pulse)
    end
    Kit.card(x - 8, y - 12, w, 106, 0.94, 14)
    local color = low and Kit.RED or Kit.INK
    local nw = Kit.text(tostring(math.ceil(hp)), 34, x + 2, y - 6, color, 1)
    Kit.text("HP", 12, x + 8 + nw, y + 14, Kit.INK, 0.5)
    local bx, bw = x + nw + 40, w - nw - 56
    local seg = (bw - (HP_SEGMENTS - 1) * 3) / HP_SEGMENTS
    for k = 1, HP_SEGMENTS do
        local fill = Kit.clamp(share * HP_SEGMENTS - (k - 1), 0, 1)
        local sx = bx + (k - 1) * (seg + 3)
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.1)
        lg.rectangle("fill", sx, y + 8, seg, 14, 3, 3)
        if fill > 0 then
            Kit.color(low and Kit.RED or Kit.GREEN, 0.95)
            lg.rectangle("fill", sx, y + 8, seg * fill, 14, 3, 3)
        end
    end
    if view then
        for k, slot in ipairs({ "vest", "helmet" }) do
            local inst = view.g[slot]
            local ax = x + (k - 1) * 154
            if not inst then
                Kit.text("No " .. slot, 11, ax, y + 52, Kit.INK, 0.35)
            else
                local stats = Items.armorStats(inst)
                local r = Items.rarity(inst)
                Kit.color(r.color, 1)
                lg.rectangle("fill", ax, y + 40, 3, 28, 1.5, 1.5)
                Kit.text(Items.name(inst), 11, ax + 9, y + 38, Kit.INK, 0.7)
                bar(ax + 9, y + 56, 136, 8, (inst.u or 0) / stats.durability, Kit.ALLY)
            end
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
    local sx = x - 8
    for _, status in ipairs(statuses) do
        local sw = Kit.font(12):getWidth(status[1]) + 18
        Kit.color(status[2], 0.9)
        lg.rectangle("fill", sx, y - 42, sw, 22, 11, 11)
        Kit.text(status[1], 12, sx, y - 38, { 1, 1, 1 }, 1, "center", sw)
        sx = sx + sw + 6
    end
end

--- The weapon in hand with its rarity, the ammo in big digits, a reload bar,
--- the other weapon and the quick slots.
function Hud.weapon(ext, view)
    local me = ext.raid.me
    local W, H = lg.getDimensions()
    local bx, by = W - 404, H - 130
    Kit.card(bx - 8, by - 12, 388, 118, 0.94, 14)
    local hands = { "primary", "secondary" }
    local held = view.hd == "secondary" and 2 or 1
    local inst = view.g[hands[held]]
    local other = view.g[hands[3 - held]]
    if inst then
        local r = Items.rarity(inst)
        Kit.color(r.color, 1)
        lg.rectangle("fill", bx, by + 2, 3, 46, 1.5, 1.5)
        Icons.draw(inst, bx + 10, by, 120, 50, 1)
        Kit.text(Items.name(inst), 13, bx + 140, by + 4, Kit.INK, 0.9)
        Kit.text(r.name, 11, bx + 140, by + 22, r.color, 1)
    else
        Kit.text("Fists", 16, bx + 10, by + 14, Kit.INK, 0.7)
    end
    Kit.keycap(Keys.label("weapon" .. held), bx + 140, by + 38, 0.8, 10)
    -- the other weapon, small, with its key
    local ox = bx + 262
    lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.05)
    lg.rectangle("fill", ox, by, 110, 48, 8, 8)
    if other then Icons.draw(other, ox + 4, by + 2, 80, 44, 0.45) end
    Kit.keycap(Keys.label("weapon" .. (3 - held)), ox + 86, by + 14, 0.5, 10)
    if me.def then
        if me.reload > 0 then
            local total = me.def.reloadTicks or 60
            Kit.text("Reloading", 15, bx + 10, by + 62, Kit.AMBER, 1)
            bar(bx + 10, by + 86, 130, 6, 1 - me.reload / total, Kit.AMBER)
        else
            local aw = Kit.text(tostring(me.ammo), 34, bx + 8, by + 52, me.ammo == 0 and Kit.RED or Kit.INK, 1)
            Kit.text("/ " .. me.reserve, 15, bx + 14 + aw, by + 70, Kit.INK, 0.5)
        end
    end
    local places = ext.raid.places
    for k = 1, Config.quickSlots do
        local qx = bx + 182 + (k - 1) * 48
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.06)
        lg.rectangle("fill", qx, by + 56, 42, 42, 6, 6)
        local uid = view.g.quick[k]
        local loc = places and uid and uid ~= 0 and Inventory.locate(places, uid)
        if loc then Icons.draw(loc.inst, qx, by + 56, 42, 42) end
        Kit.keycap(Keys.label("quick" .. k), qx + 2, by + 80, 0.8, 10)
    end
end

--- A soft glow on the screen edges.
function Hud.edgeGlow(color, alpha)
    local W, H = lg.getDimensions()
    local steps, depth = 10, 90
    for k = 1, steps do
        local d = depth * k / steps
        lg.setColor(color[1], color[2], color[3], alpha * (1 - k / steps) * 0.35)
        lg.setLineWidth(depth / steps + 1)
        lg.rectangle("line", d / 2, d / 2, W - d, H - d)
    end
    lg.setLineWidth(1)
end

--- The title card when you arrive in the world: where you are and how deep.
function Hud.intro(ext, now)
    local start = ext.introAt
    if not start then return end
    local t = now - start
    if t > 4.5 then ext.introAt = nil return end
    local raid = ext.raid
    local W, H = lg.getDimensions()
    local a = min(1, t * 2.5) * min(1, (4.5 - t) * 1.5)
    local rise = (1 - min(1, t * 2)) * 16
    local chunk = Worldgen.chunkAt(raid.def, raid.me.x, raid.me.y)
    local y = H * 0.36 + rise
    Kit.text("THE WILDS", 13, 0, y, Kit.RED, a, "center", W)
    Kit.color(Kit.RED, a)
    local line = 140 * min(1, t * 1.5)
    lg.rectangle("fill", W / 2 - line / 2, y + 22, line, 2)
    Kit.text(Worldgen.BIOMES[chunk.biome].name, 44, 0, y + 32, Kit.INK, a, "center", W)
    local label = "Danger"
    local lw = Kit.font(12):getWidth(label)
    local total = lw + 12 + 4 * 14
    Kit.text(label, 12, W / 2 - total / 2, y + 92, Kit.INK, 0.6 * a)
    Hud.danger(W / 2 - total / 2 + lw + 12, y + 95, chunk.tier, a)
    Kit.text("Loot what you can, then reach an extraction", 14, 0, y + 118, Kit.INK, 0.6 * a, "center", W)
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

    -- Extraction progress: a ring that closes, the seconds left inside it
    if own.ex then
        local t = min(1, own.ex / Config.extractTicks)
        local cx, cy, r = W / 2, H * 0.26, 46
        local pulse = 0.5 + 0.5 * sin(now * 6)
        lg.setColor(Kit.PAPER[1], Kit.PAPER[2], Kit.PAPER[3], 0.92)
        lg.circle("fill", cx, cy, r + 12)
        lg.setColor(Kit.GREEN[1], Kit.GREEN[2], Kit.GREEN[3], 0.15)
        lg.setLineWidth(8)
        lg.circle("line", cx, cy, r)
        Kit.color(Kit.GREEN, 1)
        lg.arc("line", "open", cx, cy, r, -pi / 2, -pi / 2 + t * 2 * pi, 64)
        lg.setLineWidth(2)
        lg.setColor(Kit.GREEN[1], Kit.GREEN[2], Kit.GREEN[3], 0.25 * pulse)
        lg.circle("line", cx, cy, r + 12 + pulse * 6)
        lg.setLineWidth(1)
        Kit.text(string.format("%.1f", (Config.extractTicks - own.ex) / 60), 26, cx - r, cy - 18, Kit.GREEN, 1, "center", r * 2)
        Kit.text("EXTRACTING", 12, 0, cy + r + 18, Kit.GREEN, 1, "center", W)
        Kit.text("Stay in the zone", 12, 0, cy + r + 36, Kit.INK, 0.55, "center", W)
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
    if banner and now - banner.time < 6 then
        local a = min(1, (6 - (now - banner.time)) * 2)
        local slide = (1 - min(1, (now - banner.time) * 4)) * 30
        Kit.card(W / 2 - 280, 120 - slide, 560, 70, 0.95 * a, 14)
        Kit.color(banner.color or Kit.INK, a)
        lg.rectangle("fill", W / 2 - 280, 120 - slide + 14, 4, 42, 2, 2)
        Kit.text(banner.title:upper(), 20, 0, 132 - slide, banner.color or Kit.INK, a, "center", W)
        Kit.text(banner.text or "", 14, 0, 160 - slide, Kit.INK, 0.7 * a, "center", W)
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
        local t = min(1, (now - ext.diedAt) * 1.5)
        lg.setColor(0.05, 0.05, 0.06, 0.6 * t)
        lg.rectangle("fill", 0, 0, W, H)
        Kit.color(Kit.RED, t)
        lg.rectangle("fill", W / 2 - 160 * t, H / 2 - 74, 320 * t, 3)
        Kit.text("KILLED IN ACTION", 40, 0, H / 2 - 60, Kit.RED, t, "center", W)
        Kit.text(ext.killer and ("by " .. ext.killer) or "by the wilds", 18, 0, H / 2 - 6, { 1, 1, 1 }, 0.9 * t, "center", W)
        Kit.text("Your gear stays on your body for others to loot.", 14, 0, H / 2 + 26, { 1, 1, 1 }, 0.6 * t, "center", W)
    else
        ext.diedAt = nil
    end

    Hud.intro(ext, now)

    Kit.hint(Keys.label("inventory"), "Inventory", 24, 24, 0.7, 12)
    Kit.hint(Keys.label("map"), "Map", 24, 50, 0.7, 12)
    local ping = GM.Multiplayer and GM.Multiplayer:Ping()
    if ping then Kit.text(string.format("%d ms", floor(ping)), 11, 24, 76, Kit.INK, 0.4) end
end

return Hud
