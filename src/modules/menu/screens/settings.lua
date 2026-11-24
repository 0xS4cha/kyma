local Kit = require("src.ui.kit")
local Common = require("src.modules.menu.screens.common")
local Settings = require("src.modules.menu.settings")

local Screen = {}

local function rows()
    return {
        { id = "volume", label = "Sound volume", hint = "Sounds are synthesized live, no audio files", kind = "segments", options = { "Off", "25%", "50%", "75%", "100%" } },
        { id = "sensitivity", label = "Mouse sensitivity", hint = "How fast the view turns with the mouse", kind = "segments", options = { "1", "2", "3", "4", "5" } },
        { id = "zoom", label = "Camera distance", hint = "Close shows details, far shows more of the arena", kind = "segments", options = Settings.ZOOM_LABELS },
        { id = "fullscreen", label = "Fullscreen", hint = "Borderless desktop fullscreen", kind = "toggle" },
        { id = "vsync", label = "VSync", hint = "Sync frames with your display", kind = "toggle" },
        { id = "background", label = "Live duel in the menu", hint = "Two bots fight behind the menu", kind = "toggle" },
        { id = "showHelp", label = "Controls reminder", hint = "Show the controls for a few seconds when a game starts", kind = "toggle" }
    }
end

local function layout()
    local W = love.graphics.getWidth()
    local M = Common.margin()
    return { x = M, y = 130, w = math.min(720, W - M * 2), rowH = 70 }
end

function Screen.build(menu)
    local l = layout()
    local list = { Common.backElement(menu, function() Screen.back(menu) end) }
    local y = l.y + 22
    for _, row in ipairs(rows()) do
        local element = { id = row.id, x = l.x + 16, y = y, w = l.w - 32, h = l.rowH - 8, row = row }
        if row.kind == "toggle" then
            element.press = function() menu:setOption(row.id, not menu.settings[row.id]) end
            element.left = function() menu:setOption(row.id, false) end
            element.right = function() menu:setOption(row.id, true) end
        else
            local count = #row.options
            local segX, segW = element.x + element.w - 300, 280
            element.press = function(_, mx)
                if mx and mx >= segX then
                    menu:setOption(row.id, Kit.clamp(math.floor((mx - segX) / (segW / count)) + 1, 1, count))
                elseif not mx then
                    menu:setOption(row.id, menu.settings[row.id] % count + 1)
                end
            end
            element.left = function() menu:setOption(row.id, math.max(1, menu.settings[row.id] - 1)) end
            element.right = function() menu:setOption(row.id, math.min(count, menu.settings[row.id] + 1)) end
        end
        list[#list + 1] = element
        y = y + l.rowH
    end
    return list
end

function Screen.draw(menu, elements, p)
    local l = layout()
    Common.header(menu, elements, p, "Settings", "Saved automatically.")
    local count = #elements - 1
    local e = menu:stagger(p, 2)
    Kit.card(l.x, l.y + (1 - e) * 20, l.w, count * l.rowH + 36, e, 18)
    for k = 2, #elements do
        local element = elements[k]
        local row = element.row
        local a = menu:stagger(p, k + 1)
        local x, y, w, h = element.x - (1 - a) * 24, element.y, element.w, element.h
        local hot = Kit.ease("row:" .. row.id, menu.focus == row.id)
        if hot > 0.01 then
            love.graphics.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.045 * hot * a)
            love.graphics.rectangle("fill", x, y, w, h, 10, 10)
            Kit.color(Kit.RED, hot * a)
            love.graphics.rectangle("fill", x, y + 14, 3, h - 28, 1.5, 1.5)
        end
        Kit.text(row.label, 17, x + 18, y + 10, Kit.INK, a)
        Kit.text(row.hint, 12, x + 18, y + 35, Kit.INK, 0.5 * a)
        if row.kind == "toggle" then
            Kit.toggle(row.id, x + w - 66, y + (h - 26) / 2, menu.settings[row.id], a)
        else
            Kit.segments(row.id, x + w - 300, y + (h - 36) / 2, 280, 36, row.options, menu.settings[row.id], a)
        end
    end
end

function Screen.back(menu)
    if menu.paused then
        menu:switch("pause", -1)
    else
        menu:switch("root", -1)
    end
end

return Screen
