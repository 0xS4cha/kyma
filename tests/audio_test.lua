local Synth = require("src.modules.audio.synth")
local Sounds = require("src.modules.audio.sounds")
local Weapons = require("src.game.weapons")

return {
    {
        name = "every sound renders short, clean samples",
        run = function()
            for name, recipe in pairs(Sounds) do
                local samples, count = Synth.render(recipe, 8000)
                assert(count > 0 and count / 8000 < 1.5, name .. " lasts " .. count / 8000 .. " s")
                local peak = 0
                for k = 0, count - 1 do peak = math.max(peak, math.abs(samples[k])) end
                assert(peak > 0.05 and peak <= 0.951, name .. " peak " .. peak)
            end
        end
    },
    {
        name = "every weapon and every game event has a sound",
        run = function()
            for _, kind in ipairs(Weapons.order) do
                assert(Sounds[kind], "missing sound for " .. kind)
            end
            for _, name in ipairs({ "swing", "punch", "hit", "hurt", "kill", "death", "dash", "slide", "step", "door", "glass",
                "reload", "empty", "pickup", "ammo", "heal", "level", "beep", "start", "win", "lose", "hover", "click" }) do
                assert(Sounds[name], "missing sound " .. name)
            end
        end
    }
}
