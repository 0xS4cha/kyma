local Weapons = require("src.config.weapons")

local LOADOUT = {
    mods = {
        { id = "none", name = "No mod", text = "The weapon as it comes" },
        { id = "extended", name = "Extended mag", text = "+50% magazine", magazine = 1.5 },
        { id = "hands", name = "Fast hands", text = "Reload 35% faster", reloadTicks = 0.65 },
        { id = "steady", name = "Steady aim", text = "Half the spread", spread = 0.5 },
        { id = "pouch", name = "Ammo pouch", text = "+50% spare ammo", reserve = 1.5 },
        -- Trade-offs: each of these gives something and costs something.
        { id = "drum", name = "Drum mag", text = "Double mag, 50% slower reload", magazine = 2, reloadTicks = 1.5 },
        { id = "hair", name = "Hair trigger", text = "+25% fire rate, more spread", fireTicks = 0.8, spread = 1.35 },
        { id = "heavy", name = "Heavy rounds", text = "+25% damage, fires slower", damage = 1.25, fireTicks = 1.25 }
    },
    gadgets = { "none", "smoke", "flash", "decoy", "stim", "shock" },
    gadgetLabels = { "None", "Smoke", "Flash", "Decoy", "Stim", "Shock" },
    spawn = { "pistol", "own", "preset" },
    spawnLabels = { "Pistol", "Own loadout", "Same for all" }
}

--- @param kit any
--- @return table
function LOADOUT.sanitize(kit)
    kit = type(kit) == "table" and kit or {}
    local w = math.floor(tonumber(kit.w) or 1)
    local m = math.floor(tonumber(kit.m) or 1)
    local g = math.floor(tonumber(kit.g) or 1)
    if w < 1 or w > #Weapons.order then w = 1 end
    if m < 1 or m > #LOADOUT.mods then m = 1 end
    if g < 1 or g > #LOADOUT.gadgets then g = 1 end
    return { w = w, m = m, g = g }
end

--- Shield plates everyone spawns with in the games you start from the menu.
--- A match that doesn't set it (rated games, older clients) starts without.
LOADOUT.startArmor = 1
LOADOUT.armorLabels = { "None", "1 plate", "2 plates", "3 plates" }

--- @param plates any
--- @return integer between 0 and the most plates a player can carry
function LOADOUT.startPlates(plates)
    plates = math.floor(tonumber(plates) or 0)
    return math.max(0, math.min(require("src.config.game").shield.plates, plates))
end

--- Health a player gets back for each kill when the rule is on.
LOADOUT.killHeal = 50

--- @param rules any
--- @return table
function LOADOUT.rules(rules)
    rules = type(rules) == "table" and rules or {}
    local spawn = math.floor(tonumber(rules.s) or 1)
    if spawn < 1 or spawn > #LOADOUT.spawn then spawn = 1 end
    return {
        loot = rules.f ~= false, spawn = LOADOUT.spawn[spawn], s = spawn, f = rules.f ~= false, preset = LOADOUT.sanitize(rules.p),
        heal = rules.h == true, shields = rules.sh ~= false, armor = LOADOUT.startPlates(rules.ss),
        elimination = rules.el == true
    }
end

--- @param rules table
--- @return table
function LOADOUT.pack(rules)
    local packed = { f = rules.loot, s = rules.s, p = rules.preset, h = rules.heal or nil, ss = rules.armor, el = rules.elimination or nil }
    if rules.shields == false then packed.sh = false end -- (x and false or nil) vaut toujours nil en Lua
    return packed
end

--- The rules of a mode once the match options are applied. With the Elimination
--- rule on a mode that has it (duel, teams), nobody respawns until their side is
--- wiped, each wipe is a point and the match is played to fewer points.
--- @param base table a mode from src.config.game
--- @param options table? from LOADOUT.rules
--- @return table
function LOADOUT.modeRules(base, options)
    if not (options and options.elimination and base.elimination) then return base end
    local rules = {}
    for k, v in pairs(base) do rules[k] = v end
    rules.elim = true
    rules.scoreLimit = base.elimination
    rules.name = base.name .. " elimination"
    rules.text = base.teams and "Two teams, no respawn until a team is wiped out" or "One on one, one life per round"
    return rules
end

return LOADOUT
