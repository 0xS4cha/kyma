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

--- Validate the state produced by one client command.
--- @param player table
--- @param previous table position before the command ({ x, y })
--- @param world table
--- @return table?
function AntiCheat.validate(player, previous, world)
    local arena, dt = world.arena, world.dt
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
    -- Arena collision resolution may push a player out of a wall or corner in
    -- addition to the movement for this tick. Keep that correction bounded by
    -- the player's collision size while still rejecting large teleports.
    if distance > maxSpeed * dt + radius * 2 + EPSILON then
        return invalid("displacement", distance)
    end

    local def = Weapons.def(player.weapon)
    if def then
        local magazine = Weapons.stat(player, "magazine")
        local reserveCap = Weapons.reserveCap(def, player)
        if not finite(player.ammo) or player.ammo ~= math.floor(player.ammo)
            or player.ammo < 0 or player.ammo > magazine then
            return invalid("ammo", player.ammo)
        end
        -- Ladder modes (gun game) hand out 999 reserve, but malformed values
        -- must still be rejected there.
        if not finite(player.reserve) or player.reserve ~= math.floor(player.reserve)
            or player.reserve < 0 or (not world.rules.ladder and player.reserve > reserveCap) then
            return invalid("reserve", player.reserve)
        end
        if not finite(player.reload) or player.reload ~= math.floor(player.reload)
            or player.reload < 0 or player.reload > Weapons.stat(player, "reloadTicks") then
            return invalid("reload", player.reload)
        end
        if not finite(player.fireCooldown) or player.fireCooldown ~= math.floor(player.fireCooldown)
            or player.fireCooldown < 0 or player.fireCooldown > Weapons.stat(player, "fireTicks") then
            return invalid("fireCooldown", player.fireCooldown)
        end
    end
    return nil
end

return AntiCheat
