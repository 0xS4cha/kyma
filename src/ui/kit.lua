local Theme = require("src.ui.theme")
local Text = require("src.core.text")
local TextEdit = require("src.ui.textedit")

local Kit = {}

local exp, min, max, sin, floor, pi = math.exp, math.min, math.max, math.sin, math.floor, math.pi

Kit.INK = Theme.colors.ink
Kit.RED = { 0.88, 0.14, 0.12 }
Kit.GREEN = { 0.22, 0.68, 0.4 }
Kit.AMBER = { 0.92, 0.6, 0.12 }
Kit.ALLY = { 0.24, 0.42, 0.62 }
Kit.CARD = Theme.colors.card
Kit.PAPER = Theme.colors.paper
Kit.SURFACE = Theme.colors.surface
Kit.SHADOW = Theme.colors.shadow
Kit.RADIUS = 12

local INK, CARD, SURFACE, SHADOW = Kit.INK, Kit.CARD, Kit.SURFACE, Kit.SHADOW

local fonts = {}
local eased = {}
local scrolls = {}

--- @param size number
--- @return love.Font
function Kit.font(size)
    if not fonts[size] then
        local file = size >= 20 and "assets/fonts/Inter-SemiBold.ttf" or "assets/fonts/Inter-Regular.ttf"
        local ok, f = pcall(love.graphics.newFont, file, size, "light")
        fonts[size] = ok and f or love.graphics.newFont(size)
    end
    return fonts[size]
end

function Kit.approach(current, target, rate, dt)
    return current + (target - current) * (1 - exp(-rate * dt))
end

function Kit.clamp(v, a, b)
    return max(a, min(b, v))
end

function Kit.easeOutCubic(t)
    t = Kit.clamp(t, 0, 1)
    return 1 - (1 - t) ^ 3
end

function Kit.easeOutBack(t)
    t = Kit.clamp(t, 0, 1)
    local c = 1.70158
    return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

function Kit.pop(since, duration)
    local t = (love.timer.getTime() - since) / (duration or 0.35)
    if t < 0 or t > 1 then return 1 end
    return 1 + 0.25 * sin(t * pi) * (1 - t)
end

--- @param id string
--- @param target number|boolean
--- @param rate number?
--- @return number
function Kit.ease(id, target, rate)
    if type(target) == "boolean" then target = target and 1 or 0 end
    local value = eased[id]
    if value == nil then value = target end
    value = Kit.approach(value, target, rate or 14, min(love.timer.getDelta(), 0.1))
    eased[id] = value
    return value
end

function Kit.color(c, alpha)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (alpha or 1))
end

function Kit.card(x, y, w, h, alpha, radius, lift)
    local lg = love.graphics
    radius = radius or Kit.RADIUS
    lift = lift or 0
    lg.setColor(SHADOW[1], SHADOW[2], SHADOW[3], (0.1 + 0.06 * lift) * alpha * (Theme.dark() and 2.5 or 1))
    lg.rectangle("fill", x, y + 3 + 3 * lift, w, h, radius, radius)
    lg.setColor(CARD[1], CARD[2], CARD[3], 0.94 * alpha)
    lg.rectangle("fill", x, y, w, h, radius, radius)
end

function Kit.text(str, size, x, y, c, alpha, align, width)
    local lg = love.graphics
    local f = Kit.font(size)
    lg.setFont(f)
    Kit.color(c, alpha)
    if align == "center" then
        x = x + ((width or 0) - f:getWidth(str)) / 2
    elseif align == "right" then
        x = x - f:getWidth(str)
    end
    lg.print(str, floor(x + 0.5), floor(y + 0.5))
    return f:getWidth(str)
end

function Kit.keycap(label, x, y, alpha, size)
    local lg = love.graphics
    size = size or 14
    local f = Kit.font(size)
    local w = max(f:getWidth(label) + 14, size + 12)
    local h = size + 12
    lg.setColor(INK[1], INK[2], INK[3], 0.08 * alpha)
    lg.rectangle("fill", x, y + 2, w, h, 6, 6)
    lg.setColor(SURFACE[1], SURFACE[2], SURFACE[3], alpha)
    lg.rectangle("fill", x, y, w, h, 6, 6)
    lg.setColor(INK[1], INK[2], INK[3], 0.35 * alpha)
    lg.setLineWidth(1.5)
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 6, 6)
    lg.setLineWidth(1)
    Kit.text(label, size, x, y + 5, INK, alpha, "center", w)
    return w, h
end

function Kit.measureHint(key, label, size)
    local f = Kit.font(size)
    return max(Kit.font(size - 2):getWidth(key) + 14, size + 10) + 10 + f:getWidth(label)
end

function Kit.hint(key, label, x, y, alpha, size, c)
    size = size or 16
    local w = Kit.keycap(key, x, y, alpha, size - 2)
    Kit.text(label, size, x + w + 10, y + 4, c or INK, alpha)
end

