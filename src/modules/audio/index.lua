local GM = require("src.core.index")
local Synth = require("src.modules.audio.synth")
local Sounds = require("src.modules.audio.sounds")

GM.Audio = {}

GM.Modules:Register("Audio", 15)

local DEFAULT_COOLDOWN = 0.04
local DEFAULT_VOICES = 3
local HEARING = 1500

GM.Audio.levels = { 0, 0.25, 0.5, 0.75, 1 }
GM.Audio.labels = { "Off", "25%", "50%", "75%", "100%" }

function GM.Audio:Initialize()
    self.bank = {}
    self.lastPlayed = {}
    self.enabled = love.audio ~= nil and love.sound ~= nil
    if not self.enabled then return end
    local started = love.timer.getTime()
    for name, recipe in pairs(Sounds) do
        local ok, data = pcall(Synth.soundData, recipe)
        if ok then
            local source = love.audio.newSource(data, "static")
            self.bank[name] = { recipe = recipe, voices = { source } }
        else
            Logger:warn("Audio", "Could not render " .. name .. ": " .. tostring(data))
        end
    end
    Logger:info("Audio", string.format("Rendered %d sounds in %.1f ms", self:count(), (love.timer.getTime() - started) * 1000))
end

--- @return number
function GM.Audio:count()
    local n = 0
    for _ in pairs(self.bank) do n = n + 1 end
    return n
end

--- @return number
function GM.Audio:Master()
    local index = GM.Menu and GM.Menu.settings and GM.Menu.settings.volume or 4
    return self.levels[index] or 0.75
end

local function freeVoice(entry)
    for _, voice in ipairs(entry.voices) do
        if not voice:isPlaying() then return voice end
    end
    if #entry.voices < (entry.recipe.voices or DEFAULT_VOICES) then
        local voice = entry.voices[1]:clone()
        entry.voices[#entry.voices + 1] = voice
        return voice
    end
    return nil
end

--- @param name string
--- @param gain number?
--- @param pan number?
--- @param pitch number?
function GM.Audio:Play(name, gain, pan, pitch)
    if not self.enabled then return end
    local master = self:Master()
    if master <= 0 or (gain or 1) <= 0.01 then return end
    local entry = self.bank[name]
    if not entry then return end
    local now = love.timer.getTime()
    if now - (self.lastPlayed[name] or -math.huge) < (entry.recipe.cooldown or DEFAULT_COOLDOWN) then return end
    local voice = freeVoice(entry)
    if not voice then return end
    self.lastPlayed[name] = now
    local jitter = entry.recipe.jitter or 0
    voice:setPitch((pitch or 1) * (1 + (love.math.random() * 2 - 1) * jitter))
    voice:setVolume(math.min(1, (entry.recipe.volume or 1) * (gain or 1) * master))
    voice:setRelative(true)
    voice:setPosition(math.max(-1, math.min(1, pan or 0)), 0, 0)
    voice:stop()
    voice:play()
end

--- @param name string
--- @param x number
--- @param y number
--- @param gain number?
function GM.Audio:PlayAt(name, x, y, gain)
    local session = GM.Session
    local camera = session and session.camera
    if not camera or not session.world then
        self:Play(name, gain)
        return
    end
    local listener = session.world.me
    local d = math.sqrt((x - listener.x) ^ 2 + (y - listener.y) ^ 2)
    if d > HEARING then return end
    local falloff = (1 - d / HEARING) ^ 1.6
    local sx = camera:toScreen(x, y)
    local ax = camera:anchor()
    local W = love.graphics.getWidth()
    local pan = (sx - ax) / (W * 0.5)
    self:Play(name, (gain or 1) * (0.15 + 0.85 * falloff), pan * 0.8)
end

return GM.Audio
