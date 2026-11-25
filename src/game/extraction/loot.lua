--- Rolls what is inside a container or dropped by a monster. Better tiers roll more
--- items and better rarities.
local ItemConfig = require("src.config.items")
local Items = require("src.game.extraction.items")
local Inventory = require("src.game.extraction.inventory")

local Loot = {}

local floor, min, max = math.floor, math.min, math.max

-- Grid size of each container and what it mostly holds (weights per category).
Loot.containers = {
    crate = { name = "Crate", w = 6, h = 4, rolls = { 2, 4 }, weights = { weapon = 3, mod = 3, utility = 3, ammo = 4, valuable = 3, armor = 1, backpack = 1, material = 5, blueprint = 1 } },
    locker = { name = "Locker", w = 4, h = 6, rolls = { 1, 3 }, weights = { weapon = 2, armor = 3, backpack = 2, ammo = 3, utility = 2, material = 2 } },
    cabinet = { name = "Cabinet", w = 5, h = 3, rolls = { 1, 3 }, weights = { valuable = 5, utility = 2, ammo = 2, mod = 1, blueprint = 2, material = 2 } },
    fridge = { name = "Fridge", w = 4, h = 4, rolls = { 1, 2 }, weights = { utility = 5, valuable = 2, material = 1 } },
    drawer = { name = "Drawer", w = 4, h = 2, rolls = { 1, 2 }, weights = { valuable = 4, ammo = 3, mod = 2, blueprint = 2, material = 3 } },
    medbox = { name = "Medical box", w = 4, h = 3, rolls = { 2, 3 }, weights = { utility = 8, valuable = 1, material = 2 }, medical = true },
    toolbox = { name = "Toolbox", w = 5, h = 3, rolls = { 2, 4 }, weights = { mod = 4, valuable = 1, ammo = 1, material = 9, blueprint = 1 } },
    weapon_case = { name = "Weapon case", w = 6, h = 3, rolls = { 1, 2 }, weights = { weapon = 8, mod = 3, blueprint = 1 } },
    ammo_crate = { name = "Ammo crate", w = 5, h = 4, rolls = { 2, 4 }, weights = { ammo = 8, utility = 2, material = 2 } },
    stash = { name = "Hidden stash", w = 4, h = 4, rolls = { 1, 3 }, weights = { valuable = 4, weapon = 2, mod = 2, ammo = 2, blueprint = 3 } },
    supply = { name = "Supply drop", w = 8, h = 6, rolls = { 5, 8 }, weights = { weapon = 5, mod = 5, armor = 3, backpack = 2, utility = 3, blueprint = 3 }, bonus = 2 },
    cache = { name = "Horde cache", w = 6, h = 6, rolls = { 4, 6 }, weights = { weapon = 3, mod = 3, valuable = 4, utility = 2, material = 3, blueprint = 2 }, bonus = 1 },
    remains = { name = "Remains", w = 4, h = 3, rolls = { 0, 0 } }
}

-- Weapons available per danger tier.
local WEAPON_TIERS = {
    { "p9", "derringer", "viper", "needle", "sawed", "hornet", "pump", "revolver", "flaregun", "nailer", "lever" },
    { "p9", "viper", "needle", "revolver", "hornet", "wasp", "lynx", "pump", "double", "sawed", "ar", "carbine", "bullpup", "scout", "lever", "crossbow", "flaregun" },
    { "revolver", "cannon", "wasp", "drifter", "ripper", "lynx", "ar", "carbine", "bullpup", "kestrel", "battle", "auto", "slugger", "double", "bolt", "dmr", "lmg", "crossbow", "scorcher" },
    { "cannon", "ripper", "drifter", "kestrel", "carbine", "battle", "hammer", "auto", "slugger", "drum12", "bolt", "dmr", "longshot", "lmg", "minigun", "scorcher", "launcher", "railgun" }
}

local ARMOR_TIERS = {
    { "cap", "rig", "vest", "cap" }, { "cap", "helmet", "gasmask", "rig", "vest", "vest" },
    { "helmet", "visor", "gasmask", "vest", "carrier", "firesuit" }, { "visor", "nightcap", "carrier", "juggernaut", "firesuit", "helmet" }
}

local BACKPACK_TIERS = { { "sling", "daypack" }, { "sling", "daypack", "rucksack" }, { "daypack", "rucksack", "raid" }, { "rucksack", "raid", "hauler" } }

local VALUABLE_TIERS = {
    { "phone", "lighter", "watch" },
    { "phone", "lighter", "watch", "drive", "chain" },
    { "watch", "drive", "chain", "documents", "gpu", "statue" },
    { "drive", "chain", "documents", "gpu", "statue", "painting", "relic" }
}

local MATERIAL_TIERS = {
    { "scrap", "scrap", "screws", "string", "cloth", "wood", "tape", "powder", "springs", "glue" },
    { "scrap", "screws", "springs", "string", "cloth", "tape", "powder", "chemicals", "wires", "glue", "polymer" },
    { "screws", "springs", "powder", "chemicals", "wires", "circuit", "lens", "steel", "polymer", "fuelcan", "battery" },
    { "chemicals", "circuit", "lens", "steel", "polymer", "battery", "fuelcan", "alloy", "wires" }
}

local MEDICAL = { "bandage", "bandage", "food", "medkit", "stim", "plate", "antidote", "painkillers", "adrenaline", "trauma" }

