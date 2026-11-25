local T = require("src.ui.theme").colors
local Kit = require("src.ui.kit")
local Shield = require("src.modules.session.shield")
local Shaders = require("src.modules.session.shaders")

local Effects = {}
Effects.__index = Effects

local cos, sin, pi, random = math.cos, math.sin, math.pi, love.math.random

local TRACER_LIFE = 0.18
local TRAIL_LIFE = 1.2
local IMPACT_LIFE = 10
local DUST_LIFE = 0.6
local MAX_IMPACTS = 80
local FLASH_LIFE = 0.06
local GLOW_LIFE = 0.1
local SHARD_LIFE = 1.4
local HIT_LIFE = 0.25
local MARK_LIFE = { hit = 0.32, shield = 0.32, kill = 0.6 }
local MARK_SIZE = { hit = 92, shield = 92, kill = 132 }
local MARK_COLOR = { hit = { 0.88, 0.14, 0.12 }, shield = { 0.35, 0.78, 1 }, kill = { 0.88, 0.14, 0.12 } }
local DAMAGE_TIERS = {
    { 75, { 1, 0.25, 0.2 } },
    { 50, { 1, 0.55, 0.2 } },
    { 25, { 1, 0.82, 0.3 } },
    { 0, { 1, 0.96, 0.9 } }
}
local HURT_LIFE = 0.45
local ECHO_LIFE = 1.1
local PRINT_LIFE = 2.6
local PRINT_LENGTH = 17
local PRINT_WIDTH = 8
local PRINT_GAP = 6
local NUMBER_LIFE = 0.9
local PING_LIFE = 6
local ECHO_SIZE = { shot = 70, dash = 46, step = 30, throw = 40, clank = 40 }
local LIGHT_LIFE = 0.09
local LIGHT_RADIUS = 230
local LIGHT_RAYS = 72
local LIGHT_COLOR = { 1, 0.78, 0.45 }
local LIGHT_TINT = { 1, 0.66, 0.3 }
--- How much light each weapon's muzzle gives off.
local MUZZLE = { pistol = 1, rifle = 0.85, lmg = 0.95, shotgun = 1.25, sniper = 1.45, silencer = 0.25 }

