local CONFIG = require("src.config.window")

local function headless()
    for _, value in ipairs(arg or {}) do
        if value == "--test" then return true end
    end
    return false
end

--- @param t table
function love.conf(t)
    t.console = true
    if headless() then
        t.window = false
        for _, name in ipairs({ "window", "graphics", "audio", "sound", "video", "image", "font", "joystick", "keyboard", "mouse", "touch" }) do
            t.modules[name] = false
        end
        return
    end
    t.window.title      = CONFIG.title
    t.window.width      = CONFIG.width
    t.window.height     = CONFIG.height
    t.window.resizable  = CONFIG.resizable
    t.window.vsync      = CONFIG.vsync
    t.window.fullscreen = CONFIG.fullscreen
    t.window.icon       = CONFIG.icon
end
