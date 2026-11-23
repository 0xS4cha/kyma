local GM = require("src.core.index")
local Config = require("src.config.game")
local WeaponConfig = require("src.config.weapons")
local Weapons = require("src.game.weapons")

local Hud = {}
Hud.__index = Hud

local exp, min, max, sin, floor, pi = math.exp, math.min, math.max, math.sin, math.floor, math.pi

local INK = { 0.1, 0.11, 0.13 }
local RED = { 0.88, 0.14, 0.12 }
local GREEN = { 0.22, 0.68, 0.4 }
local AMBER = { 0.92, 0.6, 0.12 }
local CARD = { 1, 1, 1 }

local MARGIN = 24
local RADIUS = 12
local FEED_LIFE = 4.5
local HELP_SECONDS = 7
local DAMAGE_LIFE = 1.1
local NOISE_LIFE = 1.4

local fonts = {}

local function font(size)
    if not fonts[size] then
        fonts[size] = love.graphics.newFont(size)
    end
    return fonts[size]
end

local function approach(current, target, rate, dt)
    return current + (target - current) * (1 - exp(-rate * dt))
end

local function clamp(v, a, b)
    return max(a, min(b, v))
end

local function easeOutCubic(t)
    t = clamp(t, 0, 1)
    return 1 - (1 - t) ^ 3
end

local function easeOutBack(t)
    t = clamp(t, 0, 1)
    local c = 1.70158
    return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

local function pop(since, duration)
    local t = (love.timer.getTime() - since) / (duration or 0.35)
    if t < 0 or t > 1 then return 1 end
    return 1 + 0.25 * sin(t * pi) * (1 - t)
end

local function color(c, alpha)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (alpha or 1))
end

local function card(x, y, w, h, alpha, radius)
    local lg = love.graphics
    radius = radius or RADIUS
    lg.setColor(0.05, 0.07, 0.1, 0.1 * alpha)
    lg.rectangle("fill", x, y + 3, w, h, radius, radius)
    lg.setColor(CARD[1], CARD[2], CARD[3], 0.92 * alpha)
    lg.rectangle("fill", x, y, w, h, radius, radius)
end

local function text(str, size, x, y, c, alpha, align, width)
    local lg = love.graphics
    local f = font(size)
    lg.setFont(f)
    color(c, alpha)
    if align == "center" then
        x = x + ((width or 0) - f:getWidth(str)) / 2
    elseif align == "right" then
        x = x - f:getWidth(str)
    end
    lg.print(str, floor(x + 0.5), floor(y + 0.5))
    return f:getWidth(str)
end

local function keycap(label, x, y, alpha, size)
    local lg = love.graphics
    size = size or 14
    local f = font(size)
    local w = max(f:getWidth(label) + 14, size + 12)
    local h = size + 12
    lg.setColor(INK[1], INK[2], INK[3], 0.08 * alpha)
    lg.rectangle("fill", x, y + 2, w, h, 6, 6)
    lg.setColor(1, 1, 1, alpha)
    lg.rectangle("fill", x, y, w, h, 6, 6)
    lg.setColor(INK[1], INK[2], INK[3], 0.35 * alpha)
    lg.setLineWidth(1.5)
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 6, 6)
    lg.setLineWidth(1)
    text(label, size, x, y + 5, INK, alpha, "center", w)
    return w, h
end

local function measureHint(key, label, size)
    local f = font(size)
    return max(font(size - 2):getWidth(key) + 14, size + 10) + 10 + f:getWidth(label)
end

local function hint(key, label, x, y, alpha, size, c)
    size = size or 16
    local w = keycap(key, x, y, alpha, size - 2)
    text(label, size, x + w + 10, y + 4, c or INK, alpha)
end

local function bar(x, y, w, h, fill, c, alpha, ghost)
    local lg = love.graphics
    lg.setColor(INK[1], INK[2], INK[3], 0.08 * alpha)
    lg.rectangle("fill", x, y, w, h, h / 2, h / 2)
    if ghost and ghost > fill then
        lg.setColor(1, 0.8, 0.75, alpha)
        lg.rectangle("fill", x, y, w * clamp(ghost, 0, 1), h, h / 2, h / 2)
    end
    if fill > 0 then
        color(c, alpha)
        lg.rectangle("fill", x, y, max(h, w * clamp(fill, 0, 1)), h, h / 2, h / 2)
    end
