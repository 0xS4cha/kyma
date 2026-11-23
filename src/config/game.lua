local CONFIG = {
    tickRate = 60,
    snapshotTicks = 2,

    player = {
        radius = 14,
        speed = 230,
        backSpeed = 0.7,
        acceleration = 14
    },

    health = 100,
    respawnTicks = 120,
    rewindTicks = 20,

    vision = {
        halfAngle = 0.95,
        nearRadius = 90,
        range = 1500,
        serverMargin = 0.2,
        serverNearRadius = 130
    },

    noise = {
        shot = 1100,
        dash = 420,
        step = 320,
        throw = 380,
        clank = 420,
        slide = 380,
        stepTicks = 20,
        stepSpeed = 110,
        quietSpeed = 0.45
    },

    slide = {
        ticks = 28,
        speed = 760,
        endSpeed = 140,
        invulnerable = 8,
        runSpeed = 0.8
    },

    dash = {
        speed = 900,
        ticks = 9,
        cooldown = 60
    },

    camera = {
        scale = 1.6,
        anchorX = 0.5,
        anchorY = 0.68,
        minScale = 0.8,
        maxScale = 3
    },

    mouseSensitivity = 0.0035,
    turnSpeed = 3,
    laserLength = 900,
    interpolationTicks = 6
}

return CONFIG
