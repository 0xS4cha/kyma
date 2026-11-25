--- The loading screen shown while a game is being reached: the map draws
--- itself wall by wall, with the mode, the connection status and a tip.
--- When the map is not known yet (joining a server, matchmaking), it shows
--- the maps one after the other.
local Kit = require("src.ui.kit")
local Maps = require("src.maps.index")
local Config = require("src.config.game")
local Keys = require("src.input.keybinds")
local Tips = require("src.config.tips")
local Theme = require("src.ui.theme")

local Loading = {}

local TRACE = 1.6
local CYCLE = 4.2
local TIP = 7
local INK, RED = Kit.INK, Kit.RED
local clamp, easeOutCubic, easeOutBack = Kit.clamp, Kit.easeOutCubic, Kit.easeOutBack
local floor = math.floor

local KINDS = {
    { list = "pits", color = { 0.3, 0.33, 0.38 } },
    { list = "cover", color = { 0.6, 0.64, 0.7 } },
    { list = "walls", color = { 0.98, 0.985, 0.99 } },
    { list = "glass", color = { 0.45, 0.68, 0.9 } },
    { list = "doors", color = RED }
}

local pieces = {}

--- Every block of a map in the order it gets drawn: a sweep from the top
--- left corner to the bottom right one.
--- @param def table
--- @return table[]
local function piecesOf(def)
    if pieces[def.id] then return pieces[def.id] end
    local list = {}
    for _, kind in ipairs(KINDS) do
        for _, r in ipairs(def[kind.list] or {}) do
            list[#list + 1] = { r = r, color = kind.color, key = (r.x + r.w / 2) / def.width + (r.y + r.h / 2) / def.height }
        end
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    pieces[def.id] = list
    return list
end

--- @param text string
--- @return string
local function withKeys(text)
    return (text:gsub("{(%w+)}", function(action)
        local ok, label = pcall(Keys.label, action)
        return ok and label or action
    end))
end

--- Draws a map growing piece by piece.
--- @param def table
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param t number seconds since the drawing started
--- @param alpha number
function Loading.trace(def, x, y, w, h, t, alpha)
    local lg = love.graphics
    local scale = math.min(w / def.width, h / def.height)
    local mw, mh = def.width * scale, def.height * scale
    local ox, oy = x + (w - mw) / 2, y + (h - mh) / 2
    local base = easeOutCubic(t / 0.3)
    local fl = Theme.colors.minimapFloor
    lg.setColor(fl[1], fl[2], fl[3], alpha * base)
    lg.rectangle("fill", ox, oy, mw, mh, 6, 6)
    lg.setColor(INK[1], INK[2], INK[3], 0.06 * alpha * base)
    lg.setLineWidth(1)
    local step = 80 * scale
    for gx = step, mw - 1, step * 2 do lg.line(ox + gx, oy, ox + gx, oy + mh) end
    for gy = step, mh - 1, step * 2 do lg.line(ox, oy + gy, ox + mw, oy + gy) end

    local list = piecesOf(def)
    local n = #list
    for k, piece in ipairs(list) do
        local start = 0.2 + (k - 1) / math.max(1, n) * (TRACE - 0.55)
        local p = clamp((t - start) / 0.35, 0, 1)
        if p > 0 then
            local r = piece.r
            local e = easeOutCubic(p)
            local rx, ry = ox + r.x * scale, oy + r.y * scale
            local rw, rh = math.max(1, r.w * scale), math.max(1, r.h * scale)
            local c = piece.color
            lg.setColor(c[1], c[2], c[3], (c[4] or 1) * alpha)
            if rw >= rh then
                lg.rectangle("fill", rx, ry, rw * e, rh)
                if p < 1 then
                    Kit.color(RED, alpha * (1 - p))
                    lg.rectangle("fill", rx + rw * e - 1, ry - 2, 2, rh + 4)
                end
            else
                lg.rectangle("fill", rx, ry, rw, rh * e)
                if p < 1 then
                    Kit.color(RED, alpha * (1 - p))
                    lg.rectangle("fill", rx - 2, ry + rh * e - 1, rw + 4, 2)
                end
            end
        end
    end

    for k, spawn in ipairs(def.spawns or {}) do
        local p = clamp((t - TRACE - 0.05 * k) / 0.4, 0, 1)
        if p > 0 then
            local c = spawn.team == 2 and RED or Kit.ALLY
            local s = easeOutBack(p)
            Kit.dot(ox + spawn.x * scale, oy + spawn.y * scale, math.max(2.5, 18 * scale) * s, c, alpha * 0.85)
        end
    end
end

--- The tip shown at a given moment, and how visible it is.
--- @param elapsed number
--- @param seed number
--- @return string, number
function Loading.tip(elapsed, seed)
    local index = (seed + floor(elapsed / TIP)) % #Tips + 1
    local phase = elapsed % TIP
    local fade = math.min(clamp(phase / 0.4, 0, 1), clamp((TIP - phase) / 0.4, 0, 1))
    return withKeys(Tips[index]), fade
end

--- @param pending table? { map, game, label, at, seed }
--- @param status string text under the title
--- @param failed boolean
--- @param alpha number
function Loading.draw(pending, status, failed, alpha)
    pending = pending or {}
    local lg = love.graphics
    local W, H = lg.getDimensions()
    local now = love.timer.getTime()
    local elapsed = now - (pending.at or now)
    local seed = pending.seed or 0

    local mode = pending.game and Config.modes[pending.game]
    local known = pending.map and Maps.get(pending.map)
    local title = pending.label or "Joining a game"
    if known then title = (mode and (mode.name .. " on ") or "") .. known.name end

    local cw = math.min(680, floor(W * 0.56))
    local x = floor((W - cw) / 2)
    local top = math.max(36, floor(H * 0.08))
    local intro = easeOutCubic(elapsed / 0.5)

    Kit.text("KYMA", 14, x, top, RED, alpha * intro)
    Kit.text(title, 30, x, top + 22 + (1 - intro) * 10, INK, alpha * intro)
    local sy = top + 66
    if not failed then
        lg.setLineWidth(2.5)
        Kit.color(RED, alpha)
        local spin = now * 5
        lg.arc("line", "open", x + 8, sy + 9, 7, spin, spin + math.pi * 1.3, 20)
        lg.setLineWidth(1)
    end
    Kit.text(status, 15, failed and x or x + 24, sy, failed and RED or INK, (failed and 1 or 0.6) * alpha)

    local tipH = 76
    local mapY = sy + 40
    local mapH = H - mapY - tipH - 120
    local def, t, fade = known, elapsed, 1
    if not def then
        local index = (seed + floor(elapsed / CYCLE)) % #Maps.order + 1
        def = Maps.get(Maps.order[index])
        t = elapsed % CYCLE
        fade = clamp((CYCLE - t) / 0.35, 0, 1)
    end
    if mapH > 80 then
        Loading.trace(def, x, mapY, cw, mapH, t, alpha * fade)
        local scale = math.min(cw / def.width, mapH / def.height)
        local by = mapY + (mapH + def.height * scale) / 2 + 10
        local info = clamp((t - TRACE * 0.6) / 0.5, 0, 1) * alpha * fade
        local nw = Kit.text(def.name, 16, x, by, INK, info)
        Kit.text(known and string.format("%d x %d", def.width, def.height) or "Map gallery", 12, x + nw + 12, by + 3, INK, 0.45 * info)
        if def.description then
            lg.setFont(Kit.font(12))
            Kit.color(INK, 0.5 * info)
            lg.printf(def.description, x, by + 24, cw, "left")
        end
    end

    local tip, tipFade = Loading.tip(elapsed, seed)
    local ty = H - tipH - 44
    Kit.card(x, ty, cw, tipH, alpha, 16)
    Kit.text("Tip", 12, x + 22, ty + 14, RED, alpha * tipFade)
    lg.setFont(Kit.font(14))
    Kit.color(INK, 0.8 * alpha * tipFade)
    lg.printf(tip, x + 22, ty + 34 + (1 - tipFade) * 4, cw - 44, "left")
    local progress = (elapsed % TIP) / TIP
    Kit.color(RED, 0.5 * alpha)
    lg.rectangle("fill", x + 16, ty + tipH - 3, (cw - 32) * progress, 2)

    local hw = Kit.measureHint("Esc", "Menu", 13)
    Kit.hint("Esc", "Menu", x + (cw - hw) / 2, H - 34, 0.55 * alpha, 13)
end

return Loading