function Kit.bar(x, y, w, h, fill, c, alpha, ghost)
    local lg = love.graphics
    lg.setColor(INK[1], INK[2], INK[3], 0.08 * alpha)
    lg.rectangle("fill", x, y, w, h, h / 2, h / 2)
    if ghost and ghost > fill then
        Kit.color(Theme.colors.ghost, alpha)
        lg.rectangle("fill", x, y, w * Kit.clamp(ghost, 0, 1), h, h / 2, h / 2)
    end
    if fill > 0 then
        Kit.color(c, alpha)
        lg.rectangle("fill", x, y, max(h, w * Kit.clamp(fill, 0, 1)), h, h / 2, h / 2)
    end
end

function Kit.ring(x, y, radius, fill, width, c, alpha)
    local lg = love.graphics
    lg.setLineWidth(width)
    lg.setColor(INK[1], INK[2], INK[3], 0.1 * alpha)
    lg.circle("line", x, y, radius)
    if fill > 0 then
        Kit.color(c, alpha)
        lg.arc("line", "open", x, y, radius, -pi / 2, -pi / 2 + 2 * pi * Kit.clamp(fill, 0, 1), 48)
    end
    lg.setLineWidth(1)
end

function Kit.dot(x, y, r, c, alpha)
    Kit.color(c, alpha)
    love.graphics.circle("fill", x, y, r)
end

--- @param id string
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param label string
--- @param options table?
function Kit.button(id, x, y, w, h, label, options)
    options = options or {}
    local lg = love.graphics
    local alpha = options.alpha or 1
    local hot = Kit.ease("button:" .. id, options.hot == true)
    local primary = options.primary
    local lift = hot * 3
    y = y - lift
    if primary then
        lg.setColor(SHADOW[1], SHADOW[2], SHADOW[3], (0.16 + 0.1 * hot) * alpha)
        lg.rectangle("fill", x, y + 4 + lift, w, h, Kit.RADIUS, Kit.RADIUS)
        local r = Kit.RED
        lg.setColor(r[1] * (0.92 + 0.08 * hot), r[2], r[3], alpha)
        lg.rectangle("fill", x, y, w, h, Kit.RADIUS, Kit.RADIUS)
    else
        Kit.card(x, y, w, h, alpha, Kit.RADIUS, hot)
        if hot > 0.01 then
            Kit.color(Kit.RED, hot * alpha)
            lg.rectangle("fill", x, y + 12, 3, h - 24, 1.5, 1.5)
        end
    end
    local ink = primary and { 1, 1, 1 } or INK
    local size = options.size or 18
    local f = Kit.font(size)
    local sub = options.sublabel
    local ty = y + (h - f:getHeight()) / 2 - (sub and 9 or 0)
    local tx = x + 22 + hot * 6
    if options.align == "center" then
        Kit.text(label, size, x, ty, ink, alpha, "center", w)
    else
        Kit.text(label, size, tx, ty, ink, alpha)
    end
    if sub then
        Kit.text(sub, 12, tx, ty + f:getHeight() + 2, ink, 0.6 * alpha)
    end
    if options.hint then
        local hw = Kit.font(12):getWidth(options.hint) + 14
        local hx = x + w - hw - 16
        local hy = y + (h - 24) / 2
        if primary then
            lg.setColor(1, 1, 1, 0.25 * alpha)
            lg.rectangle("fill", hx, hy, hw, 24, 6, 6)
            Kit.text(options.hint, 12, hx, hy + 5, { 1, 1, 1 }, alpha, "center", hw)
        else
            Kit.keycap(options.hint, hx, hy, alpha * (0.4 + 0.6 * hot), 12)
        end
    elseif not primary and options.arrow ~= false then
        local ax = x + w - 24 + hot * 4
        local ay = y + h / 2
        Kit.color(INK, (0.25 + 0.5 * hot) * alpha)
        lg.setLineWidth(2)
        lg.line(ax - 4, ay - 6, ax + 2, ay, ax - 4, ay + 6)
        lg.setLineWidth(1)
    end
    return hot
end

function Kit.toggle(id, x, y, on, alpha)
    local lg = love.graphics
    local t = Kit.ease("toggle:" .. id, on == true, 16)
    local w, h = 46, 26
    local r = Kit.RED
    lg.setColor(INK[1] + (r[1] - INK[1]) * t, INK[2] + (r[2] - INK[2]) * t, INK[3] + (r[3] - INK[3]) * t, (0.15 + 0.85 * t) * alpha)
    lg.rectangle("fill", x, y, w, h, h / 2, h / 2)
    lg.setColor(1, 1, 1, alpha)
    lg.circle("fill", x + h / 2 + (w - h) * t, y + h / 2, h / 2 - 3)
    return w, h
end

function Kit.segments(id, x, y, w, h, options, selected, alpha)
    local lg = love.graphics
    local count = #options
    local cell = w / count
    lg.setColor(INK[1], INK[2], INK[3], 0.07 * alpha)
    lg.rectangle("fill", x, y, w, h, h / 2, h / 2)
    local pos = Kit.ease("segments:" .. id, selected, 16)
    lg.setColor(SURFACE[1], SURFACE[2], SURFACE[3], alpha)
    lg.rectangle("fill", x + (pos - 1) * cell + 3, y + 3, cell - 6, h - 6, (h - 6) / 2, (h - 6) / 2)
    for k, label in ipairs(options) do
        local active = 1 - Kit.clamp(math.abs(pos - k), 0, 1)
        Kit.text(label, 13, x + (k - 1) * cell, y + (h - 16) / 2, INK, (0.45 + 0.55 * active) * alpha, "center", cell)
    end
