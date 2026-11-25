--- Every item of the extraction mode. An item instance is { i = id, d = def id,
--- r = rarity index, x, y, o = rotated, n = stack count, a = loaded rounds,
--- u = durability, m = { [slot] = attachment instance }, c = { contents } }.
local ITEMS = {}

ITEMS.rarities = {
    order = { "common", "uncommon", "rare", "epic", "legendary", "mythic" },
    common = { name = "Common", color = { 0.62, 0.64, 0.68 }, power = 1.00, slots = 1, value = 1 },
    uncommon = { name = "Uncommon", color = { 0.30, 0.72, 0.36 }, power = 1.06, slots = 2, value = 1.8 },
    rare = { name = "Rare", color = { 0.24, 0.52, 0.94 }, power = 1.12, slots = 3, value = 3.5 },
    epic = { name = "Epic", color = { 0.64, 0.32, 0.88 }, power = 1.20, slots = 4, value = 7 },
    legendary = { name = "Legendary", color = { 0.96, 0.62, 0.12 }, power = 1.30, slots = 6, value = 15 },
    mythic = { name = "Mythic", color = { 0.94, 0.20, 0.26 }, power = 1.42, slots = 6, value = 35 }
}

-- Chance (out of 1000) of each rarity per danger tier; mythic only drops from events and bosses.
ITEMS.rarityRolls = {
    { 640, 260, 85, 13, 2, 0 },
    { 470, 310, 160, 48, 12, 0 },
    { 330, 310, 220, 100, 38, 2 },
    { 200, 280, 270, 160, 82, 8 },
    boss = { 0, 0, 200, 380, 330, 90 }
}

ITEMS.slots = {
    order = { "muzzle", "barrel", "mag", "optic", "under", "rounds" },
    muzzle = "Muzzle", barrel = "Barrel", mag = "Magazine", optic = "Optic", under = "Underbarrel", rounds = "Rounds"
}

ITEMS.calibers = {
    light = { name = "Light rounds", color = { 0.84, 0.72, 0.36 } },
    medium = { name = "Medium rounds", color = { 0.74, 0.5, 0.26 } },
    heavy = { name = "Heavy rounds", color = { 0.6, 0.36, 0.2 } },
    shell = { name = "Shells", color = { 0.82, 0.24, 0.18 } },
    sniper = { name = "Sniper rounds", color = { 0.4, 0.42, 0.46 } }
}

local ALL = { "muzzle", "barrel", "mag", "optic", "under", "rounds" }
local PISTOL = { "muzzle", "mag", "optic", "under", "rounds" }
local SHOTGUN = { "muzzle", "barrel", "mag", "under", "rounds" }

--- @param def table
local function weapon(def)
    def.kind = "weapon"
    def.pellets = def.pellets or 1
    def.slots = def.slots or ALL
    return def
end

