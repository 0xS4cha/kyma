local GM = require("src.core.index")
local Kit = require("src.ui.kit")
local Minimap = require("src.ui.minimap")
local Common = require("src.modules.menu.screens.common")
local Settings = require("src.modules.menu.settings")
local Rules = require("src.modules.menu.screens.rules")
local Config = require("src.config.game")
local Maps = require("src.maps.index")
local Bracket = require("src.game.bracket")

local Screen = {}

local SERVERS = { "Official server", "Your server" }
local ROW = 74

local function layout()
    local W, H = love.graphics.getDimensions()
    local M = Common.margin()
    local gap = 32
    local right = math.min(420, math.floor(W * 0.3))
    local left = math.min(700, W - M * 2 - right - gap)
    return { M = M, H = H, left = { x = M, w = left }, right = { x = M + left + gap, w = right }, y = 150 }
end

local function modeNames()
    local out = {}
    for _, id in ipairs(Config.modes.order) do out[#out + 1] = Config.modes[id].name end
    return out
end

local function sizeNames()
    local out = {}
    for k, size in ipairs(Bracket.SIZES) do out[k] = size .. " players" end
    return out
end

local function bestOfNames()
    local out = {}
    for k, count in ipairs(Bracket.BEST_OF) do out[k] = count == 1 and "One game" or ("Best of " .. count) end
    return out
end

--- @param menu table
--- @return string
local function address(menu)
    if menu.settings.tournamentServer == 2 and menu.settings.server ~= "" then return menu.settings.server end
    return GM.Multiplayer:OfficialAddress()
end

--- @param menu table
--- @return string
local function mapId(menu)
    local rules = Config.modes[Settings.gameMode(menu.settings)]
    return Maps.valid(rules.map or menu.settings.map)
end

--- @param menu table
local function create(menu)
    local s = menu.settings
    local name = s.tournamentName ~= "" and s.tournamentName or nil
    menu:saveSettings()
    menu:Play({
        mode = "tournament", address = address(menu), label = "Opening your tournament",
        request = {
            a = "create", name = name, mode = Settings.gameMode(s), map = mapId(menu),
            size = Bracket.SIZES[s.tournamentSize], bestOf = Bracket.BEST_OF[s.tournamentBestOf],
            rules = Settings.matchRules(s)
        }
    })
end

--- @param menu table
local function browse(menu)
    menu:saveSettings()
    menu:Play({ mode = "tournament", address = address(menu), label = "Looking for tournaments", request = { a = "list" } })
end

--- @param menu table
--- @param id string
--- @param key string
--- @param count number
--- @param x number
--- @param y number
--- @param w number
--- @return table
local function segments(menu, id, key, count, x, y, w)
    return {
        id = id, x = x, y = y, w = w, h = 40,
        press = function(_, mx)
            if mx then
                menu:setOption(key, Kit.clamp(math.floor((mx - x) / (w / count)) + 1, 1, count))
            else
                menu:setOption(key, menu.settings[key] % count + 1)
            end
        end,
        left = function() menu:setOption(key, math.max(1, menu.settings[key] - 1)) end,
        right = function() menu:setOption(key, math.min(count, menu.settings[key] + 1)) end
    }
end

--- @param menu table
--- @param step number
local function cycleMap(menu, step)
    local index = 1
    for k, id in ipairs(Maps.order) do
        if id == menu.settings.map then index = k end
    end
    menu:setOption("map", Maps.order[(index - 1 + step) % #Maps.order + 1])
end

function Screen.build(menu)
    local l = layout()
    local x, w, y = l.left.x, l.left.w, l.y
    local list = { Common.backElement(menu, function() menu:switch("root", -1) end) }
    list[#list + 1] = {
        id = "tournamentName", x = x, y = y, w = w, h = 44,
        press = function() menu.editing = "tournamentName" end,
        text = Common.textHandler(menu, "tournamentName", 32, Common.NAME_PATTERN)
    }
    list[#list + 1] = segments(menu, "tmode", "mode", #Config.modes.order, x, y + ROW, w)
    list[#list + 1] = {
        id = "tmap", x = x, y = y + ROW * 2, w = w, h = 40,
        press = function(_, mx)
            if mx and mx < x + w / 2 then cycleMap(menu, -1) else cycleMap(menu, 1) end
        end,
        left = function() cycleMap(menu, -1) end,
        right = function() cycleMap(menu, 1) end
    }
    list[#list + 1] = segments(menu, "tsize", "tournamentSize", #Bracket.SIZES, x, y + ROW * 3, w)
    list[#list + 1] = segments(menu, "tbest", "tournamentBestOf", #Bracket.BEST_OF, x, y + ROW * 4, w)
    list[#list + 1] = segments(menu, "tserver", "tournamentServer", #SERVERS, x, y + ROW * 5, w)
    list[#list + 1] = { id = "create", x = x, y = y + ROW * 6 + 20, w = w, h = 64, press = function() create(menu) end }

    local rx, rw = l.right.x, l.right.w
    list[#list + 1] = { id = "browse", x = rx + 22, y = y + 96, w = rw - 44, h = 52, press = function() browse(menu) end }
    list[#list + 1] = {
        id = "name", x = rx, y = y + 250, w = rw, h = 44,
        press = function() menu.editing = "name" end,
        text = Common.textHandler(menu, "name", 20, Common.NAME_PATTERN)
    }
    list[#list + 1] = {
        id = "server", x = rx, y = y + 250 + ROW, w = rw, h = 44,
        press = function() menu.editing = "server" end,
        text = Common.textHandler(menu, "server", 64, Common.SERVER_PATTERN)
    }
    return list
end

function Screen.draw(menu, elements, p)
    local l = layout()
    Common.header(menu, elements, p, "Tournaments", "Single elimination brackets on the official server or your own.")
    local find = menu.find
    local s = menu.settings
    local a = menu:stagger(p, 2)

    local name = find(elements, "tournamentName")
    Kit.text("Tournament name", 12, name.x, name.y - 20, Kit.INK, 0.5 * a)
    Kit.field("tournamentName", name.x, name.y, name.w, name.h, s.tournamentName, s.name .. "'s cup", menu.editing == "tournamentName", menu.focus == "tournamentName", a)

    local mode = find(elements, "tmode")
    Kit.text("Mode", 12, mode.x, mode.y - 20, Kit.INK, 0.5 * a)
    Kit.segments("tmode", mode.x, mode.y, mode.w, mode.h, modeNames(), s.mode, a)

    local map = find(elements, "tmap")
    local rules = Config.modes[Settings.gameMode(s)]
    local def = Maps.get(mapId(menu))
    local hot = Kit.ease("tmap", menu.focus == "tmap")
    Kit.text("Map", 12, map.x, map.y - 20, Kit.INK, 0.5 * a)
    love.graphics.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], (0.07 + 0.04 * hot) * a)
    love.graphics.rectangle("fill", map.x, map.y, map.w, map.h, map.h / 2, map.h / 2)
    local locked = rules.map ~= nil
    Kit.text(def.name .. (locked and "  (set by the mode)" or ""), 14, map.x, map.y + 11, Kit.INK, a, "center", map.w)
    if not locked then
        Kit.text("<", 16, map.x + 20, map.y + 10, Kit.INK, (0.35 + 0.5 * hot) * a)
        Kit.text(">", 16, map.x + map.w - 20, map.y + 10, Kit.INK, (0.35 + 0.5 * hot) * a, "right")
    end

    local size = find(elements, "tsize")
    Kit.text("Bracket size", 12, size.x, size.y - 20, Kit.INK, 0.5 * a)
    Kit.segments("tsize", size.x, size.y, size.w, size.h, sizeNames(), s.tournamentSize, a)

    local best = find(elements, "tbest")
    Kit.text("Each match", 12, best.x, best.y - 20, Kit.INK, 0.5 * a)
    Kit.segments("tbest", best.x, best.y, best.w, best.h, bestOfNames(), s.tournamentBestOf, a)

    local server = find(elements, "tserver")
    Kit.text("Hosted on", 12, server.x, server.y - 20, Kit.INK, 0.5 * a)
    Kit.segments("tserver", server.x, server.y, server.w, server.h, SERVERS, s.tournamentServer, a)
    Kit.text(address(menu), 12, server.x + server.w, server.y - 20, Kit.INK, 0.45 * a, "right")

    local e = menu:stagger(p, 3)
    local go = find(elements, "create")
    Kit.button("create", go.x, go.y, go.w, go.h, "Create tournament", { hot = menu.focus == "create", primary = true, size = 22, hint = "Enter", alpha = e })
    Common.paragraph("Players join from Browse tournaments. You start it once at least two are in, and empty seats become byes. Match rules: " .. Rules.summary(s) .. ".", 13, go.x, go.y + go.h + 16, go.w, Kit.INK, 0.5 * e)

    local ra = menu:stagger(p, 3)
    local r = l.right
    local browseEl = find(elements, "browse")
    local cy = l.y - 20
    Kit.card(r.x, cy, r.w, browseEl.y + browseEl.h + 22 - cy, ra, 16)
    Kit.text("Join a tournament", 18, r.x + 22, cy + 18, Kit.INK, ra)
    Common.paragraph("See the tournaments open on the selected server and take a seat.", 13, r.x + 22, cy + 50, r.w - 44, Kit.INK, 0.55 * ra)
    Kit.button("browse", browseEl.x, browseEl.y, browseEl.w, browseEl.h, "Browse tournaments", { hot = menu.focus == "browse", size = 16, alpha = ra })
    local preview = browseEl.y + browseEl.h + 40
    local field = find(elements, "name")
    Kit.text("Your name", 12, field.x, field.y - 20, Kit.INK, 0.5 * ra)
    Kit.field("name", field.x, field.y, field.w, field.h, s.name, "Player", menu.editing == "name", menu.focus == "name", ra)
    local own = find(elements, "server")
    Kit.text("Your server", 12, own.x, own.y - 20, Kit.INK, 0.5 * ra)
    Kit.field("server", own.x, own.y, own.w, own.h, s.server, "localhost:6789", menu.editing == "server", menu.focus == "server", ra)
    local mapY = own.y + own.h + 30
    local mapH = math.min(220, l.H - mapY - l.M)
    if mapH > 80 and preview < mapY then
        Kit.card(r.x, mapY, r.w, mapH, ra, 16)
        Minimap.draw(def, r.x + 12, mapY + 12, r.w - 24, mapH - 24, ra, { loot = false })
    end
end

function Screen.keyPressed(menu, key)
    if (key == "return" or key == "kpenter") and (not menu.focus or menu.editing == "tournamentName") then
        create(menu)
        return true
    end
    return false
end

function Screen.back(menu)
    menu:switch("root", -1)
end

return Screen
