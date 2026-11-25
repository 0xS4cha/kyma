local Kit = require("src.ui.kit")

local Common = {}

--- @return number
function Common.margin()
    local W = love.graphics.getWidth()
    return math.max(36, math.floor(W * 0.05))
end

--- @param menu table
--- @param back function
--- @return table
function Common.backElement(menu, back)
    local M = Common.margin()
    return { id = "back", x = M, y = 36, w = 140, h = 48, nav = false, press = back or function() menu:back() end }
end

--- @param menu table
--- @param elements table[]
--- @param p number
--- @param title string
--- @param subtitle string
function Common.header(menu, elements, p, title, subtitle)
    local back = menu.find(elements, "back")
    local a = menu:stagger(p, 1)
    Kit.button("back", back.x, back.y, back.w, back.h, "Back", { hot = menu.focus == "back", size = 15, hint = "Esc", alpha = a, arrow = false })
    Kit.text(title, 34, back.x + back.w + 28, 30, Kit.INK, a)
    Kit.text(subtitle, 14, back.x + back.w + 30, 72, Kit.INK, 0.55 * a)
end

--- @param menu table
--- @param key string
--- @param limit number
--- @param pattern string
--- @return function
function Common.textHandler(menu, key, limit, pattern)
    return function(_, text)
        local value = menu.settings[key]
        if text then
            if #value < limit and text:match(pattern) then
                menu.settings[key] = value .. text
            end
        else
            menu.settings[key] = value:sub(1, -2)
        end
    end
end

--- @param str string
--- @param size number
--- @param x number
--- @param y number
--- @param width number
--- @param color table
--- @param alpha number
--- @return number
function Common.paragraph(str, size, x, y, width, color, alpha)
    local f = Kit.font(size)
    love.graphics.setFont(f)
    Kit.color(color, alpha)
    love.graphics.printf(str, math.floor(x), math.floor(y), width)
    local _, lines = f:getWrap(str, width)
    return #lines * f:getHeight()
end

Common.NAME_PATTERN = "^[%w%s%-_%.']$"
Common.PASSWORD_PATTERN = "^[%w%p ]$"
Common.SERVER_PATTERN = "^[%w%.%-:]$"

return Common
