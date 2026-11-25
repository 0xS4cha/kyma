local Config = require("src.config.game")
local Weapons = require("src.game.weapons")

local AntiCheat = {}

local abs, sqrt = math.abs, math.sqrt
local EPSILON = 1e-3

local function finite(value)
    return type(value) == "number" and value == value and abs(value) < math.huge
end

local function invalid(field, value)
    return { field = field, value = value }
end

function AntiCheat.sync(player)
    player._antiCheatX, player._antiCheatY = player.x, player.y
end

--- Validate the state produced by one authoritative simulation step.
--- @param player table
--- @param previous table
--- @param arena table
--- @param dt number
--- @return table?
function AntiCheat.validate(player, previous, arena, dt)
    for _, field in ipairs({ "x", "y", "vx", "vy", "angle" }) do
        if not finite(player[field]) then return invalid(field, player[field]) end
    end

    local radius = Config.player.radius
    if player.x < radius - EPSILON or player.x > arena.width - radius + EPSILON
        or player.y < radius - EPSILON or player.y > arena.height - radius + EPSILON then
        return invalid("position", player.x .. "," .. player.y)
    end

    local resolvedX, resolvedY = arena:resolve(player.x, player.y, radius)
    if abs(resolvedX - player.x) > EPSILON or abs(resolvedY - player.y) > EPSILON then
        return invalid("collision", player.x .. "," .. player.y)
    end

    local dx, dy = player.x - previous.x, player.y - previous.y
    local distance = sqrt(dx * dx + dy * dy)
    local maxSpeed = Config.player.speed
    if player.weapon then
        maxSpeed = maxSpeed * (Weapons.def(player.weapon).speed or 1)
    end
    maxSpeed = math.max(maxSpeed, Config.dash.speed, Config.slide.speed)
    if distance > maxSpeed * dt + EPSILON then
        return invalid("displacement", distance)
    end

    local def = Weapons.def(player.weapon)
    if def then
        local magazine = Weapons.stat(player, "magazine")
        local reserve = Weapons.stat(player, "reserve")
        local reserveCap = Weapons.reserveCap(def, player)
        if not finite(player.ammo) or player.ammo ~= math.floor(player.ammo)
            or player.ammo < 0 or player.ammo > magazine then
            return invalid("ammo", player.ammo)
        end
        if not finite(player.reserve) or player.reserve ~= math.floor(player.reserve)
            or player.reserve < 0 or player.reserve > reserveCap then
            return invalid("reserve", player.reserve)
        end
        if not finite(player.reload) or player.reload ~= math.floor(player.reload)
            or player.reload < 0 or player.reload > Weapons.stat(player, "reloadTicks") then
            return invalid("reload", player.reload)
        end
        if not finite(player.fireCooldown) or player.fireCooldown ~= math.floor(player.fireCooldown)
            or player.fireCooldown < 0 or player.fireCooldown > def.fireTicks then
            return invalid("fireCooldown", player.fireCooldown)
        end
    else
        if player.ammo ~= 0 or player.reserve ~= 0 or player.reload ~= 0 or player.fireCooldown ~= 0 then
            return invalid("unarmedAmmo", player.ammo)
        end
    end
    return nil
end

return AntiCheat