--- @return table
function Effects.new()
    return setmetatable({
        tracers = {}, flashes = {}, lights = {}, glows = {}, shards = {}, echoes = {}, impacts = {}, dust = {}, texts = {}, pings = {}, hit = -1, hurt = -1
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
    self:glow(x1, y1, 30, { 1, 0.78, 0.42 }, GLOW_LIFE)
    if hit == 1 then
        self:impact(x2, y2, x2 - x1, y2 - y1)
    elseif hit == 2 then
        self:spray(x2, y2, { 0.88, 0.14, 0.12 }, 8)
        self:glow(x2, y2, 22, { 1, 0.3, 0.22 }, 0.14)
    end
end

--- A muzzle flash that lights up the floor around the shooter for a few
--- frames, stopped by walls like the view is.
--- @param arena table?
--- @param x number
--- @param y number
--- @param weapon string?
function Effects:muzzle(arena, x, y, weapon)
    if not arena then return end
    local strength = MUZZLE[weapon or ""] or 1
    local now = love.timer.getTime()
    for _, light in ipairs(self.lights) do
        if now - light.time < 0.02 and math.abs(light.x - x) < 2 and math.abs(light.y - y) < 2 then return end
    end
    local radius = LIGHT_RADIUS * (0.75 + 0.25 * strength) * (0.9 + 0.2 * love.math.random())
    local shape = { x, y }
    for k = 0, LIGHT_RAYS do
        local a = k / LIGHT_RAYS * 2 * math.pi
        local dx, dy = math.cos(a), math.sin(a)
        local length = arena:raycast(x, y, dx, dy, radius, "vision")
        shape[#shape + 1] = x + dx * length
        shape[#shape + 1] = y + dy * length
    end
    self.lights[#self.lights + 1] = { x = x, y = y, radius = radius, strength = strength, shape = shape, time = now }
    if #self.lights > 24 then table.remove(self.lights, 1) end
end

--- Draws the muzzle lights on the floor, clipped by the walls around them.
function Effects:drawLights()
    if #self.lights == 0 then return end
    local shader = Shaders.get("light")
    if not shader then return end
    local lg = love.graphics
    local now = love.timer.getTime()
    local dark = require("src.ui.theme").dark()
    for _, light in ipairs(self.lights) do
        local t = (now - light.time) / LIGHT_LIFE
        if t < 1 then
            local shape = light.shape
            lg.stencil(function()
                for k = 3, #shape - 3, 2 do
                    lg.polygon("fill", shape[1], shape[2], shape[k], shape[k + 1], shape[k + 2], shape[k + 3])
                end
            end, "replace", 1)
            lg.setStencilTest("equal", 1)
            lg.setBlendMode(dark and "add" or "alpha")
            lg.setShader(shader)
            local a = (1 - t) ^ 1.6 * math.min(1, light.strength) * (dark and 0.55 or 0.5)
            local c = dark and LIGHT_COLOR or LIGHT_TINT
            lg.setColor(c[1], c[2], c[3], a)
            local size = light.radius * 2
            lg.draw(Shaders.pixel(), light.x, light.y, 0, size, size, 0.5, 0.5)
            lg.setShader()
            lg.setBlendMode("alpha")
            lg.setStencilTest()
        end
    end
end

--- @param x number
--- @param y number
--- @param radius number
--- @param color table
--- @param life number
function Effects:glow(x, y, radius, color, life)
    self.glows[#self.glows + 1] = { x = x, y = y, radius = radius, color = color, life = life, time = love.timer.getTime() }
    if #self.glows > 64 then table.remove(self.glows, 1) end
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
    self:glow(x - ux * 3, y - uy * 3, 16, { 1, 0.66, 0.3 }, 0.12)
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
    self:glow(x, y, 70, color, 0.3)
end

Effects.PING_LIFE = PING_LIFE

--- Ping d'équipe affiché dans le monde (un seul par joueur : le dernier remplace l'ancien).
--- @param ping table { x, y, s, mine, t, label, name }
function Effects:ping(ping)
    for k = #self.pings, 1, -1 do
        if self.pings[k].s == ping.s then table.remove(self.pings, k) end
    end
    ping.time = love.timer.getTime()
    self.pings[#self.pings + 1] = ping
    if #self.pings > 8 then table.remove(self.pings, 1) end
end

--- Chiffre de dégâts flottant à côté de la cible.
--- @param x number
--- @param y number
--- @param text string
--- @param color table
--- @param big boolean?
--- @param scale number? taille relative (réglage "Damage number size")
function Effects:damageNumber(x, y, text, color, big, scale)
    if not color then
        local amount = tonumber(text) or 0
        for _, tier in ipairs(DAMAGE_TIERS) do
            if amount >= tier[1] then color = tier[2] break end
        end
    end
    self.texts[#self.texts + 1] = {
        x = x + 15 + random() * 8, y = y - 12 - random() * 6, text = text, color = color,
        big = big, scale = scale or 1, time = love.timer.getTime(), drift = (random() - 0.3) * 10
    }
    if #self.texts > 40 then table.remove(self.texts, 1) end
end

--- @param x number
--- @param y number
--- @param kind string
--- @param angle number?
--- @param side number?
function Effects:echo(x, y, kind, angle, side)
    if kind == "step" and angle then
        self.prints = self.prints or {}
        local lateral = (side == 1 and 1 or -1) * PRINT_GAP
        self.prints[#self.prints + 1] = {
            x = x - sin(angle) * lateral, y = y + cos(angle) * lateral,
            angle = angle, mirror = side == 1 and -1 or 1, time = love.timer.getTime()
        }
        if #self.prints > 60 then table.remove(self.prints, 1) end
        return
    end
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

--- @param x number
--- @param y number
function Effects:burst(x, y)
    self.bursts = self.bursts or {}
    self.bursts[#self.bursts + 1] = { x = x, y = y, time = love.timer.getTime() }
    self:glow(x, y, 420, { 1, 1, 0.92 }, 0.6)
end

--- @param kind string?
--- @param x number?
--- @param y number?
function Effects:hitMarker(kind, x, y)
    local now = love.timer.getTime()
    self.hit = now
    self.marks = self.marks or {}
    kind = MARK_LIFE[kind or "hit"] and kind or "hit"
    self.marks[#self.marks + 1] = { kind = kind, x = x, y = y, time = now }
    if #self.marks > 12 then table.remove(self.marks, 1) end
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
    prune(self.lights, LIGHT_LIFE)
    for k = #self.glows, 1, -1 do
        if now - self.glows[k].time > self.glows[k].life then table.remove(self.glows, k) end
    end
    prune(self.shards, SHARD_LIFE)
    prune(self.texts, NUMBER_LIFE)
    for k = #(self.marks or {}), 1, -1 do
        local mark = self.marks[k]
        if now - mark.time > MARK_LIFE[mark.kind] then table.remove(self.marks, k) end
    end
    prune(self.pings, PING_LIFE)
    prune(self.echoes, ECHO_LIFE)
    if self.prints then prune(self.prints, PRINT_LIFE) end
    local drag = math.exp(-4 * dt)
    for _, shard in ipairs(self.shards) do
        shard.x, shard.y = shard.x + shard.vx * dt, shard.y + shard.vy * dt
        shard.vx, shard.vy = shard.vx * drag, shard.vy * drag
        shard.angle = shard.angle + shard.spin * dt
        shard.spin = shard.spin * drag
    end
end

--- Couleur d'un ping : rouge = ennemi, ambre = objet, bleu = lieu.
--- @param ping table
--- @return table
function Effects.pingColor(ping)
    if ping.t == 2 then return { 0.95, 0.25, 0.2 } end
    if ping.t == 1 then return { 1, 0.78, 0.2 } end
    return { 0.35, 0.78, 1 }
end

--- @param ping table
--- @param now number
function Effects.drawPing(ping, now)
    local lg = love.graphics
    local age = now - ping.time
    local fade = age > PING_LIFE - 1 and math.max(0, PING_LIFE - age) or 1
    local c = Effects.pingColor(ping)
    local pop = 1 + 0.6 * math.max(0, 1 - age * 6)
    -- ondes qui partent du point
    for ring = 0, 2 do
        local k = (age * 0.9 - ring * 0.3) % 1.4 / 1.4
        if age * 0.9 - ring * 0.3 >= 0 and age < 3.2 then
            lg.setColor(c[1], c[2], c[3], (1 - k) * 0.6 * fade)
            lg.setLineWidth(2.5 - 1.5 * k)
            lg.circle("line", ping.x, ping.y, 6 + 26 * k)
        end
    end
    -- losange
    local r = 9 * pop
    lg.setColor(0.05, 0.07, 0.1, 0.5 * fade)
    lg.polygon("fill", ping.x, ping.y - r - 2, ping.x + r + 2, ping.y, ping.x, ping.y + r + 2, ping.x - r - 2, ping.y)
    lg.setColor(c[1], c[2], c[3], fade)
    lg.polygon("fill", ping.x, ping.y - r, ping.x + r, ping.y, ping.x, ping.y + r, ping.x - r, ping.y)
    lg.setColor(1, 1, 1, 0.9 * fade)
    lg.circle("fill", ping.x, ping.y, 2.2)
    -- libellé : arme visée / objet ; nom de l'auteur en dessous
    local function label(text, size, y, alpha)
        local font = Kit.font(size)
        lg.setFont(font)
        lg.push()
        lg.translate(ping.x, ping.y + y)
        lg.scale(0.5)
        local w, h = font:getWidth(text), font:getHeight()
        lg.setColor(0.04, 0.05, 0.08, 0.8 * fade * alpha)
        for _, o in ipairs({ { -1.5, 0 }, { 1.5, 0 }, { 0, -1.5 }, { 0, 1.5 } }) do
            lg.print(text, -w / 2 + o[1], -h / 2 + o[2])
        end
        lg.setColor(c[1] * 0.4 + 0.6, c[2] * 0.4 + 0.6, c[3] * 0.4 + 0.6, fade * alpha)
        lg.print(text, -w / 2, -h / 2)
        lg.pop()
    end
    if ping.label and ping.label ~= "" then label(ping.label, 22, -24, 1) end
    if ping.name and ping.name ~= "" then label(ping.name, 16, 22, 0.8) end
    lg.setLineWidth(1)
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
    self:drawPrints(now)
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
    Shield.drawEffects()
    for _, tracer in ipairs(self.tracers) do
        local age = now - tracer.time
        local c = tracer.color
        local smoke = 1 - age / tracer.trail
        lg.setColor(T.smoke[1], T.smoke[2], T.smoke[3], 0.35 * smoke * smoke)
        lg.setLineWidth(3 + 4 * (1 - smoke))
        lg.line(tracer.x1, tracer.y1, tracer.x2, tracer.y2)
        if age < TRACER_LIFE then
            local fade = 1 - age / TRACER_LIFE
            lg.setBlendMode(Shaders.lightBlend())
            local beam = Shaders.beam(tracer.x1, tracer.y1, tracer.x2, tracer.y2, 10 * (0.6 + 0.4 * fade),
                c[1], c[2], c[3], 0.8 * fade)
            lg.setBlendMode("alpha")
            lg.setColor(c[1], c[2], c[3], (beam and 0.6 or 0.85) * fade)
            lg.setLineWidth(beam and 1.2 or 2.2)
            lg.line(tracer.x1, tracer.y1, tracer.x2, tracer.y2)
        end
    end
    for k = #(self.bursts or {}), 1, -1 do
        local burst = self.bursts[k]
        local t = (now - burst.time) / 0.5
        if t >= 1 then
            table.remove(self.bursts, k)
        else
            if not Shaders.get("glow") then
                lg.setColor(1, 1, 0.96, 0.9 * (1 - t))
                lg.circle("fill", burst.x, burst.y, 30 + 220 * t)
            end
        end
    end
    lg.setBlendMode(Shaders.lightBlend())
    for _, glow in ipairs(self.glows) do
        local t = (now - glow.time) / glow.life
        local c = glow.color
        Shaders.glow(glow.x, glow.y, glow.radius * (0.8 + 0.4 * t), c[1], c[2], c[3], 0.9 * (1 - t) ^ 2)
    end
    lg.setBlendMode("alpha")
    for _, flash in ipairs(self.flashes) do
        lg.setColor(1, 0.95, 0.8, 1 - (now - flash.time) / FLASH_LIFE)
        lg.circle("fill", flash.x, flash.y, 7)
    end
    for _, ping in ipairs(self.pings) do
        Effects.drawPing(ping, now)
    end
    for _, n in ipairs(self.texts) do
        local t = (now - n.time) / NUMBER_LIFE
        local rise = 1 - (1 - t) ^ 3
        local pop = 1 + 0.55 * math.max(0, 1 - t * 7)
        local alpha = t < 0.6 and 1 or 1 - (t - 0.6) / 0.4
        local font = Kit.font(math.floor((n.big and 26 or 20) * n.scale + 0.5))
        local nx, ny = n.x + n.drift * rise, n.y - 26 * rise
        lg.setBlendMode(Shaders.lightBlend())
        Shaders.glow(nx, ny, (n.big and 22 or 15) * n.scale * pop, n.color[1], n.color[2], n.color[3], 0.45 * alpha)
        lg.setBlendMode("alpha")
        lg.setFont(font)
        lg.push()
        lg.translate(nx, ny)
        lg.scale(0.5 * pop)
        local w, h = font:getWidth(n.text), font:getHeight()
        lg.setColor(0.04, 0.05, 0.08, 0.75 * alpha)
        for _, o in ipairs({ { -1.5, 0 }, { 1.5, 0 }, { 0, -1.5 }, { 0, 1.5 } }) do
            lg.print(n.text, -w / 2 + o[1], -h / 2 + o[2])
        end
        lg.setColor(n.color[1], n.color[2], n.color[3], alpha)
        lg.print(n.text, -w / 2, -h / 2)
        lg.pop()
    end
    lg.setLineWidth(1)
end

--- @param now number
function Effects:drawPrints(now)
    if not self.prints or #self.prints == 0 then return end
    local lg = love.graphics
    local shader = Shaders.get("footprint")
    local ink = T.ink
    for _, footprint in ipairs(self.prints) do
        local age = now - footprint.time
        local t = age / PRINT_LIFE
        local pop = 1 + 0.35 * math.max(0, 1 - age / 0.12)
        local alpha = 0.6 * (1 - t) ^ 1.6
        local sx, sy = PRINT_LENGTH * pop, PRINT_WIDTH * pop * footprint.mirror
        if age < 0.25 then
            lg.setColor(ink[1], ink[2], ink[3], 0.25 * (1 - age / 0.25))
            lg.setLineWidth(1.2)
            lg.circle("line", footprint.x, footprint.y, 6 + 14 * age / 0.25)
        end
        lg.setColor(ink[1], ink[2], ink[3], alpha)
        if shader then
            lg.setShader(shader)
            lg.draw(Shaders.pixel(), footprint.x, footprint.y, footprint.angle, sx, sy, 0.5, 0.5)
            lg.setShader()
        else
            lg.push()
            lg.translate(footprint.x, footprint.y)
            lg.rotate(footprint.angle)
            lg.ellipse("fill", PRINT_LENGTH * 0.14, 0, PRINT_LENGTH * 0.33, PRINT_WIDTH * 0.43)
            lg.ellipse("fill", -PRINT_LENGTH * 0.3, 0, PRINT_LENGTH * 0.17, PRINT_WIDTH * 0.34)
            lg.pop()
        end
    end
    lg.setLineWidth(1)
end

function Effects:drawImpacts()
    local lg = love.graphics
    local now = love.timer.getTime()
    for _, impact in ipairs(self.impacts) do
        local fade = math.min(1, (IMPACT_LIFE - (now - impact.time)) / 2)
        lg.setColor(T.impactRim[1], T.impactRim[2], T.impactRim[3], 0.75 * fade)
        lg.polygon("fill", impact.points)
        lg.setColor(T.impactHole[1], T.impactHole[2], T.impactHole[3], 0.9 * fade)
        lg.circle("fill", impact.x, impact.y, 1.3)
    end
    for _, d in ipairs(self.dust) do
        local t = (now - d.time) / DUST_LIFE
        local c = d.color
        lg.setColor(c[1], c[2], c[3], (1 - t) * 0.8)
        lg.circle("fill", d.x, d.y, d.size * (1 + t))
    end
end

--- @param now number
--- @param camera table?
--- @param W number
--- @param H number
function Effects:drawMarks(now, camera, W, H)
    if not self.marks or #self.marks == 0 then return end
    local lg = love.graphics
    local shader = Shaders.get("hitmark")
    local dark = require("src.ui.theme").dark()
    for _, mark in ipairs(self.marks) do
        local age = now - mark.time
        local t = age / MARK_LIFE[mark.kind]
        local cx, cy = W / 2, H * 0.3
        if mark.x and camera then cx, cy = camera:toScreen(mark.x, mark.y) end
        local pop = 1 + 0.45 * math.max(0, 1 - age / 0.09)
        local size = MARK_SIZE[mark.kind] * pop
        local c = MARK_COLOR[mark.kind]
        if shader then
            lg.setBlendMode(dark and "add" or "alpha")
            lg.setColor(c[1], c[2], c[3], 1)
            lg.setShader(shader)
            shader:send("progress", t)
            shader:send("kill", mark.kind == "kill" and 1 or 0)
            shader:send("whiten", dark and 0.7 or 0.25)
            lg.draw(Shaders.pixel(), cx, cy, 0, size, size, 0.5, 0.5)
            lg.setShader()
            lg.setBlendMode("alpha")
        else
            local s = size * 0.22
            lg.setColor(c[1], c[2], c[3], 1 - t)
            lg.setLineWidth(3)
            lg.line(cx - s, cy - s, cx - s / 3, cy - s / 3)
            lg.line(cx + s, cy - s, cx + s / 3, cy - s / 3)
            lg.line(cx - s, cy + s, cx - s / 3, cy + s / 3)
            lg.line(cx + s, cy + s, cx + s / 3, cy + s / 3)
            lg.setLineWidth(1)
        end
    end
end

--- @param composited boolean?
--- @param camera table?
function Effects:drawScreen(composited, camera)
    local lg = love.graphics
    local W, H = lg.getDimensions()
    local now = love.timer.getTime()

    local hurt = now - self.hurt
    if hurt < HURT_LIFE and not composited then
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

    self:drawMarks(now, camera, W, H)
end

return Effects
