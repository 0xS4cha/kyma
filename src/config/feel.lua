local FEEL = {
    shake = {
        pistol = 0.16,
        silencer = 0.1,
        rifle = 0.12,
        lmg = 0.13,
        shotgun = 0.42,
        sniper = 0.55,
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
