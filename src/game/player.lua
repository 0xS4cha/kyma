local Config = require("src.config.game")
local Weapons = require("src.game.weapons")
local WeaponConfig = require("src.config.weapons")

local Player = {}

local cos, sin, sqrt, floor, pi = math.cos, math.sin, math.sqrt, math.floor, math.pi

local TAU = 2 * pi
local ANGLE_STEPS = 65536

Player.ANGLE_STEPS = ANGLE_STEPS

--- @param angle number
--- @return number
function Player.packAngle(angle)
    return floor((angle % TAU) / TAU * ANGLE_STEPS + 0.5) % ANGLE_STEPS
end

--- @param value number
--- @return number
function Player.unpackAngle(value)
    return value / ANGLE_STEPS * TAU
end

--- @param slot number
--- @param name string
--- @param spawn table
--- @return table
function Player.new(slot, name, spawn)
    local p = {
        slot = slot,
        name = name,
        x = spawn.x,
        y = spawn.y,
        angle = Player.unpackAngle(Player.packAngle(spawn.angle)),
        vx = 0,
        vy = 0,
        dash = 0,
        cooldown = 0,
        dashX = 0,
        dashY = 0,
        slide = 0,
        slideX = 0,
        slideY = 0,
        hp = Config.health,
        dead = 0,
        stun = 0,
        meleeCooldown = 0,
        trigger = false
    }
    Weapons.give(p, "pistol")
    return p
end

--- @param p table
--- @param spawn table
function Player.respawn(p, spawn)
    p.x, p.y = spawn.x, spawn.y
    p.angle = Player.unpackAngle(Player.packAngle(spawn.angle or 0))
    p.vx, p.vy, p.dash, p.cooldown, p.slide = 0, 0, 0, 0, 0
    p.hp, p.dead, p.stun, p.meleeCooldown = Config.health, 0, 0, 0
    Weapons.give(p, "pistol")
end

--- @param from table
--- @param to table?
--- @return table
function Player.copy(from, to)
    to = to or {}
    to.slot, to.name = from.slot, from.name
    to.x, to.y, to.angle, to.vx, to.vy = from.x, from.y, from.angle, from.vx, from.vy
    to.dash, to.cooldown, to.dashX, to.dashY = from.dash, from.cooldown, from.dashX, from.dashY
    to.hp, to.dead, to.trigger = from.hp, from.dead, from.trigger
    to.slide, to.slideX, to.slideY = from.slide, from.slideX, from.slideY
    to.stun, to.meleeCooldown = from.stun, from.meleeCooldown
    to.weapon, to.ammo, to.reserve, to.reload, to.fireCooldown = from.weapon, from.ammo, from.reserve, from.reload, from.fireCooldown
    return to
end

--- @param p table
--- @param input table
--- @return boolean
function Player.running(p, input)
    if input.f ~= 1 or input.k == 1 then return false end
    local speed = sqrt(p.vx * p.vx + p.vy * p.vy)
    return speed >= Config.player.speed * Config.slide.runSpeed
end

--- @param p table
--- @return boolean
function Player.evading(p)
    return p.dash > 0 or p.slide > Config.slide.ticks - Config.slide.invulnerable
end

--- @param p table
--- @param input table
--- @param arena table
--- @param dt number
--- @return boolean
function Player.step(p, input, arena, dt)
    local def = Config.player
    local angle = Player.unpackAngle(input.a)
    p.angle = angle

    if p.dead > 0 then
        if not p.out or p.dead > 1 then p.dead = p.dead - 1 end
        p.vx, p.vy, p.dash, p.slide = 0, 0, 0, 0
        p.trigger = input.b == 1
        return false
    end

    local ca, sa = cos(angle), sin(angle)
    local forward = input.f
    if forward < 0 then forward = forward * def.backSpeed end
    local wx = ca * forward - sa * input.r
    local wy = sa * forward + ca * input.r
    local len = sqrt(wx * wx + wy * wy)
    if len > 1 then
        wx, wy = wx / len, wy / len
    end
    if input.k == 1 then
        local quiet = Config.noise.quietSpeed
        wx, wy = wx * quiet, wy * quiet
    end
    local held = Weapons.held(p)
    if held and held.speed then
        wx, wy = wx * held.speed, wy * held.speed
    end
    local stunned = p.stun > 0
    if stunned then
        p.stun = p.stun - 1
        local slow = WeaponConfig.melee.stunSpeed
        wx, wy = wx * slow, wy * slow
    end

    local dash = Config.dash
    if p.cooldown > 0 then
        p.cooldown = p.cooldown - 1
    end
    local slide = Config.slide
    if input.d == 1 and not stunned and p.cooldown == 0 and p.dash == 0 and p.slide == 0 then
        if Player.running(p, input) then
            local speed = sqrt(p.vx * p.vx + p.vy * p.vy)
            p.slideX, p.slideY = p.vx / speed, p.vy / speed
            p.slide = slide.ticks
        else
            local dx, dy = wx, wy
            len = sqrt(dx * dx + dy * dy)
            if len < 1e-6 then
                dx, dy, len = ca, sa, 1
            end
            p.dashX, p.dashY = dx / len, dy / len
            p.dash = dash.ticks
        end
        p.cooldown = dash.cooldown
    end

    if p.dash > 0 then
        p.dash = p.dash - 1
        p.vx, p.vy = p.dashX * dash.speed, p.dashY * dash.speed
    elseif p.slide > 0 then
        p.slide = p.slide - 1
        local t = p.slide / slide.ticks
        local speed = slide.endSpeed + (slide.speed - slide.endSpeed) * t
        p.vx, p.vy = p.slideX * speed, p.slideY * speed
    else
        local blend = def.acceleration * dt
        if blend > 1 then blend = 1 end
        p.vx = p.vx + (wx * def.speed - p.vx) * blend
        p.vy = p.vy + (wy * def.speed - p.vy) * blend
    end

    local x, y, nx, ny = arena:resolve(p.x + p.vx * dt, p.y + p.vy * dt, def.radius)
    local into = p.vx * nx + p.vy * ny
    if into < 0 then
        p.vx, p.vy = p.vx - nx * into, p.vy - ny * into
    end
    p.x, p.y = x, y
    return Weapons.update(p, input)
end

return Player
