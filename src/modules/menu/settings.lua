local Config = require("src.config.game")

local Settings = {}

local FILE = "kyma_settings.txt"

Settings.SENSITIVITY = { 0.002, 0.0028, 0.0035, 0.0045, 0.006 }
Settings.ZOOM = { 1.3, 1.6, 2.0 }
Settings.ZOOM_LABELS = { "Far", "Normal", "Close" }

Settings.KEYS = { "name", "server", "sensitivity", "zoom", "fullscreen", "vsync", "background", "showHelp", "bot", "mode", "map", "volume" }

--- @return table
function Settings.defaults()
    return {
        name = "Player",
        server = "localhost:6789",
        sensitivity = 3,
        zoom = 2,
        fullscreen = false,
        vsync = false,
        background = true,
        showHelp = true,
        bot = 2,
        mode = 1,
        map = "atrium",
        volume = 4
    }
end

--- @param text string?
--- @return table
function Settings.parse(text)
    local values = Settings.defaults()
    for line in (text or ""):gmatch("[^\r\n]+") do
        local key, value = line:match("^(%w+)=(.*)$")
        local default = key and values[key]
        if type(default) == "number" then
            values[key] = tonumber(value) or default
        elseif type(default) == "boolean" then
            values[key] = value == "true"
        elseif type(default) == "string" then
            values[key] = value
        end
    end
    values.sensitivity = math.max(1, math.min(#Settings.SENSITIVITY, math.floor(values.sensitivity)))
    values.zoom = math.max(1, math.min(#Settings.ZOOM, math.floor(values.zoom)))
    values.bot = math.max(1, math.min(#Config.bots.order, math.floor(values.bot)))
    values.mode = math.max(1, math.min(#Config.modes.order, math.floor(values.mode)))
    values.volume = math.max(1, math.min(5, math.floor(values.volume)))
    values.map = require("src.maps.index").valid(values.map)
    return values
end

--- @param values table
--- @return string
function Settings.serialize(values)
    local lines = {}
    for _, key in ipairs(Settings.KEYS) do
        lines[#lines + 1] = key .. "=" .. tostring(values[key])
    end
    return table.concat(lines, "\n") .. "\n"
end

--- @return table
function Settings.load()
    local text = love.filesystem.getInfo(FILE) and love.filesystem.read(FILE) or nil
    return Settings.parse(text)
end

--- @param values table
function Settings.save(values)
    love.filesystem.write(FILE, Settings.serialize(values))
end

--- @param values table
--- @param display boolean?
function Settings.apply(values, display)
    Config.mouseSensitivity = Settings.SENSITIVITY[values.sensitivity]
    Config.camera.scale = Settings.ZOOM[values.zoom]
    if display and love.window and love.window.isOpen() then
        if love.window.getFullscreen() ~= values.fullscreen then
            love.window.setFullscreen(values.fullscreen, "desktop")
        end
        love.window.setVSync(values.vsync and 1 or 0)
    end
end

--- @param values table
--- @return string
function Settings.botLevel(values)
    return Config.bots.order[values.bot]
end

--- @param values table
--- @return string
function Settings.gameMode(values)
    return Config.modes.order[values.mode]
end

return Settings
