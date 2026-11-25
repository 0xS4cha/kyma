local Settings = require("src.modules.menu.settings")
local Config = require("src.config.game")

return {
    {
        name = "missing settings fall back to the defaults",
        run = function()
            local values = Settings.parse(nil)
            local defaults = Settings.defaults()
            for _, key in ipairs(Settings.KEYS) do
                assert(values[key] == defaults[key], key)
            end
        end
    },
    {
        name = "settings survive a save and load round trip",
        run = function()
            local values = Settings.defaults()
            values.name, values.server, values.sensitivity, values.zoom = "Sacha", "10.0.0.2:6789", 5, 3
            values.fullscreen, values.background, values.bot = true, false, 1
            values.mode, values.map = 3, "vault"
            local back = Settings.parse(Settings.serialize(values))
            for _, key in ipairs(Settings.KEYS) do
                assert(back[key] == values[key], key)
            end
        end
    },
    {
        name = "out of range and broken values are clamped or ignored",
        run = function()
            local values = Settings.parse("sensitivity=42\nzoom=-3\nbot=9\nfullscreen=maybe\nunknown=1\nname=Bob\nmap=nowhere\nmode=7")
            assert(values.map == "atrium" and values.mode == #Config.modes.order)
            assert(values.sensitivity == #Settings.SENSITIVITY and values.zoom == 1 and values.bot == #Config.bots.order)
            assert(values.fullscreen == false and values.unknown == nil and values.name == "Bob")
        end
    },
    {
        name = "applying settings sets the sensitivity and the camera distance",
        run = function()
            local values = Settings.defaults()
            values.sensitivity, values.zoom = 1, 3
            Settings.apply(values, false)
            assert(Config.mouseSensitivity == Settings.SENSITIVITY[1] and Config.camera.scale == Settings.ZOOM[3])
            Settings.apply(Settings.defaults(), false)
        end
    }
}
