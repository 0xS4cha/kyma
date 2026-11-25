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

-- Chance (out of 1000) of each rarity per danger tier; mythic mostly drops from events and bosses.
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
    light = { name = "Light rounds", color = { 0.84, 0.72, 0.36 }, stack = 40, price = 3 },
    medium = { name = "Medium rounds", color = { 0.74, 0.5, 0.26 }, stack = 40, price = 4 },
    heavy = { name = "Heavy rounds", color = { 0.6, 0.36, 0.2 }, stack = 30, price = 6 },
    shell = { name = "Shells", color = { 0.82, 0.24, 0.18 }, stack = 16, price = 7 },
    sniper = { name = "Sniper rounds", color = { 0.4, 0.42, 0.46 }, stack = 12, price = 10 },
    bolt = { name = "Crossbow bolts", color = { 0.5, 0.38, 0.24 }, stack = 10, price = 9 },
    cell = { name = "Energy cells", color = { 0.3, 0.78, 0.9 }, stack = 12, price = 30 },
    fuel = { name = "Fuel canister", color = { 0.86, 0.46, 0.12 }, stack = 60, price = 2 },
    nail = { name = "Nails", color = { 0.7, 0.72, 0.76 }, stack = 60, price = 1 },
    grenade = { name = "40 mm grenades", color = { 0.36, 0.46, 0.3 }, stack = 8, price = 60 }
}

ITEMS.caliberOrder = { "light", "medium", "heavy", "shell", "sniper", "bolt", "cell", "fuel", "nail", "grenade" }

local ALL = { "muzzle", "barrel", "mag", "optic", "under", "rounds" }
local PISTOL = { "muzzle", "mag", "optic", "under", "rounds" }
local SHOTGUN = { "muzzle", "barrel", "mag", "under", "rounds" }
local SPECIAL = { "barrel", "mag", "optic", "under" }

--- @param def table
local function weapon(def)
    def.kind = "weapon"
    def.pellets = def.pellets or 1
    def.slots = def.slots or ALL
    return def
end

