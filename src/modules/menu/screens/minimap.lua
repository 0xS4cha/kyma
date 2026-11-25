local Settings = require("src.modules.menu.settings")
local Base = require("src.modules.menu.screens.settings")

local Screen = {}

local MIN_ROW = 50

local function rows()
    return {
        { id = "minimap", label = "Show mini-map", hint = "Display the map during a game", kind = "toggle" },
        { id = "minimapPos", label = "Position", hint = "Corner of the screen (left corners keep it away from the kill feed)", kind = "segments", options = Settings.MAP_POSITIONS },
        { id = "minimapSize", label = "Size", hint = "How much room the map takes on screen", kind = "segments", options = Settings.MAP_SIZES },
        { id = "minimapOpacity", label = "Opacity", hint = "Make the map more discreet", kind = "segments", options = Settings.MAP_OPACITY_LABELS },
        { id = "minimapView", label = "View", hint = "The whole arena, or a zoomed view centered on you", kind = "segments", options = Settings.MAP_VIEWS },
        { id = "minimapZoom", label = "Zoom", hint = "Only used by the Follow me view (Far shows more)", kind = "segments", options = Settings.ZOOM_LABELS },
        { id = "minimapRotate", label = "Rotate with me", hint = "You always face up; the map turns around you (centers on you)", kind = "toggle" },
        { id = "minimapVision", label = "Vision cone", hint = "Show what you can currently see", kind = "toggle" },
        { id = "minimapAllies", label = "Show allies", hint = "Teammates, with their direction", kind = "toggle" },
        { id = "minimapEnemies", label = "Show spotted enemies", hint = "Enemies you can see right now", kind = "toggle" },
        { id = "minimapLoot", label = "Show loot", hint = "Weapons, ammo and health on the floor", kind = "toggle" }
    }
end

function Screen.build(menu)
    return Base.buildRows(menu, rows(), function() Screen.back(menu) end, MIN_ROW)
end

function Screen.draw(menu, elements, p)
    Base.drawRows(menu, elements, p, "Mini-map", "Saved automatically.", MIN_ROW)
end

Screen.viewport = Base.viewport

function Screen.back(menu)
    menu:switch("settings", -1)
end

return Screen