-- Weapons. `look` is the model and sound used for it, `w` x `h` its size in the grid.
ITEMS.weapon = {
    p9 = weapon({ name = "P9", class = "Pistol", look = "pistol", w = 2, h = 1, ammo = "light", price = 450, slots = PISTOL,
        damage = 28, spread = 0.014, range = 1300, fireTicks = 12, auto = false, magazine = 12, reloadTicks = 66, muzzle = 21 }),
    viper = weapon({ name = "Viper", class = "Machine pistol", look = "pistol", w = 2, h = 1, ammo = "light", price = 900, slots = PISTOL,
        damage = 15, spread = 0.05, range = 900, fireTicks = 4, auto = true, magazine = 20, reloadTicks = 70, muzzle = 21 }),
    needle = weapon({ name = "Needle", class = "Silenced pistol", look = "silencer", w = 2, h = 1, ammo = "light", price = 1100, slots = PISTOL,
        damage = 30, spread = 0.012, range = 1200, fireTicks = 15, auto = false, magazine = 10, reloadTicks = 80, muzzle = 26, silent = true }),
    revolver = weapon({ name = "Bulldog", class = "Revolver", look = "pistol", w = 2, h = 1, ammo = "heavy", price = 1300, slots = PISTOL,
        damage = 58, spread = 0.01, range = 1500, fireTicks = 26, auto = false, magazine = 6, reloadTicks = 120, muzzle = 22 }),
    cannon = weapon({ name = "Hand cannon", class = "Pistol", look = "pistol", w = 2, h = 1, ammo = "heavy", price = 2100, slots = PISTOL,
        damage = 72, spread = 0.02, range = 1400, fireTicks = 34, auto = false, magazine = 7, reloadTicks = 100, muzzle = 24 }),

    hornet = weapon({ name = "Hornet", class = "SMG", look = "rifle", w = 3, h = 2, ammo = "light", price = 1500,
        damage = 17, spread = 0.04, range = 1100, fireTicks = 5, auto = true, magazine = 30, reloadTicks = 90, muzzle = 24 }),
    wasp = weapon({ name = "Wasp", class = "SMG", look = "rifle", w = 3, h = 2, ammo = "light", price = 2200,
        damage = 13, spread = 0.055, range = 950, fireTicks = 3, auto = true, magazine = 32, reloadTicks = 84, muzzle = 23 }),
    drifter = weapon({ name = "Drifter", class = "SMG", look = "rifle", w = 3, h = 2, ammo = "light", price = 2600,
        damage = 16, spread = 0.045, range = 1050, fireTicks = 5, auto = true, magazine = 50, reloadTicks = 130, muzzle = 25 }),

    ar = weapon({ name = "AR-4", class = "Assault rifle", look = "rifle", w = 4, h = 2, ammo = "medium", price = 3200,
        damage = 24, spread = 0.032, range = 1600, fireTicks = 6, auto = true, magazine = 30, reloadTicks = 110, muzzle = 28 }),
    carbine = weapon({ name = "Ranger", class = "Carbine", look = "rifle", w = 4, h = 2, ammo = "medium", price = 3000,
        damage = 30, spread = 0.018, range = 1800, fireTicks = 9, auto = true, magazine = 25, reloadTicks = 105, muzzle = 28 }),
    bullpup = weapon({ name = "Fennec", class = "Bullpup rifle", look = "rifle", w = 3, h = 2, ammo = "medium", price = 3800,
        damage = 22, spread = 0.03, range = 1500, fireTicks = 5, auto = true, magazine = 30, reloadTicks = 120, muzzle = 25 }),
    battle = weapon({ name = "Warden", class = "Battle rifle", look = "rifle", w = 4, h = 2, ammo = "heavy", price = 4800,
        damage = 40, spread = 0.022, range = 1900, fireTicks = 11, auto = true, magazine = 20, reloadTicks = 130, muzzle = 30 }),

    pump = weapon({ name = "Thumper", class = "Pump shotgun", look = "shotgun", w = 4, h = 1, ammo = "shell", price = 1400, slots = SHOTGUN,
        damage = 14, pellets = 7, spread = 0.22, range = 520, fireTicks = 45, auto = false, magazine = 6, reloadTicks = 120, muzzle = 25 }),
    auto = weapon({ name = "Riot", class = "Auto shotgun", look = "shotgun", w = 4, h = 2, ammo = "shell", price = 3600, slots = SHOTGUN,
        damage = 11, pellets = 6, spread = 0.24, range = 480, fireTicks = 16, auto = true, magazine = 8, reloadTicks = 150, muzzle = 26 }),
    double = weapon({ name = "Twin", class = "Double barrel", look = "shotgun", w = 4, h = 1, ammo = "shell", price = 1600, slots = SHOTGUN,
        damage = 16, pellets = 9, spread = 0.26, range = 460, fireTicks = 10, auto = false, magazine = 2, reloadTicks = 90, muzzle = 25 }),
    sawed = weapon({ name = "Stub", class = "Sawed-off", look = "shotgun", w = 2, h = 1, ammo = "shell", price = 900, slots = SHOTGUN,
        damage = 13, pellets = 8, spread = 0.34, range = 330, fireTicks = 12, auto = false, magazine = 2, reloadTicks = 80, muzzle = 18 }),

    bolt = weapon({ name = "Heron", class = "Bolt sniper", look = "sniper", w = 5, h = 1, ammo = "sniper", price = 4200,
        damage = 100, spread = 0, range = 3000, fireTicks = 75, auto = false, magazine = 5, reloadTicks = 150, muzzle = 36, exposed = true }),
    dmr = weapon({ name = "Marksman", class = "DMR", look = "sniper", w = 5, h = 2, ammo = "sniper", price = 5200,
        damage = 55, spread = 0.008, range = 2600, fireTicks = 22, auto = false, magazine = 10, reloadTicks = 130, muzzle = 34 }),
    longshot = weapon({ name = "Longshot", class = "Anti-materiel", look = "sniper", w = 6, h = 2, ammo = "sniper", price = 9000,
        damage = 160, spread = 0, range = 3600, fireTicks = 110, auto = false, magazine = 3, reloadTicks = 190, muzzle = 40, exposed = true, speed = 0.85 }),

    lmg = weapon({ name = "Mule", class = "LMG", look = "lmg", w = 5, h = 2, ammo = "medium", price = 5600,
        damage = 19, spread = 0.06, range = 1500, fireTicks = 5, auto = true, magazine = 80, reloadTicks = 220, muzzle = 32, speed = 0.75 }),
    minigun = weapon({ name = "Shredder", class = "Rotary gun", look = "lmg", w = 6, h = 2, ammo = "medium", price = 12000,
        damage = 14, spread = 0.09, range = 1300, fireTicks = 2, auto = true, magazine = 200, reloadTicks = 320, muzzle = 34, speed = 0.6 })
}