-- Weapons. `look` is the model and sound used for it, `w` x `h` its size in the grid.
-- `set` lists built-in traits, applied like the traits of attachments.
ITEMS.weapon = {
    p9 = weapon({ name = "P9", class = "Pistol", look = "pistol", w = 2, h = 1, ammo = "light", price = 450, slots = PISTOL,
        damage = 28, spread = 0.014, range = 1300, fireTicks = 12, auto = false, magazine = 12, reloadTicks = 66, muzzle = 21 }),
    derringer = weapon({ name = "Pocket ace", class = "Derringer", look = "pistol", w = 1, h = 1, ammo = "heavy", price = 380, slots = { "rounds" },
        damage = 62, spread = 0.03, range = 700, fireTicks = 14, auto = false, magazine = 2, reloadTicks = 70, muzzle = 16 }),
    viper = weapon({ name = "Viper", class = "Machine pistol", look = "smg", w = 2, h = 1, ammo = "light", price = 900, slots = PISTOL,
        damage = 15, spread = 0.05, range = 900, fireTicks = 4, auto = true, magazine = 20, reloadTicks = 70, muzzle = 21 }),
    needle = weapon({ name = "Needle", class = "Silenced pistol", look = "silencer", w = 2, h = 1, ammo = "light", price = 1100, slots = PISTOL,
        damage = 30, spread = 0.012, range = 1200, fireTicks = 15, auto = false, magazine = 10, reloadTicks = 80, muzzle = 26, silent = true }),
    revolver = weapon({ name = "Bulldog", class = "Revolver", look = "revolver", w = 2, h = 1, ammo = "heavy", price = 1300, slots = PISTOL,
        damage = 58, spread = 0.01, range = 1500, fireTicks = 26, auto = false, magazine = 6, reloadTicks = 120, muzzle = 22 }),
    cannon = weapon({ name = "Hand cannon", class = "Pistol", look = "revolver", w = 2, h = 1, ammo = "heavy", price = 2100, slots = PISTOL,
        damage = 72, spread = 0.02, range = 1400, fireTicks = 34, auto = false, magazine = 7, reloadTicks = 100, muzzle = 24 }),
    flaregun = weapon({ name = "Flare gun", class = "Signal pistol", look = "pistol", w = 2, h = 1, ammo = "shell", price = 700, slots = { "barrel", "rounds" },
        damage = 22, spread = 0.02, range = 900, fireTicks = 40, auto = false, magazine = 1, reloadTicks = 70, muzzle = 22, set = { burn = 6, mark = 180 } }),
    nailer = weapon({ name = "Nailer", class = "Nail gun", look = "silencer", w = 2, h = 2, ammo = "nail", price = 600, slots = { "mag", "under", "rounds" },
        damage = 11, spread = 0.04, range = 650, fireTicks = 6, auto = true, magazine = 40, reloadTicks = 100, muzzle = 22, silent = true }),

    hornet = weapon({ name = "Hornet", class = "SMG", look = "smg", w = 3, h = 2, ammo = "light", price = 1500,
        damage = 17, spread = 0.04, range = 1100, fireTicks = 5, auto = true, magazine = 30, reloadTicks = 90, muzzle = 24 }),
    wasp = weapon({ name = "Wasp", class = "SMG", look = "smg", w = 3, h = 2, ammo = "light", price = 2200,
        damage = 13, spread = 0.055, range = 950, fireTicks = 3, auto = true, magazine = 32, reloadTicks = 84, muzzle = 23 }),
    drifter = weapon({ name = "Drifter", class = "SMG", look = "smg", w = 3, h = 2, ammo = "light", price = 2600,
        damage = 16, spread = 0.045, range = 1050, fireTicks = 5, auto = true, magazine = 50, reloadTicks = 130, muzzle = 25 }),
    ripper = weapon({ name = "Ripper", class = "SMG", look = "smg", w = 3, h = 2, ammo = "heavy", price = 3400,
        damage = 21, spread = 0.05, range = 1000, fireTicks = 4, auto = true, magazine = 25, reloadTicks = 95, muzzle = 24 }),
    lynx = weapon({ name = "Lynx", class = "PDW", look = "smg", w = 3, h = 2, ammo = "medium", price = 2900,
        damage = 19, spread = 0.035, range = 1250, fireTicks = 4, auto = true, magazine = 40, reloadTicks = 100, muzzle = 24 }),

    ar = weapon({ name = "AR-4", class = "Assault rifle", look = "rifle", w = 4, h = 2, ammo = "medium", price = 3200,
        damage = 24, spread = 0.032, range = 1600, fireTicks = 6, auto = true, magazine = 30, reloadTicks = 110, muzzle = 28 }),
    carbine = weapon({ name = "Ranger", class = "Carbine", look = "rifle", w = 4, h = 2, ammo = "medium", price = 3000,
        damage = 30, spread = 0.018, range = 1800, fireTicks = 9, auto = true, magazine = 25, reloadTicks = 105, muzzle = 28 }),
    bullpup = weapon({ name = "Fennec", class = "Bullpup rifle", look = "rifle", w = 3, h = 2, ammo = "medium", price = 3800,
        damage = 22, spread = 0.03, range = 1500, fireTicks = 5, auto = true, magazine = 30, reloadTicks = 120, muzzle = 25 }),
    scout = weapon({ name = "Scout", class = "Semi rifle", look = "dmr", w = 4, h = 1, ammo = "medium", price = 2400,
        damage = 42, spread = 0.01, range = 2100, fireTicks = 16, auto = false, magazine = 15, reloadTicks = 100, muzzle = 30 }),
    kestrel = weapon({ name = "Kestrel", class = "Rapid rifle", look = "rifle", w = 4, h = 2, ammo = "medium", price = 4600,
        damage = 20, spread = 0.028, range = 1500, fireTicks = 3, auto = true, magazine = 30, reloadTicks = 115, muzzle = 27 }),
    battle = weapon({ name = "Warden", class = "Battle rifle", look = "rifle", w = 4, h = 2, ammo = "heavy", price = 4800,
        damage = 40, spread = 0.022, range = 1900, fireTicks = 11, auto = true, magazine = 20, reloadTicks = 130, muzzle = 30 }),
    hammer = weapon({ name = "Hammer", class = "Heavy rifle", look = "rifle", w = 5, h = 2, ammo = "heavy", price = 5600,
        damage = 52, spread = 0.02, range = 2000, fireTicks = 15, auto = true, magazine = 15, reloadTicks = 140, muzzle = 31, speed = 0.92 }),
    lever = weapon({ name = "Homestead", class = "Lever action", look = "rifle", w = 4, h = 1, ammo = "heavy", price = 1800,
        damage = 64, spread = 0.012, range = 1900, fireTicks = 30, auto = false, magazine = 8, reloadTicks = 150, muzzle = 29 }),

    pump = weapon({ name = "Thumper", class = "Pump shotgun", look = "shotgun", w = 4, h = 1, ammo = "shell", price = 1400, slots = SHOTGUN,
        damage = 14, pellets = 7, spread = 0.22, range = 520, fireTicks = 45, auto = false, magazine = 6, reloadTicks = 120, muzzle = 25 }),
    auto = weapon({ name = "Riot", class = "Auto shotgun", look = "autoshotgun", w = 4, h = 2, ammo = "shell", price = 3600, slots = SHOTGUN,
        damage = 11, pellets = 6, spread = 0.24, range = 480, fireTicks = 16, auto = true, magazine = 8, reloadTicks = 150, muzzle = 26 }),
    double = weapon({ name = "Twin", class = "Double barrel", look = "shotgun", w = 4, h = 1, ammo = "shell", price = 1600, slots = SHOTGUN,
        damage = 16, pellets = 9, spread = 0.26, range = 460, fireTicks = 10, auto = false, magazine = 2, reloadTicks = 90, muzzle = 25 }),
    sawed = weapon({ name = "Stub", class = "Sawed-off", look = "shotgun", w = 2, h = 1, ammo = "shell", price = 900, slots = SHOTGUN,
        damage = 13, pellets = 8, spread = 0.34, range = 330, fireTicks = 12, auto = false, magazine = 2, reloadTicks = 80, muzzle = 18 }),
    slugger = weapon({ name = "Slugger", class = "Slug shotgun", look = "breaker", w = 4, h = 1, ammo = "shell", price = 2300, slots = SHOTGUN,
        damage = 78, pellets = 1, spread = 0.025, range = 1100, fireTicks = 40, auto = false, magazine = 5, reloadTicks = 130, muzzle = 26, set = { knock = 280 } }),
    drum12 = weapon({ name = "Typhoon", class = "Drum shotgun", look = "autoshotgun", w = 4, h = 2, ammo = "shell", price = 6200, slots = SHOTGUN,
        damage = 12, pellets = 7, spread = 0.26, range = 500, fireTicks = 9, auto = true, magazine = 20, reloadTicks = 220, muzzle = 27, speed = 0.88 }),

    bolt = weapon({ name = "Heron", class = "Bolt sniper", look = "sniper", w = 5, h = 1, ammo = "sniper", price = 4200,
        damage = 100, spread = 0, range = 3000, fireTicks = 75, auto = false, magazine = 5, reloadTicks = 150, muzzle = 36, exposed = true }),
    dmr = weapon({ name = "Marksman", class = "DMR", look = "dmr", w = 5, h = 2, ammo = "sniper", price = 5200,
        damage = 55, spread = 0.008, range = 2600, fireTicks = 22, auto = false, magazine = 10, reloadTicks = 130, muzzle = 34 }),
    longshot = weapon({ name = "Longshot", class = "Anti-materiel", look = "sniper", w = 6, h = 2, ammo = "sniper", price = 9000,
        damage = 160, spread = 0, range = 3600, fireTicks = 110, auto = false, magazine = 3, reloadTicks = 190, muzzle = 40, exposed = true, speed = 0.85, set = { pierce = 1 } }),
    crossbow = weapon({ name = "Whisper", class = "Crossbow", look = "sniper", w = 4, h = 2, ammo = "bolt", price = 2600, slots = { "optic", "under", "rounds" },
        damage = 85, spread = 0.004, range = 1800, fireTicks = 50, auto = false, magazine = 1, reloadTicks = 75, muzzle = 30, silent = true }),
    railgun = weapon({ name = "Tesla rail", class = "Railgun", look = "sniper", w = 6, h = 2, ammo = "cell", price = 16000, slots = SPECIAL,
        damage = 140, spread = 0, range = 4000, fireTicks = 90, auto = false, magazine = 4, reloadTicks = 170, muzzle = 40, speed = 0.88, set = { pierce = 3, armorPierce = 0.7, chain = 30 } }),

    lmg = weapon({ name = "Mule", class = "LMG", look = "lmg", w = 5, h = 2, ammo = "medium", price = 5600,
        damage = 19, spread = 0.06, range = 1500, fireTicks = 5, auto = true, magazine = 80, reloadTicks = 220, muzzle = 32, speed = 0.75 }),
    minigun = weapon({ name = "Shredder", class = "Rotary gun", look = "lmg", w = 6, h = 2, ammo = "medium", price = 12000,
        damage = 14, spread = 0.09, range = 1300, fireTicks = 2, auto = true, magazine = 200, reloadTicks = 320, muzzle = 34, speed = 0.6 }),
    scorcher = weapon({ name = "Scorcher", class = "Flamethrower", look = "lmg", w = 5, h = 2, ammo = "fuel", price = 6800, slots = SPECIAL,
        damage = 4, pellets = 6, spread = 0.3, range = 280, fireTicks = 3, auto = true, magazine = 100, reloadTicks = 200, muzzle = 30, speed = 0.85, set = { burn = 4 } }),
    launcher = weapon({ name = "Boomer", class = "Grenade launcher", look = "breaker", w = 4, h = 2, ammo = "grenade", price = 8200, slots = SPECIAL,
        damage = 30, spread = 0.02, range = 900, fireTicks = 55, auto = false, magazine = 4, reloadTicks = 180, muzzle = 28, set = { blast = 130 } })
}

