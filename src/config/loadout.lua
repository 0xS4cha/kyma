local Weapons = require("src.config.weapons")

local LOADOUT = {
    mods = {
        { id = "none", name = "No mod", text = "The weapon as it comes" },
        { id = "extended", name = "Extended mag", text = "+50% magazine", magazine = 1.5 },
        { id = "hands", name = "Fast hands", text = "Reload 35% faster", reloadTicks = 0.65 },
        { id = "steady", name = "Steady aim", text = "Half the spread", spread = 0.5 },
        { id = "pouch", name = "Ammo pouch", text = "+50% spare ammo", reserve = 1.5 }
    },
    gadgets = { "none", "smoke", "flash", "decoy" },
    gadgetLabels = { "None", "Smoke", "Flash", "Decoy" },
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

--- Health a player gets back for each kill when the rule is on.
LOADOUT.killHeal = 50

--- @param rules any
--- @return table
function LOADOUT.rules(rules)
    rules = type(rules) == "table" and rules or {}
    local spawn = math.floor(tonumber(rules.s) or 1)
    if spawn < 1 or spawn > #LOADOUT.spawn then spawn = 1 end
    return { loot = rules.f ~= false, spawn = LOADOUT.spawn[spawn], s = spawn, f = rules.f ~= false, preset = LOADOUT.sanitize(rules.p), heal = rules.h == true }
end

--- @param rules table
--- @return table
function LOADOUT.pack(rules)
    return { f = rules.loot, s = rules.s, p = rules.preset, h = rules.heal or nil }
end

return LOADOUT
