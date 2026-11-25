local GM = require("src.core.index")
local Kit = require("src.ui.kit")
local BracketView = require("src.ui.bracket")
local Bracket = require("src.game.bracket")
local Config = require("src.config.game")
local Maps = require("src.maps.index")

--- What a connected player sees between tournament matches: the list of
--- tournaments of a server, a lobby, or the bracket.
local View = {}

local LEAVE_CONFIRM = 2.5
local ROW = 64

View.selected = 1
View.leaveAt = -10
View.hits = {}

--- @param session table
--- @return boolean
function View.active(session)
    local mp = GM.Multiplayer
    return session.active and not session.world and mp.state == "online" and (mp.tournament ~= nil or mp.tournaments ~= nil)
end

--- @param t table
--- @return string
local function summary(t)
    local mode = Config.modes[t.m or ""] or Config.modes.duel
    local parts = { mode.name, Maps.get(t.map).name, t.b and t.b > 1 and ("best of " .. t.b) or "single game" }
    return table.concat(parts, "  -  ")
end

--- @param t table
--- @return string, table
local function stateLabel(t)
    if t.st == "lobby" then return "Waiting for players", Kit.AMBER end
    if t.st == "running" then return "In progress", Kit.RED end
    return "Finished", Kit.GREEN
end

--- @param t table
--- @return string
local function status(t)
    local me = t.me
    if t.st == "lobby" then
        if t.own then
            return #t.pl >= 2 and "Start whenever you are ready" or "Waiting for at least one more player"
        end
        return "Waiting for " .. (t.o ~= "" and t.o or "the organiser") .. " to start"
    end
    local br = t.br
    if not br or not me then return "" end
    if br.c then
        return br.c == me and "You won the tournament" or ((t.e[br.c] and t.e[br.c].n or "?") .. " won the tournament")
    end
    for round = 1, #br.r do
        for _, m in ipairs(br.r[round]) do
            if m[5] == 0 and (m[1] == me or m[2] == me) then
                local other = m[1] == me and m[2] or m[1]
                local name = Bracket.roundName(round, #br.r)
                if other == 0 then return name .. ": waiting for your opponent" end
                return name .. ": you play " .. (t.e[other] and t.e[other].n or "?") .. " next"
            end
        end
    end
    return "You are out. Stay to follow the bracket"
end

--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param action function
local function hit(x, y, w, h, action)
    View.hits[#View.hits + 1] = { x = x, y = y, w = w, h = h, action = action }
end

--- @param list table[]
--- @param x number
--- @param y number
--- @param w number
--- @param h number
local function drawList(list, x, y, w, h)
    local mp = GM.Multiplayer
    Kit.card(x, y, w, h, 1, 18)
    Kit.text("Tournaments on " .. ((mp.server and mp.server.name) or mp.address or "this server"), 18, x + 24, y + 20, Kit.INK, 1)
    if #list == 0 then
        Kit.text("No tournament here yet.", 16, x + 24, y + 70, Kit.INK, 0.6)
        Kit.text("Create one from Tournaments in the main menu.", 14, x + 24, y + 96, Kit.INK, 0.45)
        return
    end
    View.selected = Kit.clamp(View.selected, 1, #list)
    local rows = math.floor((h - 80) / ROW)
    local first = math.max(1, math.min(View.selected - rows + 1, #list - rows + 1))
    for k = first, math.min(#list, first + rows - 1) do
        local t = list[k]
        local ry = y + 64 + (k - first) * ROW
        local selected = k == View.selected
        local hot = Kit.ease("tour:" .. t.id, selected)
        love.graphics.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.03 + 0.05 * hot)
        love.graphics.rectangle("fill", x + 16, ry, w - 32, ROW - 8, 10, 10)
        if hot > 0.01 then
            Kit.color(Kit.RED, hot)
            love.graphics.rectangle("fill", x + 16, ry + 10, 3, ROW - 28, 1.5, 1.5)
        end
        local label, c = stateLabel(t)
        Kit.dot(x + 38, ry + (ROW - 8) / 2, 5, c, 1)
        Kit.text(t.n, 16, x + 54 + hot * 4, ry + 8, Kit.INK, 1)
        Kit.text(summary(t) .. "  -  by " .. tostring(t.o), 12, x + 54 + hot * 4, ry + 31, Kit.INK, 0.5)
        local open = t.st == "lobby" and t.p < t.s
        Kit.text(string.format("%d / %d", t.p, t.s), 15, x + w - 36, ry + 8, Kit.INK, 0.8, "right")
        Kit.text(open and "Join" or label, 12, x + w - 36, ry + 31, open and Kit.RED or Kit.INK, open and 1 or 0.5, "right")
        hit(x + 16, ry, w - 32, ROW - 8, function()
            View.selected = k
            if open then mp:Tournament({ a = "join", id = t.id }) end
        end)
    end
end

--- @param t table
--- @param x number
--- @param y number
--- @param w number
--- @param h number
local function drawLobby(t, x, y, w, h)
    local mp = GM.Multiplayer
    local listW = math.min(520, math.floor(w * 0.55))
    Kit.card(x, y, listW, h, 1, 18)
    Kit.text("Players", 18, x + 24, y + 20, Kit.INK, 1)
    Kit.text(#t.pl .. " / " .. t.s, 15, x + listW - 24, y + 22, Kit.INK, 0.6, "right")
    local rowH = math.min(44, math.floor((h - 76) / t.s))
    for k = 1, t.s do
        local ry = y + 64 + (k - 1) * rowH
        local name = t.pl[k]
        Kit.text(tostring(k), 13, x + 24, ry + (rowH - 16) / 2, Kit.INK, 0.35)
        if name then
            local mine = name == mp.name
            Kit.text(name, rowH >= 34 and 16 or 13, x + 56, ry + (rowH - 19) / 2, mine and Kit.RED or Kit.INK, 1)
            if name == t.o then Kit.text("Organiser", 12, x + listW - 24, ry + (rowH - 15) / 2, Kit.INK, 0.45, "right") end
        else
            Kit.text("Open seat", rowH >= 34 and 15 or 13, x + 56, ry + (rowH - 18) / 2, Kit.INK, 0.25)
        end
    end

    local px, pw = x + listW + 24, math.min(480, w - listW - 24)
    Kit.card(px, y, pw, 250, 1, 18)
    Kit.text("Format", 18, px + 24, y + 20, Kit.INK, 1)
    local rows = {
        { "Mode", (Config.modes[t.m] or Config.modes.duel).name },
        { "Map", Maps.get(t.map).name },
        { "Matches", t.b > 1 and ("Best of " .. t.b) or "One game" },
        { "Bracket", "Single elimination, seeded by rating" }
    }
    for k, row in ipairs(rows) do
        local ry = y + 62 + (k - 1) * 40
        Kit.text(row[1], 13, px + 24, ry, Kit.INK, 0.5)
        Kit.text(row[2], 15, px + 130, ry - 1, Kit.INK, 0.9)
    end
    if t.own then
        local can = #t.pl >= 2
        local by = y + 274
        Kit.button("tournament:start", px, by, pw, 60, "Start the tournament", {
            primary = can, hot = can, size = 20, hint = can and "Enter" or nil, alpha = can and 1 or 0.5
        })
        if can then hit(px, by, pw, 60, function() mp:Tournament({ a = "start" }) end) end
    end
end

--- @param session table
function View.draw(session)
    local mp = GM.Multiplayer
    local W, H = love.graphics.getDimensions()
    local M = math.max(36, math.floor(W * 0.05))
    View.hits = {}
    love.graphics.setColor(Kit.PAPER[1], Kit.PAPER[2], Kit.PAPER[3], 1)
    love.graphics.rectangle("fill", 0, 0, W, H)
    local t = mp.tournament
    local top = 40
    if t then
        Kit.text(t.n, 34, M, top, Kit.INK, 1)
        local sub = summary(t) .. "  -  " .. (t.e and #t.e or #t.pl) .. " players  -  organised by " .. tostring(t.o)
        Kit.text(sub, 14, M + 2, top + 46, Kit.INK, 0.55)
        local label, c = stateLabel(t)
        local lw = Kit.font(14):getWidth(label) + 44
        Kit.card(W - M - lw, top + 6, lw, 34, 1, 17)
        Kit.dot(W - M - lw + 20, top + 23, 5, c, t.st == "running" and (0.5 + 0.5 * math.sin(love.timer.getTime() * 4)) or 1)
        Kit.text(label, 14, W - M - lw + 32, top + 14, Kit.INK, 1)
        Kit.text(status(t), 20, M, top + 84, t.br and t.br.c == t.me and Kit.RED or Kit.INK, 1)
        local y = top + 136
        local h = H - y - 80
        if t.st == "lobby" then
            drawLobby(t, M, y, W - M * 2, math.min(h, 620))
        elseif t.br then
            local live = {}
            for _, entry in ipairs(t.lv or {}) do live[entry[1] .. ":" .. entry[2]] = true end
            BracketView.draw(t.br, t.e, M, y, W - M * 2, h, { me = t.me, live = live })
        end
    else
        Kit.text("Tournaments", 34, M, top, Kit.INK, 1)
        Kit.text("Pick one to join. The organiser starts it once enough players are in.", 14, M + 2, top + 46, Kit.INK, 0.55)
        local w = math.min(860, W - M * 2)
        drawList(mp.tournaments or {}, M, top + 100, w, math.min(H - top - 200, 640))
    end
    if mp.error then
        Kit.text(mp.error, 15, M, H - 96, Kit.RED, 1)
    end
    local hints = {}
    if t then
        if t.own and t.st == "lobby" then hints[#hints + 1] = { "Enter", "Start" } end
        local confirming = love.timer.getTime() - View.leaveAt < LEAVE_CONFIRM
        local leaving = t.st == "running" and t.me and not (t.e[t.me] or {}).l and t.br and not t.br.c
        hints[#hints + 1] = { "Esc", confirming and "Press again to forfeit and leave" or (leaving and "Forfeit and leave" or "Leave") }
    else
        hints[#hints + 1] = { "Enter", "Join" }
        hints[#hints + 1] = { "R", "Refresh" }
        hints[#hints + 1] = { "Esc", "Back to the menu" }
    end
    local hx = M
    for _, entry in ipairs(hints) do
        Kit.hint(entry[1], entry[2], hx, H - 56, 0.75, 15)
        hx = hx + Kit.measureHint(entry[1], entry[2], 15) + 28
    end
end

--- @param session table
--- @param key string
--- @return boolean handled
function View.keyPressed(session, key)
    local mp = GM.Multiplayer
    local t = mp.tournament
    if key == "escape" then
        local risky = t and t.st == "running" and t.me and t.br and not t.br.c and not (t.e[t.me] or {}).l
        local now = love.timer.getTime()
        if risky and now - View.leaveAt > LEAVE_CONFIRM then
            View.leaveAt = now
            return true
        end
        View.leaveAt = -10
        if GM.Menu then
            GM.Menu:LeaveGame()
            GM.Menu.consumed = key
        end
        return true
    end
    if t then
        if (key == "return" or key == "kpenter") and t.own and t.st == "lobby" then
            mp:Tournament({ a = "start" })
        end
        return true
    end
    local list = mp.tournaments or {}
    if key == "up" then
        View.selected = math.max(1, View.selected - 1)
    elseif key == "down" then
        View.selected = math.min(#list, View.selected + 1)
    elseif key == "r" then
        mp:Tournament({ a = "list" })
    elseif (key == "return" or key == "kpenter") and list[View.selected] then
        mp:Tournament({ a = "join", id = list[View.selected].id })
    end
    return true
end

--- @param x number
--- @param y number
--- @return boolean handled
function View.mousePressed(x, y)
    for _, area in ipairs(View.hits) do
        if x >= area.x and x <= area.x + area.w and y >= area.y and y <= area.y + area.h then
            area.action()
            return true
        end
    end
    return false
end

return View
