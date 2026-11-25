local GM = require("src.core.index")
local Config = require("src.config.game")
local Character = require("src.modules.session.character")
local Kit = require("src.ui.kit")
local Camera = require("src.core.camera")
local Weapons = require("src.game.weapons")
local Player = require("src.game.player")
local Vision = require("src.game.vision")
local Shaders = require("src.modules.session.shaders")
local Shadows = require("src.modules.session.shadows")
local Effects = require("src.modules.session.effects")
local Occlusion = require("src.modules.session.occlusion")

local Renderer = {}

local cos, sin = math.cos, math.sin

local T = require("src.ui.theme").colors

local COLORS = {
    background = T.background,
    floor = T.floor,
    grid = T.grid,
    wallTop = T.wallTop,
    wallSide = T.wallSide,
    wallShadow = T.wallShadow,
    hud = { 0.13, 0.14, 0.16 },
    laser = { 0.88, 0.14, 0.12 },
    opponent = { 0.88, 0.14, 0.12 },
    muted = { 0.13, 0.14, 0.16, 0.55 },
    fog = T.fog,
    pad = T.pad
}

local WALL = {
    height = 70,
    cameraHeight = 1400
}

local TRAIL_LIFE = 0.22
local TRAIL_SPACING = 0.018

local trails = {}



local font = Kit.font

local STYLES = {
    wall = { top = T.wallTop, side = T.wallSide, height = 70 },
    door = { top = T.doorTop, side = T.doorSide, height = 70, stripe = true },
    glass = { top = T.glassTop, side = T.glassSide, height = 70, edge = true },
    cover = { top = T.coverTop, side = T.coverSide, height = 24 }
}

local function shadow(rect, ox, oy)
    love.graphics.polygon("fill",
        rect.x, rect.y, rect.x + rect.w, rect.y, rect.x + rect.w + ox, rect.y + oy,
        rect.x + rect.w + ox, rect.y + rect.h + oy, rect.x + ox, rect.y + rect.h + oy, rect.x, rect.y + rect.h)
end

local function drawShards(pane)
    local lg = love.graphics
    lg.setColor(0.6, 0.78, 0.92, 0.55)
    local long = pane.w >= pane.h
    local length = long and pane.w or pane.h
    for k = 0, math.floor(length / 14) do
        local t = (k * 14 + (k * 37 % 11)) / length
        local px = long and pane.x + t * pane.w or pane.x + pane.w / 2 + ((k * 53 % 13) - 6) * 2
        local py = long and pane.y + pane.h / 2 + ((k * 53 % 13) - 6) * 2 or pane.y + t * pane.h
        local s = 3 + k % 3
        lg.polygon("fill", px, py - s, px + s, py + s * 0.6, px - s * 0.8, py + s * 0.4)
    end
end

local drawPit
local PIT_DEPTH = 620
local PIT_STRATA = { 0.18, 0.4, 0.66 }

--- A point of the floor seen at some depth below it, from the camera.
local function sink(x, y, cx, cy, depth)
    local f = WALL.cameraHeight / (WALL.cameraHeight + depth)
    return cx + (x - cx) * f, cy + (y - cy) * f
end

local pitFaces = love.graphics and love.graphics.newMesh(4, "fan", "stream")

