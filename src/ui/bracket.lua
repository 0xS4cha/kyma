local Kit = require("src.ui.kit")
local Bracket = require("src.game.bracket")

--- Draws a packed bracket (see Bracket:Pack) as columns of match cards joined by lines.
local View = {}

local GAP = 44
local CHAMPION_W = 200

--- @param name string
--- @param width number
--- @param size number
--- @return string
local function fit(name, width, size)
    local f = Kit.font(size)
    if f:getWidth(name) <= width then return name end
    while #name > 1 and f:getWidth(name .. "...") > width do name = name:sub(1, -2) end
    return name .. "..."
end

--- @param packed table
--- @param round number
--- @param index number
--- @return table
local function match(packed, round, index)
    local m = packed.r[round][index]
    return { a = m[1] ~= 0 and m[1] or nil, b = m[2] ~= 0 and m[2] or nil, wa = m[3], wb = m[4], winner = m[5] ~= 0 and m[5] or nil, bye = m[6] == 1 }
end

--- @param packed table
--- @return table layout per round { x, w, centers = {} }
function View.layout(packed, x, y, w, h)
    local rounds = #packed.r
    local colW = math.floor((w - CHAMPION_W - GAP * rounds) / rounds)
    colW = math.min(colW, 260)
    local first = packed.s / 2
    local spacing = h / first
    local boxH = math.min(66, math.floor(spacing - 10))
    local columns = {}
    for round = 1, rounds do
        local count = #packed.r[round]
        local step = h / count
        local centers = {}
        for index = 1, count do centers[index] = y + (index - 0.5) * step end
        columns[round] = { x = x + (round - 1) * (colW + GAP), w = colW, centers = centers }
    end
    return { columns = columns, boxH = boxH, colW = colW, champion = { x = x + rounds * (colW + GAP), y = y + h / 2 } }
end

--- @param entrants table[]? { n, l }
--- @param id number?
--- @return string, boolean
local function nameOf(entrants, id)
    local entrant = id and entrants and entrants[id]
    if not entrant then return "", false end
    return entrant.n or "?", entrant.l == true
end

--- @param packed table the bracket
--- @param entrants table[] names, by entrant id
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param options table { me = entrant id, live = { ["round:index"] = true }, alpha }
function View.draw(packed, entrants, x, y, w, h, options)
    options = options or {}
    local lg = love.graphics
    local alpha = options.alpha or 1
    local me = options.me
    local live = options.live or {}
    local l = View.layout(packed, x, y + 30, w, h - 30)
    local rounds = #packed.r
    local now = love.timer.getTime()
    local rowH = l.boxH / 2

    for round = 1, rounds do
        local column = l.columns[round]
        Kit.text(Bracket.roundName(round, rounds), 12, column.x, y, Kit.INK, 0.5 * alpha)
    end
    Kit.text("Champion", 12, l.champion.x, y, Kit.RED, 0.8 * alpha)

    lg.setLineWidth(2)
    for round = 1, rounds do
        local column = l.columns[round]
        for index, cy in ipairs(column.centers) do
            local m = match(packed, round, index)
            local winner = m.winner and (m.winner == 1 and m.a or m.b)
            local mine = winner ~= nil and winner == me
            local x1 = column.x + column.w
            local tx, ty
            if round < rounds then
                local parent = l.columns[round + 1]
                tx, ty = parent.x, parent.centers[math.ceil(index / 2)]
            else
                tx, ty = l.champion.x, l.champion.y
            end
            local mx = x1 + GAP / 2
            Kit.color(mine and Kit.RED or Kit.INK, (winner and (mine and 0.8 or 0.35) or 0.12) * alpha)
            lg.line(x1, cy, mx, cy, mx, ty, tx, ty)
        end
    end
    lg.setLineWidth(1)

    for round = 1, rounds do
        local column = l.columns[round]
        for index, cy in ipairs(column.centers) do
            local m = match(packed, round, index)
            local bx, by = column.x, cy - l.boxH / 2
            local isLive = live[round .. ":" .. index]
            local involved = me and (m.a == me or m.b == me)
            Kit.card(bx, by, column.w, l.boxH, alpha * (m.bye and 0.55 or 1), 10, involved and 1 or 0)
            if involved then
                Kit.color(Kit.RED, alpha)
                lg.rectangle("fill", bx, by + 8, 3, l.boxH - 16, 1.5, 1.5)
            end
            Kit.color(Kit.INK, 0.06 * alpha)
            lg.rectangle("fill", bx + 10, cy - 0.5, column.w - 20, 1)
            for side = 1, 2 do
                local id = side == 1 and m.a or m.b
                local wins = side == 1 and m.wa or m.wb
                local name, left = nameOf(entrants, id)
                local ry = by + (side - 1) * rowH
                local size = rowH >= 28 and 14 or 12
                local ty = ry + (rowH - Kit.font(size):getHeight()) / 2
                local won = m.winner == side
                local lost = m.winner and not won
                local label, ink, a
                if not id then
                    label = m.bye and "Bye" or "To be decided"
                    ink, a = Kit.INK, 0.3
                else
                    label = fit(name, column.w - 70, size) .. (left and "  (left)" or "")
                    ink = id == me and Kit.RED or Kit.INK
                    a = lost and 0.35 or (won and 1 or 0.8)
                end
                Kit.text(label, won and size + 1 or size, bx + 14, ty, ink, a * alpha)
                if id and not m.bye and packed.b > 1 then
                    Kit.text(tostring(wins), size, bx + column.w - 14, ty, won and Kit.RED or Kit.INK, (won and 1 or 0.5) * alpha, "right")
                elseif won and not m.bye then
                    Kit.dot(bx + column.w - 18, ry + rowH / 2, 4, Kit.RED, alpha)
                end
            end
            if isLive then
                local pulse = 0.5 + 0.5 * math.sin(now * 5)
                local lw = Kit.font(11):getWidth("LIVE") + 22
                Kit.color(Kit.RED, alpha)
                lg.rectangle("fill", bx + column.w - lw, by - 22, lw, 18, 9, 9)
                lg.setColor(1, 1, 1, (0.5 + 0.5 * pulse) * alpha)
                lg.circle("fill", bx + column.w - lw + 9, by - 13, 3)
                Kit.text("LIVE", 11, bx + column.w - lw + 15, by - 20, { 1, 1, 1 }, alpha)
            end
        end
    end

    local c = l.champion
    local champion = packed.c
    local cw, ch = CHAMPION_W - 20, 72
    Kit.card(c.x, c.y - ch / 2, cw, ch, alpha, 14, champion and 1 or 0)
    if champion then
        local name = nameOf(entrants, champion)
        Kit.color(Kit.RED, alpha)
        lg.rectangle("fill", c.x, c.y - ch / 2, cw, 4, 2, 2)
        Kit.text(fit(name, cw - 28, 20), 20, c.x + 14, c.y - 13, champion == me and Kit.RED or Kit.INK, alpha)
    else
        Kit.text("?", 22, c.x, c.y - 14, Kit.INK, 0.25 * alpha, "center", cw)
    end
end

return View