end

local function ring(x, y, radius, fill, width, c, alpha)
    local lg = love.graphics
    lg.setLineWidth(width)
    lg.setColor(INK[1], INK[2], INK[3], 0.1 * alpha)
    lg.circle("line", x, y, radius)
    if fill > 0 then
        color(c, alpha)
        lg.arc("line", "open", x, y, radius, -pi / 2, -pi / 2 + 2 * pi * clamp(fill, 0, 1), 48)
    end
    lg.setLineWidth(1)
end

local function dot(x, y, r, c, alpha)
    color(c, alpha)
    love.graphics.circle("fill", x, y, r)
end

--- @return table
function Hud.new()
    return setmetatable({
        hp = Config.health,
        ghost = Config.health,
        ghostAt = 0,
        charge = 1,
        readyAt = -10,
        scores = {},
        scoreAt = {},
        weapon = nil,
        ammo = 0,
        spent = {},
        refillAt = -10,
        prompt = 0,
        promptText = nil,
        death = 0,
        overlay = 0,
        help = 0,
        helpUntil = 0,
        helpOpen = false,
        joinedAt = -10,
        feed = {},
        damage = {},
        noises = {},
        connecting = 1
    }, Hud)
end

function Hud:joined()
    local now = love.timer.getTime()
    self.joinedAt = now
    self.helpUntil = now + HELP_SECONDS
end

function Hud:toggleHelp()
    self.helpOpen = not self.helpOpen
    self.helpUntil = 0
end