ITEMS.weaponOrder = {
    "p9", "viper", "needle", "revolver", "cannon", "hornet", "wasp", "drifter", "ar", "carbine", "bullpup", "battle",
    "pump", "auto", "double", "sawed", "bolt", "dmr", "longshot", "lmg", "minigun"
}

--- Attachments: `mul` multiplies weapon stats, `set` adds traits; both grow with rarity.
local function mod(def)
    def.kind = "mod"
    def.w, def.h = def.w or 1, def.h or 1
    return def
end

ITEMS.mod = {
    suppressor = mod({ name = "Suppressor", slot = "muzzle", w = 2, price = 900, mul = { range = 0.9 }, set = { silent = true },
        text = "Silent shots, slightly shorter range" }),
    compensator = mod({ name = "Compensator", slot = "muzzle", price = 600, mul = { spread = 0.72 }, text = "Tighter spread" }),
    choke = mod({ name = "Choke", slot = "muzzle", price = 500, mul = { spread = 0.6, range = 1.15 }, text = "Shotgun spread and reach" }),
    longbarrel = mod({ name = "Long barrel", slot = "barrel", w = 2, price = 800, mul = { range = 1.3, damage = 1.1 }, text = "Range and damage" }),
    shortbarrel = mod({ name = "Short barrel", slot = "barrel", price = 700, mul = { fireTicks = 0.82, spread = 1.15 }, text = "Fires faster, spreads more" }),
    heavybarrel = mod({ name = "Heavy barrel", slot = "barrel", w = 2, price = 1100, mul = { damage = 1.22, fireTicks = 1.1 }, text = "Hits harder, fires slower" }),
    extended = mod({ name = "Extended mag", slot = "mag", h = 2, price = 700, mul = { magazine = 1.5 }, text = "+50% magazine" }),
    drum = mod({ name = "Drum mag", slot = "mag", w = 2, h = 2, price = 1500, mul = { magazine = 2.2, reloadTicks = 1.3 }, text = "Huge magazine, slow reload" }),
    quickmag = mod({ name = "Quick mag", slot = "mag", price = 900, mul = { reloadTicks = 0.6 }, text = "Fast reload" }),
    reddot = mod({ name = "Red dot", slot = "optic", price = 500, mul = { spread = 0.85 }, text = "Steadier aim" }),
    scope = mod({ name = "Scope", slot = "optic", w = 2, price = 1400, mul = { spread = 0.8 }, set = { sight = 200 }, text = "See farther ahead" }),
    laser = mod({ name = "Laser sight", slot = "optic", price = 800, mul = { spread = 0.62 }, set = { exposed = true }, text = "Very tight spread, enemies see your laser" }),
    flashlight = mod({ name = "Flashlight", slot = "under", price = 450, set = { light = true }, text = "Lights far ahead in the dark" }),
    grip = mod({ name = "Grip", slot = "under", price = 600, mul = { spread = 0.8 }, text = "Tighter spread" }),
    stock = mod({ name = "Light stock", slot = "under", price = 700, set = { haste = 1.06 }, text = "Move faster while holding it" }),
    bouncing = mod({ name = "Bouncing rounds", slot = "rounds", price = 1200, set = { bounce = 2 }, mul = { damage = 0.9 }, text = "Bullets ricochet off walls twice" }),
    piercing = mod({ name = "Piercing rounds", slot = "rounds", price = 1400, set = { pierce = 1, armorPierce = 0.5 }, text = "Go through a target and half of armor" }),
    incendiary = mod({ name = "Incendiary rounds", slot = "rounds", price = 1300, set = { burn = 3 }, text = "Sets targets on fire" }),
    explosive = mod({ name = "Explosive rounds", slot = "rounds", price = 2200, set = { blast = 70 }, mul = { damage = 0.8 }, text = "Small explosion on impact" }),
    hollow = mod({ name = "Hollow points", slot = "rounds", price = 800, set = { flesh = 1.35, armorPierce = -0.3 }, text = "+35% against monsters, weak against armor" }),
    frost = mod({ name = "Frost rounds", slot = "rounds", price = 1100, set = { chill = 70 }, text = "Slows what you hit" }),
    vampire = mod({ name = "Leech rounds", slot = "rounds", price = 2600, set = { leech = 0.15 }, text = "Heal 15% of the damage you deal" })
}

