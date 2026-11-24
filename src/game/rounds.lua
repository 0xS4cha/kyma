local Config = require("src.config.game")
local WeaponConfig = require("src.config.weapons")
local Loadout = require("src.config.loadout")
local Combat = require("src.game.combat")
local Gadgets = require("src.game.gadgets")

local Rounds = {}

local sqrt = math.sqrt

local function index(list, id)
    for k, value in ipairs(list) do
        if value == id or (type(value) == "table" and value.id == id) then return k end
    end
    return 1
end

--- @param world table
function Rounds.setup(world)
    if not world.rules.rounds then
        world.round = nil
        return
    end
    world.round = { number = 1, attackers = 1, timer = world.rules.roundTicks, hack = {}, over = 0 }
    for k in ipairs(world.arena.objectives or {}) do world.round.hack[k] = 0 end
end

--- @param world table
--- @param p table
--- @return string?
function Rounds.role(world, p)
    local round = world.round
    if not round or not p.team then return nil end
    return p.team == round.attackers and "attack" or "defend"
end

--- @param world table
--- @param p table
--- @return table?
function Rounds.kit(world, p)
    local role = Rounds.role(world, p)
    if not role then return nil end
    local kits = world.rules.kits
    local kit = role == "attack" and kits.attack or kits.defend[(p.slot or 1) % #kits.defend + 1]
    return {
        w = index(WeaponConfig.order, kit.weapon),
        m = index(Loadout.mods, kit.mod or "none"),
        g = index(Loadout.gadgets, kit.gadget or "none")
    }
end

local function event(world, data)
    world.events[#world.events + 1] = data
end

--- @param world table
--- @param side string
--- @param why string
function Rounds.win(world, side, why)
    local round = world.round
    if round.over > 0 or world.over then return end
    local team = side == "attack" and round.attackers or (3 - round.attackers)
    world.teamScore[team] = world.teamScore[team] + 1
    event(world, { kind = "round", w = team, s = side, y = why, n = round.number })
    if world.teamScore[team] >= world.rules.scoreLimit then
        world:finish(team, true)
    else
        round.over = world.rules.roundEndTicks
    end
end

--- @param world table
function Rounds.next(world)
    local round = world.round
    round.number = round.number + 1
    round.attackers = 3 - round.attackers
    round.timer = world.rules.roundTicks
    round.over = 0
    for k in pairs(round.hack) do round.hack[k] = 0 end
    Gadgets.setup(world)
    for k = #world.items, 1, -1 do
        if not world.items[k].pad then table.remove(world.items, k) end
    end
    for _, p in pairs(world.players) do
        p.out = nil
        require("src.game.player").respawn(p, world:spawnPoint(p))
        world:loadout(p)
    end
    event(world, { kind = "roundstart", n = round.number, a = round.attackers })
end

--- @param world table
--- @param p table
--- @return boolean
function Rounds.alive(p)
    return p.hp > 0 and p.dead == 0 and not p.out
end

--- @param world table
function Rounds.update(world)
    local round = world.round
    if not round or world.phase ~= "playing" or world.over then return end
    if round.over > 0 then
        round.over = round.over - 1
        if round.over == 0 then Rounds.next(world) end
        return
    end
    round.timer = round.timer - 1
    local counts = { attack = 0, defend = 0 }
    local alive = { attack = 0, defend = 0 }
    for _, p in pairs(world.players) do
        local role = Rounds.role(world, p)
        if role then
            counts[role] = counts[role] + 1
            if Rounds.alive(p) then alive[role] = alive[role] + 1 end
        end
    end
    local rules = world.rules
    for k, objective in ipairs(world.arena.objectives or {}) do
        local attackers, defenders, hacker = 0, 0, nil
        for _, p in pairs(world.players) do
            if Rounds.alive(p) then
                local dx, dy = p.x - objective.x, p.y - objective.y
                if dx * dx + dy * dy <= rules.hackRadius * rules.hackRadius then
                    if Rounds.role(world, p) == "attack" then
                        attackers, hacker = attackers + 1, p
                    else
                        defenders = defenders + 1
                    end
                end
            end
        end
        if attackers > 0 and defenders == 0 then
            round.hack[k] = round.hack[k] + 1
            if round.hack[k] % 45 == 1 then
                Combat.noise(world, "hack", objective.x, objective.y, hacker.slot)
            end
            if round.hack[k] >= rules.hackTicks then
                Rounds.win(world, "attack", "hack")
                return
            end
        elseif attackers == 0 and round.hack[k] > 0 then
            round.hack[k] = math.max(0, round.hack[k] - 0.25)
        end
    end
    if counts.attack > 0 and alive.attack == 0 then
        Rounds.win(world, "defend", "eliminated")
    elseif counts.defend > 0 and alive.defend == 0 then
        Rounds.win(world, "attack", "eliminated")
    elseif round.timer <= 0 then
        Rounds.win(world, "defend", "time")
    end
end

--- @param world table
--- @return table?
function Rounds.snapshot(world)
    local round = world.round
    if not round then return nil end
    local hack = {}
    for k, value in ipairs(round.hack) do hack[k] = math.floor(value) end
    return { n = round.number, a = round.attackers, t = round.timer, h = hack, o = round.over }
end

return Rounds
