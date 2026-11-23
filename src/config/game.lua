local CONFIG = {
    tickRate = 60,
    snapshotTicks = 2,

    player = {
        radius = 14,
        speed = 230,
        backSpeed = 0.7,
        acceleration = 14
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