ITEMS.modOrder = {
    "suppressor", "compensator", "choke", "longbarrel", "shortbarrel", "heavybarrel", "extended", "drum", "quickmag",
    "reddot", "scope", "laser", "flashlight", "grip", "stock", "bouncing", "piercing", "incendiary", "explosive", "hollow", "frost", "vampire"
}

--- Utilities go in the quick slots (keys 3 to 6 by default).
ITEMS.utility = {
    frag = { name = "Frag grenade", kind = "utility", w = 1, h = 1, stack = 3, price = 400, throw = "frag", text = "Explodes after 1.6 s" },
    smoke = { name = "Smoke grenade", kind = "utility", w = 1, h = 1, stack = 3, price = 250, throw = "smoke", text = "Blocks sight for 9 s" },
    flash = { name = "Flashbang", kind = "utility", w = 1, h = 1, stack = 3, price = 300, throw = "flash", text = "Blinds those who look at it" },
    molotov = { name = "Molotov", kind = "utility", w = 1, h = 1, stack = 2, price = 450, throw = "fire", text = "Burns the ground for 7 s" },
    bandage = { name = "Bandage", kind = "utility", w = 1, h = 1, stack = 4, price = 150, heal = 20, useTicks = 90, text = "Heals 20 over 1.5 s" },
    medkit = { name = "Medkit", kind = "utility", w = 1, h = 2, stack = 1, price = 700, heal = 70, useTicks = 210, text = "Heals 70, takes 3.5 s" },
    stim = { name = "Stim", kind = "utility", w = 1, h = 1, stack = 2, price = 900, heal = 10, useTicks = 30, haste = 60 * 12, text = "Heal 10 and run 25% faster for 12 s" },
    plate = { name = "Armor plate", kind = "utility", w = 2, h = 1, stack = 1, price = 600, repair = 45, useTicks = 150, text = "Repairs your vest by 45" }
}

ITEMS.utilityOrder = { "bandage", "medkit", "stim", "plate", "frag", "smoke", "flash", "molotov" }

ITEMS.armor = {
    cap = { name = "Cap", kind = "armor", slot = "helmet", w = 2, h = 2, price = 300, reduce = 0.08, durability = 40 },
    helmet = { name = "Helmet", kind = "armor", slot = "helmet", w = 2, h = 2, price = 1200, reduce = 0.15, durability = 80, flash = 0.5 },
    visor = { name = "Visor helmet", kind = "armor", slot = "helmet", w = 2, h = 2, price = 2600, reduce = 0.22, durability = 120, flash = 0.2 },
    vest = { name = "Light vest", kind = "armor", slot = "vest", w = 2, h = 3, price = 900, reduce = 0.25, durability = 100 },
    carrier = { name = "Plate carrier", kind = "armor", slot = "vest", w = 3, h = 3, price = 2400, reduce = 0.38, durability = 160, haste = 0.97 },
    juggernaut = { name = "Juggernaut", kind = "armor", slot = "vest", w = 3, h = 3, price = 6000, reduce = 0.52, durability = 260, haste = 0.9 }
}

