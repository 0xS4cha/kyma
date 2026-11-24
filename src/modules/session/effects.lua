local Effects = {}
Effects.__index = Effects

local cos, sin, pi, random = math.cos, math.sin, math.pi, love.math.random

local TRACER_LIFE = 0.18
local TRAIL_LIFE = 1.2
local IMPACT_LIFE = 10
local DUST_LIFE = 0.6
local MAX_IMPACTS = 80
local FLASH_LIFE = 0.06
local SHARD_LIFE = 1.4
local HIT_LIFE = 0.25
local HURT_LIFE = 0.45
local ECHO_LIFE = 1.1
local ECHO_SIZE = { shot = 70, dash = 46, step = 30, throw = 40, clank = 40 }

--- @return table
function Effects.new()
    return setmetatable({
        tracers = {}, flashes = {}, shards = {}, echoes = {}, impacts = {}, dust = {}, hit = -1, hurt = -1
    }, Effects)
end

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @param color table
--- @param hit number?
--- @param trail number?
function Effects:tracer(x1, y1, x2, y2, color, hit, trail)
    local now = love.timer.getTime()
    self.tracers[#self.tracers + 1] = {
        x1 = x1, y1 = y1, x2 = x2, y2 = y2, color = color, time = now, trail = trail or TRAIL_LIFE
    }
    self.flashes[#self.flashes + 1] = { x = x1, y = y1, time = now }
    if hit == 1 then
        self:impact(x2, y2, x2 - x1, y2 - y1)
    elseif hit == 2 then
        self:spray(x2, y2, { 0.88, 0.14, 0.12 }, 8)
    end
end

--- @param x number
--- @param y number
--- @param c table
--- @param count number
function Effects:spray(x, y, c, count)
    local now = love.timer.getTime()
    for _ = 1, count do
        local a, speed = random() * 2 * pi, 40 + random() * 120
        self.dust[#self.dust + 1] = {
            x = x, y = y, vx = cos(a) * speed, vy = sin(a) * speed,
            size = 1.5 + random() * 2.5, color = c, time = now
        }
    end
end

--- @param x number
--- @param y number
--- @param dx number
--- @param dy number
function Effects:impact(x, y, dx, dy)
    local now = love.timer.getTime()
    local d = math.sqrt(dx * dx + dy * dy)
    local ux, uy = d > 0 and dx / d or 1, d > 0 and dy / d or 0
    local points = {}
    for k = 0, 5 do
        local a = k / 6 * 2 * pi
        local r = 2.2 + random() * 2.2
        points[#points + 1] = x + cos(a) * r
        points[#points + 1] = y + sin(a) * r
    end
    self.impacts[#self.impacts + 1] = { x = x, y = y, points = points, time = now }
    if #self.impacts > MAX_IMPACTS then table.remove(self.impacts, 1) end
    for _ = 1, 7 do
        local a = math.atan2(-uy, -ux) + (random() - 0.5) * 2.2
        local speed = 30 + random() * 110
        self.dust[#self.dust + 1] = {
            x = x - ux * 2, y = y - uy * 2, vx = cos(a) * speed, vy = sin(a) * speed,
            size = 2 + random() * 3, color = { 0.55, 0.58, 0.63 }, time = now
        }
    end
end

--- @param x number
--- @param y number
--- @param color table
function Effects:shatter(x, y, color)
    local now = love.timer.getTime()
    for _ = 1, 22 do
        local a, speed = random() * 2 * pi, 60 + random() * 160
        self.shards[#self.shards + 1] = {
            x = x, y = y, vx = cos(a) * speed, vy = sin(a) * speed,
            angle = random() * 2 * pi, spin = (random() - 0.5) * 12,
            size = 3 + random() * 5, color = color, time = now
        }
    end
end

--- @param x number
--- @param y number
--- @param kind string
function Effects:echo(x, y, kind)
    self.echoes[#self.echoes + 1] = { x = x, y = y, kind = kind, time = love.timer.getTime() }
    if #self.echoes > 40 then table.remove(self.echoes, 1) end
end

--- @param x number
--- @param y number
--- @param angle number
function Effects:swing(x, y, angle)
    self.swings = self.swings or {}
    self.swings[#self.swings + 1] = { x = x, y = y, angle = angle, time = love.timer.getTime() }
end

function Effects:hitMarker()
    self.hit = love.timer.getTime()
end

function Effects:hurtFlash()
    self.hurt = love.timer.getTime()
end

--- @param dt number
function Effects:update(dt)
    local now = love.timer.getTime()
    local function prune(list, life)
        for k = #list, 1, -1 do
            if now - list[k].time > life then table.remove(list, k) end
        end
    end
    for k = #self.tracers, 1, -1 do
        if now - self.tracers[k].time > self.tracers[k].trail then table.remove(self.tracers, k) end
    end
    prune(self.impacts, IMPACT_LIFE)
    prune(self.dust, DUST_LIFE)
    local dustDrag = math.exp(-6 * dt)
    for _, d in ipairs(self.dust) do
        d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
        d.vx, d.vy = d.vx * dustDrag, d.vy * dustDrag
    end
    prune(self.flashes, FLASH_LIFE)
    prune(self.shards, SHARD_LIFE)
    prune(self.echoes, ECHO_LIFE)
    local drag = math.exp(-4 * dt)
    for _, shard in ipairs(self.shards) do
        shard.x, shard.y = shard.x + shard.vx * dt, shard.y + shard.vy * dt
        shard.vx, shard.vy = shard.vx * drag, shard.vy * drag
        shard.angle = shard.angle + shard.spin * dt
        shard.spin = shard.spin * drag
    end
end

function Effects:drawWorld()
    local lg = love.graphics
    local now = love.timer.getTime()
    for k = #(self.swings or {}), 1, -1 do
        local swing = self.swings[k]
        local t = (now - swing.time) / 0.22
        if t >= 1 then
            table.remove(self.swings, k)
        else
            lg.setColor(1, 1, 1, 0.75 * (1 - t))
            lg.setLineWidth(4 - 3 * t)
            local a = swing.angle
            lg.arc("line", "open", swing.x, swing.y, 34 + 10 * t, a - 0.7 + 0.5 * t, a + 0.4 + 0.5 * t, 16)
        end
    end
    for _, echo in ipairs(self.echoes) do
        local t = (now - echo.time) / ECHO_LIFE
        local size = ECHO_SIZE[echo.kind] or 36
        local loud = echo.kind == "shot"
        local r, g, b = loud and 0.88 or 0.1, loud and 0.14 or 0.11, loud and 0.12 or 0.13
        for ring = 0, 1 do
            local k = math.max(0, t - ring * 0.18)
            if k > 0 and k < 1 then
                lg.setColor(r, g, b, (1 - k) * 0.7)
                lg.setLineWidth(2.5 - k * 1.5)
                lg.circle("line", echo.x, echo.y, 6 + size * (1 - (1 - k) ^ 3))
            end
        end
        lg.setColor(r, g, b, (1 - t) * 0.8)
        lg.circle("fill", echo.x, echo.y, 4)
    end
    for _, shard in ipairs(self.shards) do
        local fade = 1 - (now - shard.time) / SHARD_LIFE
        local c, s = shard.color, shard.size
        local ca, sa = cos(shard.angle), sin(shard.angle)
        lg.setColor(c[1], c[2], c[3], fade)
        lg.polygon("fill",
            shard.x + ca * s, shard.y + sa * s,
            shard.x - sa * s * 0.6, shard.y + ca * s * 0.6,
            shard.x - ca * s * 0.8, shard.y - sa * s * 0.8)
    end
    for _, tracer in ipairs(self.tracers) do
        local age = now - tracer.time
        local c = tracer.color
        local smoke = 1 - age / tracer.trail
        lg.setColor(0.45, 0.48, 0.53, 0.35 * smoke * smoke)
        lg.setLineWidth(3 + 4 * (1 - smoke))
        lg.line(tracer.x1, tracer.y1, tracer.x2, tracer.y2)
        if age < TRACER_LIFE then
            lg.setColor(c[1], c[2], c[3], 0.85 * (1 - age / TRACER_LIFE))
            lg.setLineWidth(2.2)
            lg.line(tracer.x1, tracer.y1, tracer.x2, tracer.y2)
        end
    end
    for _, flash in ipairs(self.flashes) do
        lg.setColor(1, 0.95, 0.8, 1 - (now - flash.time) / FLASH_LIFE)
        lg.circle("fill", flash.x, flash.y, 7)
    end
    lg.setLineWidth(1)
end

function Effects:drawImpacts()
    local lg = love.graphics
    local now = love.timer.getTime()
    for _, impact in ipairs(self.impacts) do
        local fade = math.min(1, (IMPACT_LIFE - (now - impact.time)) / 2)
        lg.setColor(0.18, 0.2, 0.24, 0.75 * fade)
        lg.polygon("fill", impact.points)
        lg.setColor(0.05, 0.06, 0.08, 0.9 * fade)
        lg.circle("fill", impact.x, impact.y, 1.3)
    end
    for _, d in ipairs(self.dust) do
        local t = (now - d.time) / DUST_LIFE
        local c = d.color
        lg.setColor(c[1], c[2], c[3], (1 - t) * 0.8)
        lg.circle("fill", d.x, d.y, d.size * (1 + t))
    end
end

function Effects:drawScreen()
    local lg = love.graphics
    local W, H = lg.getDimensions()
    local now = love.timer.getTime()

    local hurt = now - self.hurt
    if hurt < HURT_LIFE then
        local alpha = 0.55 * (1 - hurt / HURT_LIFE)
        local d = math.min(W, H) * 0.18
        local r, g, b = 0.88, 0.14, 0.12
        local function edge(x1, y1, x2, y2, x3, y3, x4, y4)
            local mesh = lg.newMesh({
                { x1, y1, 0, 0, r, g, b, alpha },
                { x2, y2, 0, 0, r, g, b, alpha },
                { x3, y3, 0, 0, r, g, b, 0 },
                { x4, y4, 0, 0, r, g, b, 0 }
            }, "fan", "stream")
            lg.setColor(1, 1, 1, 1)
            lg.draw(mesh)
        end
        edge(0, 0, W, 0, W - d, d, d, d)
        edge(W, 0, W, H, W - d, H - d, W - d, d)
        edge(W, H, 0, H, d, H - d, W - d, H - d)
        edge(0, H, 0, 0, d, d, d, H - d)
    end

    local hit = now - self.hit
    if hit < HIT_LIFE then
        local cx, cy = W / 2, H * 0.3
        local s = 10
        lg.setColor(0.88, 0.14, 0.12, 1 - hit / HIT_LIFE)
        lg.setLineWidth(3)
        lg.line(cx - s, cy - s, cx - s / 3, cy - s / 3)
        lg.line(cx + s, cy - s, cx + s / 3, cy - s / 3)
        lg.line(cx - s, cy + s, cx - s / 3, cy + s / 3)
        lg.line(cx + s, cy + s, cx + s / 3, cy + s / 3)
        lg.setLineWidth(1)
    end
end

return Effects
