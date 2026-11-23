local GM = require("src.core.index")
local Config = require("src.config.game")
local Character = require("src.modules.session.character")

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
    muted = { 0.13, 0.14, 0.16, 0.55 }
}

local WALL = {
    height = 70,
    cameraHeight = 1400
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

local function drawPlayer(p, arena, palette)
    local lg = love.graphics
    local ca, sa = cos(p.angle), sin(p.angle)
    local mx, my = Character.muzzle(p)

    Character.draw(p, palette)

    local length = arena:raycast(mx, my, ca, sa, Config.laserLength)
    lg.setColor(COLORS.laser[1], COLORS.laser[2], COLORS.laser[3], 0.45)
    lg.setLineWidth(1)
    lg.line(mx, my, mx + ca * length, my + sa * length)
    lg.circle("fill", mx + ca * length, my + sa * length, 2)
end

local function label(camera, p, color)
    local lg = love.graphics
    local sx, sy = camera:toScreen(p.x, p.y)
    local f = font(22)
    lg.setFont(f)
    lg.setColor(color[1], color[2], color[3], 0.8)
    lg.print(p.name, sx - f:getWidth(p.name) / 2, sy - 30 * camera.scale - f:getHeight())
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
            drawPlayer(p, world.arena, Character.PALETTES.opponent)
        end
        drawWalls(world.arena, camera)
        drawPlayer(me, world.arena, Character.PALETTES.self)
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
