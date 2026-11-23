local GM = require("src.core.index")
local Kit = require("src.ui.kit")

local Pause = {}

local W_CARD, BUTTON = 420, 54

local function origin()
    local W, H = love.graphics.getDimensions()
    local h = 120 + 4 * (BUTTON + 12)
    return math.floor((W - W_CARD) / 2), math.floor((H - h) / 2), h
end

function Pause.build(menu)
    local x, y = origin()
    local list = {
        { id = "resume", label = "Resume", primary = true, hint = "Esc", press = function() menu:Resume() end },
        { id = "settings", label = "Settings", press = function() menu:switch("settings", 1) end },
        { id = "leave", label = "Leave the duel", press = function() menu:LeaveGame() end },
        { id = "quit", label = "Quit Kyma", press = function() love.event.quit() end }
    }
    local by = y + 104
    for _, element in ipairs(list) do
        element.x, element.y, element.w, element.h = x + 24, by, W_CARD - 48, BUTTON
        by = by + BUTTON + 12
    end
    return list
end

function Pause.draw(menu, elements, p)
    local x, y, h = origin()
    local e = Kit.easeOutBack(p)
    local a = Kit.easeOutCubic(p)
    Kit.card(x, y + (1 - e) * 20, W_CARD, h, a, 20)
    Kit.text("Paused", 30, x + 24, y + 22 + (1 - e) * 20, Kit.INK, a)
    local room = GM.Session.room
    local sub = room and room.practice and "Practice keeps running" or "The duel keeps running"
    Kit.text(sub, 14, x + 26, y + 62 + (1 - e) * 20, Kit.INK, 0.5 * a)
    for k, element in ipairs(elements) do
        local s = menu:stagger(p, k + 1)
        Kit.button(element.id, element.x, element.y + (1 - s) * 16, element.w, element.h, element.label, {
            hot = menu.focus == element.id, primary = element.primary, hint = element.hint, size = 17, alpha = s
        })
    end
end

function Pause.back(menu)
    menu:Resume()
end

return Pause
