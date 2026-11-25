local Kit = require("src.ui.kit")
local Minimap = require("src.ui.minimap")
local Common = require("src.modules.menu.screens.common")
local Settings = require("src.modules.menu.settings")
local Config = require("src.config.game")
local Maps = require("src.maps.index")
local Address = require("src.net.address")
local Rules = require("src.modules.menu.screens.rules")
local GM = require("src.core.index")

local Play = {}

local COLS = math.ceil(#Maps.order / 2)
local WHERE = { "Your network", "Official server" }

local function layout()
    local W, H = love.graphics.getDimensions()
    local M = Common.margin()
    local right = math.min(380, math.floor(W * 0.28))
    local gap = 28
    local leftW = W - M * 2 - right - gap
    local tileW = math.floor((leftW - (COLS - 1) * 12) / COLS)
    local tileH = math.floor(tileW * 0.62) + 26
    return {
        M = M, W = W, H = H,
        left = { x = M, w = leftW },
        right = { x = M + leftW + gap, w = right },
        modeY = 136,
        gridY = 236,
        tileW = tileW, tileH = tileH,
        detailY = 236 + 2 * (tileH + 12) + 6
    }
end

local function names(list, source)
    local out = {}
    for _, id in ipairs(list) do out[#out + 1] = source[id].name end
    return out
end

local function selectedMap(menu)
    local rules = Config.modes[Settings.gameMode(menu.settings)]
    return Maps.get(rules.map or menu.settings.map)
end

function Play.enter(menu)
    menu.lanAddress = Address.lan()
end

function Play.build(menu)
    local l = layout()
    local list = { Common.backElement(menu, function() menu:switch("root", -1) end) }
    local modes = #Config.modes.order
    list[#list + 1] = {
        id = "mode", x = l.left.x, y = l.modeY, w = math.min(520, l.left.w), h = 40,
        press = function(_, mx)
            if mx then
                local cell = math.min(520, l.left.w) / modes
                menu:setOption("mode", Kit.clamp(math.floor((mx - l.left.x) / cell) + 1, 1, modes))
            else
                menu:setOption("mode", menu.settings.mode % modes + 1)
            end
        end,
        left = function() menu:setOption("mode", math.max(1, menu.settings.mode - 1)) end,
        right = function() menu:setOption("mode", math.min(modes, menu.settings.mode + 1)) end
    }
    list[#list + 1] = {
        id = "rules", x = l.left.x, y = l.modeY + 50, w = math.min(560, l.left.w), h = 26,
        press = function() menu:switch("rules", 1) end
    }
    for k, id in ipairs(Maps.order) do
        local col, row = (k - 1) % COLS, math.floor((k - 1) / COLS)
        list[#list + 1] = {
            id = "map:" .. id, map = id,
            x = l.left.x + col * (l.tileW + 12), y = l.gridY + row * (l.tileH + 12), w = l.tileW, h = l.tileH,
            press = function() menu:setOption("map", id) end
        }
    end
    local rx, rw = l.right.x, l.right.w
    list[#list + 1] = {
        id = "name", x = rx, y = l.modeY, w = rw, h = 44,
        press = function() menu.editing = "name" end,
        text = Common.textHandler(menu, "name", 20, Common.NAME_PATTERN)
    }
    local levels = #Config.bots.order
    list[#list + 1] = {
        id = "level", x = rx + 20, y = l.gridY + 84, w = rw - 40, h = 36,
        press = function(_, mx)
            if mx then
                menu:setOption("bot", Kit.clamp(math.floor((mx - rx - 20) / ((rw - 40) / levels)) + 1, 1, levels))
            else
                menu:setOption("bot", menu.settings.bot % levels + 1)
            end
        end,
        left = function() menu:setOption("bot", math.max(1, menu.settings.bot - 1)) end,
        right = function() menu:setOption("bot", math.min(levels, menu.settings.bot + 1)) end
    }
    local watchW = 96
    list[#list + 1] = {
        id = "watch", x = rx + rw - 20 - watchW, y = l.gridY + 136, w = watchW, h = 50,
        press = function()
            local mode = Settings.gameMode(menu.settings)
            menu:Play({
                mode = "practice", spectate = true, bot = Settings.botLevel(menu.settings), game = mode, map = menu.settings.map,
                rules = Settings.matchRules(menu.settings),
                label = "Watching bots on " .. selectedMap(menu).name
            })
        end
    }
    list[#list + 1] = {
        id = "practice", x = rx + 20, y = l.gridY + 136, w = rw - 50 - watchW, h = 50,
        press = function()
            local mode = Settings.gameMode(menu.settings)
            menu:Play({
                mode = "practice", bot = Settings.botLevel(menu.settings), game = mode, map = menu.settings.map,
                rules = Settings.matchRules(menu.settings),
                label = Config.modes[mode].name .. " on " .. selectedMap(menu).name
            })
        end
    }
    list[#list + 1] = {
        id = "where", x = rx + 20, y = l.gridY + 266, w = rw - 40, h = 32,
        press = function(_, mx)
            if mx then
                menu:setOption("hostWhere", Kit.clamp(math.floor((mx - rx - 20) / ((rw - 40) / #WHERE)) + 1, 1, #WHERE))
            else
                menu:setOption("hostWhere", menu.settings.hostWhere % #WHERE + 1)
            end
        end,
        left = function() menu:setOption("hostWhere", 1) end,
        right = function() menu:setOption("hostWhere", #WHERE) end
    }
    list[#list + 1] = {
        id = "hostPassword", x = rx + 20, y = l.gridY + 330, w = rw - 40, h = 40,
        press = function() menu.editing = "hostPassword" end,
        text = Common.textHandler(menu, "hostPassword", 24, Common.PASSWORD_PATTERN)
    }
    list[#list + 1] = {
        id = "host", x = rx + 20, y = l.gridY + 382, w = rw - 40, h = 46,
        press = function()
            local password = menu.settings.hostPassword ~= "" and menu.settings.hostPassword or nil
            local options = {
                mode = "host", game = Settings.gameMode(menu.settings), map = menu.settings.map,
                rules = Settings.matchRules(menu.settings), password = password, label = "Opening your game"
            }
            if menu.settings.hostWhere == 2 then
                options.mode = "hostServer"
                options.address = GM.Multiplayer:OfficialAddress()
                options.label = "Opening your game on the official server"
            end
            menu:saveSettings()
            menu:Play(options)
        end
    }
    list[#list + 1] = {
        id = "join", x = rx, y = l.gridY + 452, w = rw, h = 50,
        press = function() menu:switch("multiplayer", 1) end
    }
    return list
end

local function drawTile(menu, element, alpha)
    local id = element.map
    local def = Maps.get(id)
    local selected = selectedMap(menu).id == id
    local hot = Kit.ease("tile:" .. id, menu.focus == element.id)
    local pick = Kit.ease("tilesel:" .. id, selected)
    local x, y, w, h = element.x, element.y - hot * 3, element.w, element.h
    Kit.card(x, y, w, h, alpha, 12, hot)
    Minimap.draw(def, x + 8, y + 8, w - 16, h - 36, alpha, { loot = false })
    Kit.text(def.name, 13, x + 10, y + h - 24, Kit.INK, alpha * (0.6 + 0.4 * pick))
    if pick > 0.01 then
        Kit.color(Kit.RED, pick * alpha)
        love.graphics.setLineWidth(2.5)
        love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2, 12, 12)
        love.graphics.setLineWidth(1)
    end
end

function Play.draw(menu, elements, p)
    local l = layout()
    Common.header(menu, elements, p, "Play", "Pick a mode and a map, then practice against bots or open a game.")
    local find = menu.find

    local a = menu:stagger(p, 2)
    local mode = find(elements, "mode")
    Kit.text("Mode", 12, mode.x, mode.y - 20, Kit.INK, 0.5 * a)
    Kit.segments("mode", mode.x, mode.y, mode.w, mode.h, names(Config.modes.order, Config.modes), menu.settings.mode, a)
    local rules = Config.modes[Settings.gameMode(menu.settings)]
    local summary = rules.ladder and (rules.text .. ", win with your fists.") or (rules.text .. ", first to " .. rules.scoreLimit .. ".")
    Common.paragraph(summary, 13, mode.x + mode.w + 18, mode.y + 2, l.left.w - mode.w - 18, Kit.INK, 0.55 * a)

    local chip = find(elements, "rules")
    local rhot = Kit.ease("rules:chip", menu.focus == "rules")
    local label = Rules.summary(menu.settings)
    local rw = Kit.text("Rules", 12, chip.x, chip.y + 6, Kit.RED, (0.8 + 0.2 * rhot) * a)
    local tw = Kit.text(label, 13, chip.x + rw + 10, chip.y + 5, Kit.INK, (0.55 + 0.35 * rhot) * a)
    Kit.color(Kit.INK, (0.3 + 0.5 * rhot) * a)
    love.graphics.setLineWidth(1.5)
    local ax = chip.x + rw + tw + 22 + rhot * 3
    love.graphics.line(ax - 3, chip.y + 9, ax + 1, chip.y + 13, ax - 3, chip.y + 17)
    love.graphics.setLineWidth(1)
    Kit.text("Map", 12, l.left.x, l.gridY - 20, Kit.INK, 0.5 * a)
    local k = 0
    for _, element in ipairs(elements) do
        if element.map then
            k = k + 1
            local e = menu:stagger(p, 3 + k * 0.4)
            drawTile(menu, element, e)
        end
    end

    local e = menu:stagger(p, 8)
    local def = selectedMap(menu)
    local dy = l.detailY + (1 - e) * 16
    local dh = math.max(120, l.H - dy - l.M)
    Kit.card(l.left.x, dy, l.left.w, dh, e, 16)
    local pw = math.min(320, math.floor(l.left.w * 0.36))
    Minimap.draw(def, l.left.x + 16, dy + 16, pw, dh - 32, e)
    local tx = l.left.x + pw + 36
    Kit.text(def.name, 24, tx, dy + 18, Kit.INK, e)
    Kit.text(def.width .. " x " .. def.height, 12, tx, dy + 52, Kit.INK, 0.45 * e)
    Common.paragraph(def.description, 14, tx, dy + 76, l.left.w - pw - 56, Kit.INK, 0.7 * e)
    local features = {}
    if #(def.doors or {}) > 0 then features[#features + 1] = { Kit.RED, #def.doors .. " doors" } end
    if #(def.glass or {}) > 0 then features[#features + 1] = { { 0.45, 0.68, 0.9 }, #def.glass .. " glass panes" } end
    if #(def.cover or {}) > 0 then features[#features + 1] = { { 0.6, 0.64, 0.7 }, #def.cover .. " low covers" } end
    if #(def.pits or {}) > 0 then features[#features + 1] = { { 0.3, 0.33, 0.38 }, "a chasm" } end
    features[#features + 1] = { Kit.INK, #def.loot .. " loot spots" }
    local fx = tx
    for _, feature in ipairs(features) do
        Kit.dot(fx + 5, dy + dh - 30, 5, feature[1], e)
        fx = fx + 18 + Kit.text(feature[2], 13, fx + 16, dy + dh - 38, Kit.INK, 0.7 * e) + 18
    end

    local r = l.right
    local ra = menu:stagger(p, 3)
    local name = find(elements, "name")
    Kit.text("Your name", 12, name.x, name.y - 20, Kit.INK, 0.5 * ra)
    Kit.field("name", name.x, name.y, name.w, name.h, menu.settings.name, "Player", menu.editing == "name", menu.focus == "name", ra)

    local cy = l.gridY + (1 - ra) * 20
    local practiceHot = Kit.ease("card:practice", menu.focus == "practice" or menu.focus == "level")
    Kit.card(r.x, cy - practiceHot * 3, r.w, 206, ra, 16, practiceHot)
    Kit.text("Practice", 20, r.x + 20, cy + 16 - practiceHot * 3, Kit.INK, ra)
    local bots = rules.players - 1
    Kit.text(bots == 1 and "Against one bot" or ("Against " .. bots .. " bots"), 13, r.x + 20, cy + 44 - practiceHot * 3, Kit.INK, 0.55 * ra)
    local level = find(elements, "level")
    Kit.text("Bot level", 11, level.x, level.y - 18 + (cy - l.gridY), Kit.INK, 0.45 * ra)
    Kit.segments("level", level.x, level.y + (cy - l.gridY), level.w, level.h, names(Config.bots.order, Config.bots), menu.settings.bot, ra)
    local practice = find(elements, "practice")
    Kit.button("practice", practice.x, practice.y + (cy - l.gridY), practice.w, practice.h, "Start practice", {
        hot = menu.focus == "practice", primary = true, size = 17, align = "center", alpha = ra
    })
    local watch = find(elements, "watch")
    Kit.button("watch", watch.x, watch.y + (cy - l.gridY), watch.w, watch.h, "Watch", {
        hot = menu.focus == "watch", size = 15, align = "center", alpha = ra, arrow = false
    })

    local hy = cy + 222
    local hostFocus = menu.focus == "host" or menu.focus == "where" or menu.focus == "hostPassword"
    local hostHot = Kit.ease("card:host", hostFocus)
    local lift = hostHot * 3
    local official = menu.settings.hostWhere == 2
    Kit.card(r.x, hy - lift, r.w, 216, ra, 16, hostHot)
    Kit.text("Host a game", 18, r.x + 20, hy + 14 - lift, Kit.INK, ra)
    local reach = official and "Listed in Multiplayer, anyone can join"
        or ("Friends join " .. (menu.lanAddress and (menu.lanAddress .. ":6789") or "- no network found"))
    Kit.text(reach, 12, r.x + r.w - 20, hy + 19 - lift, Kit.INK, 0.5 * ra, "right")
    local where = find(elements, "where")
    Kit.segments("play:where", where.x, where.y + (cy - l.gridY) - lift, where.w, where.h, WHERE, menu.settings.hostWhere, ra)
    local pass = find(elements, "hostPassword")
    Kit.text("Password, empty for an open game", 11, pass.x, pass.y - 17 + (cy - l.gridY) - lift, Kit.INK, 0.45 * ra)
    Kit.field("hostPassword", pass.x, pass.y + (cy - l.gridY) - lift, pass.w, pass.h, string.rep("*", #menu.settings.hostPassword), "No password",
        menu.editing == "hostPassword", menu.focus == "hostPassword", ra)
    local host = find(elements, "host")
    Kit.button("host", host.x, host.y + (cy - l.gridY) - lift, host.w, host.h, "Host " .. rules.name:lower() .. (official and " online" or ""), {
        hot = menu.focus == "host", size = 16, align = "center", alpha = ra, arrow = false
    })
    local join = find(elements, "join")
    Kit.button("join", join.x, join.y + (cy - l.gridY), join.w, join.h, "Join a game", {
        hot = menu.focus == "join", size = 16, alpha = ra
    })
end

function Play.back(menu)
    menu:switch("root", -1)
end

return Play