-- Blueprints are rarer for strong items: a plan's target is drawn from this list.
local PLANS = {}
for _, id in ipairs(ItemConfig.craftOrder) do
    if ItemConfig.all[id].kind ~= "ammo" then PLANS[#PLANS + 1] = "plan_" .. id end
end

--- @param rng table Random
--- @param list any[]
--- @return any
local function pick(rng, list)
    return list[rng:random(#list)]
end

--- @param rng table
--- @param weights table category -> weight
--- @return string
local function category(rng, weights)
    local total = 0
    for _, weight in pairs(weights) do total = total + weight end
    local roll = rng:random() * total
    for _, key in ipairs({ "weapon", "mod", "utility", "armor", "backpack", "ammo", "valuable", "material", "blueprint" }) do
        local weight = weights[key] or 0
        if roll < weight then return key end
        roll = roll - weight
    end
    return "valuable"
end

--- @param rng table
--- @param tier number|string 1 to 4, or "boss"
--- @return number rarity index
function Loot.rarity(rng, tier)
    local rolls = ItemConfig.rarityRolls[tier] or ItemConfig.rarityRolls[1]
    local roll = rng:random(1000)
    for k, chance in ipairs(rolls) do
        if roll <= chance then return k end
        roll = roll - chance
    end
    return 1
end

--- Makes one ready to use instance: weapons may come with attachments and some
--- rounds loaded, armor at full durability, stacks partly filled.
--- @param alloc function returns a new unique id
--- @param id string
--- @param rarity number
--- @param rng table
--- @return table
function Loot.make(alloc, id, rarity, rng)
    local def = ItemConfig.all[id]
    local flat = def.kind == "ammo" or def.kind == "material" or def.kind == "valuable"
    local inst = { i = alloc(), d = id, r = flat and 1 or rarity, x = 0, y = 0 }
    if def.stack > 1 then
        if def.kind == "ammo" then
            inst.n = rng:random(floor(def.stack / 3), def.stack)
        elseif def.kind == "material" then
            inst.n = rng:random(1, max(1, floor(def.stack / 3)))
        else
            inst.n = rng:random(1, max(1, floor(def.stack / 2)))
        end
    end
    if def.kind == "weapon" then
        local stats = Items.weaponStats(inst)
        inst.a = rng:random(0, stats.magazine)
        local mods = rng:random(0, min(Items.rarity(inst).slots, max(0, rarity - 1)))
        for _ = 1, mods do
            local mod = Loot.make(alloc, pick(rng, ItemConfig.modOrder), max(1, rarity - rng:random(0, 1)), rng)
            if Items.canAttach(inst, mod) then
                inst.m = inst.m or {}
                inst.m[ItemConfig.all[mod.d].slot] = mod
            end
        end
    elseif def.kind == "armor" then
        inst.u = Items.armorStats(inst).durability
    elseif def.kind == "backpack" then
        inst.c = {}
    end
    return inst
end

--- @param rng table
--- @param kind string category
--- @param tier number
--- @param medical boolean?
--- @return string
local function pickId(rng, kind, tier, medical)
    local t = min(4, max(1, tier))
    if kind == "weapon" then return pick(rng, WEAPON_TIERS[t]) end
    if kind == "mod" then return pick(rng, ItemConfig.modOrder) end
    if kind == "utility" then return medical and pick(rng, MEDICAL) or pick(rng, ItemConfig.utilityOrder) end
    if kind == "armor" then return pick(rng, ARMOR_TIERS[t]) end
    if kind == "backpack" then return pick(rng, BACKPACK_TIERS[t]) end
    if kind == "ammo" then return pick(rng, ItemConfig.ammoOrder) end
    if kind == "material" then return pick(rng, MATERIAL_TIERS[t]) end
    if kind == "blueprint" then return pick(rng, PLANS) end
    return pick(rng, VALUABLE_TIERS[t])
end

--- Fills a container's grid.
--- @param kind string container kind
--- @param tier number|string
--- @param rng table
--- @param alloc function
--- @return table[] items placed in the grid
function Loot.roll(kind, tier, rng, alloc)
    local def = Loot.containers[kind] or Loot.containers.crate
    local list = {}
    local place = { kind = "grid", w = def.w, h = def.h, list = list }
    local numeric = type(tier) == "number" and tier or 4
    local count = rng:random(def.rolls[1], def.rolls[2]) + floor((numeric - 1) / 2) + (def.bonus or 0)
    for _ = 1, count do
        local id = pickId(rng, category(rng, def.weights or {}), numeric, def.medical)
        local rarity = Loot.rarity(rng, def.bonus and math.min(4, numeric + def.bonus) or tier)
        if tier == "boss" then rarity = Loot.rarity(rng, "boss") end
        Inventory.give({ g = place }, Loot.make(alloc, id, rarity, rng), { "g" })
    end
    return list
end

--- What a monster leaves: its own parts plus a few items by tier.
--- @param monster table definition
--- @param tier number
--- @param rng table
--- @param alloc function
--- @return table[]
function Loot.drop(monster, tier, rng, alloc)
    local list = {}
    local place = { kind = "grid", w = 4, h = 3, list = list }
    for id, chance in pairs(monster.loot or {}) do
        if rng:random() < chance then
            Inventory.give({ g = place }, Loot.make(alloc, id, 1, rng), { "g" })
        end
    end
    if monster.boss then
        place.w, place.h = 8, 6
        for _ = 1, 4 do
            local kind = rng:random() < 0.5 and "weapon" or (rng:random() < 0.5 and "mod" or "armor")
            Inventory.give({ g = place }, Loot.make(alloc, pickId(rng, kind, 4), Loot.rarity(rng, "boss"), rng), { "g" })
        end
    elseif rng:random() < 0.12 + tier * 0.05 then
        local kind = rng:random() < 0.5 and "ammo" or (rng:random() < 0.5 and "utility" or "mod")
        Inventory.give({ g = place }, Loot.make(alloc, pickId(rng, kind, tier), Loot.rarity(rng, tier), rng), { "g" })
    end
    return list, place.w, place.h
end

return Loot
