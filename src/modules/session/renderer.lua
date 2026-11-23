local Config = require("src.config.game")
local Character = require("src.modules.session.character")
local Kit = require("src.ui.kit")
local Weapons = require("src.game.weapons")
local Player = require("src.game.player")
local Vision = require("src.game.vision")

local Renderer = {}

local cos, sin = math.cos, math.sin

local COLORS = {
    background = { 0.93, 0.95, 0.97 },
    floor = { 0.8, 0.82, 0.85 },
    grid = { 0.66, 0.69, 0.74, 0.3 },
    wallTop = { 0.98, 0.985, 0.99 },
    wallSide = { 0.82, 0.86, 0.9 },
    wallShadow = { 0.35, 0.4, 0.48, 0.14 },
    hud = { 0.13, 0.14, 0.16 },
    laser = { 0.88, 0.14, 0.12 },
    opponent = { 0.88, 0.14, 0.12 },
    muted = { 0.13, 0.14, 0.16, 0.55 },
    fog = { 0.4, 0.44, 0.5, 0.5 },
    pad = { 0.13, 0.14, 0.16, 0.12 }
}

local WALL = {
    height = 70,
    cameraHeight = 1400
}

local TRAIL_LIFE = 0.22
local TRAIL_SPACING = 0.018

local trails = {}


local fonts = {}

local function font(size)
    if not fonts[size] then
        fonts[size] = love.graphics.newFont(size)
    end
    return fonts[size]
end

local STYLES = {
    wall = { top = { 0.98, 0.985, 0.99 }, side = { 0.82, 0.86, 0.9 }, height = 70 },
    door = { top = { 0.84, 0.86, 0.9 }, side = { 0.66, 0.7, 0.76 }, height = 70, stripe = true },
    glass = { top = { 0.78, 0.9, 0.98, 0.45 }, side = { 0.62, 0.8, 0.95, 0.3 }, height = 70, edge = true },
    cover = { top = { 0.93, 0.94, 0.96 }, side = { 0.7, 0.74, 0.8 }, height = 24 }
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

local function drawFloor(arena)
    local lg = love.graphics
    lg.setColor(COLORS.floor)
    lg.rectangle("fill", 0, 0, arena.width, arena.height)
    lg.setColor(COLORS.grid)
    lg.setLineWidth(1)
    for x = 0, arena.width, 80 do lg.line(x, 0, x, arena.height) end
    for y = 0, arena.height, 80 do lg.line(0, y, arena.width, y) end
    local ox, oy = -cos(Character.LIGHT) * 18, -sin(Character.LIGHT) * 18
    lg.setColor(COLORS.wallShadow)
    for _, wall in ipairs(arena.walls) do shadow(wall, ox, oy) end
    for _, door in ipairs(arena.doors or {}) do
        if not door.open then shadow(door, ox, oy) end
    end
    lg.setColor(COLORS.wallShadow[1], COLORS.wallShadow[2], COLORS.wallShadow[3], COLORS.wallShadow[4] * 0.6)
    for _, block in ipairs(arena.cover or {}) do shadow(block, ox * 0.4, oy * 0.4) end
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
    lg.setColor(0.05, 0.07, 0.1, 0.15)
    lg.rectangle("fill", x - 9, y - 7, 18, 18, 4, 4)
    lg.setColor(1, 1, 1, 1)
    lg.rectangle("fill", x - 9, y - 9, 18, 18, 4, 4)
    Kit.color(Kit.RED, 1)
    lg.rectangle("fill", x - 2.5, y - 6, 5, 12, 1, 1)
    lg.rectangle("fill", x - 6, y - 2.5, 12, 5, 1, 1)
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

local function drawPlayer(p, arena, palette)
    local lg = love.graphics
    drawTrail(p, palette)
    Character.draw(p, palette)
    if not p.weapon then return end

    drawLaser(p, arena)
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

local function drawAims(world)
    for _, aim in ipairs(world.aims or {}) do
        drawLaser({ x = aim.x, y = aim.y, angle = Player.unpackAngle(aim.a), weapon = Weapons.unpack(aim.g) }, world.arena)
    end
end

local function drawItems(world)
    local lg = love.graphics
    local pulse = 0.5 + 0.5 * sin(love.timer.getTime() * 4)
    for _, pad in ipairs(world.arena.loot) do
        lg.setColor(COLORS.pad)
        lg.setLineWidth(2)
        lg.circle("line", pad.x, pad.y, 22)
    end
    for _, item in ipairs(world.items) do
        local kind = Weapons.unpack(item.k)
        if kind then
            if item.f == 0 then
                lg.setColor(1, 1, 1, 0.35 + 0.35 * pulse)
                lg.circle("fill", item.x, item.y, 16)
            end
            Character.drawWeapon(kind, item.x, item.y, item.a or 0)
        elseif item.k == -1 then
            lg.setColor(1, 1, 1, 0.3 + 0.3 * pulse)
            lg.circle("fill", item.x, item.y, 15)
            drawHealth(item.x, item.y)
        elseif item.k == 0 then
            lg.setColor(1, 1, 1, 0.3 + 0.3 * pulse)
            lg.circle("fill", item.x, item.y, 13)
            Character.drawAmmo(item.x, item.y, item.a or 0)
        end
    end
    lg.setLineWidth(1)
end

local function drawFog(world, me)
    local lg = love.graphics
    local arena = world.arena
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

--- @param session table
function Renderer.draw(session)
    local lg = love.graphics
    lg.clear(COLORS.background)
    local world = session.world
    if world then
        local camera = session.camera
        local me = session:localView()
        local opponents = session:visibleOpponents()
        camera:apply()
        drawFloor(world.arena)
        drawItems(world)
        for _, p in ipairs(opponents) do
            drawPlayer(p, world.arena, Character.PALETTES.opponent)
        end
        drawFog(world, me)
        drawAims(world)
        session.effects:drawWorld()
        drawWalls(world.arena, camera)
        session.effects:drawImpacts()
        if me.dead == 0 then
            drawPlayer(me, world.arena, Character.PALETTES.self)
        end
        camera:clear()
        for _, p in ipairs(opponents) do
            label(camera, p, COLORS.opponent)
        end
    end
    session.effects:drawScreen()
    session.hud:draw(session)
    lg.setColor(1, 1, 1, 1)
    lg.setLineWidth(1)
end

return Renderer
