local GM = require("src.core.index")
local Kit = require("src.ui.kit")
local Common = require("src.modules.menu.screens.common")
local Settings = require("src.modules.menu.settings")
local Config = require("src.config.game")
local NetConfig = require("src.net.config")

local Online = {}

local function layout()
    local W, H = love.graphics.getDimensions()
    local M = Common.margin()
    local gap = 28
    local right = math.min(400, math.floor(W * 0.3))
    local left = math.min(640, W - M * 2 - right - gap)
    return { M = M, H = H, left = { x = M, w = left }, right = { x = M + left + gap, w = right }, y = 136 }
end

local function names()
    local out = {}
    for _, id in ipairs(Config.modes.order) do out[#out + 1] = Config.modes[id].name end
    return out
end

local function find(menu, address)
    local mode = Settings.gameMode(menu.settings)
    menu:saveSettings()
    menu:Play({ mode = "matchmaking", address = address, game = mode, label = "Looking for a " .. Config.modes[mode].name:lower() })
end

function Online.build(menu)
    local l = layout()
    local modes = #Config.modes.order
    local list = { Common.backElement(menu, function() menu:switch("root", -1) end) }
    list[#list + 1] = {
        id = "mode", x = l.left.x, y = l.y, w = l.left.w, h = 40,
        press = function(_, mx)
            if mx then
                menu:setOption("mode", Kit.clamp(math.floor((mx - l.left.x) / (l.left.w / modes)) + 1, 1, modes))
            else
                menu:setOption("mode", menu.settings.mode % modes + 1)
            end
        end,
        left = function() menu:setOption("mode", math.max(1, menu.settings.mode - 1)) end,
        right = function() menu:setOption("mode", math.min(modes, menu.settings.mode + 1)) end
    }
    list[#list + 1] = {
        id = "find", x = l.left.x, y = l.y + 130, w = l.left.w, h = 64,
        press = function() find(menu, GM.Multiplayer:OfficialAddress()) end
    }
    list[#list + 1] = {
        id = "findCustom", x = l.left.x + 22, y = l.y + 360, w = l.left.w - 44, h = 50,
        press = function() find(menu, menu.settings.server) end
    }
    local rx, rw = l.right.x, l.right.w
    list[#list + 1] = {
        id = "name", x = rx, y = l.y, w = rw, h = 44,
        press = function() menu.editing = "name" end,
        text = Common.textHandler(menu, "name", 20, Common.NAME_PATTERN)
    }
    list[#list + 1] = {
        id = "server", x = rx, y = l.y + 92, w = rw, h = 44,
        press = function() menu.editing = "server" end,
        text = Common.textHandler(menu, "server", 64, Common.SERVER_PATTERN)
    }
    return list
end

function Online.draw(menu, elements, p)
    local l = layout()
    Common.header(menu, elements, p, "Online", "Rated games against players of your level.")
    local a = menu:stagger(p, 2)
    local mode = menu.find(elements, "mode")
    local id = Settings.gameMode(menu.settings)
    local rules = Config.modes[id]
    local size = math.min(rules.players, NetConfig.matchmaking.sizes[id] or 2)
    Kit.text("Mode", 12, mode.x, mode.y - 20, Kit.INK, 0.5 * a)
    Kit.segments("online:mode", mode.x, mode.y, mode.w, mode.h, names(), menu.settings.mode, a)
    Common.paragraph(rules.text .. ". Games of " .. size .. " players, the map is picked for you.", 14, mode.x, mode.y + 56, mode.w, Kit.INK, 0.6 * a)

    local e = menu:stagger(p, 3)
    local find = menu.find(elements, "find")
    Kit.button("find", find.x, find.y, find.w, find.h, "Find a match", {
        hot = menu.focus == "find", primary = true, size = 22, hint = "Enter", alpha = e
    })

    e = menu:stagger(p, 4)
    local cy = find.y + find.h + 24
    local custom = menu.find(elements, "findCustom")
    local ch = custom.y + custom.h + 22 - cy
    Kit.card(l.left.x, cy, l.left.w, ch, e, 16)
    Kit.dot(l.left.x + 28, cy + 30, 5, Kit.GREEN, e)
    Kit.text("Official server", 18, l.left.x + 42, cy + 18, Kit.INK, e)
    Kit.text(GM.Multiplayer:OfficialAddress(), 13, l.left.x + l.left.w - 22, cy + 22, Kit.INK, 0.45 * e, "right")
    Common.paragraph("Your rating starts at 1000 and moves after every game you finish. It is kept by the server, tied to this computer.", 13, l.left.x + 22, cy + 56, l.left.w - 44, Kit.INK, 0.55 * e)
    Common.paragraph("Hosting your own? Start it with  love . --server --name \"My server\"  then queue on it here.", 13, l.left.x + 22, cy + 108, l.left.w - 44, Kit.INK, 0.45 * e)
    Kit.button("findCustom", custom.x, custom.y, custom.w, custom.h, "Find a match on " .. (menu.settings.server ~= "" and menu.settings.server or "your server"), {
        hot = menu.focus == "findCustom", size = 15, alpha = e
    })

    local ra = menu:stagger(p, 3)
    local name = menu.find(elements, "name")
    Kit.text("Your name", 12, name.x, name.y - 20, Kit.INK, 0.5 * ra)
    Kit.field("name", name.x, name.y, name.w, name.h, menu.settings.name, "Player", menu.editing == "name", menu.focus == "name", ra)
    local server = menu.find(elements, "server")
    Kit.text("Your server", 12, server.x, server.y - 20, Kit.INK, 0.5 * ra)
    Kit.field("server", server.x, server.y, server.w, server.h, menu.settings.server, "localhost:6789", menu.editing == "server", menu.focus == "server", ra)
end

function Online.keyPressed(menu, key)
    if (key == "return" or key == "kpenter") and (not menu.focus or menu.editing == "name") then
        find(menu, GM.Multiplayer:OfficialAddress())
        return true
    end
    if (key == "return" or key == "kpenter") and menu.editing == "server" then
        find(menu, menu.settings.server)
        return true
    end
    return false
end

function Online.back(menu)
    menu:switch("root", -1)
end

return Online
