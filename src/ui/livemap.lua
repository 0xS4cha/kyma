local GM = require("src.core.index")
local Kit = require("src.ui.kit")
local Minimap = require("src.ui.minimap")
local Vision = require("src.game.vision")
local Settings = require("src.modules.menu.settings")

--- Mini-map en jeu (HUD) : terrain + joueurs en temps réel.
--- Entièrement pilotée par les réglages "minimap*" (menu Settings > Mini-map).
local Livemap = {}

local BASE_W, BASE_H = 240, 170
local SIZE_FACTOR = { 0.6, 0.8, 1, 1.3, 1.65 }
local PAD = 8
local MARGIN = 24
local CARD_H = 112      -- hauteur des cartes du bas (vie / arme)
local GADGET_H = 40 + 12

--- @return table
local function options()
    local s = GM.Menu and GM.Menu.settings
    return s or Settings.defaults()
end

--- @param opt table
--- @return boolean
function Livemap.enabled(opt)
    return (opt or options()).minimap ~= false
end

--- Zone utile de la carte (hors cadre) en pixels.
local function mapBox(arena, opt)
    local f = SIZE_FACTOR[opt.minimapSize] or 1
    local maxW, maxH = BASE_W * f, BASE_H * f
    -- Le mode rotation recentre toujours sur le joueur.
    if opt.minimapView == 2 or opt.minimapRotate then
        return maxW, maxH
    end
    local scale = math.min(maxW / arena.width, maxH / arena.height)
    return arena.width * scale, arena.height * scale
end

--- Taille totale occupée (cadre compris).
--- @param session table
--- @return number, number
function Livemap.size(session)
    local mw, mh = mapBox(session.world.arena, options())
    return mw + PAD * 2, mh + PAD * 2
end

--- Position et taille du cadre à l'écran, selon le coin choisi.
--- @param session table
--- @return number? x, number? y, number? w, number? h
function Livemap.box(session)
    local opt = options()
    if not Livemap.enabled(opt) or not session.world then return nil end
    local w, h = Livemap.size(session)
    local W, H = love.graphics.getDimensions()
    local pos = opt.minimapPos or 1
    local left = pos == 1 or pos == 2
    local top = pos == 1 or pos == 3
    local x = left and MARGIN or (W - MARGIN - w)
    local y
    if top then
        y = MARGIN
    else
        y = H - MARGIN - CARD_H - 12 - h
        -- à droite, la carte se place au-dessus de la carte gadget
        if not left then y = y - GADGET_H end
    end
    return x, y, w, h
end

local function arrow(x, y, angle, r, c, alpha)
    local ca, sa = math.cos(angle), math.sin(angle)
    Kit.color(c, alpha)
    love.graphics.polygon("fill",
        x + ca * r, y + sa * r,
        x - ca * r * 0.6 - sa * r * 0.7, y - sa * r * 0.6 + ca * r * 0.7,
        x - ca * r * 0.6 + sa * r * 0.7, y - sa * r * 0.6 - ca * r * 0.7)
end

--- Dessine le cône de vision (et le halo proche) dans l'espace "monde x scale".
local function drawVision(arena, me, scale, alpha)
    local lg = love.graphics
    local cone, near = Vision.fans(arena, me.x, me.y, me.angle)
    local c = Kit.INK
    lg.setColor(c[1], c[2], c[3], 0.12 * alpha)
    for _, fan in ipairs({ cone, near }) do
        for k = 3, #fan - 3, 2 do
            lg.polygon("fill", fan[1] * scale, fan[2] * scale, fan[k] * scale, fan[k + 1] * scale, fan[k + 2] * scale, fan[k + 3] * scale)
        end
    end
    -- liseré du cône pour mieux lire la direction
    lg.setColor(c[1], c[2], c[3], 0.3 * alpha)
    lg.setLineWidth(1)
    local n = #cone
    lg.line(cone[1] * scale, cone[2] * scale, cone[3] * scale, cone[4] * scale)
    lg.line(cone[1] * scale, cone[2] * scale, cone[n - 1] * scale, cone[n] * scale)
end

--- @param session table  la session de jeu (session.world, session:opponents())
--- @param x number?      coin haut-gauche du cadre (par défaut : Livemap.box)
--- @param y number?
function Livemap.draw(session, x, y)
    local world = session.world
    local arena = world.arena
    local opt = options()
    local lg = love.graphics
    if not x then
        x, y = Livemap.box(session)
        if not x then return end
    end

    local alpha = Settings.MAP_OPACITY[opt.minimapOpacity] or 1
    local me = world.me
    local mw, mh = mapBox(arena, opt)
    local follow = (opt.minimapView == 2 or opt.minimapRotate) and me ~= nil
    local scale

    if follow then
        local span = Settings.MAP_SPANS[opt.minimapZoom] or 800
        scale = mw / span
    else
        scale = math.min(mw / arena.width, mh / arena.height)
    end

    -- 1) cadre
    Kit.card(x, y, mw + PAD * 2, mh + PAD * 2, alpha, 10)
    local ox, oy = x + PAD, y + PAD

    -- 2) contenu (clippé dans le cadre)
    local sx, sy, sw, sh = lg.getScissor()
    lg.intersectScissor(ox, oy, mw, mh)
    lg.push()
    if follow then
        lg.translate(ox + mw / 2, oy + mh / 2)
        if opt.minimapRotate then
            -- le joueur regarde toujours vers le haut
            lg.rotate(-math.pi / 2 - me.angle)
        end
        lg.translate(-me.x * scale, -me.y * scale)
    else
        lg.translate(ox, oy)
    end

    Minimap.draw(arena, 0, 0, arena.width * scale, arena.height * scale, alpha, { loot = opt.minimapLoot, spawns = false })

    if opt.minimapVision and me and me.dead == 0 then
        drawVision(arena, me, scale, alpha)
    end

    -- alliés (toujours visibles) et ennemis repérés ("spotted")
    local ok, list = pcall(session.opponents, session)
    for _, p in ipairs(ok and list or {}) do
        if p.dead == 0 then
            if p.ally then
                if opt.minimapAllies then arrow(p.x * scale, p.y * scale, p.angle, 5, Kit.ALLY, alpha) end
            elseif opt.minimapEnemies and (p.spotted or world.spectator) then
                Kit.dot(p.x * scale, p.y * scale, 4, Kit.RED, alpha)
            end
        end
    end

    -- le joueur local : flèche + halo
    if me and me.dead == 0 then
        local mx, my = me.x * scale, me.y * scale
        Kit.dot(mx, my, 9, Kit.RED, 0.25 * alpha)
        arrow(mx, my, me.angle, 6, Kit.INK, alpha)
    end

    lg.pop()
    if sx then lg.setScissor(sx, sy, sw, sh) else lg.setScissor() end

    -- 3) repère "N" quand la carte tourne : montre où est le haut du monde
    if opt.minimapRotate and me then
        local cx, cy = ox + mw / 2, oy + mh / 2
        local a = -math.pi - me.angle -- direction du "haut du monde" à l'écran
        local r = math.min(mw, mh) / 2 - 10
        local nx, ny = cx + math.cos(a) * r, cy + math.sin(a) * r
        Kit.dot(nx, ny, 7, Kit.INK, 0.12 * alpha)
        Kit.text("N", 11, nx - 10, ny - 7, Kit.INK, 0.7 * alpha, "center", 20)
    end
end

return Livemap
