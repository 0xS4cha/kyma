local GM = require("src.core.index")
local Kit = require("src.ui.kit")
local Common = require("src.modules.menu.screens.common")
local Config = require("src.config.game")
local Maps = require("src.maps.index")

local Multiplayer = {}

local ROW = 58
local SOURCES = { "Official server", "Your server", "Your network" }

local function layout()
    local W, H = love.graphics.getDimensions()
    local M = Common.margin()
    local gap = 24
    local listW = math.min(640, math.floor((W - M * 2 - gap) * 0.58))
    local panelW = math.min(440, W - M * 2 - gap - listW)
    local y = 130
    local h = math.min(600, H - y - M)
    return { M = M, list = { x = M, y = y, w = listW, h = h }, panel = { x = M + listW + gap, y = y, w = panelW, h = h } }
end

--- @param menu table
--- @return string?
local function sourceAddress(menu)
    local source = menu.settings.browseSource
    if source == 1 then return GM.Multiplayer:OfficialAddress() end
    if source == 2 then return menu.settings.server ~= "" and menu.settings.server or nil end
    return nil
end

--- The server the browser lists, kept while the address is being typed.
--- @param menu table
--- @return string?
function Multiplayer.browsing(menu)
    if menu.settings.browseSource == 2 and menu.editing == "server" then
        return GM.Multiplayer.browser.address
    end
    return sourceAddress(menu)
end

--- @param menu table
--- @return table[]
local function games(menu)
    if menu.settings.browseSource == 3 then return GM.Multiplayer:LanGames() end
    return GM.Multiplayer:ServerGames()
end

local function join(menu, address, label, options)
    options = options or {}
    menu:saveSettings()
    menu:Play({
        mode = "connect", address = address, label = label, spectate = options.spectate,
        room = options.room, password = options.room and menu.settings.password or nil
    })
end

--- @param menu table
--- @param game table
local function pick(menu, game)
    if game.locked and menu.settings.password == "" then
        menu.editing = "password"
        menu.focus = "password"
        menu.notice = game.name .. " needs a password"
        return
    end
    local full = game.max > 0 and game.players >= game.max
    join(menu, game.address, (full and "Watching " or "Joining ") .. game.name, { room = game.room, spectate = full or nil })
end

function Multiplayer.enter(menu)
    menu.notice = nil
    GM.Multiplayer.browser:Refresh()
end