ITEMS.weaponOrder = {
    "p9", "derringer", "viper", "needle", "revolver", "cannon", "flaregun", "nailer",
    "hornet", "wasp", "drifter", "ripper", "lynx",
    "ar", "carbine", "bullpup", "scout", "kestrel", "battle", "hammer", "lever",
    "pump", "auto", "double", "sawed", "slugger", "drum12",
    "bolt", "dmr", "longshot", "crossbow", "railgun",
    "lmg", "minigun", "scorcher", "launcher"
}

--- Attachments: `mul` multiplies weapon stats, `set` adds traits; both grow with rarity.
local function mod(def)
    def.kind = "mod"
    def.w, def.h = def.w or 1, def.h or 1
    return def
end

ITEMS.mod = {
    -- Muzzle
    suppressor = mod({ name = "Suppressor", slot = "muzzle", w = 2, price = 900, mul = { range = 0.9 }, set = { silent = true }, text = "Silent shots, slightly shorter range" }),
    oilcan = mod({ name = "Oil can suppressor", slot = "muzzle", w = 2, price = 400, mul = { range = 0.8, damage = 0.92 }, set = { silent = true }, text = "Crude but silent" }),
    compensator = mod({ name = "Compensator", slot = "muzzle", price = 600, mul = { spread = 0.72 }, text = "Tighter spread" }),
    brake = mod({ name = "Muzzle brake", slot = "muzzle", price = 700, mul = { spread = 0.82, fireTicks = 0.94 }, text = "Steadier and a bit faster" }),
    hider = mod({ name = "Flash hider", slot = "muzzle", price = 800, set = { hidden = true }, text = "Others don't see your tracers" }),
    choke = mod({ name = "Choke", slot = "muzzle", price = 500, mul = { spread = 0.6, range = 1.15 }, text = "Shotgun spread and reach" }),
    duckbill = mod({ name = "Duckbill", slot = "muzzle", price = 650, mul = { pellets = 1.35, spread = 1.25 }, text = "More pellets, wider spread" }),
    -- Barrel
    longbarrel = mod({ name = "Long barrel", slot = "barrel", w = 2, price = 800, mul = { range = 1.3, damage = 1.1 }, text = "Range and damage" }),
    shortbarrel = mod({ name = "Short barrel", slot = "barrel", price = 700, mul = { fireTicks = 0.82, spread = 1.15 }, text = "Fires faster, spreads more" }),
    heavybarrel = mod({ name = "Heavy barrel", slot = "barrel", w = 2, price = 1100, mul = { damage = 1.22, fireTicks = 1.1 }, text = "Hits harder, fires slower" }),
    fluted = mod({ name = "Fluted barrel", slot = "barrel", w = 2, price = 1000, mul = { range = 1.15, fireTicks = 0.92 }, text = "Light and fast" }),
    match = mod({ name = "Match barrel", slot = "barrel", w = 2, price = 1600, mul = { spread = 0.55 }, text = "Precision machined" }),
    sawn = mod({ name = "Sawn barrel", slot = "barrel", price = 300, mul = { range = 0.7, damage = 1.15, spread = 1.3 }, text = "Brutal up close" }),
    -- Magazine
    extended = mod({ name = "Extended mag", slot = "mag", h = 2, price = 700, mul = { magazine = 1.5 }, text = "+50% magazine" }),
    drum = mod({ name = "Drum mag", slot = "mag", w = 2, h = 2, price = 1500, mul = { magazine = 2.2, reloadTicks = 1.3 }, text = "Huge magazine, slow reload" }),
    quickmag = mod({ name = "Quick mag", slot = "mag", price = 900, mul = { reloadTicks = 0.6 }, text = "Fast reload" }),
    dualmag = mod({ name = "Taped mags", slot = "mag", h = 2, price = 800, mul = { reloadTicks = 0.75, magazine = 1.2 }, text = "Bigger and quicker" }),
    belt = mod({ name = "Ammo belt", slot = "mag", w = 2, h = 2, price = 2200, mul = { magazine = 3, reloadTicks = 1.6 }, set = { haste = 0.92 }, text = "Triple magazine, heavy" }),
    compact = mod({ name = "Compact mag", slot = "mag", price = 500, mul = { magazine = 0.75, reloadTicks = 0.5 }, set = { haste = 1.04 }, text = "Small, light, instant reload" }),
    -- Optic
    reddot = mod({ name = "Red dot", slot = "optic", price = 500, mul = { spread = 0.85 }, text = "Steadier aim" }),
    holo = mod({ name = "Holo sight", slot = "optic", price = 800, mul = { spread = 0.78 }, text = "Steady aim" }),
    scope = mod({ name = "Scope", slot = "optic", w = 2, price = 1400, mul = { spread = 0.8 }, set = { sight = 200 }, text = "See farther ahead" }),
    acog = mod({ name = "Combat scope", slot = "optic", w = 2, price = 2000, mul = { spread = 0.9 }, set = { sight = 300 }, text = "See much farther ahead" }),
    rangefinder = mod({ name = "Rangefinder", slot = "optic", price = 1200, mul = { range = 1.25 }, set = { sight = 80 }, text = "Bullets carry farther" }),
    laser = mod({ name = "Laser sight", slot = "optic", price = 800, mul = { spread = 0.62 }, set = { exposed = true }, text = "Very tight spread, enemies see your laser" }),
    thermal = mod({ name = "Thermal sight", slot = "optic", w = 2, price = 4200, set = { thermal = 260 }, text = "See bodies around you through the dark" }),
    -- Underbarrel
    flashlight = mod({ name = "Flashlight", slot = "under", price = 450, set = { light = true }, text = "Lights far ahead in the dark" }),
    strobe = mod({ name = "Strobe light", slot = "under", price = 1500, set = { light = true, daze = 20 }, text = "Light that dazes monsters you hit" }),
    grip = mod({ name = "Grip", slot = "under", price = 600, mul = { spread = 0.8 }, text = "Tighter spread" }),
    angled = mod({ name = "Angled grip", slot = "under", price = 700, mul = { fireTicks = 0.93 }, text = "Faster follow-up shots" }),
    stock = mod({ name = "Light stock", slot = "under", price = 700, set = { haste = 1.06 }, text = "Move faster while holding it" }),
    bipod = mod({ name = "Bipod", slot = "under", w = 2, price = 900, mul = { spread = 0.5 }, set = { haste = 0.92 }, text = "Rock steady, heavier" }),
    -- Rounds
    bouncing = mod({ name = "Bouncing rounds", slot = "rounds", price = 1200, set = { bounce = 2 }, mul = { damage = 0.9 }, text = "Bullets ricochet off walls twice" }),
    piercing = mod({ name = "Piercing rounds", slot = "rounds", price = 1400, set = { pierce = 1, armorPierce = 0.5 }, text = "Go through a target and half of armor" }),
    incendiary = mod({ name = "Incendiary rounds", slot = "rounds", price = 1300, set = { burn = 3 }, text = "Sets targets on fire" }),
    explosive = mod({ name = "Explosive rounds", slot = "rounds", price = 2200, set = { blast = 70 }, mul = { damage = 0.8 }, text = "Small explosion on impact" }),
    hollow = mod({ name = "Hollow points", slot = "rounds", price = 800, set = { flesh = 1.35, armorPierce = -0.3 }, text = "+35% against monsters, weak against armor" }),
    frost = mod({ name = "Frost rounds", slot = "rounds", price = 1100, set = { chill = 70 }, text = "Slows what you hit" }),
    vampire = mod({ name = "Leech rounds", slot = "rounds", price = 2600, set = { leech = 0.15 }, text = "Heal 15% of the damage you deal" }),
    shock = mod({ name = "Shock rounds", slot = "rounds", price = 2400, set = { chain = 40 }, text = "Arcs to another enemy nearby" }),
    toxic = mod({ name = "Toxic rounds", slot = "rounds", price = 1500, set = { poison = 5 }, text = "Poison that lingers" }),
    tracer = mod({ name = "Tracer rounds", slot = "rounds", price = 600, set = { mark = 150 }, text = "Hit targets stay visible to you for a while" }),
    rubber = mod({ name = "Rubber rounds", slot = "rounds", price = 500, set = { knock = 240 }, mul = { damage = 0.7 }, text = "Knock targets back" }),
    split = mod({ name = "Split rounds", slot = "rounds", price = 1700, mul = { pellets = 2, damage = 0.58 }, text = "Every shot splits in two" }),
    ap = mod({ name = "AP rounds", slot = "rounds", price = 1600, set = { armorPierce = 0.8 }, mul = { damage = 0.92 }, text = "Ignore most armor" }),
    magnum = mod({ name = "Magnum rounds", slot = "rounds", price = 1300, mul = { damage = 1.25, fireTicks = 1.15 }, text = "Heavier hits, slower fire" }),
    ghost = mod({ name = "Ghost rounds", slot = "rounds", price = 2800, set = { silent = true, hidden = true }, mul = { damage = 0.85 }, text = "Silent and invisible shots" }),
    execution = mod({ name = "Execution rounds", slot = "rounds", price = 2000, set = { execute = 0.3 }, text = "x1.6 damage on wounded targets" })
}

