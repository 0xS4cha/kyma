local Settings = require("src.modules.menu.settings")
local Base = require("src.modules.menu.screens.settings")

local Screen = {}

local MIN_ROW = 50

local function rows()
    local list = {}
    for _, stat in ipairs(Settings.STATS) do
        list[#list + 1] = { id = stat.key, label = stat.label, hint = stat.hint, kind = "segments", options = Settings.STAT_MODES }
    end
    return list
end

function Screen.build(menu)
    return Base.buildRows(menu, rows(), function() Screen.back(menu) end, MIN_ROW)
end

function Screen.draw(menu, elements, p)
    Base.drawRows(menu, elements, p, "Performance stats", "Shown in the top right corner during a game. Saved automatically.", MIN_ROW)
end

Screen.viewport = Base.viewport

function Screen.back(menu)
    menu:switch("settings", -1)
end

return Screen
