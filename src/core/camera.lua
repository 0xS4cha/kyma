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

local cos, sin, pi = math.cos, math.sin, math.pi

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
end

--- @param x number
--- @param y number
--- @param angle number
function Camera:follow(x, y, angle)
    self.x, self.y, self.angle = x, y, angle
end

--- @return number
function Camera:rotation()
    return -pi / 2 - self.angle
end

--- @return number, number
function Camera:anchor()
    local W, H = love.graphics.getDimensions()
    return W * self.anchorX, H * self.anchorY
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
