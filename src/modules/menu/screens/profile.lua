local Kit = require("src.ui.kit")
local Common = require("src.modules.menu.screens.common")
local Profile = require("src.config.profile")
local Character = require("src.modules.session.character")

local Screen = {}

local function layout()
    local W, H = love.graphics.getDimensions()
    local M = Common.margin()
    local panelW = math.min(560, math.floor((W - M * 2) * 0.48))
    return { M = M, W = W, H = H, x = M, y = 130, w = panelW, preview = { x = M + panelW + 30, y = 130, w = W - M * 2 - panelW - 30, h = H - 130 - M } }
end

local function swatches(list, key, menu, x, y, w)
    local elements = {}
    local count = #list
    local size = math.min(44, math.floor((w - (count - 1) * 10) / count))
    for k = 1, count do
        elements[#elements + 1] = {
            id = key .. ":" .. k, x = x + (k - 1) * (size + 10), y = y, w = size, h = size, swatch = list[k], key = key, value = k,
            press = function() menu:setOption(key, k) end
        }
    end
    return elements
end

function Screen.build(menu)
    local l = layout()
    local list = { Common.backElement(menu, function() menu:switch("root", -1) end) }
    list[#list + 1] = {
        id = "name", x = l.x + 22, y = l.y + 62, w = l.w - 44, h = 46,
        press = function() menu.editing = "name" end,
        text = Common.textHandler(menu, "name", 20, Common.NAME_PATTERN)
    }
    for _, e in ipairs(swatches(Profile.bodies, "body", menu, l.x + 22, l.y + 170, l.w - 44)) do list[#list + 1] = e end
    for _, e in ipairs(swatches(Profile.accents, "accent", menu, l.x + 22, l.y + 268, l.w - 44)) do list[#list + 1] = e end
    local heads = #Profile.heads
    list[#list + 1] = {
        id = "head", x = l.x + 22, y = l.y + 366, w = l.w - 44, h = 40,
        press = function(_, mx)
            if mx then
                menu:setOption("head", Kit.clamp(math.floor((mx - l.x - 22) / ((l.w - 44) / heads)) + 1, 1, heads))
            else
                menu:setOption("head", menu.settings.head % heads + 1)
            end
        end,
        left = function() menu:setOption("head", math.max(1, menu.settings.head - 1)) end,
        right = function() menu:setOption("head", math.min(heads, menu.settings.head + 1)) end
    }
    return list
end

function Screen.draw(menu, elements, p)
    local l = layout()
    Common.header(menu, elements, p, "Profile", "How you look to yourself and to the others.")
    local s = menu.settings
    local e = menu:stagger(p, 2)
    local panelH = 440
    Kit.card(l.x, l.y + (1 - e) * 20, l.w, panelH, e, 18)
    local name = menu.find(elements, "name")
    Kit.text("Name", 12, name.x, name.y - 20, Kit.INK, 0.5 * e)
    Kit.field("name", name.x, name.y, name.w, name.h, s.name, "Player", menu.editing == "name", menu.focus == "name", e)

    Kit.text("Body, only you see it", 12, l.x + 22, l.y + 148, Kit.INK, 0.5 * e)
    Kit.text("Accent, everyone sees it", 12, l.x + 22, l.y + 246, Kit.INK, 0.5 * e)
    Kit.text("Head, everyone sees it", 12, l.x + 22, l.y + 344, Kit.INK, 0.5 * e)
    for _, element in ipairs(elements) do
        if element.swatch then
            local selected = s[element.key] == element.value
            local hot = Kit.ease("swatch:" .. element.id, menu.focus == element.id or selected)
            local c = element.swatch.color
            local lg = love.graphics
            lg.setColor(Kit.SHADOW[1], Kit.SHADOW[2], Kit.SHADOW[3], 0.12 * e)
            lg.circle("fill", element.x + element.w / 2, element.y + element.h / 2 + 2, element.w / 2)
            lg.setColor(c[1], c[2], c[3], e)
            lg.circle("fill", element.x + element.w / 2, element.y + element.h / 2, element.w / 2 - 2)
            if hot > 0.01 then
                Kit.color(selected and Kit.RED or Kit.INK, hot * e)
                lg.setLineWidth(2.5)
                lg.circle("line", element.x + element.w / 2, element.y + element.h / 2, element.w / 2 + 3)
                lg.setLineWidth(1)
            end
        end
    end
    local head = menu.find(elements, "head")
    Kit.segments("head", head.x, head.y, head.w, head.h, Profile.heads, s.head, e)

    local pv = l.preview
    local a = menu:stagger(p, 3)
    Kit.card(pv.x, pv.y + (1 - a) * 20, pv.w, pv.h, a, 18)
    local lg = love.graphics
    local cx, cy = pv.x + pv.w / 2, pv.y + pv.h / 2 + 10
    local scale = math.min(pv.w, pv.h) / 70
    lg.push()
    lg.translate(cx, cy)
    lg.scale(scale, scale)
    local t = love.timer.getTime()
    Character.draw({
        slot = 777, x = 0, y = 0, angle = -math.pi / 2 + math.sin(t * 0.8) * 0.9, vx = 0, vy = 0,
        weapon = "rifle", look = { h = s.head, a = s.accent }
    }, { body = require("src.ui.theme").lifted(Profile.bodies[s.body].color) }, { alpha = a, phase = 0 })
    lg.pop()
    Kit.text(s.name ~= "" and s.name or "Player", 22, pv.x, pv.y + 24, Kit.INK, a, "center", pv.w)
    Kit.text(Profile.bodies[s.body].name .. " body, " .. Profile.accents[s.accent].name:lower() .. " accent, " .. Profile.heads[s.head]:lower() .. " head",
        13, pv.x, pv.y + pv.h - 40, Kit.INK, 0.5 * a, "center", pv.w)
end

function Screen.back(menu)
    menu:switch("root", -1)
end

return Screen
