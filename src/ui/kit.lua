local Kit = {}

local exp, min, max, sin, floor, pi = math.exp, math.min, math.max, math.sin, math.floor, math.pi

Kit.INK = { 0.1, 0.11, 0.13 }
Kit.RED = { 0.88, 0.14, 0.12 }
Kit.GREEN = { 0.22, 0.68, 0.4 }
Kit.AMBER = { 0.92, 0.6, 0.12 }
Kit.CARD = { 1, 1, 1 }
Kit.PAPER = { 0.93, 0.95, 0.97 }
Kit.RADIUS = 12

local INK, CARD = Kit.INK, Kit.CARD

local fonts = {}
local eased = {}

--- @param size number
--- @return love.Font
function Kit.font(size)
    if not fonts[size] then
        fonts[size] = love.graphics.newFont(size)
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
    lg.setColor(0.05, 0.07, 0.1, (0.1 + 0.06 * lift) * alpha)
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
    lg.setColor(1, 1, 1, alpha)
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
        lg.setColor(1, 0.8, 0.75, alpha)
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
        lg.setColor(0.05, 0.07, 0.1, (0.16 + 0.1 * hot) * alpha)
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
    lg.setColor(1, 1, 1, alpha)
    lg.rectangle("fill", x + (pos - 1) * cell + 3, y + 3, cell - 6, h - 6, (h - 6) / 2, (h - 6) / 2)
    for k, label in ipairs(options) do
        local active = 1 - Kit.clamp(math.abs(pos - k), 0, 1)
        Kit.text(label, 13, x + (k - 1) * cell, y + (h - 16) / 2, INK, (0.45 + 0.55 * active) * alpha, "center", cell)
    end
end

function Kit.field(id, x, y, w, h, value, placeholder, editing, hot, alpha)
    local lg = love.graphics
    local focus = Kit.ease("field:" .. id, editing == true or hot == true)
    lg.setColor(INK[1], INK[2], INK[3], (0.05 + 0.03 * focus) * alpha)
    lg.rectangle("fill", x, y, w, h, 10, 10)
    Kit.color(editing and Kit.RED or INK, (0.15 + 0.6 * focus) * alpha)
    lg.setLineWidth(1.5)
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 10, 10)
    lg.setLineWidth(1)
    local empty = value == ""
    local tw = Kit.text(empty and placeholder or value, 16, x + 14, y + (h - 19) / 2, INK, (empty and 0.35 or 1) * alpha)
    if editing and love.timer.getTime() % 1 < 0.55 then
        Kit.color(Kit.RED, alpha)
        lg.rectangle("fill", x + 15 + (empty and 0 or tw), y + 10, 2, h - 20)
    end
end

return Kit
