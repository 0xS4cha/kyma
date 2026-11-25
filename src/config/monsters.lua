--- Monsters of the extraction mode. `attack` is "melee", "spit" (a slow projectile) or
--- "burst" (hitscan bullets). Nests pick their kinds from the biome and danger tier.
local MONSTERS = {
    order = { "crawler", "stalker", "brute", "spitter", "sentinel", "warden" },

    crawler = {
        name = "Crawler", hp = 45, speed = 250, radius = 13, color = { 0.42, 0.5, 0.36 },
        attack = "melee", damage = 11, reach = 30, cooldown = 40, sight = 420, hearing = 1.0, loot = { fang = 0.5 }
    },
    stalker = {
        name = "Stalker", hp = 85, speed = 265, radius = 13, color = { 0.24, 0.2, 0.3 },
        attack = "melee", damage = 24, reach = 34, cooldown = 48, sight = 380, hearing = 1.3, faint = true, loot = { fang = 0.8, core = 0.06 }
    },
    brute = {
        name = "Brute", hp = 340, speed = 150, radius = 24, color = { 0.56, 0.34, 0.26 },
        attack = "melee", damage = 34, reach = 44, cooldown = 70, sight = 360, hearing = 0.8, knock = 520, loot = { fang = 1, core = 0.15 }
    },
    spitter = {
        name = "Spitter", hp = 70, speed = 175, radius = 14, color = { 0.5, 0.66, 0.2 },
        attack = "spit", damage = 16, range = 520, keep = 300, cooldown = 80, projectile = 420, sight = 500, hearing = 1.0, loot = { fang = 0.6, core = 0.04 }
    },
    sentinel = {
        name = "Sentinel", hp = 180, speed = 120, radius = 16, color = { 0.36, 0.4, 0.46 },
        attack = "burst", damage = 9, range = 700, keep = 420, cooldown = 110, burst = 4, burstTicks = 6, spread = 0.08, sight = 620, hearing = 0.7,
        armored = 0.25, loot = { battery = 0.7, scrap = 1, drive = 0.1 }
    },
    warden = {
        name = "The Warden", hp = 3200, speed = 165, radius = 34, color = { 0.62, 0.12, 0.16 },
        attack = "burst", damage = 14, range = 760, keep = 260, cooldown = 70, burst = 8, burstTicks = 4, spread = 0.12, sight = 700, hearing = 1.5,
        armored = 0.3, boss = true, summon = "crawler", summonEvery = 60 * 9, loot = { crown = 1, core = 1, relic = 0.5 }
    }
}

-- Which monsters a nest spawns, per biome, and how many per tier.
MONSTERS.nests = {
    forest = { "crawler", "crawler", "stalker", "spitter" },
    field = { "crawler", "crawler", "spitter" },
    lake = { "crawler", "spitter", "spitter" },
    town = { "crawler", "crawler", "stalker", "brute", "spitter" },
    industrial = { "crawler", "brute", "spitter", "sentinel" },
    military = { "sentinel", "sentinel", "brute", "stalker" }
}

MONSTERS.nestSize = { 2, 3, 4, 5 }
MONSTERS.respawn = 60 * 120

return MONSTERS
