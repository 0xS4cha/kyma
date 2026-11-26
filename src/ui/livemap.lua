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
local SCAN_H = 40 + 10  -- carte du scan, au-dessus de la carte gadget
local GameConfig = require("src.config.game")

--- Un scan est en cours : la mini-map s'affiche même si elle est désactivée.
--- @param session table
--- @return boolean
function Livemap.scanning(session)
    local world = session.world
    if not world then return false end
    if world.scanAt and love.timer.getTime() - world.scanAt < GameConfig.scan.sweep + 0.3 then return true end
    return world.scans ~= nil and next(world.scans) ~= nil
end

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
    if not session.world or (not Livemap.enabled(opt) and not Livemap.scanning(session)) then return nil end
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
        if not left then y = y - GADGET_H - SCAN_H end
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

    -- scan : un anneau part du joueur, et chaque ennemi apparaît en point rouge
    -- quand l'anneau l'atteint (le son "blip" part au même moment).
    local now = love.timer.getTime()
    local sweep = GameConfig.scan.sweep
    if world.scanAt and me and now - world.scanAt < sweep + 0.3 then
        local t = math.min(1, (now - world.scanAt) / sweep)
        local r = GameConfig.scan.radius * scale * (1 - (1 - t) ^ 2)
        local fade = 1 - math.max(0, (now - world.scanAt - sweep) / 0.3)
        lg.setColor(Kit.RED[1], Kit.RED[2], Kit.RED[3], 0.12 * fade * alpha)
        lg.circle("fill", me.x * scale, me.y * scale, r)
        lg.setLineWidth(2)
        lg.setColor(Kit.RED[1], Kit.RED[2], Kit.RED[3], 0.85 * fade * alpha)
        lg.circle("line", me.x * scale, me.y * scale, r)
        lg.setLineWidth(1)
    end
    if world.scans then
        local pulse = 0.7 + 0.3 * math.sin(now * 10)
        -- en mode "Follow me", les points hors du cadre restent collés au bord
        local edgeR = follow and (math.min(mw, mh) / 2 - 5) or nil
        for _, dot in pairs(world.scans) do
            if now >= dot.born then
                local fade = math.max(0, math.min(1, (dot.ends - now) / 0.6))
                local age = now - dot.born
                local grow = Kit.easeOutBack(math.min(1, age / 0.22))
                local px, py = dot.x * scale, dot.y * scale
                if edgeR and me then
                    local dx, dy = px - me.x * scale, py - me.y * scale
                    local d = math.sqrt(dx * dx + dy * dy)
                    if d > edgeR then px, py = me.x * scale + dx / d * edgeR, me.y * scale + dy / d * edgeR end
                end
                if age < 0.4 then
                    local k = age / 0.4
                    lg.setColor(Kit.RED[1], Kit.RED[2], Kit.RED[3], (1 - k) * alpha)
                    lg.circle("line", px, py, 4 + 10 * k)
                end
                Kit.dot(px, py, 7 * grow, Kit.RED, 0.25 * fade * alpha)
                Kit.dot(px, py, 4 * grow, Kit.RED, pulse * fade * alpha)
            end
        end
    end

    -- pings (les miens et ceux de mon équipe) : losange + onde, avec le nom de l'arme / objet
    local pings = session.effects and session.effects.pings
    if opt.minimapPings ~= false and pings and #pings > 0 then
        local Effects = require("src.modules.session.effects")
        local now = love.timer.getTime()
        for _, ping in ipairs(pings) do
            local age = now - ping.time
            local fade = age > Effects.PING_LIFE - 1 and math.max(0, Effects.PING_LIFE - age) or 1
            local c = Effects.pingColor(ping)
            local px, py = ping.x * scale, ping.y * scale
            local k = (age * 1.2) % 1
            lg.push()
            lg.translate(px, py)
            if follow and opt.minimapRotate then lg.rotate(math.pi / 2 + me.angle) end -- texte toujours droit
            lg.setLineWidth(1.5)
            lg.setColor(c[1], c[2], c[3], (1 - k) * 0.8 * fade * alpha)
            lg.circle("line", 0, 0, 5 + 10 * k)
            lg.setLineWidth(1)
            lg.setColor(0.05, 0.07, 0.1, 0.6 * fade * alpha)
            lg.polygon("fill", 0, -8, 8, 0, 0, 8, -8, 0)
            lg.setColor(c[1], c[2], c[3], fade * alpha)
            lg.polygon("fill", 0, -6, 6, 0, 0, 6, -6, 0)
            if ping.label and ping.label ~= "" then
                Kit.text(ping.label, 11, -45, 9, c, fade * alpha, "center", 90)
            end
            lg.pop()
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
