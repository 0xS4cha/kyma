local Config = require("src.config.game")
local Character = require("src.modules.session.character")
local Weapons = require("src.game.weapons")
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
    for _, wall in ipairs(arena.walls) do
        lg.polygon("fill",
            wall.x, wall.y, wall.x + wall.w, wall.y, wall.x + wall.w + ox, wall.y + oy,
            wall.x + wall.w + ox, wall.y + wall.h + oy, wall.x + ox, wall.y + wall.h + oy, wall.x, wall.y + wall.h)
    end
end

local function lift(x, y, cx, cy, factor)
    return cx + (x - cx) * factor, cy + (y - cy) * factor
end

local function drawWall(wall, cx, cy, factor)
    local lg = love.graphics
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
            local side = COLORS.wallSide
            lg.setColor(side[1] * light, side[2] * light, side[3] * light)
            lg.polygon("fill", ax, ay, bx, by, top[n], top[n + 1], top[k], top[k + 1])
        end
    end

    lg.setColor(COLORS.wallTop)
    lg.polygon("fill", top)
end

local function drawWalls(arena, camera)
    local cx, cy = camera.x, camera.y
    local factor = WALL.cameraHeight / (WALL.cameraHeight - WALL.height)
    local order = {}
    for _, wall in ipairs(arena.walls) do
        local dx = math.max(wall.x - cx, 0, cx - wall.x - wall.w)
        local dy = math.max(wall.y - cy, 0, cy - wall.y - wall.h)
        order[#order + 1] = { wall = wall, distance = dx * dx + dy * dy }
    end
    table.sort(order, function(a, b) return a.distance > b.distance end)
    for _, entry in ipairs(order) do
        drawWall(entry.wall, cx, cy, factor)
    end
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

local function drawPlayer(p, arena, palette)
    local lg = love.graphics
    drawTrail(p, palette)
    Character.draw(p, palette)
    if not p.weapon then return end

    local ca, sa = cos(p.angle), sin(p.angle)
    local mx, my = Weapons.muzzle(p)
    local length = arena:raycast(mx, my, ca, sa, Config.laserLength)
    lg.setColor(COLORS.laser[1], COLORS.laser[2], COLORS.laser[3], 0.45)
    lg.setLineWidth(1)
    lg.line(mx, my, mx + ca * length, my + sa * length)
    lg.circle("fill", mx + ca * length, my + sa * length, 2)
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
        session.effects:drawWorld()
        drawWalls(world.arena, camera)
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
