local GM = require("src.core.index")
local Config = require("src.config.game")
local WeaponConfig = require("src.config.weapons")
local Weapons = require("src.game.weapons")

local Hud = {}
Hud.__index = Hud

local Kit = require("src.ui.kit")

local min, max, sin, pi = math.min, math.max, math.sin, math.pi

local INK, RED, GREEN, AMBER = Kit.INK, Kit.RED, Kit.GREEN, Kit.AMBER

local MARGIN = 24
local FEED_LIFE = 4.5
local HELP_SECONDS = 7
local DAMAGE_LIFE = 1.1
local NOISE_LIFE = 1.4

local font, approach, clamp = Kit.font, Kit.approach, Kit.clamp
local easeOutCubic, easeOutBack, pop = Kit.easeOutCubic, Kit.easeOutBack, Kit.pop
local color, card, text, keycap = Kit.color, Kit.card, Kit.text, Kit.keycap
local measureHint, hint, bar, ring, dot = Kit.measureHint, Kit.hint, Kit.bar, Kit.ring, Kit.dot

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
        reserve = 0,
        gain = 0,
        gainAt = -10,
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
        board = 0,
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

    if me.weapon == self.weapon and me.reserve > self.reserve then
        self.gain, self.gainAt = me.reserve - self.reserve, now
    end
    self.reserve = me.reserve
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
    local holding = love.keyboard and love.keyboard.isScancodeDown("tab") and not session:paused()
    self.board = approach(self.board, holding and 1 or 0, 14, dt)
    if world.rules.teams then
        for team = 1, 2 do
            local value = world.teamScore[team] or 0
            if self.scores["team" .. team] and value > self.scores["team" .. team] then self.scoreAt["team" .. team] = now end
            self.scores["team" .. team] = value
        end
    end
    self.overlay = approach(self.overlay, session.captured and 0 or 1, 10, dt)
    local showHelp = self.helpOpen or now < self.helpUntil
    self.help = approach(self.help, showHelp and 1 or 0, 9, dt)
end

function Hud:drawStatus(session)
    local mp = GM.Multiplayer
    local now = love.timer.getTime()
    local room = session.room
    local duel = room and #room.players >= 2
    local rules = session.world and session.world.rules
    local label = duel and (rules and rules.name or "Duel") or "Waiting for an opponent"
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

local function scoreNumber(hud, value, cx, cy, key, c, size)
    local s = pop(hud.scoreAt[key] or -10, 0.45)
    local lg = love.graphics
    lg.push()
    lg.translate(cx, cy)
    lg.scale(s, s)
    local f = font(size or 30)
    lg.setFont(f)
    color(c, 1)
    lg.print(tostring(value), -f:getWidth(tostring(value)) / 2, -f:getHeight() / 2)
    lg.pop()
end