--- A chasm going down: its inner walls in perspective from the camera,
--- fading into the dark, strata lines at a few depths, and two layers of
--- mist drifting at different depths.
--- @param pit table
--- @param camera table
drawPit = function(pit, camera)
    local lg = love.graphics
    local cx, cy = camera.x, camera.y
    local now = love.timer.getTime()
    lg.stencil(function()
        lg.rectangle("fill", pit.x, pit.y, pit.w, pit.h)
    end, "replace", 1)
    lg.setStencilTest("equal", 1)
    local deep, rim = T.pitDeep, T.pitRim
    lg.setColor(deep[1] * 0.6, deep[2] * 0.6, deep[3] * 0.6, 1)
    lg.rectangle("fill", pit.x, pit.y, pit.w, pit.h)

    local top = { pit.x, pit.y, pit.x + pit.w, pit.y, pit.x + pit.w, pit.y + pit.h, pit.x, pit.y + pit.h }
    local bottom = {}
    for k = 1, 8, 2 do bottom[k], bottom[k + 1] = sink(top[k], top[k + 1], cx, cy, PIT_DEPTH) end
    for k = 1, 8, 2 do
        local j = (k + 1) % 8 + 1
        local ax, ay, bx, by = top[k], top[k + 1], top[j], top[j + 1]
        local nx, ny = ay - by, bx - ax
        local light = 1 + 0.18 * cos(math.atan2(ny, nx) - Character.LIGHT)
        local r, g, b = math.min(1, rim[1] * light * 1.35), math.min(1, rim[2] * light * 1.35), math.min(1, rim[3] * light * 1.35)
        pitFaces:setVertices({
            { ax, ay, 0, 0, r, g, b, 1 },
            { bx, by, 0, 0, r, g, b, 1 },
            { bottom[j], bottom[j + 1], 0, 0, deep[1] * 0.6, deep[2] * 0.6, deep[3] * 0.6, 1 },
            { bottom[k], bottom[k + 1], 0, 0, deep[1] * 0.6, deep[2] * 0.6, deep[3] * 0.6, 1 }
        })
        lg.setColor(1, 1, 1, 1)
        lg.draw(pitFaces)
    end

    lg.setLineWidth(1)
    for _, t in ipairs(PIT_STRATA) do
        local ring = {}
        for k = 1, 8, 2 do ring[k], ring[k + 1] = sink(top[k], top[k + 1], cx, cy, PIT_DEPTH * t) end
        lg.setColor(T.pitEdge[1], T.pitEdge[2], T.pitEdge[3], (T.pitEdge[4] or 1) * 0.7 * (1 - t))
        lg.polygon("line", ring)
    end

    local mist = Shaders.get("mist")
    if mist then
        local cloud = T.cloud
        lg.setShader(mist)
        for layer, def in ipairs({ { depth = 0.85, alpha = 0.5, drift = 1 }, { depth = 0.55, alpha = 0.2, drift = -1.4 } }) do
            local x1, y1 = sink(pit.x, pit.y, cx, cy, PIT_DEPTH * def.depth)
            local x2, y2 = sink(pit.x + pit.w, pit.y + pit.h, cx, cy, PIT_DEPTH * def.depth)
            mist:send("time", now)
            mist:send("seed", (pit.x * 0.011 + pit.y * 0.017 + layer * 5.3) % 23)
            mist:send("scale", { math.max(1, (x2 - x1) / 90), math.max(1, (y2 - y1) / 90) })
            mist:send("drift", def.drift)
            lg.setColor(cloud[1], cloud[2], cloud[3], def.alpha)
            lg.draw(Shaders.pixel(), x1, y1, 0, x2 - x1, y2 - y1)
        end
        lg.setShader()
    end
    lg.setStencilTest()
end

local function drawFloor(arena, camera)
    local lg = love.graphics
    lg.setColor(COLORS.floor)
    lg.rectangle("fill", 0, 0, arena.width, arena.height)
    lg.setColor(COLORS.grid)
    lg.setLineWidth(1)
    for x = 0, arena.width, 80 do lg.line(x, 0, x, arena.height) end
    for y = 0, arena.height, 80 do lg.line(0, y, arena.width, y) end
    local ox, oy = -cos(Character.LIGHT) * 18, -sin(Character.LIGHT) * 18
    for _, pit in ipairs(arena.pits or {}) do
        if camera then
            drawPit(pit, camera)
        else
            lg.setColor(T.pitRim)
            lg.rectangle("fill", pit.x, pit.y, pit.w, pit.h)
            lg.setColor(T.pitDeep)
            lg.rectangle("fill", pit.x + 8, pit.y + 8, pit.w - 16, pit.h - 16)
        end
        lg.setColor(T.pitEdge)
        lg.setLineWidth(2)
        lg.rectangle("line", pit.x, pit.y, pit.w, pit.h)
        lg.setLineWidth(1)
    end
    lg.setColor(COLORS.wallShadow)
    for _, wall in ipairs(arena.walls) do shadow(wall, ox, oy) end
    for _, door in ipairs(arena.doors or {}) do
        if not door.open then shadow(door, ox, oy) end
    end
    lg.setColor(COLORS.wallShadow[1], COLORS.wallShadow[2], COLORS.wallShadow[3], COLORS.wallShadow[4] * 0.6)
    for _, block in ipairs(arena.cover or {}) do shadow(block, ox * 0.4, oy * 0.4) end
    Occlusion.draw(arena, require("src.ui.theme").dark() and 0.55 or 0.38)
    for _, pane in ipairs(arena.glass or {}) do
        if pane.broken then drawShards(pane) end
    end
