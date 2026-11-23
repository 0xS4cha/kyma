local Effects = {}
Effects.__index = Effects

local cos, sin, pi, random = math.cos, math.sin, math.pi, love.math.random

local TRACER_LIFE = 0.18
local FLASH_LIFE = 0.06
local SHARD_LIFE = 1.4
local FEED_LIFE = 4
local HIT_LIFE = 0.25
local HURT_LIFE = 0.35

--- @return table
function Effects.new()
    return setmetatable({ tracers = {}, flashes = {}, shards = {}, feed = {}, hit = -1, hurt = -1 }, Effects)
end

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @param color table
function Effects:tracer(x1, y1, x2, y2, color)
    local now = love.timer.getTime()
    self.tracers[#self.tracers + 1] = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, color = color, time = now }
    self.flashes[#self.flashes + 1] = { x = x1, y = y1, time = now }
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

function Effects:hitMarker()
    self.hit = love.timer.getTime()
end

function Effects:hurtFlash()
    self.hurt = love.timer.getTime()
end

--- @param text string
--- @param color table
function Effects:announce(text, color)
    self.feed[#self.feed + 1] = { text = text, color = color, time = love.timer.getTime() }
    if #self.feed > 4 then table.remove(self.feed, 1) end
end

--- @param dt number
function Effects:update(dt)
    local now = love.timer.getTime()
    local function prune(list, life)
        for k = #list, 1, -1 do
            if now - list[k].time > life then table.remove(list, k) end
        end
    end
    prune(self.tracers, TRACER_LIFE)
    prune(self.flashes, FLASH_LIFE)
    prune(self.shards, SHARD_LIFE)
    prune(self.feed, FEED_LIFE)
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
        local fade = 1 - (now - tracer.time) / TRACER_LIFE
        local c = tracer.color
        lg.setColor(c[1], c[2], c[3], 0.85 * fade)
        lg.setLineWidth(2.2)
        lg.line(tracer.x1, tracer.y1, tracer.x2, tracer.y2)
    end
    for _, flash in ipairs(self.flashes) do
        lg.setColor(1, 0.95, 0.8, 1 - (now - flash.time) / FLASH_LIFE)
        lg.circle("fill", flash.x, flash.y, 7)
    end
    lg.setLineWidth(1)
end

--- @param font function
function Effects:drawScreen(font)
    local lg = love.graphics
    local W, H = lg.getDimensions()
    local now = love.timer.getTime()

    local hurt = now - self.hurt
    if hurt < HURT_LIFE then
        lg.setColor(0.88, 0.14, 0.12, 0.28 * (1 - hurt / HURT_LIFE))
        lg.rectangle("fill", 0, 0, W, H)
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

    local f = font(22)
    lg.setFont(f)
    for k, entry in ipairs(self.feed) do
        local fade = math.min(1, (FEED_LIFE - (now - entry.time)) * 2)
        local c = entry.color
        lg.setColor(c[1], c[2], c[3], fade)
        lg.print(entry.text, W - f:getWidth(entry.text) - 24, 20 + (k - 1) * 28)
    end
end

return Effects