function Hud:drawScore(session)
    local world = session.world
    local W = love.graphics.getWidth()
    local rules = world.rules
    local w = 320
    local x = (W - w) / 2
    local limit = "First to " .. rules.scoreLimit

    if rules.teams then
        local mine = world.team or 1
        local other = mine == 1 and 2 or 1
        card(x, MARGIN, w, 70, 1, 16)
        text("Your team", 14, x + 18, MARGIN + 10, Kit.ALLY, 0.9)
        text("Enemy team", 14, x + w - 18, MARGIN + 10, RED, 0.85, "right")
        text(limit, 11, x, MARGIN + 12, INK, 0.4, "center", w)
        scoreNumber(self, world.teamScore[mine] or 0, x + 70, MARGIN + 46, "team" .. mine, Kit.ALLY)
        text(":", 24, x + w / 2 - 4, MARGIN + 30, INK, 0.3)
        scoreNumber(self, world.teamScore[other] or 0, x + w - 70, MARGIN + 46, "team" .. other, RED)
        return
    end

    local standings = session:standings()
    if #standings < 2 then return end
    if world.mode == "duel" then
        local theirs
        for _, entry in ipairs(standings) do
            if not entry.me then theirs = entry end
        end
        card(x, MARGIN, w, 70, 1, 16)
        text("You", 14, x + 18, MARGIN + 10, INK, 0.55)
        text(theirs.name, 14, x + w - 18, MARGIN + 10, RED, 0.8, "right")
        text(limit, 11, x, MARGIN + 12, INK, 0.4, "center", w)
        scoreNumber(self, world.score[world.slot] or 0, x + 70, MARGIN + 46, world.slot, INK)
        text(":", 24, x + w / 2 - 4, MARGIN + 30, INK, 0.3)
        scoreNumber(self, theirs.kills, x + w - 70, MARGIN + 46, theirs.slot, RED)
        return
    end

    local rank, leader = 1, standings[1]
    for k, entry in ipairs(standings) do
        if entry.me then rank = k end
    end
    local suffix = rank == 1 and "st" or rank == 2 and "nd" or rank == 3 and "rd" or "th"
    card(x, MARGIN, w, 70, 1, 16)
    text(rank .. suffix .. " of " .. #standings, 14, x + 18, MARGIN + 10, INK, 0.55)
    text(limit, 11, x + w - 18, MARGIN + 12, INK, 0.4, "right")
    scoreNumber(self, world.score[world.slot] or 0, x + 46, MARGIN + 46, world.slot, INK)
    local lead = leader.me and "You lead" or (leader.name .. "  " .. leader.kills)
    text(lead, 16, x + w - 18, MARGIN + 36, leader.me and INK or RED, 0.85, "right")
end

function Hud:drawBoard(session)
    if self.board < 0.01 then return end
    local W, H = love.graphics.getDimensions()
    local world = session.world
    local a = self.board
    local list = session:standings()
    local rowH = 34
    local w = 460
    local h = 84 + #list * rowH
    local x, y = (W - w) / 2, math.max(110, (H - h) / 2) + (1 - easeOutCubic(a)) * 14
    card(x, y, w, h, a, 18)
    text(world.rules.name, 20, x + 22, y + 18, INK, a)
    text("First to " .. world.rules.scoreLimit, 13, x + w - 22, y + 22, INK, 0.5 * a, "right")
    text("Kills", 12, x + w - 22, y + 52, INK, 0.45 * a, "right")
    for k, entry in ipairs(list) do
        local ry = y + 70 + (k - 1) * rowH
        if entry.me then
            love.graphics.setColor(INK[1], INK[2], INK[3], 0.05 * a)
            love.graphics.rectangle("fill", x + 12, ry - 4, w - 24, rowH - 4, 8, 8)
        end
        local c = (entry.me or session:friendly(entry.slot)) and (entry.me and INK or Kit.ALLY) or RED
        text(tostring(k), 14, x + 22, ry + 3, INK, 0.4 * a)
        dot(x + 52, ry + 12, 5, c, a)
        local nw = text(entry.name, 15, x + 66, ry + 2, INK, a)
        if entry.bot then
            text("BOT", 10, x + 74 + nw, ry + 6, INK, 0.4 * a)
        end
        text(tostring(entry.kills), 16, x + w - 22, ry + 2, INK, a, "right")
    end
end

function Hud:drawMatchOver(session)
    local over = session.world.over
    self.overShown = approach(self.overShown or 0, over and 1 or 0, 8, love.timer.getDelta())
    if self.overShown < 0.01 then return end
    local W, H = love.graphics.getDimensions()
    local a = self.overShown
    local world = session.world
    local title, won
    if over then
        if over.tm == 1 then
            won = over.w == world.team
            title = won and "Your team wins" or "Your team lost"
        else
            won = over.w == world.slot
            title = won and "You win" or (session:nameOf(over.w) .. " wins")
        end
        self.overTitle, self.overWon, self.overTimer = title, won, over.c
    end
    love.graphics.setColor(0.96, 0.97, 0.98, 0.6 * a)
    love.graphics.rectangle("fill", 0, 0, W, H)
    local t = easeOutBack(a)
    local y = H * 0.28 + (1 - t) * 20
    text(self.overTitle or "", 52, 0, y, self.overWon and INK or RED, a, "center", W)
    text("Next match in " .. math.ceil((self.overTimer or 0) / 60), 18, 0, y + 74, INK, 0.6 * a, "center", W)
    self.board = math.max(self.board, a)
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
    local slide = ready and session:canSlide()
    text(slide and "Slide" or "Dash", 13, x + 18, y + 70, INK, slide and 0.9 or 0.5)
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
    local nameWidth = text(def.name:lower():gsub("^%l", string.upper), 13, x + 18, y + 14, INK, 0.5)
    if def.tag and me.reload == 0 then
        local tagSize = 11
        local available = w - 36 - nameWidth - 12
        local tag = def.tag
        while #tag > 4 and font(tagSize):getWidth(tag) > available do
            tag = tag:sub(1, -6) .. "..."
        end
        text(tag, tagSize, x + w - 18, y + 16, def.exposed and RED or INK, 0.55, "right")
    end
    local empty = me.ammo == 0
    local ammoStr = tostring(me.ammo)
    local aw = text(ammoStr, 34, x + 18, y + 30 - (1 - refill) * 6, empty and RED or INK, 0.4 + 0.6 * refill)
    local rw = text("/ " .. me.reserve, 16, x + 26 + aw, y + 46, INK, me.reserve == 0 and 0.3 or 0.5)
    local gained = (now - self.gainAt) / 1.2
    if gained < 1 then
        text("+" .. self.gain, 16, x + 34 + aw + rw, y + 46 - 14 * easeOutCubic(gained), GREEN, 1 - gained)
    end

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
        { "Space", "While running: slide, you can shoot" },
        { "C", "Walk quietly" },
        { "R", "Reload" },
        { "G", "Throw your weapon" },
        { "E", "Swap with a weapon on the floor" },
        { "Tab", "Hold for the scoreboard" },
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
        if mp.error or status == "offline" then
            label = (mp.error or "Disconnected") .. "  -  Esc for the menu"
        end
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
    if o > 0.01 and session.world and not session:paused() then
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
        self:drawMatchOver(session)
        self:drawBoard(session)
        self:drawStatus(session)
        self:drawHelp()
    end
    self:drawOverlay(session)
end

return Hud
