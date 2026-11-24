local Class = require("src.core.class")
local Camera = require("src.core.camera")
local World = require("src.game.world")
local Bot = require("src.game.bot")
local Arena = require("src.game.arena")
local Maps = require("src.maps.index")
local Config = require("src.config.game")
local Renderer = require("src.modules.session.renderer")
local Character = require("src.modules.session.character")
local Effects = require("src.modules.session.effects")
local Kit = require("src.ui.kit")

local Background = Class()

local SLOTS = { 11, 12 }
local LEVELS = { "medium", "hard" }
local DT = 1 / Config.tickRate
local FEED = 4

function Background:init()
    self.camera = Camera({ scale = 1.15, anchorX = 0.62, anchorY = 0.55, minScale = 0.5, maxScale = 3 })
    self.running = false
    self.fade = 1
    self:reset()
end

function Background:reset()
    self.mapIndex = ((self.mapIndex or love.math.random(#Maps.order)) % #Maps.order) + 1
    self.world = World.new(Arena.new(Maps.get(Maps.order[self.mapIndex])))
    self.bots = {}
    for k, slot in ipairs(SLOTS) do
        local bot = Bot.new(slot, LEVELS[k], os.time() + k * 31)
        self.world:add(slot, bot:name()).bot = true
        self.bots[k] = bot
    end
    self.effects = Effects.new()
    self.accumulator = 0
    self.time = 0
    self.feed = {}
    self.focusX, self.focusY = self.world.arena.width / 2, self.world.arena.height / 2
    self.camera:follow(self.focusX, self.focusY, 0)
end

function Background:start()
    if not self.running then
        self:reset()
        self.fade = 1
    end
    self.running = true
end

function Background:stop()
    self.running = false
end

--- @param slot number
--- @return table
function Background:palette(slot)
    return slot == SLOTS[1] and Character.PALETTES.self or Character.PALETTES.opponent
end

--- @param slot number
--- @return string
function Background:name(slot)
    for _, bot in ipairs(self.bots) do
        if bot.slot == slot then return bot:name() end
    end
    return "?"
end

function Background:tick()
    local world = self.world
    for _, bot in ipairs(self.bots) do
        world:queue(bot.slot, { bot:command(world) })
    end
    world:step()
    local events, shots = world:drain()
    for _, shot in ipairs(shots) do
        local color = shot.o == SLOTS[1] and { 0.15, 0.15, 0.17 } or Kit.RED
        self.effects:tracer(shot.x, shot.y, shot.X, shot.Y, color, shot.h)
    end
    for _, event in ipairs(events) do
        if event.kind == "kill" then
            local victim = world.players[event.v]
            if victim then
                self.effects:shatter(victim.x, victim.y, self:palette(event.v).body)
            end
            if event.k and event.k ~= event.v then
                table.insert(self.feed, 1, { killer = event.k, victim = event.v, time = love.timer.getTime() })
                if #self.feed > FEED then table.remove(self.feed) end
            end
        end
    end
end

--- @param dt number
function Background:update(dt)
    if not self.running then return end
    self.time = self.time + dt
    self.accumulator = math.min(self.accumulator + dt, DT * 6)
    while self.accumulator >= DT do
        self.accumulator = self.accumulator - DT
        self:tick()
    end
    self.effects:update(dt)
    self.fade = Kit.approach(self.fade, 0, 2, dt)

    local sx, sy, count = 0, 0, 0
    for _, p in pairs(self.world.players) do
        if p.dead == 0 then
            sx, sy, count = sx + p.x, sy + p.y, count + 1
        end
    end
    if count > 0 then
        self.focusX = Kit.approach(self.focusX, sx / count, 1.2, dt)
        self.focusY = Kit.approach(self.focusY, sy / count, 1.2, dt)
    end
    self.camera:follow(self.focusX, self.focusY, -math.pi / 2 + self.time * 0.05)
end

local function view(p)
    return {
        slot = p.slot, x = p.x, y = p.y, angle = p.angle, vx = p.vx, vy = p.vy,
        weapon = p.weapon, dashing = p.dash > 0, sliding = p.slide > 0
    }
end

function Background:draw()
    local lg = love.graphics
    local W, H = lg.getDimensions()
    lg.clear(Renderer.COLORS.background)
    if not self.running then return end
    local world = self.world
    self.camera:apply()
    Renderer.drawFloor(world.arena)
    for _, item in ipairs(world.items) do
        if item.kind == "ammo" then
            Character.drawAmmo(item.x, item.y, item.angle or 0)
        elseif item.kind == "health" then
            Renderer.drawHealth(item.x, item.y)
        else
            Character.drawWeapon(item.kind, item.x, item.y, item.angle or 0)
        end
    end
    for _, p in pairs(world.players) do
        if p.dead == 0 then
            Character.draw(view(p), self:palette(p.slot))
        end
    end
    self.effects:drawWorld()
    Renderer.drawWalls(world.arena, self.camera)
    self.effects:drawImpacts()
    self.camera:clear()
    if self.fade > 0.01 then
        local paper = Kit.PAPER
        lg.setColor(paper[1], paper[2], paper[3], self.fade)
        lg.rectangle("fill", 0, 0, W, H)
    end
end

--- @return table
function Background:score()
    return { self.world.score[SLOTS[1]] or 0, self.world.score[SLOTS[2]] or 0 }
end

Background.SLOTS = SLOTS

return Background
