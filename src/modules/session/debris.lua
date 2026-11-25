--- Physical debris, on the client only: shell casings thrown out of the gun,
--- chips knocked off walls, shards of broken glass and the facets of an
--- eliminated player. They are Box2D bodies sliding on the floor: they
--- bounce off walls, cover, closed doors and whole panes, slow down with the
--- floor's friction, get kicked by players walking through them and blown
--- by flashbangs, and fall into chasms. Nothing here is sent over the
--- network, it is only for the eye.
local Theme = require("src.ui.theme")

local Debris = {}
Debris.__index = Debris

local MAX = 260
local METER = 32
local STEP = 1 / 120
local FADE = 0.6
local random, cos, sin, pi = love.math.random, math.cos, math.sin, math.pi

local BRASS = { 0.86, 0.66, 0.3 }
local SHELL = { 0.78, 0.18, 0.14 }
local CASINGS = {
    pistol = { w = 2.2, h = 4.5, color = BRASS },
    silencer = { w = 2.2, h = 4.5, color = BRASS },
    rifle = { w = 2.4, h = 6, color = BRASS },
    lmg = { w = 2.4, h = 6, color = BRASS },
    sniper = { w = 3, h = 8, color = BRASS },
    shotgun = { w = 3.4, h = 7, color = SHELL }
}

--- @param body love.Body
--- @param rect table
local function addRect(body, rect)
    local shape = love.physics.newRectangleShape(rect.x + rect.w / 2, rect.y + rect.h / 2, rect.w, rect.h)
    local fixture = love.physics.newFixture(body, shape)
    fixture:setFriction(0.4)
    return fixture
end

