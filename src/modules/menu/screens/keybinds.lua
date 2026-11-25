local Kit = require("src.ui.kit")
local Common = require("src.modules.menu.screens.common")
local Keys = require("src.input.keybinds")

local Screen = {}

local ROW = 40

local function layout()
    local W = love.graphics.getWidth()
    local M = Common.margin()
    local gap = 24
    local w = math.min(560, math.floor((W - M * 2 - gap) / 2))
    return { M = M, x = M, y = 130, w = w, gap = gap }
end

local function columns()
    local half = math.ceil(#Keys.actions / 2)
    return half
end

function Screen.enter(menu)
    menu.binding = nil
    menu.bindMessage = nil
end

function Screen.build(menu)
    local l = layout()
    local list = { Common.backElement(menu, function() Screen.back(menu) end) }
    local half = columns()
    for k, action in ipairs(Keys.actions) do
        local col = k <= half and 0 or 1
        local row = col == 0 and k - 1 or k - half - 1
        local x = l.x + col * (l.w + l.gap)
        local y = l.y + 22 + row * ROW
        for slot = 1, 2 do
            local sw = 96
            list[#list + 1] = {
                id = action.id .. ":" .. slot, action = action, slot = slot,
                x = x + l.w - 18 - (3 - slot) * (sw + 8) + 8, y = y, w = sw, h = ROW - 8,
                press = function()
                    menu.binding = { id = action.id, slot = slot }
                    menu.bindMessage = nil
                end
            }
        end
    end
    local rows = math.max(half, #Keys.actions - half)
    list[#list + 1] = {
        id = "reset", x = l.x, y = l.y + 44 + rows * ROW + 20, w = 240, h = 48,
        press = function()
            Keys.reset()
            menu.binding = nil
            menu.bindMessage = "Default keys restored"
        end
    }
    return list
end

function Screen.capture(menu, key, scancode)
    if not menu.binding then return false end
    if key == "escape" then
        menu.binding = nil
        return true
    end
    local binding = menu.binding
    local code = (key == "backspace" or key == "delete") and nil or scancode
    local moved = Keys.set(binding.id, binding.slot, code)
    menu.binding = nil
    if moved then
        menu.bindMessage = Keys.name(code) .. " moved from " .. Keys.byId[moved].label:lower()
    else
        menu.bindMessage = nil
    end
    return true
end

function Screen.draw(menu, elements, p)
    local l = layout()
    Common.header(menu, elements, p, "Controls", "Click a key, then press the new one. Backspace clears it, Escape cancels.")
    local half = columns()
    local rows = math.max(half, #Keys.actions - half)
    for col = 0, 1 do
        local e = menu:stagger(p, 2 + col)
        local x = l.x + col * (l.w + l.gap)
        Kit.card(x, l.y + (1 - e) * 20, l.w, rows * ROW + 36, e, 18)
    end
    for k, action in ipairs(Keys.actions) do
        local col = k <= half and 0 or 1
        local row = col == 0 and k - 1 or k - half - 1
        local x = l.x + col * (l.w + l.gap)
        local y = l.y + 22 + row * ROW
        local e = menu:stagger(p, 3 + k * 0.25)
        Kit.text(action.label, 15, x + 20, y + 6, Kit.INK, e)
    end
    for _, element in ipairs(elements) do
        if element.action then
            local e = menu:stagger(p, 4)
            local waiting = menu.binding ~= nil and menu.binding.id == element.action.id and menu.binding.slot == element.slot
            local key = Keys.keys(element.action.id)[element.slot]
            local hot = Kit.ease("bind:" .. element.id, menu.focus == element.id or waiting)
            local lg = love.graphics
            lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], (0.05 + 0.05 * hot) * e)
            lg.rectangle("fill", element.x, element.y, element.w, element.h, 8, 8)
            if waiting then
                Kit.color(Kit.RED, e * (0.6 + 0.4 * math.sin(love.timer.getTime() * 8)))
                lg.setLineWidth(2)
                lg.rectangle("line", element.x + 1, element.y + 1, element.w - 2, element.h - 2, 8, 8)
                lg.setLineWidth(1)
                Kit.text("Press a key", 12, element.x, element.y + 9, Kit.RED, e, "center", element.w)
            else
                Kit.text(Keys.name(key), 14, element.x, element.y + 7, Kit.INK, (key and 1 or 0.3) * e, "center", element.w)
            end
        end
    end
    local reset = menu.find(elements, "reset")
    Kit.button("reset", reset.x, reset.y, reset.w, reset.h, "Restore defaults", { hot = menu.focus == "reset", size = 15, alpha = menu:stagger(p, 6), arrow = false })
    if menu.bindMessage then
        Kit.text(menu.bindMessage, 14, reset.x + reset.w + 20, reset.y + 14, Kit.INK, 0.6)
    end
    Kit.text("Mouse: left click fires or strikes, right click dashes, middle click pings.", 13, reset.x, reset.y + reset.h + 18, Kit.INK, 0.45)
end

function Screen.back(menu)
    menu:switch("settings", -1)
end

return Screen