end

--- @param str string
--- @return string[]
local function glyphs(str)
    local list = Text.chars(str)
    if list then return list end
    list = {}
    for i = 1, #str do list[i] = str:sub(i, i) end
    return list
end

--- @param f love.Font
--- @param list string[]
--- @param n integer
--- @return number
local function prefixWidth(f, list, n)
    return f:getWidth(table.concat(list, "", 1, n))
end

--- Draws the text of a field being edited, clipped to its width: the
--- selection, the text, and the caret, scrolled so the caret stays in view.
--- @param id string
--- @param str string what is shown (stars for a password)
--- @param state table a TextEdit state with the same number of characters
--- @param x number
--- @param y number top of the text
--- @param w number visible width
--- @param size number font size
--- @param c table text color
--- @param alpha number
--- @param caret table? { top, height } of the caret, relative to y
function Kit.editable(id, str, state, x, y, w, size, c, alpha, caret)
    local lg = love.graphics
    local f = Kit.font(size)
    local list = glyphs(str)
    local cursor = min(state.cursor, #list)
    local cx = prefixWidth(f, list, cursor)
    local total = f:getWidth(str)
    local scroll = scrolls[id] or 0
    if cx - scroll > w - 3 then scroll = cx - w + 3 end
    if cx < scroll then scroll = cx end
    scroll = max(0, min(scroll, total - w + 3))
    scrolls[id] = scroll
    local left = floor(x - scroll + 0.5)
    caret = caret or { top = -2, height = size + 6 }

    lg.push("all")
    local sx, sy = lg.transformPoint(x - 2, y + caret.top - 2)
    local ex, ey = lg.transformPoint(x + w + 2, y + caret.top + caret.height + 2)
    lg.intersectScissor(min(sx, ex), min(sy, ey), max(1, math.abs(ex - sx)), max(1, math.abs(ey - sy)))
    local a, b = TextEdit.range(state)
    if a then
        local ax, bx = prefixWidth(f, list, min(a, #list)), prefixWidth(f, list, min(b, #list))
        Kit.color(Kit.RED, 0.2 * alpha)
        lg.rectangle("fill", left + ax, y + caret.top, bx - ax, caret.height, 3, 3)
    end
    lg.setFont(f)
    Kit.color(c, alpha)
    lg.print(str, left, floor(y + 0.5))
    local now = love.timer.getTime()
    if (now - (state.moved or 0)) % 1 < 0.55 then
        Kit.color(Kit.RED, alpha)
        lg.rectangle("fill", left + cx, y + caret.top, 2, caret.height)
    end
    lg.pop()
end

--- The caret position closest to a point inside a field drawn by Kit.editable.
--- @param id string
--- @param str string what is shown
--- @param size number font size
--- @param dx number distance from the start of the text box
--- @return integer
function Kit.caretAt(id, str, size, dx)
    local f = Kit.font(size)
    local list = glyphs(str)
    local target = dx + (scrolls[id] or 0)
    local best, gap = 0, math.huge
    for n = 0, #list do
        local d = math.abs(prefixWidth(f, list, n) - target)
        if d < gap then best, gap = n, d end
    end
    return best
end

--- @param id string
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param value string what is shown
--- @param placeholder string
--- @param editing boolean
--- @param hot boolean
--- @param alpha number
--- @param state table? the TextEdit state while editing
function Kit.field(id, x, y, w, h, value, placeholder, editing, hot, alpha, state)
    local lg = love.graphics
    local focus = Kit.ease("field:" .. id, editing == true or hot == true)
    lg.setColor(INK[1], INK[2], INK[3], (0.05 + 0.03 * focus) * alpha)
    lg.rectangle("fill", x, y, w, h, 10, 10)
    Kit.color(editing and Kit.RED or INK, (0.15 + 0.6 * focus) * alpha)
    lg.setLineWidth(1.5)
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 10, 10)
    lg.setLineWidth(1)
    local empty = value == ""
    local ty = y + (h - 19) / 2
    if editing and state and not empty then
        Kit.editable("field:" .. id, value, state, x + 14, ty, w - 28, 16, INK, alpha, { top = y + 10 - ty, height = h - 20 })
        return
    end
    scrolls["field:" .. id] = nil
    local f = Kit.font(16)
    local shown = empty and placeholder or value
    while #shown > 0 and f:getWidth(shown) > w - 28 do shown = Text.dropLast(shown) end
    Kit.text(shown, 16, x + 14, ty, INK, (empty and 0.35 or 1) * alpha)
    if editing and (love.timer.getTime() - (state and state.moved or 0)) % 1 < 0.55 then
        Kit.color(Kit.RED, alpha)
        lg.rectangle("fill", x + 15, y + 10, 2, h - 20)
    end
end

--- Where the text of Kit.field starts, from the left edge of the field.
Kit.FIELD_PADDING = 14

return Kit
