local WEAPONS = {
    order = { "pistol", "rifle", "shotgun", "sniper", "silencer", "lmg" },

    pistol = {
        name = "PISTOL",
        damage = 34,
        pellets = 1,
        spread = 0.012,
        range = 1400,
        fireTicks = 14,
        auto = false,
        magazine = 8,
        reserve = 32,
        reloadTicks = 70,
        muzzle = 21
    },

    rifle = {
        name = "RIFLE",
        damage = 22,
        pellets = 1,
        spread = 0.035,
        range = 1600,
        fireTicks = 6,
        auto = true,
        magazine = 24,
        reserve = 48,
        reloadTicks = 110,
        muzzle = 28
    },

    shotgun = {
        name = "SHOTGUN",
        damage = 14,
        pellets = 7,
        spread = 0.22,
        range = 520,
        fireTicks = 45,
        auto = false,
        magazine = 5,
        reserve = 15,
        reloadTicks = 120,
        muzzle = 25
    },

    sniper = {
        name = "SNIPER",
        tag = "One shot kills. Your laser shows through walls",
        damage = 100,
        pellets = 1,
        spread = 0,
        range = 3000,
        fireTicks = 75,
        auto = false,
        magazine = 4,
        reserve = 8,
        reloadTicks = 150,
        muzzle = 36,
        exposed = true
    },

    silencer = {
        name = "SILENCER",
        tag = "Silent. Only seen by those who see you",
        damage = 30,
        pellets = 1,
        spread = 0.015,
        range = 1300,
        fireTicks = 15,
        auto = false,
        magazine = 10,
        reserve = 30,
        reloadTicks = 80,
        muzzle = 26,
        silent = true
    },

    lmg = {
        name = "LMG",
        tag = "Heavy. Slows you down, no slide",
        damage = 15,
        pellets = 1,
        spread = 0.06,
        range = 1500,
        fireTicks = 5,
        auto = true,
        magazine = 60,
        reserve = 60,
        reloadTicks = 210,
        muzzle = 32,
        speed = 0.72
    },

    throw = {
        damage = 45,
        speed = 750,
        inherit = 0.3,
        friction = 0.985,
        landSpeed = 150,
        radius = 6
    },

    ammoReserveCap = 2,
    pickupRadius = 34,
    itemLifetime = 45 * 60,
    padRespawn = 600,
    maxItems = 24
}

return WEAPONS
