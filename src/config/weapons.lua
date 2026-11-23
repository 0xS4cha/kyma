local WEAPONS = {
    order = { "pistol", "rifle", "shotgun" },

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