ITEMS.modOrder = {
    "suppressor", "oilcan", "compensator", "brake", "hider", "choke", "duckbill",
    "longbarrel", "shortbarrel", "heavybarrel", "fluted", "match", "sawn",
    "extended", "drum", "quickmag", "dualmag", "belt", "compact",
    "reddot", "holo", "scope", "acog", "rangefinder", "laser", "thermal",
    "flashlight", "strobe", "grip", "angled", "stock", "bipod",
    "bouncing", "piercing", "incendiary", "explosive", "hollow", "frost", "vampire", "shock", "toxic", "tracer",
    "rubber", "split", "ap", "magnum", "ghost", "execution"
}

--- Utilities go in the quick slots (keys 3 to 6 by default).
local function utility(def)
    def.kind = "utility"
    def.w, def.h = def.w or 1, def.h or 1
    return def
end

ITEMS.utility = {
    bandage = utility({ name = "Bandage", stack = 4, price = 150, heal = 20, useTicks = 90, text = "Heals 20 over 1.5 s" }),
    food = utility({ name = "Canned food", stack = 3, price = 100, heal = 15, useTicks = 120, text = "Heals 15" }),
    medkit = utility({ name = "Medkit", h = 2, price = 700, heal = 70, useTicks = 210, text = "Heals 70, takes 3.5 s" }),
    trauma = utility({ name = "Trauma kit", w = 2, h = 2, price = 1600, heal = 100, useTicks = 300, cure = true, text = "Full heal and cures burns and poison" }),
    stim = utility({ name = "Stim", stack = 2, price = 900, heal = 10, useTicks = 30, haste = 60 * 12, text = "Heal 10 and run 25% faster for 12 s" }),
    adrenaline = utility({ name = "Adrenaline", stack = 2, price = 1200, regen = 40, useTicks = 20, rush = 60 * 15, text = "Heals 40 over 10 s, dash recharges twice as fast" }),
    painkillers = utility({ name = "Painkillers", stack = 3, price = 600, useTicks = 40, fortify = 60 * 20, text = "Take 25% less damage for 20 s" }),
    antidote = utility({ name = "Antidote", stack = 2, price = 400, useTicks = 40, cure = true, text = "Cures burns, poison and frost" }),
    plate = utility({ name = "Armor plate", w = 2, price = 600, repair = 45, useTicks = 150, text = "Repairs your vest by 45" }),
    frag = utility({ name = "Frag grenade", stack = 3, price = 400, throw = "frag", text = "Explodes after 1.6 s" }),
    sticky = utility({ name = "Sticky bomb", stack = 2, price = 700, throw = "sticky", text = "Sticks to the first thing it hits" }),
    smoke = utility({ name = "Smoke grenade", stack = 3, price = 250, throw = "smoke", text = "Blocks sight for 9 s" }),
    flash = utility({ name = "Flashbang", stack = 3, price = 300, throw = "flash", text = "Blinds and stuns those who look at it" }),
    molotov = utility({ name = "Molotov", stack = 2, price = 450, throw = "fire", text = "Burns the ground for 7 s" }),
    cryo = utility({ name = "Cryo grenade", stack = 2, price = 650, throw = "cryo", text = "Freezes everything around it" }),
    gas = utility({ name = "Gas grenade", stack = 2, price = 700, throw = "gas", text = "A poison cloud for 8 s" }),
    decoy = utility({ name = "Noisemaker", stack = 3, price = 200, throw = "decoy", text = "Lures monsters with fake gunfire" }),
    mine = utility({ name = "Tripmine", w = 2, stack = 2, price = 900, place = "mine", text = "Explodes when an enemy comes close" }),
    scanner = utility({ name = "Pulse scanner", h = 2, stack = 1, price = 1500, scan = 700, charges = 3, useTicks = 30, text = "Reveals every body within 700 for 4 s" }),
    beacon = utility({ name = "Extraction flare", h = 2, stack = 1, price = 6000, beacon = 60 * 45, useTicks = 60, text = "Calls an extraction where you stand in 45 s" }),
    energy = utility({ name = "Energy drink", stack = 3, price = 250, useTicks = 30, rush = 60 * 20, text = "Dash recharges twice as fast for 20 s" })
}

