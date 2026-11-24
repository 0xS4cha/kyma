local GM = require("src.core.index")
local Kit = require("src.ui.kit")
local Minimap = require("src.ui.minimap")
local Maps = require("src.maps.index")
local Config = require("src.config.game")

local Pause = {}

local ACTIONS_W, INFO_W, GAP, BUTTON = 380, 440, 20, 52
local ACTIONS = 5

local function layout()
    local W, H = love.graphics.getDimensions()
    local h = 112 + ACTIONS * (BUTTON + 10) + 14
    local total = ACTIONS_W + GAP + INFO_W
    local x = math.floor((W - total) / 2)
    return { x = x, y = math.floor((H - h) / 2), h = h, infoX = x + ACTIONS_W + GAP }
end

local function confirm(menu, id, action)
    return function()
        if menu.confirm == id then
            menu.confirm = nil
            action()
        else
            menu.confirm = id
        end
    end
end

function Pause.enter(menu)
    menu.confirm = nil
end

function Pause.build(menu)
    local l = layout()
    local list = {
        { id = "resume", label = "Resume", primary = true, hint = "Esc", press = function() menu:Resume() end },
        { id = "settings", label = "Settings", press = function() menu:switch("settings", 1) end },
        { id = "howto", label = "How to play", press = function() menu:switch("howto", 1) end },
        { id = "leave", label = "Leave the match", confirm = "Click again to leave", press = confirm(menu, "leave", function() menu:LeaveGame() end) },
        { id = "quit", label = "Quit Kyma", confirm = "Click again to quit", press = confirm(menu, "quit", function() love.event.quit() end) }
    }
    local by = l.y + 112
    for _, element in ipairs(list) do
        element.x, element.y, element.w, element.h = l.x + 22, by, ACTIONS_W - 44, BUTTON
        by = by + BUTTON + 10
    end
    return list
end

local function subtitle()
    local session = GM.Session
    if session.halted then return "The game is paused" end
    if session.world and session.world.spectator then return "The match keeps running" end
    return "The match keeps running, you are still in it"
end

local function drawInfo(menu, l, p)
    local session = GM.Session
    local world = session.world
    local a = menu:stagger(p, 3)
    local x, y, w, h = l.infoX, l.y + (1 - a) * 20, INFO_W, l.h
    Kit.card(x, y, w, h, a, 20)
    if not world then
        Kit.text("Connecting", 18, x + 24, y + 24, Kit.INK, 0.6 * a)
        return
    end
    local rules = world.rules
    local def = Maps.get(session.room and session.room.map or world.arena.id)
    Kit.text(rules.name, 22, x + 24, y + 22, Kit.INK, a)
    Kit.text(def.name .. "  -  first to " .. rules.scoreLimit .. (rules.ladder and " levels" or ""), 13, x + 24, y + 54, Kit.INK, 0.5 * a)
    local mapH = 170
    local me = not world.spectator and world.me.dead == 0 and session:localView() or nil
    Minimap.draw(def, x + 24, y + 82, w - 48, mapH, a, { loot = false, spawns = false, marker = me })
    local ty = y + 82 + mapH + 18
    if rules.teams then
        local score = world.teamScore or { 0, 0 }
        local mine = world.team or 1
        Kit.text(world.spectator and "Blue" or "Your team", 14, x + 24, ty, Kit.ALLY, a)
        Kit.text(tostring(score[mine] or 0) .. "  :  " .. tostring(score[mine == 1 and 2 or 1] or 0), 20, x, ty - 4, Kit.INK, a, "center", w)
        Kit.text(world.spectator and "Red" or "Enemies", 14, x + w - 24, ty, Kit.RED, a, "right")
        ty = ty + 36
    end
    local standings = session:standings()
    local rows = math.min(#standings, math.floor((y + h - 20 - ty) / 26))
    for k = 1, rows do
        local entry = standings[k]
        local c = entry.me and Kit.INK or (rules.teams and (entry.team == (world.team or 1) and Kit.ALLY or Kit.RED) or Kit.INK)
        if entry.me then
            love.graphics.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.05 * a)
            love.graphics.rectangle("fill", x + 14, ty - 4, w - 28, 26, 8, 8)
        end
        Kit.text(k .. ".", 14, x + 24, ty, Kit.INK, 0.4 * a)
        Kit.text(entry.name, 14, x + 48, ty, c, (entry.me and 1 or 0.8) * a)
        local value = rules.ladder and ("Lv " .. math.min(#rules.ladder, entry.kills + 1)) or tostring(entry.kills)
        Kit.text(value, 14, x + w - 24, ty, Kit.INK, 0.8 * a, "right")
        ty = ty + 26
    end
end

function Pause.draw(menu, elements, p)
    local l = layout()
    local e = Kit.easeOutBack(p)
    local a = Kit.easeOutCubic(p)
    local y = l.y + (1 - e) * 20
    Kit.card(l.x, y, ACTIONS_W, l.h, a, 20)
    local halted = GM.Session.halted
    Kit.dot(l.x + 30, y + 40, 5, halted and Kit.AMBER or Kit.GREEN, a * (halted and 1 or (love.timer.getTime() % 1.2 < 0.8 and 1 or 0.35)))
    Kit.text("Paused", 30, l.x + 44, y + 22, Kit.INK, a)
    Kit.text(subtitle(), 14, l.x + 24, y + 64, Kit.INK, 0.5 * a)
    for k, element in ipairs(elements) do
        local s = menu:stagger(p, k + 1)
        local asking = menu.confirm == element.id
        Kit.button(element.id, element.x, element.y + (1 - s) * 16, element.w, element.h, asking and element.confirm or element.label, {
            hot = menu.focus == element.id or asking, primary = element.primary or asking, hint = element.hint, size = 16, alpha = s
        })
    end
    drawInfo(menu, l, p)
end

function Pause.back(menu)
    if menu.confirm then
        menu.confirm = nil
        return
    end
    menu:Resume()
end

return Pause