--- @param arena table
--- @return table?
function Debris.new(arena)
    if not love.physics then return nil end
    love.physics.setMeter(METER)
    local world = love.physics.newWorld(0, 0, true)
    local static = love.physics.newBody(world, 0, 0, "static")
    for _, wall in ipairs(arena.walls or {}) do addRect(static, wall) end
    for _, block in ipairs(arena.cover or {}) do addRect(static, block) end
    local self = setmetatable({ world = world, arena = arena, pieces = {}, gates = {}, accumulator = 0 }, Debris)
    for _, list in ipairs({ arena.doors or {}, arena.glass or {} }) do
        for _, rect in ipairs(list) do
            local body = love.physics.newBody(world, 0, 0, "static")
            addRect(body, rect)
            self.gates[#self.gates + 1] = { rect = rect, body = body }
        end
    end
    return self
end

function Debris:destroy()
    if self.world then
        self.world:destroy()
        self.world = nil
    end
end

--- @param x number
--- @param y number
--- @param points number[] polygon around the center
--- @param color table
--- @param life number
--- @param options table? { bounce, damping, spin }
--- @return love.Body?
function Debris:add(x, y, points, color, life, options)
    if not self.world then return nil end
    options = options or {}
    if #self.pieces >= MAX then
        local old = table.remove(self.pieces, 1)
        old.body:destroy()
    end
    local ok, shape = pcall(love.physics.newPolygonShape, points)
    if not ok then return nil end
    local body = love.physics.newBody(self.world, x, y, "dynamic")
    body:setLinearDamping(options.damping or 3.2)
    body:setAngularDamping(options.spin or 2.6)
    local fixture = love.physics.newFixture(body, shape, 1)
    fixture:setRestitution(options.bounce or 0.45)
    fixture:setFriction(0.3)
    fixture:setGroupIndex(-1)
    self.pieces[#self.pieces + 1] = { body = body, points = points, color = color, life = life, born = love.timer.getTime(), shine = options.shine }
    return body
end

--- A spent casing thrown out of the right side of the gun.
--- @param x number gun position
--- @param y number
--- @param angle number aim
--- @param weapon string?
function Debris:casing(x, y, angle, weapon)
    local def = CASINGS[weapon or ""]
    if not def then return end
    local hw, hh = def.w / 2, def.h / 2
    local body = self:add(x, y, { -hh, -hw, hh, -hw, hh, hw, -hh, hw }, def.color, 7, { bounce = 0.55, damping = 2.6, shine = true })
    if not body then return end
    local side = angle + pi / 2 + (random() - 0.5) * 0.6
    local back = angle + pi
    local speed = 140 + random() * 90
    body:setAngle(angle + (random() - 0.5))
    body:setLinearVelocity(cos(side) * speed + cos(back) * 30, sin(side) * speed + sin(back) * 30)
    body:setAngularVelocity((random() - 0.3) * 30)
end

--- @param n number corners
--- @param size number
--- @return number[]
local function shard(n, size)
    local points = {}
    local start = random() * 2 * pi
    for k = 0, n - 1 do
        local a = start + k / n * 2 * pi + (random() - 0.5) * 0.9
        local r = size * (0.55 + random() * 0.6)
        points[#points + 1] = cos(a) * r
        points[#points + 1] = sin(a) * r
    end
    return points
end

--- Bits of wall knocked back towards the shooter.
--- @param x number impact point
--- @param y number
--- @param dx number shot direction
--- @param dy number
function Debris:chips(x, y, dx, dy)
    local d = math.sqrt(dx * dx + dy * dy)
    if d == 0 then return end
    local back = math.atan2(-dy, -dx)
    local c = Theme.colors.wallSide
    for _ = 1, 3 do
        local a = back + (random() - 0.5) * 1.8
        local speed = 80 + random() * 160
        local body = self:add(x - dx / d * 4, y - dy / d * 4, shard(3, 1.6 + random() * 1.6), c, 4, { bounce = 0.3, damping = 4.5 })
        if body then
            body:setLinearVelocity(cos(a) * speed, sin(a) * speed)
            body:setAngularVelocity((random() - 0.5) * 40)
        end
    end
end

--- A pane breaking into shards thrown to both sides.
--- @param pane table
function Debris:glass(pane)
    local long = pane.w >= pane.h
    local length = long and pane.w or pane.h
    local c = Theme.colors.glassTop
    local color = { c[1], c[2], c[3], 0.85 }
    for _ = 1, math.max(6, math.floor(length / 9)) do
        local t = random()
        local x = long and pane.x + t * pane.w or pane.x + pane.w / 2
        local y = long and pane.y + pane.h / 2 or pane.y + t * pane.h
        local side = random() < 0.5 and -1 or 1
        local nx, ny = long and 0 or side, long and side or 0
        local speed = 40 + random() * 170
        local body = self:add(x + nx * 6, y + ny * 6, shard(3, 2.5 + random() * 3.5), color, 9, { bounce = 0.25, damping = 3.8, shine = true })
        if body then
            body:setLinearVelocity(nx * speed + (random() - 0.5) * 80, ny * speed + (random() - 0.5) * 80)
            body:setAngularVelocity((random() - 0.5) * 18)
        end
    end
end

--- The facets of an eliminated player bursting out.
--- @param x number
--- @param y number
--- @param color table
--- @param count number?
function Debris:burst(x, y, color, count)
    for _ = 1, count or 18 do
        local a, speed = random() * 2 * pi, 90 + random() * 220
        local body = self:add(x + cos(a) * 6, y + sin(a) * 6, shard(3 + math.floor(random() * 2), 3 + random() * 4.5), color, 6, { bounce = 0.4, damping = 2.8 })
        if body then
            body:setLinearVelocity(cos(a) * speed, sin(a) * speed)
            body:setAngularVelocity((random() - 0.5) * 24)
        end
    end
end

--- Pushes the debris around a point away from it.
--- @param x number
--- @param y number
--- @param radius number
--- @param strength number speed given at the center
function Debris:blast(x, y, radius, strength)
    for _, piece in ipairs(self.pieces) do
        local px, py = piece.body:getPosition()
        local dx, dy = px - x, py - y
        local d = math.sqrt(dx * dx + dy * dy)
        if d < radius and d > 0.01 then
            local push = strength * (1 - d / radius) * piece.body:getMass()
            piece.body:applyLinearImpulse(dx / d * push, dy / d * push)
            piece.body:applyAngularImpulse((random() - 0.5) * push * 0.4)
        end
    end
end

--- @param movers table[] players { x, y, vx, vy }
--- @param dt number
function Debris:update(movers, dt)
    if not self.world then return end
    for _, gate in ipairs(self.gates) do
        local solid = not (gate.rect.open or gate.rect.broken)
        if gate.body:isActive() ~= solid then gate.body:setActive(solid) end
    end
    for _, p in ipairs(movers) do
        local vx, vy = p.vx or 0, p.vy or 0
        local speed = math.sqrt(vx * vx + vy * vy)
        if speed > 20 then
            self.world:queryBoundingBox(p.x - 16, p.y - 16, p.x + 16, p.y + 16, function(fixture)
                local body = fixture:getBody()
                if body:getType() == "dynamic" then
                    local bx, by = body:getPosition()
                    local dx, dy = bx - p.x, by - p.y
                    local d = math.max(1, math.sqrt(dx * dx + dy * dy))
                    local m = body:getMass()
                    body:applyLinearImpulse((dx / d * 60 + vx * 0.5) * m, (dy / d * 60 + vy * 0.5) * m)
                    body:applyAngularImpulse((random() - 0.5) * m * 8)
                end
                return true
            end)
        end
    end
    self.accumulator = math.min(self.accumulator + dt, STEP * 8)
    while self.accumulator >= STEP do
        self.world:update(STEP)
        self.accumulator = self.accumulator - STEP
    end
    local now = love.timer.getTime()
    local pits = self.arena.pits or {}
    for k = #self.pieces, 1, -1 do
        local piece = self.pieces[k]
        local x, y = piece.body:getPosition()
        if not piece.falling then
            for _, pit in ipairs(pits) do
                if x > pit.x + 6 and x < pit.x + pit.w - 6 and y > pit.y + 6 and y < pit.y + pit.h - 6 then
                    piece.falling = now
                    piece.body:setLinearDamping(6)
                    break
                end
            end
        end
        local gone = now - piece.born > piece.life or (piece.falling and now - piece.falling > 0.4)
        if gone then
            piece.body:destroy()
            table.remove(self.pieces, k)
        end
    end
end

--- Draws the debris on the floor, in world coordinates.
function Debris:draw()
    local lg = love.graphics
    local now = love.timer.getTime()
    for _, piece in ipairs(self.pieces) do
        local body = piece.body
        local x, y = body:getPosition()
        local left = piece.life - (now - piece.born)
        local alpha = math.min(1, left / FADE)
        local scale = 1
        if piece.falling then
            local t = math.min(1, (now - piece.falling) / 0.4)
            scale = 1 - t * 0.8
            alpha = alpha * (1 - t)
        end
        local c = piece.color
        lg.push()
        lg.translate(x, y)
        lg.rotate(body:getAngle())
        lg.scale(scale)
        lg.setColor(0, 0, 0, 0.12 * alpha)
        lg.translate(1, 1.5)
        lg.polygon("fill", piece.points)
        lg.translate(-1, -1.5)
        lg.setColor(c[1], c[2], c[3], (c[4] or 1) * alpha)
        lg.polygon("fill", piece.points)
        if piece.shine then
            local glint = 0.5 + 0.5 * sin(body:getAngle() * 3 + now * 2)
            lg.setColor(1, 1, 1, 0.35 * glint * alpha)
            lg.setLineWidth(1)
            lg.line(piece.points[1], piece.points[2], piece.points[3], piece.points[4])
        end
        lg.pop()
    end
end

return Debris