ITEMS.utilityOrder = {
    "bandage", "food", "medkit", "trauma", "stim", "adrenaline", "painkillers", "antidote", "energy", "plate",
    "frag", "sticky", "smoke", "flash", "molotov", "cryo", "gas", "decoy", "mine", "scanner", "beacon"
}

ITEMS.armor = {
    cap = { name = "Cap", kind = "armor", slot = "helmet", w = 2, h = 2, price = 300, reduce = 0.08, durability = 40 },
    helmet = { name = "Helmet", kind = "armor", slot = "helmet", w = 2, h = 2, price = 1200, reduce = 0.15, durability = 80, flash = 0.5 },
    visor = { name = "Visor helmet", kind = "armor", slot = "helmet", w = 2, h = 2, price = 2600, reduce = 0.22, durability = 120, flash = 0.2 },
    gasmask = { name = "Gas mask", kind = "armor", slot = "helmet", w = 2, h = 2, price = 1400, reduce = 0.06, durability = 60, immune = "poison" },
    nightcap = { name = "Night vision helmet", kind = "armor", slot = "helmet", w = 2, h = 2, price = 4800, reduce = 0.14, durability = 90, sight = 160 },
    vest = { name = "Light vest", kind = "armor", slot = "vest", w = 2, h = 3, price = 900, reduce = 0.25, durability = 100 },
    rig = { name = "Chest rig", kind = "armor", slot = "vest", w = 2, h = 2, price = 800, reduce = 0.12, durability = 70, haste = 1.03 },
    carrier = { name = "Plate carrier", kind = "armor", slot = "vest", w = 3, h = 3, price = 2400, reduce = 0.38, durability = 160, haste = 0.97 },
    firesuit = { name = "Fire suit", kind = "armor", slot = "vest", w = 3, h = 3, price = 2200, reduce = 0.2, durability = 120, immune = "burn" },
    juggernaut = { name = "Juggernaut", kind = "armor", slot = "vest", w = 3, h = 3, price = 6000, reduce = 0.52, durability = 260, haste = 0.9 }
}

