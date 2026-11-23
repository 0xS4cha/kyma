local Kit = require("src.ui.kit")
local Common = require("src.modules.menu.screens.common")
local Settings = require("src.modules.menu.settings")
local Config = require("src.config.game")
local Address = require("src.net.address")

local Play = {}

local CARDS = {
    {
        id = "practice", title = "Practice",
        text = "Duel a bot on your own. Nobody else can join, the bot plays by the same rules as you.",
        button = "Start practice"
    },
    {
        id = "host", title = "Host a duel",
        text = "Open a duel on your network and wait for an opponent. It shows up in their Multiplayer screen.",
        button = "Host"
    },
    {
        id = "join", title = "Join a duel",
        text = "Find duels hosted on your network, or connect to a dedicated server by address.",
        button = "Find duels"
    }
}

local function layout()
    local W, H = love.graphics.getDimensions()
    local M = Common.margin()
    local gap = 20
    local cardW = math.min(360, math.floor((W - M * 2 - gap * 2) / 3))
    local total = cardW * 3 + gap * 2
    local x = M
    local cardH = 300
    local y = math.max(200, math.floor((H - cardH) / 2) + 30)
    return { M = M, x = x, y = y, w = cardW, h = cardH, gap = gap, total = total }
end

local function levels()
    local list = {}
    for _, level in ipairs(Config.bots.order) do
        list[#list + 1] = Config.bots[level].name
    end
    return list
end

function Play.enter(menu)
    menu.lanAddress = Address.lan()
end

function Play.build(menu)
    local l = layout()
    local list = { Common.backElement(menu, function() menu:switch("root", -1) end) }
    list[#list + 1] = {
        id = "name", x = l.x, y = l.y - 74, w = 320, h = 46,
        press = function() menu.editing = "name" end,
        text = Common.textHandler(menu, "name", 20, Common.NAME_PATTERN)
    }
    for k, card in ipairs(CARDS) do
        local cx = l.x + (k - 1) * (l.w + l.gap)
        if card.id == "practice" then
            local count = #Config.bots.order
            list[#list + 1] = {
                id = "level", x = cx + 20, y = l.y + 166, w = l.w - 40, h = 38,
                press = function(_, mx)
                    if mx then
                        local cell = (l.w - 40) / count
                        menu:setOption("bot", Kit.clamp(math.floor((mx - cx - 20) / cell) + 1, 1, count))
                    else
                        menu:setOption("bot", menu.settings.bot % count + 1)
                    end
                end,
                left = function() menu:setOption("bot", math.max(1, menu.settings.bot - 1)) end,
                right = function() menu:setOption("bot", math.min(count, menu.settings.bot + 1)) end
            }
        end
        list[#list + 1] = {
            id = card.id, x = cx + 20, y = l.y + l.h - 72, w = l.w - 40, h = 52, card = card, cardX = cx,
            press = function()
                if card.id == "practice" then
                    menu:Play({ mode = "practice", bot = Settings.botLevel(menu.settings), label = "Practice against a bot" })
                elseif card.id == "host" then
                    menu:Play({ mode = "host", label = "Opening your duel" })
                else
                    menu:switch("multiplayer", 1)
                end
            end
        }
    end
    return list
end

function Play.draw(menu, elements, p)
    local l = layout()
    Common.header(menu, elements, p, "Play", "Choose how you want to duel.")

    local name = menu.find(elements, "name")
    local a = menu:stagger(p, 2)
    Kit.text("Your name", 12, name.x, name.y - 20, Kit.INK, 0.5 * a)
    Kit.field("name", name.x, name.y, name.w, name.h, menu.settings.name, "Player", menu.editing == "name", menu.focus == "name", a)

    for k, card in ipairs(CARDS) do
        local e = menu:stagger(p, k + 2)
        local cx = l.x + (k - 1) * (l.w + l.gap)
        local cy = l.y + (1 - e) * 30
        local button = menu.find(elements, card.id)
        local hot = Kit.ease("card:" .. card.id, menu.focus == card.id or (card.id == "practice" and menu.focus == "level"))
        Kit.card(cx, cy - hot * 4, l.w, l.h, e, 18, hot)
        local top = cy - hot * 4
        Kit.text(string.format("0%d", k), 13, cx + 20, top + 20, Kit.RED, e)
        Kit.text(card.title, 24, cx + 20, top + 40, Kit.INK, e)
        Common.paragraph(card.text, 13, cx + 20, top + 80, l.w - 40, Kit.INK, 0.6 * e)
        if card.id == "practice" then
            local level = menu.find(elements, "level")
            Kit.text("Bot level", 12, level.x, top + 142, Kit.INK, 0.5 * e)
            Kit.segments("level", level.x, top + 166, level.w, level.h, levels(), menu.settings.bot, e)
        elseif card.id == "host" then
            local address = menu.lanAddress and (menu.lanAddress .. ":6789") or "No network found"
            Kit.text("Friends connect to", 12, cx + 20, top + 150, Kit.INK, 0.5 * e)
            Kit.text(address, 18, cx + 20, top + 170, Kit.INK, e)
        end
        Kit.button(card.id, button.x, top + l.h - 72, button.w, button.h, card.button, {
            hot = menu.focus == card.id, primary = card.id == "practice", size = 17, alpha = e, align = "center", arrow = false
        })
    end
end

function Play.back(menu)
    menu:switch("root", -1)
end

return Play