end

local function lift(x, y, cx, cy, factor)
    return cx + (x - cx) * factor, cy + (y - cy) * factor
end

local function drawWall(wall, cx, cy, style)
    local lg = love.graphics
    local factor = WALL.cameraHeight / (WALL.cameraHeight - style.height)
    local alpha = style.top[4] or 1
    local base = {
        wall.x, wall.y,
        wall.x + wall.w, wall.y,
        wall.x + wall.w, wall.y + wall.h,
        wall.x, wall.y + wall.h
    }
    local top = {}
    for k = 1, 8, 2 do
        top[k], top[k + 1] = lift(base[k], base[k + 1], cx, cy, factor)
    end

    for k = 1, 8, 2 do
        local n = (k + 1) % 8 + 1
        local ax, ay, bx, by = base[k], base[k + 1], base[n], base[n + 1]
        local nx, ny = by - ay, ax - bx
        local mx, my = (ax + bx) / 2, (ay + by) / 2
        if nx * (cx - mx) + ny * (cy - my) > 0 then
            local light = 1 + 0.12 * cos(math.atan2(ny, nx) - Character.LIGHT)
            local side = style.side
            lg.setColor(side[1] * light, side[2] * light, side[3] * light, side[4] or 1)
            lg.polygon("fill", ax, ay, bx, by, top[n], top[n + 1], top[k], top[k + 1])
        end
    end

    lg.setColor(style.top[1], style.top[2], style.top[3], alpha)
    lg.polygon("fill", top)
    if style.edge then
        lg.setColor(1, 1, 1, 0.8)
        lg.setLineWidth(1.5)
        lg.polygon("line", top)
        lg.setLineWidth(1)
    end
    if style.stripe then
        local x1, y1, x2, y2 = top[1], top[2], top[5], top[6]
        Kit.color(Kit.RED, 0.85)
        if wall.w >= wall.h then
            local my = (y1 + y2) / 2
            lg.rectangle("fill", x1 + 4, my - 1.5, x2 - x1 - 8, 3)
        else
            local mx = (x1 + x2) / 2
            lg.rectangle("fill", mx - 1.5, y1 + 4, 3, y2 - y1 - 8)
        end
    end
end

local function doorPanels(door)
    local dt = math.min(love.timer.getDelta(), 0.1)
    door.anim = Kit.approach(door.anim or 0, door.open and 1 or 0, 12, dt)
    local closed = 1 - door.anim
    if closed > 0.97 then return { door } end
    local horizontal = door.w >= door.h
    local length = horizontal and door.w or door.h
    local panel = math.max(4, length / 2 * closed)
    if horizontal then
        return {
            { x = door.x, y = door.y, w = panel, h = door.h },
            { x = door.x + door.w - panel, y = door.y, w = panel, h = door.h }
        }
    end
    return {
        { x = door.x, y = door.y, w = door.w, h = panel },
        { x = door.x, y = door.y + door.h - panel, w = door.w, h = panel }
    }
end