ITEMS.armorOrder = { "cap", "helmet", "visor", "gasmask", "nightcap", "rig", "vest", "carrier", "firesuit", "juggernaut" }

ITEMS.backpack = {
    sling = { name = "Sling bag", kind = "backpack", w = 2, h = 2, grid = { 2, 3 }, price = 400 },
    daypack = { name = "Daypack", kind = "backpack", w = 3, h = 3, grid = { 3, 4 }, price = 1100 },
    rucksack = { name = "Rucksack", kind = "backpack", w = 3, h = 4, grid = { 4, 5 }, price = 2600 },
    raid = { name = "Raid pack", kind = "backpack", w = 4, h = 4, grid = { 5, 5 }, price = 5200 },
    hauler = { name = "Hauler frame", kind = "backpack", w = 4, h = 5, grid = { 6, 6 }, price = 9000, haste = 0.94 }
}

ITEMS.backpackOrder = { "sling", "daypack", "rucksack", "raid", "hauler" }

ITEMS.ammo = {}
ITEMS.ammoOrder = {}
for _, id in ipairs(ITEMS.caliberOrder) do
    local caliber = ITEMS.calibers[id]
    ITEMS.ammo["ammo_" .. id] = {
        name = caliber.name, kind = "ammo", caliber = id, w = 1, h = 1, stack = caliber.stack, price = caliber.price, color = caliber.color
    }
    ITEMS.ammoOrder[#ITEMS.ammoOrder + 1] = "ammo_" .. id
end

-- Crafting materials. Most of the scrap you find ends up here.
local function material(name, price, stack, w, h)
    return { name = name, kind = "material", price = price, stack = math.min(12, stack or 10), w = w or 1, h = h or 1 }
end

ITEMS.material = {
    scrap = material("Scrap metal", 30, 20),
    screws = material("Screws", 20, 30),
    springs = material("Springs", 45, 20),
    string = material("String", 15, 20),
    cloth = material("Cloth", 20, 20),
    tape = material("Duct tape", 40, 10),
    wood = material("Planks", 25, 10, 2, 1),
    glue = material("Glue", 35, 10),
    powder = material("Gunpowder", 30, 30),
    chemicals = material("Chemicals", 60, 10),
    wires = material("Wires", 50, 20),
    circuit = material("Circuit board", 160, 10),
    lens = material("Glass lens", 140, 10),
    steel = material("Steel plate", 120, 5, 2, 1),
    polymer = material("Polymer", 90, 10),
    fuelcan = material("Fuel", 50, 10),
    battery = material("Battery", 120, 5),
    alloy = material("Rare alloy", 900, 5),
    fang = material("Monster fang", 90, 10),
    core = material("Glowing core", 1400, 3)
}

ITEMS.materialOrder = {
    "scrap", "screws", "springs", "string", "cloth", "tape", "wood", "glue", "powder", "chemicals",
    "wires", "circuit", "lens", "steel", "polymer", "fuelcan", "battery", "alloy", "fang", "core"
}

-- Loot with no use but its price at the trader.
ITEMS.valuable = {
    watch = { name = "Watch", kind = "valuable", w = 1, h = 1, price = 380 },
    lighter = { name = "Gold lighter", kind = "valuable", w = 1, h = 1, price = 300 },
    chain = { name = "Gold chain", kind = "valuable", w = 1, h = 1, price = 650 },
    drive = { name = "Hard drive", kind = "valuable", w = 1, h = 1, price = 520 },
    phone = { name = "Old phone", kind = "valuable", w = 1, h = 1, price = 260 },
    gpu = { name = "Graphics card", kind = "valuable", w = 2, h = 1, price = 1600 },
    documents = { name = "Intel folder", kind = "valuable", w = 2, h = 1, price = 1100 },
    statue = { name = "Jade statue", kind = "valuable", w = 1, h = 2, price = 1900 },
    painting = { name = "Painting", kind = "valuable", w = 3, h = 2, price = 2600 },
    relic = { name = "Relic", kind = "valuable", w = 2, h = 2, price = 4200 },
    crown = { name = "Warden crown", kind = "valuable", w = 2, h = 2, price = 9000 }
}

ITEMS.valuableOrder = { "phone", "lighter", "watch", "drive", "chain", "documents", "gpu", "statue", "painting", "relic", "crown" }

-- What each crafted item is made of (at common rarity). Higher rarities cost more of
-- the same, plus rare alloy (epic and up) and glowing cores (legendary and up).
local RECIPES = {
    -- weapons by class
    pistol = { scrap = 4, screws = 3, springs = 1 },
    smg = { scrap = 7, screws = 5, springs = 2, polymer = 1 },
    rifle = { scrap = 10, screws = 6, springs = 3, wood = 1, steel = 1 },
    shotgun = { scrap = 8, screws = 4, springs = 2, wood = 2 },
    sniper = { scrap = 10, screws = 6, springs = 2, steel = 2, lens = 1 },
    heavy = { scrap = 16, screws = 10, springs = 4, steel = 3 },
    -- attachments by slot
    muzzle = { scrap = 3, screws = 2, steel = 1 },
    barrel = { scrap = 4, steel = 1, screws = 1 },
    mag = { scrap = 3, springs = 2, screws = 1 },
    optic = { lens = 1, screws = 2, wires = 1 },
    under = { scrap = 2, tape = 1, screws = 2 },
    rounds = { powder = 6, scrap = 2, chemicals = 1 },
    -- other kinds
    armor = { cloth = 4, steel = 2, tape = 2, string = 2 },
    backpack = { cloth = 6, string = 4, tape = 1 },
    medical = { cloth = 2, chemicals = 1 },
    grenade = { powder = 4, scrap = 2, tape = 1 },
    gadget = { wires = 2, circuit = 1, battery = 1, tape = 1 }
}

-- Extra parts for specific items, added to their class recipe.
local EXTRA = {
    railgun = { circuit = 4, battery = 3, core = 1 }, scorcher = { fuelcan = 4, polymer = 2 }, launcher = { powder = 10, circuit = 1 },
    crossbow = { string = 4, wood = 2 }, nailer = { battery = 1, wires = 2 }, flaregun = { powder = 3 },
    thermal = { circuit = 2, battery = 1 }, laser = { circuit = 1, battery = 1 }, flashlight = { battery = 1, wires = 1 },
    strobe = { battery = 2, circuit = 1 }, scope = { lens = 1 }, acog = { lens = 2 }, rangefinder = { circuit = 1 },
    incendiary = { fuelcan = 2 }, explosive = { powder = 6 }, toxic = { chemicals = 3 }, frost = { chemicals = 2 },
    shock = { battery = 1, wires = 2 }, vampire = { fang = 4, core = 1 }, ghost = { polymer = 2, core = 1 },
    molotov = { fuelcan = 2, cloth = 1 }, cryo = { chemicals = 3 }, gas = { chemicals = 3 }, smoke = { chemicals = 2 },
    mine = { wires = 2, battery = 1 }, scanner = { circuit = 2, lens = 1 }, beacon = { circuit = 3, powder = 4, core = 1 },
    trauma = { chemicals = 3, cloth = 3 }, stim = { chemicals = 2 }, adrenaline = { chemicals = 3 }, plate = { steel = 2 },
    firesuit = { chemicals = 3, cloth = 4 }, gasmask = { polymer = 2, chemicals = 1 }, nightcap = { lens = 2, circuit = 2, battery = 1 },
    juggernaut = { steel = 6, alloy = 1 }, hauler = { steel = 2, alloy = 1 }
}

local function classOf(def)
    if def.kind == "weapon" then
        if def.look == "pistol" or def.look == "silencer" then return "pistol" end
        if def.look == "shotgun" then return "shotgun" end
        if def.look == "sniper" then return "sniper" end
        if def.look == "lmg" then return "heavy" end
        return (def.class == "SMG" or def.class == "PDW") and "smg" or "rifle"
    end
    if def.kind == "mod" then return def.slot end
    if def.kind == "utility" then
        if def.heal or def.regen or def.cure or def.repair or def.fortify or def.rush or def.haste then return "medical" end
        if def.throw and def.throw ~= "decoy" then return "grenade" end
        return "gadget"
    end
    return def.kind
end

--- Every definition by id.
ITEMS.all = {}
for _, group in ipairs({ "weapon", "mod", "utility", "armor", "backpack", "ammo", "material", "valuable" }) do
    for id, def in pairs(ITEMS[group]) do
        def.id = id
        def.stack = def.stack or 1
        ITEMS.all[id] = def
    end
end

-- Blueprints: one per craftable item. Learning one at the workbench lets you craft
-- that item up to the blueprint's rarity.
ITEMS.blueprint = {}
ITEMS.recipes = {}
ITEMS.craftOrder = {}
for _, group in ipairs({ "weaponOrder", "modOrder", "utilityOrder", "armorOrder", "backpackOrder" }) do
    for _, id in ipairs(ITEMS[group]) do
        local def = ITEMS.all[id]
        local parts = {}
        for material, n in pairs(RECIPES[classOf(def)] or {}) do parts[material] = n end
        for material, n in pairs(EXTRA[id] or {}) do parts[material] = (parts[material] or 0) + n end
        local scale = math.max(1, def.price / 1500)
        local list = {}
        for _, material in ipairs(ITEMS.materialOrder) do
            if parts[material] then
                list[#list + 1] = { id = material, n = math.max(1, math.floor(parts[material] * ((material == "core" or material == "alloy") and 1 or scale ^ 0.5) + 0.5)) }
            end
        end
        ITEMS.recipes[id] = list
        ITEMS.craftOrder[#ITEMS.craftOrder + 1] = id
        local plan = { id = "plan_" .. id, name = "Plan: " .. def.name, kind = "blueprint", target = id, w = 1, h = 1, stack = 1, price = math.floor(def.price * 0.6 + 100) }
        ITEMS.blueprint[plan.id] = plan
        ITEMS.all[plan.id] = plan
    end
end
for _, id in ipairs(ITEMS.ammoOrder) do
    local caliber = ITEMS.all[id].caliber
    local parts = { { id = "powder", n = 2 }, { id = "scrap", n = 1 } }
    if caliber == "cell" then parts = { { id = "battery", n = 1 }, { id = "wires", n = 1 } } end
    if caliber == "fuel" then parts = { { id = "fuelcan", n = 1 } } end
    if caliber == "nail" then parts = { { id = "scrap", n = 2 } } end
    if caliber == "bolt" then parts = { { id = "wood", n = 1 }, { id = "scrap", n = 1 } } end
    if caliber == "grenade" then parts = { { id = "powder", n = 6 }, { id = "scrap", n = 2 } } end
    ITEMS.recipes[id] = parts
    ITEMS.craftOrder[#ITEMS.craftOrder + 1] = id
end

-- How many of an item one craft makes (ammo comes by the half stack).
--- @param id string
--- @return number
function ITEMS.yield(id)
    local def = ITEMS.all[id]
    if def and def.kind == "ammo" then return math.max(1, math.floor(def.stack / 2)) end
    return 1
end

-- Recipes everyone knows from the start (common rarity).
ITEMS.known = { "bandage", "food", "p9", "sawed", "cap", "sling", "reddot", "oilcan", "frag", "smoke" }
for _, id in ipairs(ITEMS.ammoOrder) do ITEMS.known[#ITEMS.known + 1] = id end

-- What valuables break down into at the workbench (per item in the stack).
ITEMS.salvage = {
    phone = { { id = "wires", n = 2 }, { id = "circuit", n = 1 } },
    lighter = { { id = "scrap", n = 1 }, { id = "fuelcan", n = 1 } },
    watch = { { id = "springs", n = 2 }, { id = "screws", n = 2 } },
    drive = { { id = "circuit", n = 1 }, { id = "wires", n = 2 } },
    chain = { { id = "alloy", n = 1 } },
    documents = { { id = "string", n = 2 }, { id = "glue", n = 1 } },
    gpu = { { id = "circuit", n = 3 }, { id = "wires", n = 2 }, { id = "polymer", n = 1 } },
    statue = { { id = "steel", n = 1 }, { id = "polymer", n = 2 } },
    painting = { { id = "wood", n = 2 }, { id = "cloth", n = 3 }, { id = "chemicals", n = 1 } },
    relic = { { id = "alloy", n = 2 }, { id = "core", n = 1 } },
    crown = { { id = "alloy", n = 3 }, { id = "core", n = 2 } }
}

return ITEMS
