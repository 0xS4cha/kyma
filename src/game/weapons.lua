local Config = require("src.config.weapons")

local Weapons = {}

local cos, sin, min = math.cos, math.sin, math.min

Weapons.order = Config.order
Weapons.index = {}
for k, kind in ipairs(Config.order) do
    Weapons.index[kind] = k
end

local MUZZLE_SIDE = 2.4
local UNARMED_REACH = 18

--- @param kind string?
--- @return table?
function Weapons.def(kind)
    return kind and Config[kind] or nil
end

--- @param kind string?
--- @return number
function Weapons.pack(kind)
    if kind == "health" then return -1 end
    if kind == "plate" then return -2 end
    return kind and Weapons.index[kind] or 0
end

--- @param value number?
--- @return string?
function Weapons.unpack(value)
    return value and Config.order[value] or nil
end

local INTEGER = { magazine = true, reserve = true, reloadTicks = true }

--- @param p table
--- @param key string
--- @return number?
function Weapons.stat(p, key)
    local def = Weapons.def(p.weapon)
    if not def then return nil end
    local value = def[key]
    if p.mod and p.modWeapon == p.weapon then
        local mod = require("src.config.loadout").mods[p.mod]
        local factor = mod and mod[key]
        if factor and value then
            value = value * factor
            if INTEGER[key] then value = math.floor(value + 0.5) end
        end
    end
    return value
end

--- @param def table
--- @param p table?
--- @return number
function Weapons.reserveCap(def, p)
    return (p and Weapons.stat(p, "reserve") or def.reserve) * Config.ammoReserveCap
end

--- @param p table
--- @param kind string?
--- @param ammo number?
--- @param reserve number?
function Weapons.give(p, kind, ammo, reserve)
    local def = Weapons.def(kind)
    p.weapon = def and kind or nil
    p.ammo = def and (ammo or Weapons.stat(p, "magazine")) or 0
    p.reserve = def and (reserve or Weapons.stat(p, "reserve")) or 0
    p.reload = 0
    p.fireCooldown = 0
end

local function noise(a, b, c)
    local h = (a * 73856093 + b * 19349663 + c * 83492791) % 1000003
    return h / 1000003 * 2 - 1
end

--- @param p table
--- @param input table
--- @return boolean
function Weapons.update(p, input)
    local held = input.b == 1
    local def = Weapons.def(p.weapon)
    if not def then
        local melee = Config.melee
        if p.meleeCooldown > 0 then p.meleeCooldown = p.meleeCooldown - 1 end
        local strike = held and not p.trigger and p.meleeCooldown == 0 and p.dash == 0 and p.stun == 0 and p.dead == 0
        p.trigger = held
        if strike then
            p.meleeCooldown = melee.cooldown
            return true
        end
        return false
    end
    if p.fireCooldown > 0 then
        p.fireCooldown = p.fireCooldown - 1
    end
    if p.reload > 0 then
        p.reload = p.reload - 1
        if p.reload == 0 then
            local moved = min(Weapons.stat(p, "magazine") - p.ammo, p.reserve)
            p.ammo, p.reserve = p.ammo + moved, p.reserve - moved
        end
    end
    if input.l == 1 and p.reload == 0 and p.ammo < Weapons.stat(p, "magazine") and p.reserve > 0 then
        p.reload = Weapons.stat(p, "reloadTicks")
    end

    local pull = held and (def.auto or not p.trigger)
    p.trigger = held
    if not pull or p.dash > 0 or p.stun > 0 or p.dead > 0 or p.fireCooldown > 0 or p.reload > 0 then
        return false
    end
    if p.ammo == 0 then
        if p.reserve > 0 then p.reload = Weapons.stat(p, "reloadTicks") end
        return false
    end
    p.ammo = p.ammo - 1
    p.fireCooldown = def.fireTicks
    if p.ammo == 0 and p.reserve > 0 then
        p.reload = Weapons.stat(p, "reloadTicks")
    end
    return true
end

--- @param p table
--- @return number, number
function Weapons.muzzle(p)
    local def = Weapons.def(p.weapon)
    local reach = def and def.muzzle or UNARMED_REACH
    local ca, sa = cos(p.angle), sin(p.angle)
    return p.x + ca * reach - sa * MUZZLE_SIDE, p.y + sa * reach + ca * MUZZLE_SIDE
end

--- @param p table
--- @param sequence number
--- @return table[]
function Weapons.rays(p, sequence)
    local def = Weapons.def(p.weapon)
    if not def then return {} end
    local mx, my = Weapons.muzzle(p)
    local list = {}
    for k = 1, def.pellets do
        local angle = p.angle + Weapons.stat(p, "spread") * noise(p.slot, sequence, k)
        list[k] = { x = mx, y = my, dx = cos(angle), dy = sin(angle), range = def.range }
    end
    return list
end

return Weapons
