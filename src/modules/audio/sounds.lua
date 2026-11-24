local Synth = require("src.modules.audio.synth")

local Sounds = {}

local function merge(...)
    local layers = {}
    for _, list in ipairs({ ... }) do
        for _, layer in ipairs(list) do layers[#layers + 1] = layer end
    end
    return layers
end

local function shot(volume, body, crack, tail, extra)
    local layers = {
        { wave = "noise", from = crack, to = crack * 0.4, length = tail, volume = 0.55, cutoff = crack, cutoffTo = 600, curve = 2.4 },
        { wave = "square", duty = 0.3, from = body, to = body * 0.35, length = tail * 0.6, volume = 0.45, curve = 2 }
    }
    for _, layer in ipairs(extra or {}) do layers[#layers + 1] = layer end
    return { volume = volume, cooldown = 0.02, jitter = 0.05, voices = 6, layers = layers }
end

Sounds.pistol = shot(0.5, 220, 7000, 0.16)
Sounds.rifle = shot(0.45, 180, 6000, 0.12)
Sounds.lmg = shot(0.48, 140, 5000, 0.13, { { wave = "triangle", from = 70, to = 40, length = 0.1, volume = 0.4 } })
Sounds.shotgun = shot(0.6, 120, 4500, 0.32, { { wave = "noise", from = 1500, to = 400, length = 0.3, volume = 0.4, cutoff = 1200, cutoffTo = 200 } })
Sounds.sniper = shot(0.65, 90, 8000, 0.55, { { wave = "triangle", from = 60, to = 30, length = 0.5, volume = 0.5, curve = 1.5 } })
Sounds.silencer = {
    volume = 0.35, cooldown = 0.02, jitter = 0.06, voices = 4,
    layers = {
        { wave = "noise", from = 1800, to = 600, length = 0.08, volume = 0.5, cutoff = 1400, cutoffTo = 300 },
        { wave = "sine", from = 260, to = 120, length = 0.06, volume = 0.3 }
    }
}
Sounds.empty = {
    volume = 0.35, cooldown = 0.12,
    layers = { { wave = "square", duty = 0.2, from = 1800, length = 0.02, volume = 0.4 }, { wave = "noise", from = 9000, length = 0.015, volume = 0.2 } }
}
Sounds.reload = {
    volume = 0.35, cooldown = 0.3,
    layers = {
        { wave = "noise", from = 6000, length = 0.03, volume = 0.4, cutoff = 4000 },
        { wave = "square", duty = 0.25, from = 900, to = 700, length = 0.04, volume = 0.3 },
        { wave = "noise", from = 5000, length = 0.04, volume = 0.45, cutoff = 3000, start = 0.12 },
        { wave = "square", duty = 0.25, from = 600, to = 900, length = 0.05, volume = 0.35, start = 0.12 }
    }
}
Sounds.dash = {
    volume = 0.4, cooldown = 0.1, jitter = 0.05,
    layers = { { wave = "noise", from = 3000, to = 9000, length = 0.18, attack = 0.03, volume = 0.5, cutoff = 800, cutoffTo = 5000 } }
}
Sounds.slide = {
    volume = 0.35, cooldown = 0.2,
    layers = { { wave = "noise", from = 4000, to = 1500, length = 0.45, attack = 0.02, volume = 0.5, cutoff = 2500, cutoffTo = 500, curve = 1.2 } }
}
Sounds.step = {
    volume = 0.18, cooldown = 0.08, jitter = 0.15, voices = 4,
    layers = { { wave = "noise", from = 2500, length = 0.04, volume = 0.5, cutoff = 900 }, { wave = "sine", from = 110, to = 70, length = 0.05, volume = 0.3 } }
}
Sounds.swing = {
    volume = 0.35, cooldown = 0.1, jitter = 0.08,
    layers = { { wave = "noise", from = 2000, to = 6000, length = 0.14, attack = 0.04, volume = 0.45, cutoff = 1200, cutoffTo = 3500 } }
}
Sounds.punch = {
    volume = 0.55, cooldown = 0.08, jitter = 0.06,
    layers = { { wave = "sine", from = 160, to = 50, length = 0.16, volume = 0.7, curve = 2 }, { wave = "noise", from = 3000, length = 0.05, volume = 0.4, cutoff = 1500 } }
}
Sounds.hit = {
    volume = 0.4, cooldown = 0.04,
    layers = { { wave = "square", duty = 0.15, from = 1700, to = 2300, length = 0.05, volume = 0.4 }, { wave = "sine", from = 2600, length = 0.06, volume = 0.3, start = 0.03 } }
}
Sounds.hurt = {
    volume = 0.55, cooldown = 0.08,
    layers = { { wave = "sine", from = 120, to = 55, length = 0.22, volume = 0.7 }, { wave = "noise", from = 1200, to = 300, length = 0.15, volume = 0.35, cutoff = 900 } }
}
Sounds.kill = {
    volume = 0.5, cooldown = 0.1,
    layers = merge(
        { { wave = "noise", from = 9000, to = 3000, length = 0.4, volume = 0.35, cutoff = 7000, cutoffTo = 2000, curve = 1.6 } },
        Synth.melody({ { "e6", 0.05 }, { "b5", 0.05 }, { "g6", 0.18 } }, { wave = "triangle", volume = 0.35 })
    )
}
Sounds.death = {
    volume = 0.5, cooldown = 0.5,
    layers = merge(Synth.melody({ { "g3", 0.12 }, { "d3", 0.12 }, { "a2", 0.4 } }, { wave = "triangle", volume = 0.55, curve = 1.2 }))
}
Sounds.door = {
    volume = 0.3, cooldown = 0.15,
    layers = { { wave = "noise", from = 1200, to = 800, length = 0.35, attack = 0.05, volume = 0.45, cutoff = 700, cutoffTo = 400, curve = 1.2 }, { wave = "sine", from = 90, length = 0.3, volume = 0.2 } }
}
Sounds.glass = {
    volume = 0.5, cooldown = 0.08, jitter = 0.08,
    layers = merge(
        { { wave = "noise", from = 11000, to = 6000, length = 0.5, volume = 0.45, cutoff = 9000, cutoffTo = 3000, curve = 2 } },
        Synth.melody({ { "c7", 0.03 }, { "g6", 0.03 }, { "e7", 0.03 }, { "a6", 0.15 } }, { wave = "triangle", volume = 0.25 })
    )
}
Sounds.clank = {
    volume = 0.35, cooldown = 0.08, jitter = 0.1,
    layers = { { wave = "square", duty = 0.1, from = 1200, to = 900, length = 0.12, volume = 0.3 }, { wave = "triangle", from = 2400, to = 2200, length = 0.2, volume = 0.25 } }
}
Sounds.throw = {
    volume = 0.35, cooldown = 0.1,
    layers = { { wave = "noise", from = 1500, to = 4500, length = 0.22, attack = 0.05, volume = 0.45, cutoff = 900, cutoffTo = 2500 } }
}
Sounds.pickup = {
    volume = 0.35, cooldown = 0.1,
    layers = { { wave = "square", duty = 0.25, from = 500, to = 800, length = 0.05, volume = 0.35 }, { wave = "noise", from = 6000, length = 0.03, volume = 0.3, start = 0.05, cutoff = 4000 } }
}
Sounds.ammo = {
    volume = 0.3, cooldown = 0.1,
    layers = merge(Synth.melody({ { "a5", 0.04 }, { "e6", 0.08 } }, { wave = "square", duty = 0.25, volume = 0.3 }))
}
Sounds.heal = {
    volume = 0.35, cooldown = 0.2,
    layers = merge(Synth.melody({ { "c5", 0.06 }, { "e5", 0.06 }, { "g5", 0.14 } }, { wave = "sine", volume = 0.45 }))
}
Sounds.level = {
    volume = 0.4, cooldown = 0.2,
    layers = merge(Synth.melody({ { "g4", 0.06 }, { "c5", 0.06 }, { "e5", 0.06 }, { "g5", 0.16 } }, { wave = "square", duty = 0.25, volume = 0.35 }))
}
Sounds.beep = {
    volume = 0.35, cooldown = 0.5,
    layers = { { wave = "square", duty = 0.5, from = 880, length = 0.09, volume = 0.35 } }
}
Sounds.start = {
    volume = 0.5, cooldown = 1,
    layers = merge(
        Synth.melody({ { "c5", 0.08 }, { "g5", 0.08 }, { "c6", 0.3 } }, { wave = "square", duty = 0.25, volume = 0.35 }),
        Synth.melody({ { "c3", 0.46 } }, { wave = "triangle", volume = 0.45 })
    )
}
Sounds.win = {
    volume = 0.5, cooldown = 2,
    layers = merge(Synth.melody({ { "c5", 0.1 }, { "e5", 0.1 }, { "g5", 0.1 }, { "c6", 0.4 } }, { wave = "square", duty = 0.25, volume = 0.35 }),
        Synth.melody({ { "c3", 0.7 } }, { wave = "triangle", volume = 0.4 }))
}
Sounds.lose = {
    volume = 0.5, cooldown = 2,
    layers = merge(Synth.melody({ { "a4", 0.14 }, { "f4", 0.14 }, { "d4", 0.4 } }, { wave = "triangle", volume = 0.5 }))
}
Sounds.chat = {
    volume = 0.25, cooldown = 0.15,
    layers = merge(Synth.melody({ { "e6", 0.04 }, { "a6", 0.07 } }, { wave = "sine", volume = 0.4 }))
}

Sounds.hover = {
    volume = 0.12, cooldown = 0.04,
    layers = { { wave = "sine", from = 1400, length = 0.025, volume = 0.4 } }
}
Sounds.click = {
    volume = 0.3, cooldown = 0.04, jitter = 0.03,
    layers = { { wave = "square", duty = 0.25, from = 660, to = 990, length = 0.05, volume = 0.4 }, { wave = "noise", from = 9000, length = 0.012, volume = 0.12 } }
}
Sounds.whoosh = {
    volume = 0.35, cooldown = 0.3,
    layers = { { wave = "noise", from = 800, to = 6000, length = 0.4, attack = 0.15, volume = 0.4, cutoff = 600, cutoffTo = 4000, curve = 1.5 } }
}

return Sounds
