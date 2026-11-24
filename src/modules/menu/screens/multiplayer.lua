local GM = require("src.core.index")
local Kit = require("src.ui.kit")
local Common = require("src.modules.menu.screens.common")

local Multiplayer = {}

local ROW = 58

local function layout()
    local W, H = love.graphics.getDimensions()
    local M = Common.margin()
    local gap = 24
    local listW = math.min(560, math.floor((W - M * 2 - gap) * 0.55))
    local panelW = math.min(440, W - M * 2 - gap - listW)
    local y = 130
    local h = math.min(520, H - y - M)
    return { M = M, list = { x = M, y = y, w = listW, h = h }, panel = { x = M + listW + gap, y = y, w = panelW, h = h } }
end

local function join(menu, address, label, spectate)
    menu:saveSettings()
    menu:Play({ mode = "connect", address = address, label = label, spectate = spectate })
end

function Multiplayer.build(menu)
    local l = layout()
    local list = { Common.backElement(menu, function() menu:switch("root", -1) end) }
    local games = GM.Multiplayer:LanGames()
    for k, game in ipairs(games) do
        if k * ROW + 70 > l.list.h then break end
        list[#list + 1] = {
            id = "lan:" .. k, x = l.list.x + 16, y = l.list.y + 58 + (k - 1) * ROW, w = l.list.w - 32, h = ROW - 8, game = game,
            press = function()
                if game.players < game.max then
                    join(menu, game.address, "Joining " .. game.name)
                else
                    join(menu, game.address, "Watching " .. game.name, true)
                end
            end
        }
    end
    local px, pw = l.panel.x + 22, l.panel.w - 44
    list[#list + 1] = {
        id = "name", x = px, y = l.panel.y + 92, w = pw, h = 46,
        press = function() menu.editing = "name" end,
        text = Common.textHandler(menu, "name", 20, Common.NAME_PATTERN)
    }
    list[#list + 1] = {
        id = "server", x = px, y = l.panel.y + 176, w = pw, h = 46,
        press = function() menu.editing = "server" end,
        text = Common.textHandler(menu, "server", 64, Common.SERVER_PATTERN)
    }
    list[#list + 1] = {
        id = "watchServer", x = px + pw - 110, y = l.panel.y + 250, w = 110, h = 56,
        press = function() join(menu, menu.settings.server, "Watching " .. menu.settings.server, true) end
    }
    list[#list + 1] = {
        id = "connect", x = px, y = l.panel.y + 250, w = pw - 122, h = 56,
        press = function() join(menu, menu.settings.server, "Connecting to " .. menu.settings.server) end
    }
    return list
end

function Multiplayer.draw(menu, elements, p)
    local l = layout()
    Common.header(menu, elements, p, "Multiplayer", "Join a duel on your network, or connect to a server.")
    local now = love.timer.getTime()

    local e = menu:stagger(p, 2)
    local box = l.list
    local bx = box.x - (1 - e) * 30
    Kit.card(bx, box.y, box.w, box.h, e, 18)
    Kit.text("On your network", 18, bx + 22, box.y + 18, Kit.INK, e)
    local games = 0
    for _, element in ipairs(elements) do
        if element.game then
            games = games + 1
            local game = element.game
            local hot = Kit.ease("lan:" .. element.id, menu.focus == element.id)
            local full = game.players >= game.max
            local y = element.y
            love.graphics.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], (0.04 + 0.05 * hot) * e)
            love.graphics.rectangle("fill", bx + 16, y, element.w, element.h, 10, 10)
            Kit.dot(bx + 36, y + element.h / 2, 5, full and Kit.AMBER or Kit.GREEN, e)
            Kit.text(game.name, 16, bx + 52 + hot * 4, y + 7, Kit.INK, e)
            Kit.text(game.address, 12, bx + 52 + hot * 4, y + 28, Kit.INK, 0.45 * e)
            Kit.text(full and "Full  -  Watch" or string.format("%d / %d  -  Join", game.players, game.max), 13, bx + 16 + element.w - 16, y + 16, full and Kit.AMBER or Kit.INK, (0.5 + 0.5 * hot) * e, "right")
        end
    end
    if games == 0 then
        local dots = string.rep(".", math.floor(now * 2) % 4)
        Kit.text("Searching your network" .. dots, 15, bx + 22, box.y + 66, Kit.INK, 0.5 * e)
        Common.paragraph("Duels hosted from Play > Host a duel on this network appear here by themselves. Both computers need to be on the same network, and UDP ports 6788 and 6789 must be open.", 13, bx + 22, box.y + 100, box.w - 44, Kit.INK, 0.45 * e)
        local r = 28 + (now % 2) * 40
        love.graphics.setLineWidth(2)
        Kit.color(Kit.RED, (1 - (now % 2) / 2) * 0.5 * e)
        love.graphics.circle("line", bx + box.w / 2, box.y + box.h - 110, r)
        love.graphics.setLineWidth(1)
        Kit.dot(bx + box.w / 2, box.y + box.h - 110, 6, Kit.RED, e)
    end

    e = menu:stagger(p, 3)
    local panel = l.panel
    local py = panel.y + (1 - e) * 30
    Kit.card(panel.x, py, panel.w, panel.h, e, 18)
    Kit.text("Connect to a server", 18, panel.x + 22, py + 18, Kit.INK, e)
    local name = menu.find(elements, "name")
    local server = menu.find(elements, "server")
    local connect = menu.find(elements, "connect")
    local dy = py - panel.y
    Kit.text("Your name", 12, name.x, name.y - 20 + dy, Kit.INK, 0.5 * e)
    Kit.field("name", name.x, name.y + dy, name.w, name.h, menu.settings.name, "Player", menu.editing == "name", menu.focus == "name", e)
    Kit.text("Server address", 12, server.x, server.y - 20 + dy, Kit.INK, 0.5 * e)
    Kit.field("server", server.x, server.y + dy, server.w, server.h, menu.settings.server, "localhost:6789", menu.editing == "server", menu.focus == "server", e)
    Kit.button("connect", connect.x, connect.y + dy, connect.w, connect.h, "Connect", { hot = menu.focus == "connect", primary = true, size = 18, hint = "Enter", alpha = e })
    local watch = menu.find(elements, "watchServer")
    Kit.button("watchServer", watch.x, watch.y + dy, watch.w, watch.h, "Watch", { hot = menu.focus == "watchServer", size = 15, align = "center", alpha = e, arrow = false })
    local hintY = connect.y + dy + connect.h + 24
    Common.paragraph("Run a dedicated server with  love . --server  or the Docker image, then type its address here.", 13, name.x, hintY, name.w, Kit.INK, 0.45 * e)
end

function Multiplayer.keyPressed(menu, key)
    if (key == "return" or key == "kpenter") and (menu.editing == "server" or menu.editing == "name") then
        join(menu, menu.settings.server, "Connecting to " .. menu.settings.server)
        return true
    end
    return false
end

function Multiplayer.back(menu)
    menu:switch("root", -1)
end

return Multiplayer