function Multiplayer.build(menu)
    local l = layout()
    local list = { Common.backElement(menu, function() menu:switch("root", -1) end) }
    local box = l.list
    list[#list + 1] = {
        id = "source", x = box.x + 22, y = box.y + 54, w = box.w - 44, h = 36,
        press = function(_, mx)
            if mx then
                menu:setOption("browseSource", Kit.clamp(math.floor((mx - box.x - 22) / ((box.w - 44) / #SOURCES)) + 1, 1, #SOURCES))
            else
                menu:setOption("browseSource", menu.settings.browseSource % #SOURCES + 1)
            end
        end,
        left = function() menu:setOption("browseSource", math.max(1, menu.settings.browseSource - 1)) end,
        right = function() menu:setOption("browseSource", math.min(#SOURCES, menu.settings.browseSource + 1)) end
    }
    for k, game in ipairs(games(menu)) do
        if 108 + k * ROW > box.h then break end
        list[#list + 1] = {
            id = "game:" .. k, x = box.x + 16, y = box.y + 106 + (k - 1) * ROW, w = box.w - 32, h = ROW - 8, game = game,
            press = function() pick(menu, game) end
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
        id = "password", x = px, y = l.panel.y + 260, w = pw, h = 46,
        press = function() menu.editing = "password" end,
        text = Common.textHandler(menu, "password", 24, Common.PASSWORD_PATTERN)
    }
    list[#list + 1] = {
        id = "watchServer", x = px + pw - 110, y = l.panel.y + 330, w = 110, h = 56,
        press = function() join(menu, menu.settings.server, "Watching " .. menu.settings.server, { spectate = true }) end
    }
    list[#list + 1] = {
        id = "connect", x = px, y = l.panel.y + 330, w = pw - 122, h = 56,
        press = function() join(menu, menu.settings.server, "Connecting to " .. menu.settings.server) end
    }
    return list
end

--- @param game table
--- @return string
local function describe(game)
    local parts = {}
    local mode = game.mode and Config.modes[game.mode]
    if mode then parts[#parts + 1] = mode.name end
    if game.map then parts[#parts + 1] = Maps.get(game.map).name end
    if game.phase == "playing" or game.phase == "over" then
        parts[#parts + 1] = "in progress"
    elseif game.phase then
        parts[#parts + 1] = "warming up"
    end
    if game.watchers and game.watchers > 0 then parts[#parts + 1] = game.watchers .. " watching" end
    if #parts == 0 then return game.address end
    return table.concat(parts, "  -  ")
end

--- @param menu table
--- @param x number
--- @param y number
--- @param w number
--- @param alpha number
local function drawEmpty(menu, x, y, w, alpha)
    local now = love.timer.getTime()
    local source = menu.settings.browseSource
    local browser = GM.Multiplayer.browser
    local dots = string.rep(".", math.floor(now * 2) % 4)
    local title, body
    if source == 3 then
        title = "Searching your network" .. dots
        body = "Games hosted from Play > Host a game on your network appear here by themselves. Both computers need to be on the same network, and UDP ports 6788 and 6789 must be open."
    elseif not sourceAddress(menu) then
        title = "No server address"
        body = "Type the address of your server in the panel on the right."
    elseif browser.error then
        title = browser.error
        body = browser.connected and "" or "Trying again in a moment."
    elseif not browser.loaded then
        title = "Asking " .. sourceAddress(menu) .. dots
        body = ""
    else
        title = "No game right now"
        body = "Open one from Play > Host a game and pick " .. (source == 1 and "Official server" or "Your server") .. ". Players can join it while it runs."
    end
    Kit.text(title, 15, x, y, Kit.INK, 0.6 * alpha)
    Common.paragraph(body, 13, x, y + 32, w, Kit.INK, 0.45 * alpha)
end

function Multiplayer.draw(menu, elements, p)
    local l = layout()
    Common.header(menu, elements, p, "Multiplayer", "Join a game on a server or on your network, even one that already started.")

    local e = menu:stagger(p, 2)
    local box = l.list
    local bx = box.x - (1 - e) * 30
    local dx = bx - box.x
    Kit.card(bx, box.y, box.w, box.h, e, 18)
    Kit.text("Games", 18, bx + 22, box.y + 18, Kit.INK, e)
    local address = sourceAddress(menu)
    if address then Kit.text(address, 12, bx + box.w - 22, box.y + 22, Kit.INK, 0.45 * e, "right") end
    local source = menu.find(elements, "source")
    Kit.segments("mp:source", source.x + dx, source.y, source.w, source.h, SOURCES, menu.settings.browseSource, e)

    local shown = 0
    for _, element in ipairs(elements) do
        if element.game then
            shown = shown + 1
            local game = element.game
            local hot = Kit.ease("mp:" .. element.id, menu.focus == element.id)
            local full = game.max > 0 and game.players >= game.max
            local y = element.y
            local x = element.x + dx
            love.graphics.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], (0.04 + 0.05 * hot) * e)
            love.graphics.rectangle("fill", x, y, element.w, element.h, 10, 10)
            Kit.dot(x + 20, y + element.h / 2, 5, full and Kit.AMBER or Kit.GREEN, e)
            local nw = Kit.text(game.name, 16, x + 36 + hot * 4, y + 7, Kit.INK, e)
            if game.locked then
                Kit.text("Password", 11, x + 46 + nw + hot * 4, y + 10, Kit.AMBER, e)
            end
            Kit.text(describe(game), 12, x + 36 + hot * 4, y + 28, Kit.INK, 0.45 * e)
            local count = game.max > 0 and string.format("%d / %d", game.players, game.max) or tostring(game.players)
            Kit.text(count .. (full and "  -  Watch" or "  -  Join"), 13, x + element.w - 16, y + 16, full and Kit.AMBER or Kit.INK, (0.5 + 0.5 * hot) * e, "right")
        end
    end
    if shown == 0 then drawEmpty(menu, bx + 22, box.y + 112, box.w - 44, e) end

    e = menu:stagger(p, 3)
    local panel = l.panel
    local py = panel.y + (1 - e) * 30
    Kit.card(panel.x, py, panel.w, panel.h, e, 18)
    Kit.text("Connect to a server", 18, panel.x + 22, py + 18, Kit.INK, e)
    local name = menu.find(elements, "name")
    local server = menu.find(elements, "server")
    local password = menu.find(elements, "password")
    local connect = menu.find(elements, "connect")
    local dy = py - panel.y
    Kit.text("Your name", 12, name.x, name.y - 20 + dy, Kit.INK, 0.5 * e)
    Kit.field("name", name.x, name.y + dy, name.w, name.h, menu.settings.name, "Player", menu.editing == "name", menu.focus == "name", e)
    Kit.text("Server address", 12, server.x, server.y - 20 + dy, Kit.INK, 0.5 * e)
    Kit.field("server", server.x, server.y + dy, server.w, server.h, menu.settings.server, "localhost:6789", menu.editing == "server", menu.focus == "server", e)
    Kit.text("Game password", 12, password.x, password.y - 20 + dy, menu.notice and Kit.AMBER or Kit.INK, (menu.notice and 1 or 0.5) * e)
    if menu.notice then
        Kit.text(menu.notice, 12, password.x + password.w, password.y - 20 + dy, Kit.AMBER, e, "right")
    end
    Kit.field("password", password.x, password.y + dy, password.w, password.h, string.rep("*", #menu.settings.password), "Only for locked games", menu.editing == "password", menu.focus == "password", e)
    Kit.button("connect", connect.x, connect.y + dy, connect.w, connect.h, "Connect", { hot = menu.focus == "connect", primary = true, size = 18, hint = "Enter", alpha = e })
    local watch = menu.find(elements, "watchServer")
    Kit.button("watchServer", watch.x, watch.y + dy, watch.w, watch.h, "Watch", { hot = menu.focus == "watchServer", size = 15, align = "center", alpha = e, arrow = false })
    local hintY = connect.y + dy + connect.h + 24
    Common.paragraph("Connect puts you in any open game of that server. Run a dedicated server with  love . --server  or the Docker image, then type its address here.", 13, name.x, hintY, name.w, Kit.INK, 0.45 * e)
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
