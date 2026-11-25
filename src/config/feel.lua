local FEEL = {
    shake = {
        pistol = 0.16,
        silencer = 0.1,
        rifle = 0.12,
        lmg = 0.13,
        shotgun = 0.42,
        sniper = 0.55,
        smg = 0.1,
        revolver = 0.4,
        dmr = 0.3,
        autoshotgun = 0.3,
        breaker = 0.45,
        fists = 0.05,
        dash = 0.07,
        hurt = 0.28,
        hurtPerDamage = 0.006,
        hitGiven = 0.06,
        punchLanded = 0.3,
        killGiven = 0.22,
        death = 0.75,
        nearbyShot = 0.12,
        nearbyRange = 520
    },
    recoil = {
        pistol = { gun = 4, camera = 5 },
        silencer = { gun = 3, camera = 3 },
        rifle = { gun = 3, camera = 3.5 },
        lmg = { gun = 3.5, camera = 4 },
        shotgun = { gun = 7, camera = 10 },
        sniper = { gun = 9, camera = 14 },
        smg = { gun = 2.5, camera = 2.5 },
        revolver = { gun = 7, camera = 8 },
        dmr = { gun = 5, camera = 6 },
        autoshotgun = { gun = 5, camera = 6 },
        breaker = { gun = 8, camera = 11 },
        recovery = 16
    },
    hitstop = {
        killGiven = 0.1,
        punchLanded = 0.075,
        death = 0.12,
        heavyHit = 0.06,
        heavyDamage = 40
    },
    strength = { 0, 0.5, 1 },
    labels = { "Off", "Low", "Full" }
}

return FEEL
