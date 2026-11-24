local Config = require("src.config.game")

local Settings = {}

local FILE = "kyma_settings.txt"

Settings.SENSITIVITY = { 0.002, 0.0028, 0.0035, 0.0045, 0.006 }
Settings.ZOOM = { 1.3, 1.6, 2.0 }
Settings.ZOOM_LABELS = { "Far", "Normal", "Close" }

Settings.KEYS = { "name", "server", "sensitivity", "zoom", "fullscreen", "vsync", "background", "showHelp", "bot", "mode", "map", "volume", "body", "accent", "head", "shake", "theme", "kitWeapon", "kitMods", "floorWeapons", "spawnWith", "presetWeapon", "presetMods" }

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
        volume = 4,
        body = 1,
        accent = 1,
        head = 1,
        shake = 3,
        theme = 1,
        kitWeapon = 1,
        kitMods = Settings.cleanMods(""),
        floorWeapons = true,
        spawnWith = 1,
        presetWeapon = 1,
        presetMods = Settings.cleanMods("")
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
    local Profile = require("src.config.profile")
    values.body = math.max(1, math.min(#Profile.bodies, math.floor(values.body)))
    values.accent = math.max(1, math.min(#Profile.accents, math.floor(values.accent)))
    values.head = math.max(1, math.min(#Profile.heads, math.floor(values.head)))
    values.shake = math.max(1, math.min(#require("src.config.feel").strength, math.floor(values.shake)))
    values.theme = math.max(1, math.min(#require("src.ui.theme").order, math.floor(values.theme)))
    local Loadout = require("src.config.loadout")
    values.kitWeapon = Loadout.sanitize({ w = values.kitWeapon }).w
    values.presetWeapon = Loadout.sanitize({ w = values.presetWeapon }).w
    values.kitMods = Settings.cleanMods(values.kitMods)
    values.presetMods = Settings.cleanMods(values.presetMods)
    values.spawnWith = Loadout.rules({ s = values.spawnWith }).s
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
    local Theme = require("src.ui.theme")
    Theme.apply(Theme.order[values.theme or 1])
    Config.mouseSensitivity = Settings.SENSITIVITY[values.sensitivity]
    Config.camera.scale = Settings.ZOOM[values.zoom]
    if display and love.window and love.window.isOpen() then
        if love.window.getFullscreen() ~= values.fullscreen then
            love.window.setFullscreen(values.fullscreen, "desktop")
        end
        love.window.setVSync(values.vsync and 1 or 0)
    end
end

--- @param text string?
--- @return string
function Settings.cleanMods(text)
    local Loadout = require("src.config.loadout")
    local count = #require("src.config.weapons").order
    local list = {}
    local k = 0
    for part in tostring(text or ""):gmatch("[^,]+") do
        k = k + 1
        if k > count then break end
        list[k] = Loadout.sanitize({ m = tonumber(part) }).m
    end
    for n = k + 1, count do list[n] = 1 end
    return table.concat(list, ",")
end

--- @param text string
--- @param weapon number
--- @return number
function Settings.modAt(text, weapon)
    local k = 0
    for part in Settings.cleanMods(text):gmatch("[^,]+") do
        k = k + 1
        if k == weapon then return tonumber(part) end
    end
    return 1
end

--- @param text string
--- @param weapon number
--- @param mod number
--- @return string
function Settings.withMod(text, weapon, mod)
    local list = {}
    for part in Settings.cleanMods(text):gmatch("[^,]+") do list[#list + 1] = tonumber(part) end
    list[weapon] = mod
    return Settings.cleanMods(table.concat(list, ","))
end

--- @param values table
--- @param which string?
--- @return table
function Settings.kit(values, which)
    if which == "preset" then
        return { w = values.presetWeapon, m = Settings.modAt(values.presetMods, values.presetWeapon) }
    end
    return { w = values.kitWeapon, m = Settings.modAt(values.kitMods, values.kitWeapon) }
end

--- @param values table
--- @return table
function Settings.matchRules(values)
    return { f = values.floorWeapons, s = values.spawnWith, p = Settings.kit(values, "preset") }
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