ITEMS.armorOrder = { "cap", "helmet", "visor", "vest", "carrier", "juggernaut" }

ITEMS.backpack = {
    sling = { name = "Sling bag", kind = "backpack", w = 2, h = 2, grid = { 3, 3 }, price = 400 },
    daypack = { name = "Daypack", kind = "backpack", w = 3, h = 3, grid = { 4, 5 }, price = 1100 },
    rucksack = { name = "Rucksack", kind = "backpack", w = 3, h = 4, grid = { 5, 6 }, price = 2600 },
    raid = { name = "Raid pack", kind = "backpack", w = 4, h = 4, grid = { 6, 7 }, price = 5200 }
}

ITEMS.backpackOrder = { "sling", "daypack", "rucksack", "raid" }

ITEMS.ammo = {}
for id, caliber in pairs(ITEMS.calibers) do
    ITEMS.ammo["ammo_" .. id] = {
        name = caliber.name, kind = "ammo", caliber = id, w = 1, h = 1,
        stack = id == "sniper" and 20 or id == "shell" and 24 or id == "heavy" and 40 or 60,
        price = id == "sniper" and 8 or id == "shell" and 6 or id == "heavy" and 5 or 3,
        color = caliber.color
    }
end

ITEMS.ammoOrder = { "ammo_light", "ammo_medium", "ammo_heavy", "ammo_shell", "ammo_sniper" }

-- Loot with no use but its price at the trader.
ITEMS.valuable = {
    scrap = { name = "Scrap", kind = "valuable", w = 1, h = 1, stack = 10, price = 40 },
    battery = { name = "Battery", kind = "valuable", w = 1, h = 1, stack = 5, price = 120 },
    watch = { name = "Watch", kind = "valuable", w = 1, h = 1, price = 380 },
    chain = { name = "Gold chain", kind = "valuable", w = 1, h = 1, price = 650 },
    drive = { name = "Hard drive", kind = "valuable", w = 1, h = 1, price = 520 },
    gpu = { name = "Graphics card", kind = "valuable", w = 2, h = 1, price = 1600 },
    documents = { name = "Intel folder", kind = "valuable", w = 2, h = 1, price = 1100 },
    fang = { name = "Monster fang", kind = "valuable", w = 1, h = 1, stack = 8, price = 90 },
    core = { name = "Glowing core", kind = "valuable", w = 1, h = 1, price = 1400 },
    relic = { name = "Relic", kind = "valuable", w = 2, h = 2, price = 4200 },
    crown = { name = "Warden crown", kind = "valuable", w = 2, h = 2, price = 9000 }
}

ITEMS.valuableOrder = { "scrap", "battery", "fang", "watch", "drive", "chain", "documents", "core", "gpu", "relic", "crown" }

--- Every definition by id.
ITEMS.all = {}
for _, group in ipairs({ "weapon", "mod", "utility", "armor", "backpack", "ammo", "valuable" }) do
    for id, def in pairs(ITEMS[group]) do
        def.id = id
        def.stack = def.stack or 1
        ITEMS.all[id] = def
    end
end

-- What the trader sells, and the highest rarity it sells them in.
ITEMS.shop = {
    { id = "p9", rarity = 2 }, { id = "viper", rarity = 1 }, { id = "hornet", rarity = 1 }, { id = "pump", rarity = 1 },
    { id = "sawed", rarity = 1 }, { id = "ar", rarity = 1 }, { id = "carbine", rarity = 1 }, { id = "bolt", rarity = 1 },
    { id = "ammo_light" }, { id = "ammo_medium" }, { id = "ammo_heavy" }, { id = "ammo_shell" }, { id = "ammo_sniper" },
    { id = "bandage" }, { id = "medkit" }, { id = "stim" }, { id = "plate" }, { id = "frag" }, { id = "smoke" }, { id = "flash" }, { id = "molotov" },
    { id = "cap" }, { id = "helmet" }, { id = "vest" }, { id = "carrier" },
    { id = "sling" }, { id = "daypack" }, { id = "rucksack" },
    { id = "suppressor" }, { id = "compensator" }, { id = "choke" }, { id = "extended" }, { id = "quickmag" }, { id = "reddot" },
    { id = "flashlight" }, { id = "grip" }, { id = "hollow" }
}

return ITEMS
