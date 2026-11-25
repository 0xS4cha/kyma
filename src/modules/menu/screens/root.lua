local Kit = require("src.ui.kit")
local Common = require("src.modules.menu.screens.common")
local Settings = require("src.modules.menu.settings")
local Config = require("src.config.game")

local Root = {}

local TITLE = "KYMA"

local function titleY()
    return math.floor(love.graphics.getHeight() * 0.1)
end

function Root.build(menu)
    local M = Common.margin()
    local y = titleY() + 190
    local w = 380
    local level = Config.bots[Settings.botLevel(menu.settings)].name
    local mode = Config.modes[Settings.gameMode(menu.settings)].name
    local map = require("src.maps.index").get(menu.settings.map).name
    local list = {
        { id = "play", label = "Play", sublabel = mode .. " on " .. map .. ", " .. level:lower() .. " bots, or host a game", primary = true, h = 78, press = function() menu:switch("play", 1) end },
        { id = "extraction", label = "Extraction", sublabel = "A huge persistent world on the official server", h = 62, press = function()
            require("src.modules.menu.screens.online").extraction(menu)
        end },
        { id = "online", label = "Online", sublabel = "Rated matchmaking on the official server", h = 62, press = function() menu:switch("online", 1) end },
        { id = "tournament", label = "Tournaments", sublabel = "Create or join a bracket, in any mode", h = 62, press = function() menu:switch("tournament", 1) end },
        { id = "multiplayer", label = "Multiplayer", sublabel = "Join a duel on your network or a server", h = 62, press = function() menu:switch("multiplayer", 1) end },
        { id = "profile", label = "Profile", sublabel = "Name, colors and head", h = 54, press = function() menu:switch("profile", 1) end },
        { id = "loadout", label = "Loadout", sublabel = "Your weapon and its mod", h = 54, press = function() menu.loadoutTarget = nil; menu:switch("loadout", 1) end },
        { id = "howto", label = "How to play", h = 46, press = function() menu:switch("howto", 1) end },
        { id = "settings", label = "Settings", h = 46, press = function() menu:switch("settings", 1) end },
        { id = "quit", label = "Quit", h = 46, press = function() love.event.quit() end }
    }
    for _, element in ipairs(list) do
        element.x, element.y, element.w = M, y, w
        y = y + element.h + 10
    end
    return list
end

local function drawTitle(menu, x, y, alpha)
    local lg = love.graphics
    local f = Kit.font(110)
    local now = love.timer.getTime()
    local cx = x
    for k = 1, #TITLE do
        local letter = TITLE:sub(k, k)
        local t = Kit.easeOutBack((now - menu.openTime - 0.08 * (k - 1)) / 0.6)
        local fade = Kit.clamp((now - menu.openTime - 0.08 * (k - 1)) / 0.3, 0, 1)
        Kit.text(letter, 110, cx, y - (1 - t) * 40, Kit.INK, alpha * fade)
        cx = cx + f:getWidth(letter) + 6
    end
    local reveal = Kit.easeOutCubic((now - menu.openTime - 0.45) / 0.7)
    local width = (cx - x) * reveal
    local by = y + f:getHeight() - 4
    Kit.color(Kit.RED, alpha)
    lg.polygon("fill", x, by, x + width, by, x + width - 10, by + 10, x, by + 10)
    Kit.text(require("src.ui.theme").dark() and "One on one in a dark world." or "One on one in a white world.", 18, x + 2, by + 22, Kit.INK, 0.55 * alpha * reveal)
end

local function drawLive(menu, x, y, w, alpha)
    local bg = menu.background
    if not menu.settings.background or not bg.running then return end
    local feed = bg.feed
    local h = 92 + #feed * 26
    y = y - h
    Kit.card(x, y, w, h, alpha, 16)
    local now = love.timer.getTime()
    Kit.dot(x + 22, y + 24, 5, Kit.RED, alpha * (now % 1.2 < 0.8 and 1 or 0.3))
    Kit.text("Live duel", 13, x + 34, y + 15, Kit.RED, alpha)
    Kit.text("Watch the bots while you choose", 12, x + w - 18, y + 16, Kit.INK, 0.45 * alpha, "right")
    local score = bg:score()
    local slots = bg.SLOTS
    Kit.text(bg:name(slots[1]), 15, x + 18, y + 48, Kit.INK, alpha)
    Kit.text(score[1] .. " : " .. score[2], 20, x, y + 44, Kit.INK, alpha, "center", w)
    Kit.text(bg:name(slots[2]), 15, x + w - 18, y + 48, Kit.RED, alpha, "right")
    for k, entry in ipairs(feed) do
        local age = now - entry.time
        local e = Kit.easeOutCubic(age * 3) * alpha * (1 - (k - 1) * 0.18)
        local ly = y + 82 + (k - 1) * 26
        local killer = bg:name(entry.killer)
        local victim = bg:name(entry.victim)
        local kx = x + 18 + (1 - Kit.easeOutCubic(age * 3)) * 30
        local kw = Kit.text(killer, 13, kx, ly, entry.killer == slots[1] and Kit.INK or Kit.RED, e)
        Kit.text("eliminated", 13, kx + kw + 8, ly, Kit.INK, 0.45 * e)
        local ew = Kit.font(13):getWidth("eliminated")
        Kit.text(victim, 13, kx + kw + ew + 16, ly, entry.victim == slots[1] and Kit.INK or Kit.RED, e)
    end
end

function Root.draw(menu, elements, p)
    local W, H = love.graphics.getDimensions()
    local M = Common.margin()
    local alpha = Kit.easeOutCubic(p)
    drawTitle(menu, M, titleY(), alpha)
    for k, element in ipairs(elements) do
        local e = menu:stagger(p, k + 1)
        Kit.button(element.id, element.x - (1 - e) * 40, element.y, element.w, element.h, element.label, {
            hot = menu.focus == element.id,
            primary = element.primary,
            sublabel = element.sublabel,
            size = element.primary and 24 or 18,
            hint = element.primary and "Enter" or nil,
            alpha = e
        })
    end
    Kit.text("v0.1   -   Up / Down to move, Enter to select", 12, M, H - 36, Kit.INK, 0.45 * alpha)
    local liveW = math.min(380, math.floor(W * 0.3))
    local e = menu:stagger(p, 7)
    drawLive(menu, W - M - liveW + (1 - e) * 60, H - M, liveW, e)
end

function Root.keyPressed(menu, key)
    if (key == "return" or key == "kpenter") and not menu.focus then
        menu:switch("play", 1)
        return true
    end
    return false
end

function Root.back() end

return Root
