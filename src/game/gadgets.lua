local Config = require("src.config.gadgets")
local GameConfig = require("src.config.game")
local Weapons = require("src.game.weapons")
local Combat = require("src.game.combat")

local Gadgets = {}

local cos, sin, sqrt, atan2, abs, pi, max = math.cos, math.sin, math.sqrt, math.atan2, math.abs, math.pi, math.max

--- @param world table
function Gadgets.setup(world)
    world.gadgets = {}
    world.smokes = {}
    world.decoys = {}
    world.arena.smokes = world.smokes
    world.nextGadget = 1
end

--- @param p table
--- @param kind string?
function Gadgets.give(p, kind)
    p.gadget = Config[kind or ""] and kind or nil
    p.gadgets = p.gadget and Config.charges or 0
end

--- @param world table
--- @param p table
--- @return table?
function Gadgets.use(world, p)
    if not p.gadget or (p.gadgets or 0) <= 0 or p.dead > 0 or p.hp <= 0 or p.dash > 0 then return nil end
    local def = Config[p.gadget]
    if def.self then
        if p.gadget == "stim" and p.hp >= GameConfig.health then return nil end
        p.gadgets = p.gadgets - 1
        p.stim = def.heal * def.every
        Combat.noise(world, "throw", p.x, p.y, p.slot)
        world.events[#world.events + 1] = { kind = "stim", o = p.slot, x = math.floor(p.x), y = math.floor(p.y) }
        return { kind = p.gadget, owner = p.slot, self = true }
    end
    p.gadgets = p.gadgets - 1
    local ca, sa = cos(p.angle), sin(p.angle)
    local x, y = world.arena:resolve(p.x + ca * 16, p.y + sa * 16, Config.radius)
    local gadget = {
        id = world.nextGadget, kind = p.gadget, owner = p.slot, weapon = p.weapon,
        x = x, y = y, vx = ca * Config.speed + p.vx * 0.5, vy = sa * Config.speed + p.vy * 0.5, fuse = Config.fuse
    }
    world.nextGadget = world.nextGadget + 1
    world.gadgets[#world.gadgets + 1] = gadget
    Combat.noise(world, "throw", p.x, p.y, p.slot)
    return gadget
end

local function angleBetween(a, b)
    return abs((b - a + pi) % (2 * pi) - pi)
end

local function clear(arena, x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local d = sqrt(dx * dx + dy * dy)
    if d < 1 then return true end
    return arena:raycast(x1, y1, dx / d, dy / d, d, "vision") >= d - 1
end

--- @param world table
--- @param x number
--- @param y number
function Gadgets.flash(world, x, y)
    local def = Config.flash
    for _, p in pairs(world.players) do
        if p.dead == 0 and p.hp > 0 then
            local dx, dy = x - p.x, y - p.y
            local d = sqrt(dx * dx + dy * dy)
            if d < def.radius and clear(world.arena, p.x, p.y, x, y) then
                local facing = angleBetween(p.angle, atan2(dy, dx)) <= GameConfig.vision.halfAngle + 0.3 and 1 or def.glance
                local ticks = math.floor(def.blind * facing * (1 - 0.6 * d / def.radius))
                p.blind = max(p.blind or 0, ticks)
            end
        end
    end
end

--- @param world table
--- @param x number
--- @param y number
function Gadgets.shock(world, x, y)
    local def = Config.shock
    for _, p in pairs(world.players) do
        if p.dead == 0 and p.hp > 0 then
            local dx, dy = x - p.x, y - p.y
            if dx * dx + dy * dy < def.radius * def.radius and clear(world.arena, p.x, p.y, x, y) then
                p.stun = max(p.stun or 0, def.stun)
            end
        end
    end
end

--- Scan the enemies around `p`: their positions at this moment are kept for a
--- few seconds and shown to `p` and its team.
--- @param world table
--- @param p table
--- @return boolean
function Gadgets.scan(world, p)
    local def = GameConfig.scan
    if p.dead > 0 or p.hp <= 0 or (p.scanCooldown or 0) > 0 then return false end
    local dots = {}
    for slot, other in pairs(world.players) do
        if other.dead == 0 and other.hp > 0 and world:enemies(p.slot, slot) then
            local dx, dy = other.x - p.x, other.y - p.y
            if dx * dx + dy * dy <= def.radius * def.radius then
                dots[#dots + 1] = { x = math.floor(other.x), y = math.floor(other.y) }
            end
        end
    end
    p.scanCooldown = def.cooldown
    p.scanDots, p.scanTicks = dots, def.reveal
    Combat.noise(world, "scan", p.x, p.y, p.slot)
    return true
end

local function detonate(world, gadget)
    if gadget.kind == "smoke" then
        world.smokes[#world.smokes + 1] = { x = gadget.x, y = gadget.y, r = 0, ticks = Config.smoke.ticks }
        Combat.noise(world, "throw", gadget.x, gadget.y, gadget.owner)
    elseif gadget.kind == "flash" then
        Gadgets.flash(world, gadget.x, gadget.y)
        world.events[#world.events + 1] = { kind = "flash", x = math.floor(gadget.x), y = math.floor(gadget.y) }
        Combat.noise(world, "shot", gadget.x, gadget.y, gadget.owner)
    elseif gadget.kind == "decoy" then
        world.decoys[#world.decoys + 1] = {
            x = gadget.x, y = gadget.y, owner = gadget.owner, weapon = gadget.weapon or "pistol",
            ticks = Config.decoy.ticks, timer = 0, seed = gadget.id
        }
    elseif gadget.kind == "shock" then
        Gadgets.shock(world, gadget.x, gadget.y)
        world.events[#world.events + 1] = { kind = "shock", x = math.floor(gadget.x), y = math.floor(gadget.y) }
        Combat.noise(world, "throw", gadget.x, gadget.y, gadget.owner)
    end
end

local function decoyShot(world, decoy)
    local def = Weapons.def(decoy.weapon) or Weapons.def("pistol")
    local angle = ((decoy.seed * 7919 + decoy.ticks * 104729) % 6283) / 1000
    local dx, dy = cos(angle), sin(angle)
    local length = world.arena:raycast(decoy.x, decoy.y, dx, dy, Config.decoy.range)
    world.shots[#world.shots + 1] = {
        x = decoy.x, y = decoy.y, X = decoy.x + dx * length, Y = decoy.y + dy * length,
        h = length < Config.decoy.range - 1e-6 and 1 or 0, g = Weapons.pack(decoy.weapon)
    }
    if not def.silent then
        Combat.noise(world, "shot", decoy.x, decoy.y, decoy.owner)
    end
end

--- @param world table
function Gadgets.update(world)
    local dt = world.dt
    for k = #world.gadgets, 1, -1 do
        local gadget = world.gadgets[k]
        local x, y, nx, ny = world.arena:resolve(gadget.x + gadget.vx * dt, gadget.y + gadget.vy * dt, Config.radius)
        local into = gadget.vx * nx + gadget.vy * ny
        if into < 0 then
            gadget.vx, gadget.vy = (gadget.vx - 1.6 * into * nx) * 0.5, (gadget.vy - 1.6 * into * ny) * 0.5
        end
        gadget.x, gadget.y = x, y
        gadget.vx, gadget.vy = gadget.vx * Config.friction, gadget.vy * Config.friction
        gadget.fuse = gadget.fuse - 1
        if gadget.fuse <= 0 then
            table.remove(world.gadgets, k)
            detonate(world, gadget)
        end
    end
    for k = #world.smokes, 1, -1 do
        local smoke = world.smokes[k]
        smoke.ticks = smoke.ticks - 1
        local def = Config.smoke
        local fade = math.min(1, smoke.ticks / 60)
        smoke.r = def.radius * math.min(1, (def.ticks - smoke.ticks) / def.grow) * (0.4 + 0.6 * fade)
        if smoke.ticks <= 0 then table.remove(world.smokes, k) end
    end
    for k = #world.decoys, 1, -1 do
        local decoy = world.decoys[k]
        decoy.ticks = decoy.ticks - 1
        decoy.timer = decoy.timer - 1
        if decoy.timer <= 0 then
            decoyShot(world, decoy)
            decoy.timer = Config.decoy.interval + (decoy.ticks * 13) % 12
        end
        if decoy.ticks <= 0 then table.remove(world.decoys, k) end
    end
    for _, p in pairs(world.players) do
        if (p.blind or 0) > 0 then p.blind = p.blind - 1 end
        if p.dead > 0 then p.blind = 0 end
        if (p.stim or 0) > 0 then
            if p.dead > 0 or p.hp <= 0 then
                p.stim = 0
            else
                p.stim = p.stim - 1
                if p.stim % Config.stim.every == 0 then p.hp = math.min(GameConfig.health, p.hp + 1) end
                if p.hp >= GameConfig.health then p.stim = 0 end
            end
        end
        if (p.scanCooldown or 0) > 0 then p.scanCooldown = p.scanCooldown - 1 end
        if (p.scanTicks or 0) > 0 then
            p.scanTicks = p.scanTicks - 1
            if p.scanTicks <= 0 then p.scanDots = nil end
        end
    end
end

return Gadgets