local function drawWalls(arena, camera)
    local cx, cy = camera.x, camera.y
    local order = {}
    local function add(rect, style)
        local dx = math.max(rect.x - cx, 0, cx - rect.x - rect.w)
        local dy = math.max(rect.y - cy, 0, cy - rect.y - rect.h)
        order[#order + 1] = { rect = rect, style = style, distance = dx * dx + dy * dy }
    end
    for _, block in ipairs(arena.cover or {}) do add(block, STYLES.cover) end
    for _, wall in ipairs(arena.walls) do add(wall, STYLES.wall) end
    for _, door in ipairs(arena.doors or {}) do
        for _, panel in ipairs(doorPanels(door)) do add(panel, STYLES.door) end
    end
    for _, pane in ipairs(arena.glass or {}) do
        if not pane.broken then add(pane, STYLES.glass) end
    end
    table.sort(order, function(a, b) return a.distance > b.distance end)
    for _, entry in ipairs(order) do
        drawWall(entry.rect, cx, cy, entry.style)
    end
end

local function drawHealth(x, y)
    local lg = love.graphics
    lg.setColor(T.shadow[1], T.shadow[2], T.shadow[3], 0.15)
    lg.rectangle("fill", x - 9, y - 7, 18, 18, 4, 4)
    lg.setColor(T.surface)
    lg.rectangle("fill", x - 9, y - 9, 18, 18, 4, 4)
    Kit.color(Kit.RED, 1)
    lg.rectangle("fill", x - 2.5, y - 6, 5, 12, 1, 1)
    lg.rectangle("fill", x - 6, y - 2.5, 12, 5, 1, 1)
end

local function drawPlate(x, y)
    local lg = love.graphics
    local c = require("src.modules.session.shield").COLOR
    lg.setColor(0.05, 0.1, 0.16, 0.25)
    lg.setLineWidth(8)
    lg.arc("line", "open", x, y + 1, 8, -1.05, 1.05, 12)
    lg.setColor(c[1], c[2], c[3], 1)
    lg.setLineWidth(5)
    lg.arc("line", "open", x, y, 8, -1.05, 1.05, 12)
    lg.setColor(0.9, 0.98, 1, 0.8)
    lg.setLineWidth(1.4)
    lg.arc("line", "open", x, y, 7, -0.85, 0.85, 12)
    lg.setLineWidth(1)
end

local function drawTrail(p, palette)
    local now = love.timer.getTime()
    local trail = trails[p.slot] or {}
    trails[p.slot] = trail
    local last = trail[#trail]
    if p.dashing and (not last or now - last.time >= TRAIL_SPACING) then
        trail[#trail + 1] = {
            x = p.x, y = p.y, angle = p.angle, vx = p.vx, vy = p.vy,
            phase = Character.phase(p.slot), time = now
        }
    end
    while trail[1] and now - trail[1].time > TRAIL_LIFE do
        table.remove(trail, 1)
    end
    for _, ghost in ipairs(trail) do
        local fade = 1 - (now - ghost.time) / TRAIL_LIFE
        Character.draw(ghost, palette, { alpha = 0.35 * fade, phase = ghost.phase })
    end
end

local drawLaser

--- @param p table
--- @param own boolean?
--- @return boolean
function Renderer.showsLaser(p, own)
    if not p.weapon then return false end
    if own then return true end
    local def = Weapons.def(p.weapon)
    return def ~= nil and def.exposed == true
end

local function drawPlayer(p, arena, palette, own)
    drawTrail(p, palette)
    Character.draw(p, palette)
    if Renderer.showsLaser(p, own) then
        drawLaser(p, arena)
    end
end

drawLaser = function(p, arena)
    local lg = love.graphics
    local def = Weapons.def(p.weapon)
    local exposed = def and def.exposed
    local ca, sa = cos(p.angle), sin(p.angle)
    local mx, my = Weapons.muzzle(p)
    local length = arena:raycast(mx, my, ca, sa, exposed and def.range or Config.laserLength, "vision")
    if exposed then
        lg.setColor(COLORS.laser[1], COLORS.laser[2], COLORS.laser[3], 0.18)
        lg.setLineWidth(5)
        lg.line(mx, my, mx + ca * length, my + sa * length)
    end
    lg.setColor(COLORS.laser[1], COLORS.laser[2], COLORS.laser[3], exposed and 0.85 or 0.45)
    lg.setLineWidth(exposed and 1.6 or 1)
    lg.line(mx, my, mx + ca * length, my + sa * length)
    lg.circle("fill", mx + ca * length, my + sa * length, exposed and 3 or 2)
    lg.setLineWidth(1)
end

local GADGET_COLORS = { { 0.62, 0.65, 0.7 }, { 0.98, 0.95, 0.75 }, { 0.88, 0.14, 0.12 } }

local function drawGadgets(world, session)
    local lg = love.graphics
    local now = love.timer.getTime()
    local smokeShader = Shaders.get("smoke")
    for k, smoke in ipairs(world.arena.smokes or {}) do
        if smoke.r > 1 and smokeShader then
            local size = smoke.r * 2.2
            lg.setColor(T.cloud[1], T.cloud[2], T.cloud[3], 1)
            lg.setShader(smokeShader)
            smokeShader:send("time", now)
            smokeShader:send("seed", (smoke.x * 0.013 + smoke.y * 0.007) % 17)
            if session and session.smokeFx then
                session.smokeFx:send(smokeShader, smoke, size / 2, session.effects and session.effects.lights, Effects.LIGHT_LIFE)
            end
            lg.draw(Shaders.pixel(), smoke.x, smoke.y, 0, size, size, 0.5, 0.5)
            lg.setShader()
        elseif smoke.r > 1 then
            for n = 0, 6 do
                local a = n / 7 * 2 * math.pi + now * 0.15 + k
                local ox, oy = cos(a) * smoke.r * 0.45, sin(a) * smoke.r * 0.45
                lg.setColor(T.cloud[1], T.cloud[2], T.cloud[3], 0.7)
                lg.circle("fill", smoke.x + ox, smoke.y + oy, smoke.r * 0.62)
            end
            lg.setColor(T.cloud[1], T.cloud[2], T.cloud[3], 0.95)
            lg.circle("fill", smoke.x, smoke.y, smoke.r * 0.8)
        end
    end
    for _, gadget in ipairs(world.gadgets or {}) do
        local c = GADGET_COLORS[gadget.k or 1] or GADGET_COLORS[1]
        lg.setColor(0.1, 0.11, 0.13, 1)
        lg.circle("fill", gadget.x, gadget.y, 6)
        lg.setColor(c[1], c[2], c[3], 0.6 + 0.4 * math.sin(now * 20))
        lg.circle("fill", gadget.x, gadget.y, 3)
    end
end

local function drawObjectives(world)
    local lg = love.graphics
    local round = world.round
    local rules = world.rules
    local now = love.timer.getTime()
    for k, objective in ipairs(world.arena.objectives or {}) do
        local progress = round and (round.h[k] or 0) / (rules.hackTicks or 1) or 0
        local r = rules.hackRadius or 70
        lg.setColor(Kit.RED[1], Kit.RED[2], Kit.RED[3], 0.08 + 0.06 * math.sin(now * 3))
        lg.circle("fill", objective.x, objective.y, r)
        lg.setColor(Kit.RED[1], Kit.RED[2], Kit.RED[3], 0.6)
        lg.setLineWidth(2)
        lg.circle("line", objective.x, objective.y, r)
        if progress > 0 then
            lg.setLineWidth(6)
            lg.arc("line", "open", objective.x, objective.y, r - 6, -math.pi / 2, -math.pi / 2 + progress * 2 * math.pi, 48)
        end
        lg.setLineWidth(1)
        lg.setColor(T.surface)
        lg.rectangle("fill", objective.x - 14, objective.y - 10, 28, 20, 4, 4)
        lg.setColor(Kit.RED)
        lg.rectangle("fill", objective.x - 10, objective.y - 6, 20, 12, 2, 2)
    end
end

local function drawObjectiveLabels(world, camera)
    for _, objective in ipairs(world.arena.objectives or {}) do
        local sx, sy = camera:toScreen(objective.x, objective.y)
        Kit.text(objective.name, 22, sx - 20, sy - 64, Kit.RED, 0.9, "center", 40)
    end
end

local function drawAims(world)
    for _, aim in ipairs(world.aims or {}) do
        drawLaser({ x = aim.x, y = aim.y, angle = Player.unpackAngle(aim.a), weapon = Weapons.unpack(aim.g) }, world.arena)
    end
end

local function drawSpotted(list)
    local lg = love.graphics
    local pulse = 0.6 + 0.4 * sin(love.timer.getTime() * 6)
    for _, p in ipairs(list) do
        if p.marked then
            Character.draw(p, Character.PALETTES.opponent, { alpha = 0.55, phase = Character.phase(p.slot) })
            Kit.color(Kit.RED, pulse)
            lg.setLineWidth(2)
            lg.circle("line", p.x, p.y, 22)
            lg.line(p.x - 30, p.y, p.x - 24, p.y)
            lg.line(p.x + 24, p.y, p.x + 30, p.y)
            lg.line(p.x, p.y - 30, p.x, p.y - 24)
            lg.line(p.x, p.y + 24, p.x, p.y + 30)
            lg.setLineWidth(1)
        end
    end
end

local function drawItems(world)
    local lg = love.graphics
    local pulse = 0.5 + 0.5 * sin(love.timer.getTime() * 4)
    local noWeapons = world.options and world.options.loot == false
    for _, pad in ipairs(world.arena.loot) do
        if noWeapons and Weapons.def(pad.kind) then goto continue end
        if pad.kind == "plate" and world.options and world.options.shields == false then goto continue end
        lg.setColor(COLORS.pad)
        lg.setLineWidth(2)
        lg.circle("line", pad.x, pad.y, 22)
        ::continue::
    end
    for _, item in ipairs(world.items) do
        local kind = Weapons.unpack(item.k)
        if kind then
            if item.f == 0 then
                lg.setColor(T.halo[1], T.halo[2], T.halo[3], 0.35 + 0.35 * pulse)
                lg.circle("fill", item.x, item.y, 16)
            end
            Character.drawWeapon(kind, item.x, item.y, item.a or 0)
        elseif item.k == -1 then
            lg.setColor(T.halo[1], T.halo[2], T.halo[3], 0.3 + 0.3 * pulse)
            lg.circle("fill", item.x, item.y, 15)
            drawHealth(item.x, item.y)
        elseif item.k == -2 then
            lg.setColor(0.35, 0.78, 1, 0.25 + 0.3 * pulse)
            lg.circle("fill", item.x, item.y, 15)
            drawPlate(item.x - 3, item.y)
        elseif item.k == 0 then
            lg.setColor(T.halo[1], T.halo[2], T.halo[3], 0.3 + 0.3 * pulse)
            lg.circle("fill", item.x, item.y, 13)
            Character.drawAmmo(item.x, item.y, item.a or 0)
        end
    end
    lg.setLineWidth(1)
end

local fadeMesh

local function rangeMesh()
    if fadeMesh then return fadeMesh end
    local def = Config.vision
    local inner, outer = def.range * def.fade, def.range + 2
    local vertices = {}
    local steps = 96
    for k = 0, steps do
        local a = k / steps * 2 * math.pi
        local ca, sa = cos(a), sin(a)
        vertices[#vertices + 1] = { ca * inner, sa * inner, 0, 0, 1, 1, 1, 0 }
        vertices[#vertices + 1] = { ca * outer, sa * outer, 0, 0, 1, 1, 1, 1 }
    end
    fadeMesh = love.graphics.newMesh(vertices, "strip", "static")
    return fadeMesh
end

local function drawFog(world, me, camera)
    local lg = love.graphics
    local arena = world.arena
    if Shadows.draw(arena, me, camera, COLORS.fog) then return end
    lg.stencil(function()
        if me.dead > 0 then return end
        local cone, near = Vision.fans(arena, me.x, me.y, me.angle)
        for _, fan in ipairs({ cone, near }) do
            for k = 3, #fan - 3, 2 do
                lg.polygon("fill", fan[1], fan[2], fan[k], fan[k + 1], fan[k + 2], fan[k + 3])
            end
        end
    end, "replace", 1)
    lg.setStencilTest("equal", 0)
    lg.setColor(COLORS.fog)
    lg.rectangle("fill", -2000, -2000, arena.width + 4000, arena.height + 4000)
    if me.dead == 0 then
        lg.setStencilTest("equal", 1)
        lg.setColor(COLORS.fog)
        lg.draw(rangeMesh(), me.x, me.y)
    end
    lg.setStencilTest()
end

local function label(camera, p, color)
    local lg = love.graphics
    local sx, sy = camera:toScreen(p.x, p.y)
    local f = font(22)
    lg.setFont(f)
    lg.setColor(color[1], color[2], color[3], 0.8)
    lg.print(p.name, sx - f:getWidth(p.name) / 2, sy - 30 * camera.scale - f:getHeight())
end

Renderer.drawFloor = drawFloor
Renderer.drawHealth = drawHealth
Renderer.drawWalls = drawWalls
Renderer.COLORS = COLORS

local killcamCamera
local replayCanvas, replayShader

local REPLAY_GRADE = [[
extern number amount;
extern vec2 size;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    vec4 c = Texel(tex, uv);
    float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    vec3 graded = mix(c.rgb, vec3(grey) * vec3(0.9, 0.94, 1.05), 0.8) * 0.5;
    vec2 d = (uv - 0.5) * vec2(size.x / size.y, 1.0);
    graded *= mix(0.45, 1.0, 1.0 - smoothstep(0.25, 0.9, length(d)));
    graded *= 0.95 + 0.05 * sin(screen.y * 3.14159);
    return vec4(mix(c.rgb, graded, amount), c.a) * color;
}
]]

--- @param progress number
--- @return number
function Renderer.replayAmount(progress)
    local duration = Config.killcamTicks / Config.tickRate * 0.85
    return math.max(0, math.min(1, progress * duration / 0.3))
end

local function replayTarget()
    local W, H = love.graphics.getDimensions()
    if not replayCanvas or replayCanvas:getWidth() ~= W or replayCanvas:getHeight() ~= H then
        replayCanvas = love.graphics.newCanvas(W, H)
    end
    if not replayShader then
        local ok, shader = pcall(love.graphics.newShader, REPLAY_GRADE)
        replayShader = ok and shader or false
    end
    return replayCanvas, replayShader
end

local function drawKillcam(session, cam)
    local world = session.world
    local lg = love.graphics
    killcamCamera = killcamCamera or Camera(Config.camera)
    killcamCamera.scale = session.camera.scale
    local camera = killcamCamera
    local killer = cam.killerView
    camera:follow(killer.x, killer.y, killer.angle)
    local canvas, shader = replayTarget()
    lg.setCanvas({ canvas, stencil = true })
    lg.clear(COLORS.background[1], COLORS.background[2], COLORS.background[3], 1, true, 0)
    camera:apply()
    drawFloor(world.arena, camera)
    if cam.victimView then
        Character.draw(cam.victimView, Character.PALETTES.self)
    end
    drawFog(world, killer, camera)
    drawWalls(world.arena, camera)
    camera:clear()
    lg.setCanvas()
    local amount = Renderer.replayAmount(cam.progress)
    lg.setColor(1, 1, 1, 1)
    if shader then
        lg.setShader(shader)
        shader:send("amount", amount)
        shader:send("size", { canvas:getWidth(), canvas:getHeight() })
        lg.draw(canvas)
        lg.setShader()
    else
        lg.draw(canvas)
        lg.setColor(0.05, 0.06, 0.09, 0.45 * amount)
        lg.rectangle("fill", 0, 0, canvas:getWidth(), canvas:getHeight())
    end
    camera:apply()
    for _, entry in ipairs(cam.shots) do
        local shot = entry.shot
        love.graphics.setColor(Kit.RED[1], Kit.RED[2], Kit.RED[3], 0.9 * (1 - entry.age))
        love.graphics.setLineWidth(2.5)
        love.graphics.line(shot.x, shot.y, shot.X, shot.Y)
    end
    drawPlayer(killer, world.arena, Character.PALETTES.opponent, true)
    camera:clear()
end

--- @return table
function Renderer.selfPalette()
    local settings = GM and GM.Menu and GM.Menu.settings
    local body = settings and require("src.config.profile").bodies[settings.body]
    local Theme = require("src.ui.theme")
    return { body = Theme.lifted(body and body.color or Character.PALETTES.self.body) }
end

--- @param session table
function Renderer.draw(session)
    local lg = love.graphics
    local world = session.world
    local cam = world and session:killcam()
    local post = world and not cam and session.postfx and session.postfx:begin()
    lg.clear(COLORS.background)
    if cam then
        drawKillcam(session, cam)
    elseif world then
        local camera = session.camera
        local me = session:localView()
        local opponents = session:visibleOpponents()
        camera:apply()
        drawFloor(world.arena, camera)
        if world.round then drawObjectives(world) end
        session.effects:drawLights()
        if session.debris then session.debris:draw() end
        drawItems(world)
        for _, p in ipairs(opponents) do
            if not p.marked then
                drawPlayer(p, world.arena, p.ally and Character.PALETTES.ally or Character.PALETTES.opponent,
                    world.spectator and p.slot == world.following)
            end
        end
        drawFog(world, me, camera)
        drawGadgets(world, session)
        drawSpotted(opponents)
        drawAims(world)
        session.effects:drawWorld()
        drawWalls(world.arena, camera)
        session.effects:drawImpacts()
        if me.dead == 0 and not world.spectator then
            drawPlayer(me, world.arena, Renderer.selfPalette(), true)
        end
        camera:clear()
        if post then
            session.postfx:capture()
            session.postfx:finish(camera)
        end
        for _, p in ipairs(opponents) do
            label(camera, p, p.ally and Character.PALETTES.ally.body or COLORS.opponent)
        end
        if world.round then drawObjectiveLabels(world, camera) end
    end
    session.effects:drawScreen(post and session.postfx:drawsHurt(), world and not cam and session.camera or nil)
    session.hud:draw(session)
    lg.setColor(1, 1, 1, 1)
    lg.setLineWidth(1)
end

return Renderer
