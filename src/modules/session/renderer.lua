local GM = require("src.core.index")
local Config = require("src.config.game")

local Renderer = {}

local cos, sin = math.cos, math.sin

local COLORS = {
    background = { 0.015, 0.02, 0.03 },
    floor = { 0.04, 0.07, 0.08 },
    grid = { 0.2, 0.9, 0.9, 0.05 },
    wall = { 0.01, 0.03, 0.04 },
    neon = { 0.25, 0.95, 0.95 },
    hud = { 1, 0.72, 0.15 },
    laser = { 1, 0.55, 0.1 },
    self = { 0.95, 0.95, 0.92 },
    opponent = { 1, 0.3, 0.35 },
    muted = { 1, 0.72, 0.15, 0.55 }
}

local WALL = {
    height = 70,
    cameraHeight = 650
}

local STATUS = {
    connecting = "CONNECTING",
    queued = "LOOKING FOR A ROOM",
    offline = "DISCONNECTED",
    error = "ERROR"
}

local fonts = {}

local function font(size)
    if not fonts[size] then
        local ok, f = pcall(love.graphics.newFont, "assets/fonts/Jersey10-Regular.ttf", size)
        fonts[size] = ok and f or love.graphics.newFont(size)
    end
    return fonts[size]
end

local function neonPolygon(points, color)
    local lg = love.graphics
    for k = 4, 1, -1 do
        lg.setColor(color[1], color[2], color[3], 0.07 * (5 - k))
        lg.setLineWidth(k * 4)
        lg.polygon("line", points)
    end
    lg.setColor(color[1], color[2], color[3], 1)
    lg.setLineWidth(2)
    lg.polygon("line", points)
end

local function drawFloor(arena)
    local lg = love.graphics
    lg.setColor(COLORS.floor)
    lg.rectangle("fill", 0, 0, arena.width, arena.height)
    lg.setColor(COLORS.grid)
    lg.setLineWidth(1)
    for x = 0, arena.width, 80 do lg.line(x, 0, x, arena.height) end
    for y = 0, arena.height, 80 do lg.line(0, y, arena.width, y) end
end

local function lift(x, y, cx, cy, factor)
    return cx + (x - cx) * factor, cy + (y - cy) * factor
end

local function drawWall(wall, cx, cy, factor)
    local lg = love.graphics
    local neon = COLORS.neon
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
            local face = { ax, ay, bx, by, top[n], top[n + 1], top[k], top[k + 1] }
            lg.setColor(COLORS.wall)
            lg.polygon("fill", face)
            lg.setColor(neon[1], neon[2], neon[3], 0.18)
            lg.polygon("fill", face)
            lg.setColor(neon[1], neon[2], neon[3], 0.5)
            lg.setLineWidth(1)
            lg.line(ax, ay, bx, by)
            lg.line(ax, ay, top[k], top[k + 1])
            lg.line(bx, by, top[n], top[n + 1])
        end
    end

    lg.setColor(COLORS.wall)
    lg.polygon("fill", top)
    neonPolygon(top, neon)
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

local function drawPlayer(p, arena, color)
    local lg = love.graphics
    local radius = Config.player.radius
    local ca, sa = cos(p.angle), sin(p.angle)
    local mx, my = p.x + ca * (radius + 14), p.y + sa * (radius + 14)

    local length = arena:raycast(mx, my, ca, sa, Config.laserLength)
    lg.setColor(COLORS.laser[1], COLORS.laser[2], COLORS.laser[3], 0.25)
    lg.setLineWidth(4)
    lg.line(mx, my, mx + ca * length, my + sa * length)
    lg.setColor(COLORS.laser[1], COLORS.laser[2], COLORS.laser[3], 0.9)
    lg.setLineWidth(1.5)
    lg.line(mx, my, mx + ca * length, my + sa * length)
    lg.circle("fill", mx + ca * length, my + sa * length, 3)

    lg.setColor(color[1], color[2], color[3], 0.12)
    lg.circle("fill", p.x, p.y, radius * 2.2)
    lg.setColor(0.45, 0.47, 0.5)
    lg.setLineWidth(5)
    lg.line(p.x + ca * 4 - sa * 5, p.y + sa * 4 + ca * 5, mx - sa * 5, my + ca * 5)
    lg.setColor(color)
    lg.circle("fill", p.x, p.y, radius)
    lg.setColor(0, 0, 0, 0.35)
    lg.circle("fill", p.x + ca * 4, p.y + sa * 4, radius * 0.45)
end

local function label(camera, p, color)
    local lg = love.graphics
    local sx, sy = camera:toScreen(p.x, p.y)
    local f = font(22)
    lg.setFont(f)
    lg.setColor(color[1], color[2], color[3], 0.8)
    lg.print(p.name, sx - f:getWidth(p.name) / 2, sy - Config.player.radius * camera.scale * 2.2 - f:getHeight())
end

local function drawHud(session)
    local lg = love.graphics
    local W, H = lg.getDimensions()
    local mp = GM.Multiplayer

    lg.setFont(font(36))
    lg.setColor(COLORS.hud)
    local status
    if session.world then
        local room = session.room
        local count = room and #room.players or 1
        status = count >= 2 and "DUEL" or "WAITING FOR AN OPPONENT"
    else
        status = STATUS[session.status] or session.status
    end
    lg.print(status, 24, 16)

    lg.setFont(font(24))
    if mp.error then
        lg.setColor(COLORS.opponent)
        lg.print(mp.error, 24, 56)
    end
    lg.setColor(COLORS.muted)
    local ping = mp:Ping()
    local info = mp.address or ""
    if session.room then info = info .. "   ROOM " .. session.room.id end
    if ping and not mp.isLocal then info = info .. "   " .. ping .. " MS" end
    lg.print(info, 24, H - 36)

    if session.world and not session.captured then
        local text = "CLICK TO PLAY   -   ESC TO QUIT"
        lg.setFont(font(32))
        lg.setColor(COLORS.hud)
        lg.print(text, (W - font(32):getWidth(text)) / 2, H * 0.4)
    end
    lg.setFont(font(20))
    lg.setColor(COLORS.muted)
    local help = "MOVE WASD / ZQSD   TURN MOUSE OR ARROWS   ZOOM WHEEL"
    lg.print(help, W - font(20):getWidth(help) - 24, H - 32)
end

--- @param session table
function Renderer.draw(session)
    local lg = love.graphics
    lg.clear(COLORS.background)
    local world = session.world
    if world then
        local camera = session.camera
        local me = session:localView()
        local opponents = session:opponents()
        camera:apply()
        drawFloor(world.arena)
        for _, p in ipairs(opponents) do
            drawPlayer(p, world.arena, COLORS.opponent)
        end
        drawPlayer(me, world.arena, COLORS.self)
        drawWalls(world.arena, camera)
        camera:clear()
        for _, p in ipairs(opponents) do
            label(camera, p, COLORS.opponent)
        end
    end
    drawHud(session)
    lg.setColor(1, 1, 1, 1)
    lg.setLineWidth(1)
end

return Renderer