--- @param killer string?
--- @param victim string
--- @param mine boolean
--- @param me boolean
function Hud:announce(killer, victim, mine, me)
    self.feed[#self.feed + 1] = { killer = killer, victim = victim, mine = mine, me = me, time = love.timer.getTime() }
    if #self.feed > 4 then table.remove(self.feed, 1) end
end

--- @param px number
--- @param py number
--- @param sx number
--- @param sy number
function Hud:damageFrom(px, py, sx, sy)
    self.damage[#self.damage + 1] = { angle = math.atan2(sy - py, sx - px), time = love.timer.getTime() }
end

--- @param x number
--- @param y number
--- @param kind string
function Hud:noise(x, y, kind)
    self.noises[#self.noises + 1] = { x = x, y = y, kind = kind, time = love.timer.getTime() }
    if #self.noises > 12 then table.remove(self.noises, 1) end
end

--- @param session table
--- @param dt number
function Hud:update(session, dt)
    local now = love.timer.getTime()
    local world = session.world
    self.connecting = approach(self.connecting, world and 0 or 1, 10, dt)
    for k = #self.feed, 1, -1 do
        if now - self.feed[k].time > FEED_LIFE then table.remove(self.feed, k) end
    end
    for k = #self.damage, 1, -1 do
        if now - self.damage[k].time > DAMAGE_LIFE then table.remove(self.damage, k) end
    end
    for k = #self.noises, 1, -1 do
        if now - self.noises[k].time > NOISE_LIFE then table.remove(self.noises, k) end
    end
    if not world then return end
    local me = world.me

    if me.hp < self.hp - 0.5 then
        self.ghostAt = now + 0.35
    end
    self.hp = approach(self.hp, me.hp, 22, dt)
    if me.hp > self.ghost then
        self.ghost = me.hp
    elseif now >= self.ghostAt then
        self.ghost = approach(self.ghost, me.hp, 7, dt)
    end

    local charge = session:dashCharge()
    if charge >= 1 and self.charge < 1 then self.readyAt = now end
    self.charge = charge

    for slot, kills in pairs(world.score) do
        if self.scores[slot] and kills > self.scores[slot] then self.scoreAt[slot] = now end
        self.scores[slot] = kills
    end

    if me.weapon ~= self.weapon then
        self.weapon, self.spent, self.refillAt = me.weapon, {}, now
    elseif me.ammo < self.ammo then
        for k = me.ammo + 1, self.ammo do self.spent[k] = now end
    elseif me.ammo > self.ammo then
        self.spent, self.refillAt = {}, now
    end
    self.ammo = me.ammo

    local item = session:nearbyItem()
    local promptText
    if item and me.weapon and me.dead == 0 then
        local def = WeaponConfig[Weapons.unpack(item.k) or ""]
        promptText = def and ("Swap for " .. def.name:lower():gsub("^%l", string.upper)) or nil
    end
    if promptText then self.promptText = promptText end
    self.prompt = approach(self.prompt, promptText and 1 or 0, 14, dt)

    self.death = approach(self.death, me.dead > 0 and 1 or 0, 8, dt)
    self.overlay = approach(self.overlay, session.captured and 0 or 1, 10, dt)
    local showHelp = self.helpOpen or now < self.helpUntil
    self.help = approach(self.help, showHelp and 1 or 0, 9, dt)
end

function Hud:drawStatus(session)
    local mp = GM.Multiplayer
    local now = love.timer.getTime()
    local room = session.room
    local duel = room and #room.players >= 2
    local label = duel and "Duel" or "Waiting for an opponent"
    local w = font(16):getWidth(label) + 46
    card(MARGIN, MARGIN, w, 36, 1, 18)
    local pulse = duel and 1 or 0.45 + 0.55 * (0.5 + 0.5 * sin(now * 4))
    dot(MARGIN + 20, MARGIN + 18, 5, duel and RED or AMBER, pulse)
    text(label, 16, MARGIN + 34, MARGIN + 8, INK, 1)

    local hx = MARGIN
    local hy = MARGIN + 46
    hint("H", "Controls", hx, hy, 0.75 * (1 - self.help), 14, { INK[1], INK[2], INK[3], 0.6 })

    local ping = mp:Ping()
    if ping and not mp.isLocal then
        local W = love.graphics.getWidth()
        local quality = ping < 60 and GREEN or ping < 130 and AMBER or RED
        local str = ping .. " ms"
        local pw = font(14):getWidth(str) + 40
        card(W - MARGIN - pw, MARGIN, pw, 30, 1, 15)
        dot(W - MARGIN - pw + 16, MARGIN + 15, 4, quality, 1)
        text(str, 14, W - MARGIN - pw + 28, MARGIN + 7, INK, 0.8)
    end
end

function Hud:drawScore(session)
    local world = session.world
    local W = love.graphics.getWidth()
    local slots = {}
    for slot in pairs(world.score) do slots[#slots + 1] = slot end
    table.sort(slots, function(a, b)
        if a == world.slot then return true end
        if b == world.slot then return false end
        return a < b
    end)
    if #slots == 0 then return end

    local mine = world.score[world.slot] or 0
    local theirs, theirName = nil, nil
    for _, slot in ipairs(slots) do
        if slot ~= world.slot then
            theirs, theirName = world.score[slot] or 0, session:nameOf(slot)
        end
    end
    if not theirName then return end
    local leftName = "You"
    local w = 300
    local x = (W - w) / 2
    card(x, MARGIN, w, 64, 1, 16)
    text(leftName, 14, x + 18, MARGIN + 10, INK, 0.55)
    text(theirName, 14, x + w - 18, MARGIN + 10, RED, 0.8, "right")

    local function number(value, cx, slot, c)
        local s = pop(self.scoreAt[slot] or -10, 0.45)
        local lg = love.graphics
        lg.push()
        lg.translate(cx, MARGIN + 42)
        lg.scale(s, s)
        local f = font(30)
        lg.setFont(f)
        color(c, 1)
        lg.print(tostring(value), -f:getWidth(tostring(value)) / 2, -f:getHeight() / 2)
        lg.pop()
    end
    number(mine, x + 70, world.slot, INK)
    text(":", 24, x + w / 2 - 4, MARGIN + 26, INK, 0.3)
    number(theirs, x + w - 70, slots[2], RED)
end

function Hud:drawVitals(session)
    local world = session.world
    local me = world.me
    local H = love.graphics.getHeight()
    local w, h = 300, 112
    local x, y = MARGIN, H - MARGIN - h
    card(x, y, w, h, 1)

    local hp = clamp(self.hp / Config.health, 0, 1)
    local low = me.hp <= 34
    local c = low and RED or INK
    text("Health", 13, x + 18, y + 14, INK, 0.5)
    local value = tostring(math.ceil(max(0, self.hp - 0.01)))
    text(value, 30, x + w - 18, y + 6, c, 1, "right")
    local pulse = low and me.hp > 0 and (0.75 + 0.25 * sin(love.timer.getTime() * 8)) or 1
    bar(x + 18, y + 44, w - 36, 10, hp, low and RED or INK, pulse, self.ghost / Config.health)

    if session.world.quiet then
        local qw = font(12):getWidth("Quiet") + 20
        card(x + w - qw, y - 32, qw, 24, 1, 12)
        text("Quiet", 12, x + w - qw + 10, y - 27, INK, 0.7)
    end

    local ready = self.charge >= 1
    text("Dash", 13, x + 18, y + 70, INK, 0.5)
    local s = pop(self.readyAt, 0.4)
    local lg = love.graphics
    lg.push()
    lg.translate(x + 64, y + 82)
    lg.scale(s, s)
    lg.translate(-(x + 64), -(y + 82))
    bar(x + 64, y + 78, w - 64 - 18 - 74, 8, self.charge, ready and INK or { INK[1], INK[2], INK[3], 0.35 }, 1)
    lg.pop()
    if ready then
        keycap("Space", x + w - 18 - 64, y + 70, 1, 12)
    else
        text(string.format("%.1fs", (1 - self.charge) * Config.dash.cooldown / Config.tickRate), 13, x + w - 18, y + 70, INK, 0.45, "right")
    end
end

function Hud:drawWeapon(session)
    local me = session.world.me
    local W, H = love.graphics.getDimensions()
    local now = love.timer.getTime()
    local def = Weapons.def(me.weapon)
    local w, h = 300, 112
    local x, y = W - MARGIN - w, H - MARGIN - h
    card(x, y, w, h, 1)

    if not def then
        text("Unarmed", 22, x + 18, y + 18, INK, 0.9)
        text("Walk over a weapon to pick it up", 13, x + 18, y + 54, INK, 0.5)
        return
    end

    local refill = easeOutCubic((now - self.refillAt) / 0.35)
    text(def.name:lower():gsub("^%l", string.upper), 13, x + 18, y + 14, INK, 0.5)
    local empty = me.ammo == 0
    local ammoStr = tostring(me.ammo)
    local aw = text(ammoStr, 34, x + 18, y + 30 - (1 - refill) * 6, empty and RED or INK, 0.4 + 0.6 * refill)
    text("/ " .. me.reserve, 16, x + 26 + aw, y + 46, INK, me.reserve == 0 and 0.3 or 0.5)

    local count = def.magazine
    local area = w - 36
    local gap = count > 12 and 2 or 4
    local pw = min(10, (area - gap * (count - 1)) / count)
    local px = x + 18
    local py = y + 86
    local lg = love.graphics
    for k = 1, count do
        local loaded = k <= me.ammo
        local spent = self.spent[k]
        local alpha, lift = loaded and 1 or 0.12, 0
        if not loaded and spent then
            local t = (now - spent) / 0.3
            if t < 1 then
                alpha = 0.12 + 0.88 * (1 - easeOutCubic(t))
                lift = -8 * easeOutCubic(t)
            end
        end
        if loaded and refill < 1 then
            alpha = alpha * clamp(refill * 1.4 - (k / count) * 0.4, 0, 1)
        end
        lg.setColor(INK[1], INK[2], INK[3], alpha)
        lg.rectangle("fill", px + (k - 1) * (pw + gap), py + lift, pw, 12, 2, 2)
    end

    local right = x + w - 18
    if me.reload > 0 then
        local progress = 1 - me.reload / def.reloadTicks
        ring(right - 22, y + 46, 18, progress, 4, INK, 1)
        text("Reloading", 13, right - 50, y + 14, INK, 0.6, "right")
    elseif empty and me.reserve == 0 then
        local iw = measureHint("G", "Throw it", 14)
        hint("G", "Throw it", right - iw, y + 38, 1, 14, RED)
    elseif me.ammo <= def.magazine * 0.25 and me.reserve > 0 then
        local iw = measureHint("R", "Reload", 14)
        local blink = 0.55 + 0.45 * sin(now * 6)
        hint("R", "Reload", right - iw, y + 38, blink, 14)
    end
end

function Hud:drawPrompt()
    if self.prompt < 0.01 or not self.promptText then return end
    local W, H = love.graphics.getDimensions()
    local t = easeOutBack(self.prompt)
    local label = self.promptText
    local w = measureHint("E", label, 16) + 32
    local x = (W - w) / 2
    local y = H - MARGIN - 112 - 64 + (1 - t) * 16
    card(x, y, w, 44, self.prompt, 22)
    hint("E", label, x + 16, y + 9, self.prompt, 16)
end

function Hud:drawFeed()
    local W = love.graphics.getWidth()
    local now = love.timer.getTime()
    local y = MARGIN + 44
    for _, entry in ipairs(self.feed) do
        local age = now - entry.time
        local enter = easeOutCubic(age / 0.3)
        local fade = clamp((FEED_LIFE - age) / 0.5, 0, 1)
        local alpha = enter * fade
        local left = entry.killer or ""
        local right = entry.victim
        local size = 15
        local lw = left ~= "" and font(size):getWidth(left) or 0
        local rw = font(size):getWidth(right)
        local w = lw + rw + (left ~= "" and 52 or 30)
        local x = W - MARGIN - w + (1 - enter) * 40
        card(x, y, w, 32, alpha, 16)
        local cx = x + 14
        if left ~= "" then
            text(left, size, cx, y + 7, entry.mine and INK or RED, alpha)
            cx = cx + lw + 8
            love.graphics.setColor(INK[1], INK[2], INK[3], 0.4 * alpha)
            love.graphics.polygon("fill", cx, y + 11, cx + 8, y + 16, cx, y + 21)
            cx = cx + 16
        end
        text(right, size, cx, y + 7, entry.me and INK or RED, alpha * (left ~= "" and 0.55 or 1))
        y = y + 40 * enter
    end
end

function Hud:drawDamage(session)
    if #self.damage == 0 then return end
    local camera = session.camera
    local ax, ay = camera:anchor()
    local now = love.timer.getTime()
    local lg = love.graphics
    for _, d in ipairs(self.damage) do
        local t = (now - d.time) / DAMAGE_LIFE
        local a = d.angle + camera:rotation()
        lg.setLineWidth(6)
        color(RED, (1 - t) * 0.9)
        lg.arc("line", "open", ax, ay, 70 * camera.scale / 1.6, a - 0.35, a + 0.35, 24)
    end
    lg.setLineWidth(1)
end

function Hud:drawNoises(session)
    if #self.noises == 0 then return end
    local W, H = love.graphics.getDimensions()
    local camera = session.camera
    local ax, ay = camera:anchor()
    local now = love.timer.getTime()
    local inset = 56
    local lg = love.graphics
    for _, noise in ipairs(self.noises) do
        local sx, sy = camera:toScreen(noise.x, noise.y)
        if sx < inset or sx > W - inset or sy < inset or sy > H - inset then
            local dx, dy = sx - ax, sy - ay
            local scale = math.huge
            if dx > 0 then scale = min(scale, (W - inset - ax) / dx) end
            if dx < 0 then scale = min(scale, (inset - ax) / dx) end
            if dy > 0 then scale = min(scale, (H - inset - ay) / dy) end
            if dy < 0 then scale = min(scale, (inset - ay) / dy) end
            local px, py = ax + dx * scale, ay + dy * scale
            local angle = math.atan2(dy, dx)
            local t = (now - noise.time) / NOISE_LIFE
            local c = noise.kind == "shot" and RED or INK
            local size = noise.kind == "shot" and 12 or 9
            lg.push()
            lg.translate(px, py)
            lg.rotate(angle)
            color(c, (1 - t) * 0.85)
            lg.polygon("fill", size, 0, -size * 0.7, size * 0.75, -size * 0.3, 0, -size * 0.7, -size * 0.75)
            lg.pop()
        end
    end
end

function Hud:drawDeath(session)
    if self.death < 0.01 then return end
    local W, H = love.graphics.getDimensions()
    local me = session.world.me
    local a = self.death
    love.graphics.setColor(0.96, 0.97, 0.98, 0.55 * a)
    love.graphics.rectangle("fill", 0, 0, W, H)
    local t = easeOutBack(a)
    local y = H * 0.3 + (1 - t) * 20
    text("Eliminated", 48, 0, y, RED, a, "center", W)
    local seconds = me.dead / Config.tickRate
    local progress = 1 - me.dead / Config.respawnTicks
    if me.dead > 0 then
        ring(W / 2, y + 112, 26, progress, 5, INK, a)
        text(tostring(math.ceil(seconds)), 22, W / 2 - 40, y + 99, INK, a, "center", 80)
        text("Respawning", 14, 0, y + 150, INK, 0.55 * a, "center", W)
    end
end

function Hud:drawHelp()
    if self.help < 0.01 then return end
    local W, H = love.graphics.getDimensions()
    local a = self.help
    local rows = {
        { "W A S D", "Move" },
        { "Mouse", "Aim and turn" },
        { "Left click", "Fire" },
        { "Space", "Dash, dodges bullets" },
        { "C", "Walk quietly" },
        { "R", "Reload" },
        { "G", "Throw your weapon" },
        { "E", "Swap with a weapon on the floor" },
        { "H", "Show or hide controls" }
    }
    local w, rowH = 360, 34
    local h = 64 + #rows * rowH
    local x = MARGIN
    local y = (H - h) / 2 + (1 - easeOutCubic(a)) * 12
    card(x, y, w, h, a, 16)
    text("Controls", 18, x + 20, y + 18, INK, a)
    for k, row in ipairs(rows) do
        local ry = y + 52 + (k - 1) * rowH
        local kw = keycap(row[1], x + 20, ry, a, 12)
        text(row[2], 14, x + 30 + max(kw, 92), ry + 4, INK, 0.75 * a)
    end
end

function Hud:drawOverlay(session)
    local W, H = love.graphics.getDimensions()
    local now = love.timer.getTime()
    local c = self.connecting
    if c > 0.01 then
        local status = session.status
        local mp = GM.Multiplayer
        local label = mp.error or (status == "queued" and "Looking for a room" or "Connecting")
        local w, h = 360, 120
        local x, y = (W - w) / 2, (H - h) / 2
        love.graphics.setColor(0.93, 0.95, 0.97, c)
        love.graphics.rectangle("fill", 0, 0, W, H)
        if session.world then return end
        card(x, y, w, h, c, 18)
        text("Kyma", 14, x, y + 20, INK, 0.45 * c, "center", w)
        text(label, 20, x + 20, y + 46, mp.error and RED or INK, c, "center", w - 40)
        if not mp.error then
            local lg = love.graphics
            lg.setLineWidth(3)
            color(INK, c)
            local start = now * 5
            lg.arc("line", "open", W / 2, y + 94, 10, start, start + pi * 1.3, 24)
            lg.setLineWidth(1)
        end
        return
    end

    local o = self.overlay
    if o > 0.01 and session.world then
        love.graphics.setColor(0.93, 0.95, 0.97, 0.6 * o)
        love.graphics.rectangle("fill", 0, 0, W, H)
        local w, h = 340, 96
        local x = (W - w) / 2
        local y = H * 0.4 + (1 - easeOutCubic(o)) * 16
        card(x, y, w, h, o, 18)
        text("Click to play", 22, x, y + 20, INK, o, "center", w)
        local hw = measureHint("Esc", "Quit", 14)
        hint("Esc", "Quit", x + (w - hw) / 2, y + 56, 0.7 * o, 14)
    end
end

--- @param session table
function Hud:draw(session)
    if session.world then
        self:drawDamage(session)
        self:drawNoises(session)
        self:drawScore(session)
        self:drawVitals(session)
        self:drawWeapon(session)
        self:drawPrompt()
        self:drawFeed()
        self:drawDeath(session)
        self:drawStatus(session)
        self:drawHelp()
    end
    self:drawOverlay(session)
end

return Hud
