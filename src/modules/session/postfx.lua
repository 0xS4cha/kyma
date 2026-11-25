local Shaders = require("src.modules.session.shaders")
local Theme = require("src.ui.theme")

local PostFX = {}
PostFX.__index = PostFX

local MAX_WAVES = 8
local WAVE_LIFE = 0.55
local WAVE_SPEED = 900
local ABERRATION_DECAY = 7
local HURT_DECAY = 2.6
local TINT = { 0.88, 0.14, 0.12 }

--- @return table
function PostFX.new()
    return setmetatable({
        waves = {}, aberration = 0, hurt = 0, low = 0, desat = 0, time = 0, motion = 1
    }, PostFX)
end

--- @return boolean
function PostFX.enabled()
    local GM = require("src.core.index")
    local settings = GM and GM.Menu and GM.Menu.settings
    return not settings or settings.postfx ~= false
end

--- @param strength number
function PostFX:setMotion(strength)
    self.motion = strength
end

--- @param x number
--- @param y number
--- @param strength number
--- @param reach number?
function PostFX:wave(x, y, strength, reach)
    if strength <= 0 then return end
    self.waves[#self.waves + 1] = {
        x = x, y = y, strength = math.min(1, strength), reach = reach or WAVE_SPEED * WAVE_LIFE, age = 0
    }
    if #self.waves > MAX_WAVES then table.remove(self.waves, 1) end
end

--- @param amount number
function PostFX:kick(amount)
    self.aberration = math.min(14, self.aberration + amount)
end

--- @param amount number
function PostFX:hit(amount)
    self.hurt = math.min(1, self.hurt + amount)
end

--- @param dt number
--- @param health number
--- @param dead boolean
function PostFX:update(dt, health, dead)
    self.time = self.time + dt
    for k = #self.waves, 1, -1 do
        local wave = self.waves[k]
        wave.age = wave.age + dt
        if wave.age >= WAVE_LIFE then table.remove(self.waves, k) end
    end
    self.aberration = self.aberration * math.exp(-ABERRATION_DECAY * dt)
    self.hurt = math.max(0, self.hurt - dt * HURT_DECAY)
    local lowTarget = (not dead and health < 0.35) and (1 - health / 0.35) * 0.55 or 0
    self.low = self.low + (lowTarget - self.low) * math.min(1, dt * 4)
    local desatTarget = dead and 0.85 or (health < 0.35 and (1 - health / 0.35) * 0.35 or 0)
    self.desat = self.desat + (desatTarget - self.desat) * math.min(1, dt * (dead and 2.5 or 4))
end

--- @return boolean
function PostFX:begin()
    if not PostFX.enabled() or not Shaders.get("post") then return false end
    local lg = love.graphics
    local W, H = lg.getDimensions()
    if not self.canvas or self.canvas:getWidth() ~= W or self.canvas:getHeight() ~= H then
        self.canvas = lg.newCanvas(W, H)
    end
    self.previousCanvas = lg.getCanvas()
    lg.setCanvas({ self.canvas, stencil = true })
    return true
end

--- @param camera table
function PostFX:finish(camera)
    local lg = love.graphics
    local shader = Shaders.get("post")
    if self.previousCanvas then
        lg.setCanvas({ self.previousCanvas, stencil = true })
    else
        lg.setCanvas()
    end
    self.previousCanvas = nil
    local W, H = self.canvas:getWidth(), self.canvas:getHeight()
    local packed = {}
    for k = 1, MAX_WAVES do
        local wave = self.waves[k]
        if wave then
            local t = wave.age / WAVE_LIFE
            local sx, sy = camera:toScreen(wave.x, wave.y)
            local radius = wave.reach * (1 - (1 - t) ^ 2.2) * camera.scale
            packed[k] = { sx, sy, radius, wave.strength * (1 - t) ^ 1.5 * self.motion }
        else
            packed[k] = { 0, 0, 0, 0 }
        end
    end
    shader:send("waves", unpack(packed))
    shader:send("aberration", self.aberration * self.motion)
    shader:send("hurt", self.hurt)
    shader:send("low", self.low)
    shader:send("desat", self.desat)
    shader:send("vignette", Theme.dark() and 0.32 or 0.14)
    shader:send("time", self.time)
    shader:send("size", { W, H })
    shader:send("tint", TINT)
    lg.push("all")
    lg.origin()
    lg.setBlendMode("alpha", "premultiplied")
    lg.setColor(1, 1, 1, 1)
    lg.setShader(shader)
    lg.draw(self.canvas)
    lg.pop()
end

--- @return boolean
function PostFX:drawsHurt()
    return PostFX.enabled() and Shaders.get("post") ~= false
end

return PostFX
