local Class = require("src.core.class")

--- @class Camera
--- @field x number
--- @field y number
--- @field angle number
--- @field scale number
--- @field anchorX number
--- @field anchorY number
--- @field minScale number
--- @field maxScale number
local Camera = Class()

local cos, sin, pi, max, min = math.cos, math.sin, math.pi, math.max, math.min

local SHAKE_DECAY = 1.8
local SHAKE_OFFSET = 14
local SHAKE_ROLL = 0.035
local SHAKE_SPEED = 28

--- @param options table?
function Camera:init(options)
    options = options or {}
    self.x = 0
    self.y = 0
    self.angle = -pi / 2
    self.scale = options.scale or 1
    self.anchorX = options.anchorX or 0.5
    self.anchorY = options.anchorY or 0.5
    self.minScale = options.minScale or 0.25
    self.maxScale = options.maxScale or 8
    self.trauma = 0
    self.shakeTime = 0
    self.shakeX, self.shakeY, self.roll = 0, 0, 0
    self.recoil, self.recoilSpeed = 0, 0
end

--- @param amount number
function Camera:kick(amount)
    self.recoilSpeed = self.recoilSpeed + amount * 30
end

--- @param amount number
function Camera:shake(amount)
    self.trauma = min(1, self.trauma + max(0, amount))
end

--- @param dt number
--- @param strength number?
function Camera:update(dt, strength)
    self.recoilSpeed = (self.recoilSpeed - self.recoil * 900 * dt) * math.exp(-24 * dt)
    self.recoil = self.recoil + self.recoilSpeed * dt
    if math.abs(self.recoil) < 0.01 and math.abs(self.recoilSpeed) < 0.5 then self.recoil, self.recoilSpeed = 0, 0 end
    self.trauma = max(0, self.trauma - dt * SHAKE_DECAY)
    self.shakeTime = self.shakeTime + dt
    local power = self.trauma * self.trauma * (strength or 1)
    if power <= 0 then
        self.shakeX, self.shakeY, self.roll = 0, self.recoil * (strength or 1), 0
        return
    end
    local t = self.shakeTime * SHAKE_SPEED
    local noise = love.math.noise
    self.shakeX = SHAKE_OFFSET * power * (noise(t, 11.3) * 2 - 1)
    self.shakeY = SHAKE_OFFSET * power * (noise(t, 37.9) * 2 - 1) + self.recoil * (strength or 1)
    self.roll = SHAKE_ROLL * power * (noise(t, 71.1) * 2 - 1)
end

--- @param x number
--- @param y number
--- @param angle number
function Camera:follow(x, y, angle)
    self.x, self.y, self.angle = x, y, angle
end

--- @return number
function Camera:rotation()
    return -pi / 2 - self.angle + (self.roll or 0)
end

--- @return number, number
function Camera:anchor()
    local W, H = love.graphics.getDimensions()
    return W * self.anchorX + (self.shakeX or 0), H * self.anchorY + (self.shakeY or 0)
end

--- @param factor number
function Camera:zoom(factor)
    self.scale = math.max(self.minScale, math.min(self.maxScale, self.scale * factor))
end

function Camera:apply()
    local ax, ay = self:anchor()
    love.graphics.push()
    love.graphics.translate(ax, ay)
    love.graphics.scale(self.scale)
    love.graphics.rotate(self:rotation())
    love.graphics.translate(-self.x, -self.y)
end

function Camera:clear()
    love.graphics.pop()
end

--- @param wx number
--- @param wy number
--- @return number, number
function Camera:toScreen(wx, wy)
    local r = self:rotation()
    local c, s = cos(r), sin(r)
    local dx, dy = wx - self.x, wy - self.y
    local ax, ay = self:anchor()
    return ax + (dx * c - dy * s) * self.scale, ay + (dx * s + dy * c) * self.scale
end

--- @param sx number
--- @param sy number
--- @return number, number
function Camera:toWorld(sx, sy)
    local r = self:rotation()
    local c, s = cos(r), sin(r)
    local ax, ay = self:anchor()
    local dx, dy = (sx - ax) / self.scale, (sy - ay) / self.scale
    return self.x + dx * c + dy * s, self.y - dx * s + dy * c
end

return Camera
