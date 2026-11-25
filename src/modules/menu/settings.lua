local Config = require("src.config.game")

local Settings = {}

local FILE = "kyma_settings.txt"

Settings.SENSITIVITY = { 0.002, 0.0028, 0.0035, 0.0045, 0.006 }
Settings.ZOOM = { 1.3, 1.6, 2.0 }
Settings.ZOOM_LABELS = { "Far", "Normal", "Close" }

-- Mini-map (HUD)
Settings.MAP_POSITIONS = { "Top left", "Bottom left", "Top right", "Bottom right" }
Settings.MAP_SIZES = { "Tiny", "Small", "Medium", "Large", "Huge" }
Settings.MAP_OPACITY = { 0.4, 0.6, 0.8, 1 }
Settings.MAP_OPACITY_LABELS = { "40%", "60%", "80%", "100%" }
Settings.MAP_VIEWS = { "Full arena", "Follow me" }
Settings.MAP_SPANS = { 1200, 800, 500 } -- largeur visible (unités monde) en mode "Follow me"

Settings.DMG_SIZES = { "Small", "Normal", "Large", "Huge" }
Settings.DMG_SCALES = { 0.7, 1, 1.45, 2 }

Settings.KEYS = { "name", "server", "sensitivity", "zoom", "fullscreen", "vsync", "background", "showHelp", "bot", "mode", "map", "volume", "body", "accent", "head", "shake", "theme", "minimap", "minimapPos", "minimapSize", "minimapOpacity", "minimapView", "minimapZoom", "minimapRotate", "minimapVision", "minimapAllies", "minimapEnemies", "minimapLoot", "dmgNumbers", "dmgSize", "shields", "kitWeapon", "kitMods", "floorWeapons", "spawnWith", "presetWeapon", "presetMods", "kitGadget", "presetGadget", "tournamentName", "tournamentSize", "tournamentBestOf", "tournamentServer", "browseSource", "hostWhere", "killHeal" }

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
        minimap = true,
        minimapPos = 1,
        minimapSize = 3,
        minimapOpacity = 4,
        minimapView = 1,
        minimapZoom = 2,
        minimapRotate = false,
        minimapVision = true,
        minimapAllies = true,
        minimapEnemies = true,
        minimapLoot = false,
        dmgNumbers = true,
        dmgSize = 2,
        shields = true,
        kitWeapon = 1,
        kitMods = Settings.cleanMods(""),
        floorWeapons = true,
        spawnWith = 1,
        presetWeapon = 1,
        presetMods = Settings.cleanMods(""),
        kitGadget = 1,
        presetGadget = 1,
        tournamentName = "",
        tournamentSize = 2,
        tournamentBestOf = 1,
        tournamentServer = 1,
        browseSource = 1,
        hostWhere = 1,
        killHeal = false,
        -- typed for one game and never written to disk
        password = "",
        hostPassword = ""
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
    values.minimapPos = math.max(1, math.min(#Settings.MAP_POSITIONS, math.floor(values.minimapPos)))
    values.minimapSize = math.max(1, math.min(#Settings.MAP_SIZES, math.floor(values.minimapSize)))
    values.minimapOpacity = math.max(1, math.min(#Settings.MAP_OPACITY, math.floor(values.minimapOpacity)))
    values.minimapView = math.max(1, math.min(#Settings.MAP_VIEWS, math.floor(values.minimapView)))
    values.minimapZoom = math.max(1, math.min(#Settings.MAP_SPANS, math.floor(values.minimapZoom)))
    values.dmgSize = math.max(1, math.min(#Settings.DMG_SIZES, math.floor(values.dmgSize)))
    local Loadout = require("src.config.loadout")
    values.kitWeapon = Loadout.sanitize({ w = values.kitWeapon }).w
    values.presetWeapon = Loadout.sanitize({ w = values.presetWeapon }).w
    values.kitGadget = Loadout.sanitize({ g = values.kitGadget }).g
    values.presetGadget = Loadout.sanitize({ g = values.presetGadget }).g
    values.kitMods = Settings.cleanMods(values.kitMods)
    values.presetMods = Settings.cleanMods(values.presetMods)
    values.spawnWith = Loadout.rules({ s = values.spawnWith }).s
    values.map = require("src.maps.index").valid(values.map)
    local Bracket = require("src.game.bracket")
    values.tournamentSize = math.max(1, math.min(#Bracket.SIZES, math.floor(values.tournamentSize)))
    values.tournamentBestOf = math.max(1, math.min(#Bracket.BEST_OF, math.floor(values.tournamentBestOf)))
    values.tournamentServer = math.max(1, math.min(2, math.floor(values.tournamentServer)))
    values.browseSource = math.max(1, math.min(3, math.floor(values.browseSource)))
    values.hostWhere = math.max(1, math.min(2, math.floor(values.hostWhere)))
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
        return { w = values.presetWeapon, m = Settings.modAt(values.presetMods, values.presetWeapon), g = values.presetGadget }
    end
    return { w = values.kitWeapon, m = Settings.modAt(values.kitMods, values.kitWeapon), g = values.kitGadget }
end

--- @param values table
--- @return table
function Settings.matchRules(values)
    local rules = { f = values.floorWeapons, s = values.spawnWith, p = Settings.kit(values, "preset"), h = values.killHeal or nil }
    if values.shields == false then rules.sh = false end
    return rules
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
