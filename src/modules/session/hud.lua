local GM = require("src.core.index")
local Config = require("src.config.game")
local WeaponConfig = require("src.config.weapons")
local Weapons = require("src.game.weapons")
local Keys = require("src.input.keybinds")
local Loading = require("src.modules.session.loading")

local Hud = {}
Hud.__index = Hud

local Kit = require("src.ui.kit")
local GadgetConfig = require("src.config.gadgets")
local Livemap = require("src.ui.livemap")

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
    local holding = love.keyboard and Keys.down("scoreboard") and not session:paused() and not session.chat.open
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
    if room and room.tl and duel then
        label = room.tl .. "  -  " .. (rules and rules.name or "Duel")
    end
    if session.world and session.world.spectator then
        label = "Watching - " .. (rules and rules.name or "Duel")
    end
    local phase = session.world and session.world.phase
    if phase == "warmup" or phase == "countdown" then
        label = "Warmup - " .. (room and room.tl or (rules and rules.name or "Duel"))
    end
    local w = font(16):getWidth(label) + 46
    card(MARGIN, MARGIN, w, 36, 1, 18)
    local pulse = duel and 1 or 0.45 + 0.55 * (0.5 + 0.5 * sin(now * 4))
    dot(MARGIN + 20, MARGIN + 18, 5, duel and RED or AMBER, pulse)
    text(label, 16, MARGIN + 34, MARGIN + 8, INK, 1)

    local hx = MARGIN
    local hy = MARGIN + 46
    hint(Keys.label("help"), "Controls", hx, hy, 0.75 * (1 - self.help), 14, { INK[1], INK[2], INK[3], 0.6 })

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

--- @param title string
--- @param subtitle string
--- @param good boolean
function Hud:banner(title, subtitle, good)
    self.bannerData = { title = title, subtitle = subtitle, good = good, at = love.timer.getTime() }
end

function Hud:drawBanner()
    local b = self.bannerData
    if not b then return end
    local t = love.timer.getTime() - b.at
    if t > 3.2 then
        self.bannerData = nil
        return
    end
    local a = math.min(1, t / 0.2) * math.min(1, (3.2 - t) / 0.4)
    local W, H = love.graphics.getDimensions()
    local w = 520
    local x, y = (W - w) / 2, H * 0.24 + (1 - easeOutCubic(t / 0.3)) * 16
    card(x, y, w, 92, a, 18)
    text(b.title, 30, x, y + 14, b.good and Kit.ALLY or RED, a, "center", w)
    text(b.subtitle, 15, x, y + 58, INK, 0.65 * a, "center", w)
end

function Hud:drawRound(session)
    local world = session.world
    local round = world.round
    if not round or world.phase ~= "playing" then return end
    local W = love.graphics.getWidth()
    local w = 320
    local x, y = (W - w) / 2, MARGIN + 78
    local role = session:role()
    card(x, y, w, 40, 1, 12)
    local seconds = math.max(0, math.ceil(round.t / Config.tickRate))
    local clock = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    text("Round " .. round.n, 13, x + 16, y + 12, INK, 0.6)
    text(clock, 18, x, y + 9, seconds <= 15 and RED or INK, 1, "center", w)
    local label = role == "attack" and "Attack" or role == "defend" and "Defend" or ((round.a == 1 and "Blue" or "Red") .. " attacks")
    text(label, 13, x + w - 16, y + 12, role == "attack" and RED or Kit.ALLY, 0.9, "right")
    local hy = y + 48
    for k, objective in ipairs(world.arena.objectives or {}) do
        local progress = (round.h[k] or 0) / world.rules.hackTicks
        if progress > 0 then
            card(x, hy, w, 30, 1, 10)
            local warn = role ~= "attack"
            text((warn and "Terminal " or "Hacking ") .. objective.name, 13, x + 16, hy + 8, warn and RED or INK, 0.9)
            bar(x + 130, hy + 13, w - 150, 5, progress, RED, 1)
            hy = hy + 36
        end
    end
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
        text(world.spectator and "Blue team" or "Your team", 14, x + 18, MARGIN + 10, Kit.ALLY, 0.9)
        text(world.spectator and "Red team" or "Enemy team", 14, x + w - 18, MARGIN + 10, RED, 0.85, "right")
        text(limit, 11, x, MARGIN + 12, INK, 0.4, "center", w)
        scoreNumber(self, world.teamScore[mine] or 0, x + 70, MARGIN + 46, "team" .. mine, Kit.ALLY)
        text(":", 24, x + w / 2 - 4, MARGIN + 30, INK, 0.3)
        scoreNumber(self, world.teamScore[other] or 0, x + w - 70, MARGIN + 46, "team" .. other, RED)
        return
    end

    local standings = session:standings()
    if world.spectator then
        if #standings == 0 then return end
        card(x, MARGIN, w, 70, 1, 16)
        text(rules.name .. "  -  first to " .. rules.scoreLimit, 13, x + 18, MARGIN + 10, INK, 0.5)
        local first, second = standings[1], standings[2]
        local value = function(entry) return rules.ladder and ("Lv " .. math.min(#rules.ladder, entry.kills + 1)) or tostring(entry.kills) end
        text(first.name .. "  " .. value(first), 18, x + 18, MARGIN + 34, INK, 1)
        if second then text(second.name .. "  " .. value(second), 15, x + w - 18, MARGIN + 37, INK, 0.55, "right") end
        return
    end
    if rules.ladder then
        local level = math.min(#rules.ladder, (world.score[world.slot] or 0) + 1)
        local function label(step)
            local def = WeaponConfig[step]
            return def and (def.name:sub(1, 1) .. def.name:sub(2):lower()) or "Fists"
        end
        card(x, MARGIN, w, 70, 1, 16)
        text("Level " .. level .. " / " .. #rules.ladder, 14, x + 18, MARGIN + 10, INK, 0.55)
        local leader = standings[1]
        if leader and not leader.me then
            text(leader.name .. "  Lv " .. math.min(#rules.ladder, leader.kills + 1), 13, x + w - 18, MARGIN + 11, RED, 0.85, "right")
        elseif leader then
            text("You lead", 13, x + w - 18, MARGIN + 11, INK, 0.6, "right")
        end
        local s = pop(self.levelAt or -10, 0.5)
        local lg = love.graphics
        lg.push()
        lg.translate(x + 18, MARGIN + 46)
        lg.scale(s, s)
        local nw = text(label(rules.ladder[level]), 22, 0, -14, INK, 1)
        lg.pop()
        if level < #rules.ladder then
            text("next: " .. label(rules.ladder[level + 1]), 13, x + 26 + nw, MARGIN + 38, INK, 0.45)
        else
            text("strike to win", 13, x + 26 + nw, MARGIN + 38, RED, 0.8)
        end
        return
    end
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

function Hud:drawLobby(session)
    local world = session.world
    local W = love.graphics.getWidth()
    local now = love.timer.getTime()
    local start = now - (self.startAt or -10)
    if start < 1.2 then
        local t = start / 1.2
        local s = 1 + 0.3 * (1 - easeOutCubic(t * 3))
        local lg = love.graphics
        lg.push()
        lg.translate(W / 2, love.graphics.getHeight() * 0.3)
        lg.scale(s, s)
        text("Fight!", 64, -300, -40, RED, 1 - clamp((t - 0.6) / 0.4, 0, 1), "center", 600)
        lg.pop()
    end
    if world.phase == "playing" or world.over then return end
    if world.phase == "countdown" then
        local seconds = math.ceil(world.countdown / Config.tickRate)
        local fraction = (world.countdown % Config.tickRate) / Config.tickRate
        local lg = love.graphics
        lg.push()
        lg.translate(W / 2, 170)
        lg.scale(1 + 0.25 * fraction, 1 + 0.25 * fraction)
        text(tostring(seconds), 64, -100, -40, INK, 0.4 + 0.6 * fraction, "center", 200)
        lg.pop()
        text("Match starts", 15, 0, 214, INK, 0.6, "center", W)
        return
    end
    local players = session:standings()
    local w = 360
    local h = 108 + #players * 26
    local x, y = (W - w) / 2, 112
    card(x, y, w, h, 1, 16)
    text("Warmup", 20, x + 20, y + 16, INK, 1)
    text("Kills don't count yet", 12, x + w - 20, y + 22, INK, 0.45, "right")
    local mine = world.ready[world.slot]
    local readyKey = Keys.label("ready")
    local label = mine and ("Ready - press " .. readyKey .. " to cancel") or ("Press " .. readyKey .. " when you are ready")
    hint(readyKey, label, x + 20, y + 52, mine and 0.6 or (0.7 + 0.3 * sin(now * 4)), 14, mine and GREEN or INK)
    for k, entry in ipairs(players) do
        local ry = y + 92 + (k - 1) * 26
        local ready = entry.bot or world.ready[entry.slot]
        dot(x + 28, ry + 9, 5, ready and GREEN or INK, ready and 1 or 0.25)
        text(entry.name, 14, x + 42, ry, INK, ready and 0.9 or 0.5)
        text(entry.bot and "bot" or (ready and "ready" or "warming up"), 12, x + w - 20, ry + 2, ready and GREEN or INK, 0.6, "right")
    end
    if #players < 2 then
        text("Waiting for an opponent to start", 12, x + 20, y + h - 18, INK, 0.45)
    end
end

function Hud:drawChat(session)
    local chat = session.chat
    local H = love.graphics.getHeight()
    local now = love.timer.getTime()
    local x, bottom = MARGIN + self:leftShift(session, "bottom"), H - MARGIN - 112 - 16
    local w = 420
    local open = chat.open
    if open then
        local tag = chat.team and "Team" or "All"
        card(x, bottom - 40, w, 40, 1, 12)
        local tw = font(12):getWidth(tag) + 16
        love.graphics.setColor((chat.team and Kit.ALLY or INK)[1], (chat.team and Kit.ALLY or INK)[2], (chat.team and Kit.ALLY or INK)[3], 0.12)
        love.graphics.rectangle("fill", x + 10, bottom - 31, tw, 22, 6, 6)
        text(tag, 12, x + 18, bottom - 27, chat.team and Kit.ALLY or INK, 0.9)
        local tx, tw2 = x + 20 + tw, w - tw - 44
        if chat.text == "" then
            text("Say something", 15, tx, bottom - 30, INK, 0.35)
            if now % 1 < 0.55 then
                color(RED, 1)
                love.graphics.rectangle("fill", tx + 1, bottom - 30, 2, 19)
            end
        else
            Kit.editable("chat", chat.text, chat.edit or { cursor = #chat.text }, tx, bottom - 30, tw2, 15, INK, 1, { top = 0, height = 19 })
        end
        if session.world and session.world.rules.teams then
            text("Tab: " .. (chat.team and "all" or "team"), 11, x + w - 12, bottom - 26, INK, 0.4, "right")
        end
        bottom = bottom - 50
    end
    local y = bottom
    local count = 0
    for k = #chat.log, 1, -1 do
        local entry = chat.log[k]
        local age = now - entry.time
        local alpha = open and 1 or clamp((9 - age) / 1, 0, 1)
        if alpha > 0.01 then
            count = count + 1
            if count > (open and 10 or 6) then break end
            y = y - 24
            local name = entry.name .. (entry.team and " (team)" or "")
            local friendly = session.world and entry.slot and session:friendly(entry.slot)
            local c = entry.slot and session.world and entry.slot == session.world.slot and INK or (friendly and Kit.ALLY or RED)
            local nw = font(14):getWidth(name)
            local f = font(14)
            local body = entry.text
            while #body > 0 and f:getWidth(body) > w - nw - 30 do body = body:sub(1, -2) end
            love.graphics.setColor(Kit.SURFACE[1], Kit.SURFACE[2], Kit.SURFACE[3], 0.82 * alpha)
            love.graphics.rectangle("fill", x, y - 3, nw + f:getWidth(body) + 30, 22, 8, 8)
            text(name, 14, x + 10, y, c, alpha)
            text(body, 14, x + 20 + nw, y, INK, 0.85 * alpha)
        end
    end
end

function Hud:drawSpectator(session)
    local W, H = love.graphics.getDimensions()
    local p = session:followed()
    local w = 420
    local x, y = (W - w) / 2, H - MARGIN - 96
    card(x, y, w, 96, 1, 16)
    dot(x + 24, y + 26, 5, RED, love.timer.getTime() % 1.2 < 0.8 and 1 or 0.3)
    text("Spectating", 13, x + 36, y + 17, RED, 1)
    local watchers = session.room and session.room.watchers or 1
    text(watchers .. (watchers == 1 and " watcher" or " watchers"), 12, x + w - 20, y + 18, INK, 0.45, "right")
    if p then
        local def = Weapons.def(p.weapon)
        local weapon = def and (def.name:sub(1, 1) .. def.name:sub(2):lower()) or "Fists"
        local c = session.world.rules.teams and (p.team == 1 and Kit.ALLY or RED) or INK
        local nw = text(p.name or "?", 22, x + 20, y + 38, c, 1)
        text(weapon .. (p.hp and ("  -  " .. math.max(0, p.hp) .. " hp") or ""), 14, x + 30 + nw, y + 45, INK, 0.6)
    else
        text("Waiting for players", 18, x + 20, y + 40, INK, 0.6)
    end
    local hw = measureHint(Keys.label("turnLeft") .. " " .. Keys.label("turnRight"), "or click to switch player", 12)
    hint(Keys.label("turnLeft") .. " " .. Keys.label("turnRight"), "or click to switch player", x + (w - hw) / 2, y + 68, 0.7, 12)
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
    text(world.rules.ladder and "Level" or "Kills", 12, x + w - 22, y + 52, INK, 0.45 * a, "right")
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
        local value = world.rules.ladder and tostring(math.min(#world.rules.ladder, entry.kills + 1)) or tostring(entry.kills)
        text(value, 16, x + w - 22, ry + 2, INK, a, "right")
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
    love.graphics.setColor(Kit.PAPER[1], Kit.PAPER[2], Kit.PAPER[3], 0.6 * a)
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
        local dashKey = Keys.label("dash")
        keycap(dashKey, x + w - 18 - (font(12):getWidth(dashKey) + 14), y + 70, 1, 12)
    else
        text(string.format("%.1fs", (1 - self.charge) * Config.dash.cooldown / Config.tickRate), 13, x + w - 18, y + 70, INK, 0.45, "right")
    end
end

--- Emplacements de plaques de bouclier, juste sous la barre de vie (dans la carte "vitals").
function Hud:drawPlates(session)
    local options = session.world.options
    if options and options.shields == false then return end
    local me = session.world.me
    local lg = love.graphics
    local shield = Config.shield
    local armor = me.armor or 0
    local W = 300
    local x, y = MARGIN + 18, lg.getHeight() - MARGIN - 112 + 60
    local gap = 5
    local w, h = (W - 36 - gap * (shield.plates - 1)) / shield.plates, 6
    local blue = require("src.modules.session.shield").COLOR
    for i = 1, shield.plates do
        local px = x + (i - 1) * (w + gap)
        local f = clamp((armor - (i - 1) * shield.plateHp) / shield.plateHp, 0, 1)
        Kit.color(INK, 0.1)
        lg.rectangle("fill", px, y, w, h, 3, 3)
        if f > 0 then
            Kit.color(blue, 1)
            lg.rectangle("fill", px, y, w * f, h, 3, 3)
            if f < 0.5 then
                -- plaque abîmée : petite fissure
                lg.setColor(0.04, 0.09, 0.14, 0.9)
                lg.setLineWidth(1.2)
                lg.line(px + w * 0.55, y, px + w * 0.5, y + h * 0.5, px + w * 0.58, y + h)
                lg.setLineWidth(1)
            end
        else
            Kit.color(INK, 0.22)
            lg.rectangle("line", px + 0.5, y + 0.5, w - 1, h - 1, 3, 3)
        end
    end
end

function Hud:drawBlind(session)
    local blind = session.world.me.blind or 0
    if blind <= 0 or session.world.me.dead > 0 then return end
    local W, H = love.graphics.getDimensions()
    love.graphics.setColor(1, 1, 0.98, math.min(1, blind / 50) * 0.97)
    love.graphics.rectangle("fill", 0, 0, W, H)
end

function Hud:drawGadget(session)
    local me = session.world.me
    if not me.gadget or me.dead > 0 then return end
    local W, H = love.graphics.getDimensions()
    local def = GadgetConfig[me.gadget]
    local w, h = 300, 40
    local x, y = W - MARGIN - w, H - MARGIN - 112 - 12 - h
    local left = me.gadgets or 0
    card(x, y, w, h, 1, 12)
    local kw = measureHint(Keys.label("gadget"), def.name, 14)
    hint(Keys.label("gadget"), def.name, x + 14, y + 8, left > 0 and 1 or 0.35, 14)
    text(left > 0 and ("x" .. left) or "used", 13, x + w - 16, y + 12, left > 0 and INK or RED, left > 0 and 0.6 or 0.8, "right")
    return kw
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
        local melee = WeaponConfig.melee
        text("Unarmed", 22, x + 18, y + 16, INK, 0.9)
        text("Walk over a weapon to pick it up", 13, x + 18, y + 48, INK, 0.5)
        local ready = me.meleeCooldown == 0
        hint("Left click", "Strike: knocks their weapon out", x + 18, y + 72, ready and 1 or 0.45, 13)
        if not ready then
            bar(x + 18, y + h - 10, w - 36, 3, 1 - me.meleeCooldown / melee.cooldown, INK, 0.6)
        end
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
    local rw = text("/ " .. (me.reserve >= 999 and "∞" or me.reserve), 16, x + 26 + aw, y + 46, INK, me.reserve == 0 and 0.3 or 0.5)
    local gained = (now - self.gainAt) / 1.2
    if gained < 1 then
        text("+" .. self.gain, 16, x + 34 + aw + rw, y + 46 - 14 * easeOutCubic(gained), GREEN, 1 - gained)
    end

    local count = Weapons.stat(me, "magazine") or def.magazine
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
        local progress = 1 - me.reload / (Weapons.stat(me, "reloadTicks") or def.reloadTicks)
        ring(right - 22, y + 46, 18, progress, 4, INK, 1)
        text("Reloading", 13, right - 50, y + 14, INK, 0.6, "right")
    elseif empty and me.reserve == 0 and not Weapons.sidearm(me.weapon) then
        local iw = measureHint(Keys.label("throw"), "Throw it", 14)
        hint(Keys.label("throw"), "Throw it", right - iw, y + 38, 1, 14, RED)
    elseif me.ammo <= count * 0.25 and me.reserve > 0 then
        local iw = measureHint(Keys.label("reload"), "Reload", 14)
        local blink = 0.55 + 0.45 * sin(now * 6)
        hint(Keys.label("reload"), "Reload", right - iw, y + 38, blink, 14)
    end
end

function Hud:drawPrompt()
    if self.prompt < 0.01 or not self.promptText then return end
    local W, H = love.graphics.getDimensions()
    local t = easeOutBack(self.prompt)
    local label = self.promptText
    local w = measureHint(Keys.label("pickup"), label, 16) + 32
    local x = (W - w) / 2
    local y = H - MARGIN - 112 - 64 + (1 - t) * 16
    card(x, y, w, 44, self.prompt, 22)
    hint(Keys.label("pickup"), label, x + 16, y + 9, self.prompt, 16)
end

--- Top of the column on the right edge, below the ping and a top-right mini-map.
--- @param session table
--- @return number
function Hud:rightTop(session)
    local W = love.graphics.getWidth()
    local y = MARGIN + 44
    local mx, my, mw, mh = self:mapBox(session)
    if mx and my < 100 and mx > W / 2 then y = my + mh + 12 end -- carte en haut à droite
    return y
end

local STAT_SCALE = {
    fps = function(top) return max(top, 60) end,
    frame = function(top) return max(top, 34) end,
    tick = function(top) return max(top, Config.tickRate * 1.2) end,
    rtt = function(top) return max(top, 100) end,
    jitter = function(top) return max(top, 20) end,
    loss = function(top) return max(top, 5) end,
    down = function(top) return max(top * 1.2, 1) end,
    up = function(top) return max(top * 1.2, 1) end
}

--- @param stat string
--- @param value number?
--- @return string
local function statText(stat, value)
    if not value then return "-" end
    if stat == "fps" then return string.format("%d", value + 0.5) end
    if stat == "tick" then return string.format("%d /s", value + 0.5) end
    if stat == "rtt" then return string.format("%d ms", value + 0.5) end
    if stat == "frame" or stat == "jitter" then return string.format("%.1f ms", value) end
    if stat == "loss" then return string.format("%.1f%%", value) end
    return string.format("%.1f KB/s", value)
end

--- The color that says how healthy a value is, nil when it is fine.
--- @param stat string
--- @param value number?
--- @return table?
local function statQuality(stat, value)
    if not value then return nil end
    local bad, worse
    if stat == "fps" then bad, worse = value < 60, value < 30
    elseif stat == "frame" then bad, worse = value > 25, value > 50
    elseif stat == "tick" then bad, worse = value < Config.tickRate * 0.9, value < Config.tickRate * 0.75
    elseif stat == "rtt" then bad, worse = value >= 60, value >= 130
    elseif stat == "jitter" then bad, worse = value > 10, value > 25
    elseif stat == "loss" then bad, worse = value > 0.05, value > 2
    end
    return worse and RED or bad and AMBER or nil
end

--- @param list table history, false where there was no value
--- @param stat string
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param c table
local function sparkline(list, stat, x, y, w, h, c)
    local lg = love.graphics
    local count = require("src.net.netstats").HISTORY
    local top = 0
    for _, v in ipairs(list) do if v and v > top then top = v end end
    local scale = STAT_SCALE[stat](top)
    lg.setColor(INK[1], INK[2], INK[3], 0.06)
    lg.rectangle("fill", x, y, w, h, 4, 4)
    local step = w / (count - 1)
    local offset = count - #list
    local points = {}
    local function flush()
        if #points >= 4 then
            color(c, 0.85)
            lg.setLineWidth(1.5)
            lg.line(points)
            lg.setLineWidth(1)
        elseif #points == 2 then
            color(c, 0.85)
            lg.circle("fill", points[1], points[2], 1.5)
        end
        points = {}
    end
    for k, v in ipairs(list) do
        if v then
            points[#points + 1] = x + (offset + k - 1) * step
            points[#points + 1] = y + h - 2 - clamp(v / scale, 0, 1) * (h - 4)
        else
            flush()
        end
    end
    flush()
end

--- The performance stats chosen in Settings > Performance stats, in a card
--- on the right edge. Returns where the next element on that edge can go.
--- @param session table
--- @return number
function Hud:drawStats(session)
    local top = self:rightTop(session)
    local menu = GM.Menu and GM.Menu.settings
    local stats = GM.Multiplayer and GM.Multiplayer.stats
    if not menu or not stats then return top end
    local Settings = require("src.modules.menu.settings")
    local shown = {}
    local height = 16
    for _, def in ipairs(Settings.STATS) do
        local mode = menu[def.key] or 1
        if mode > 1 then
            local textRow, graph = mode == 2 or mode == 4, mode == 3 or mode == 4
            shown[#shown + 1] = { def = def, text = textRow, graph = graph }
            height = height + 20 + (graph and 30 or 0)
        end
    end
    if #shown == 0 then return top end
    local W = love.graphics.getWidth()
    local w = 220
    local x = W - MARGIN - w
    card(x, top, w, height, 0.92, 12)
    local y = top + 9
    for _, row in ipairs(shown) do
        local stat = row.def.stat
        local value = stats.values[stat]
        local quality = statQuality(stat, value)
        text(row.def.label, 12, x + 14, y + 3, INK, 0.55)
        if row.text then
            text(statText(stat, value), 14, x + w - 14, y + 1, quality or INK, quality and 1 or 0.9, "right")
        end
        y = y + 20
        if row.graph then
            sparkline(stats.history[stat] or {}, stat, x + 14, y, w - 28, 24, quality or INK)
            y = y + 30
        end
    end
    return top + height + 10
end

function Hud:drawFeed(session, from)
    local W = love.graphics.getWidth()
    local now = love.timer.getTime()
    local y = from or self:rightTop(session)
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

local function edge(session, x, y)
    local W, H = love.graphics.getDimensions()
    local camera = session.camera
    local ax, ay = camera:anchor()
    local inset = 56
    local sx, sy = camera:toScreen(x, y)
    if sx >= inset and sx <= W - inset and sy >= inset and sy <= H - inset then return nil end
    local dx, dy = sx - ax, sy - ay
    local scale = math.huge
    if dx > 0 then scale = min(scale, (W - inset - ax) / dx) end
    if dx < 0 then scale = min(scale, (inset - ax) / dx) end
    if dy > 0 then scale = min(scale, (H - inset - ay) / dy) end
    if dy < 0 then scale = min(scale, (inset - ay) / dy) end
    return ax + dx * scale, ay + dy * scale, math.atan2(dy, dx)
end

function Hud:drawSpotted(session)
    local lg = love.graphics
    local pulse = 0.6 + 0.4 * sin(love.timer.getTime() * 6)
    for _, p in ipairs(session:visibleOpponents()) do
        if p.marked then
            local px, py, angle = edge(session, p.x, p.y)
            if px then
                lg.push()
                lg.translate(px, py)
                lg.rotate(angle)
                color(RED, pulse)
                lg.setLineWidth(2)
                lg.circle("line", 0, 0, 11)
                lg.polygon("fill", 16, 0, 9, 5, 9, -5)
                lg.setLineWidth(1)
                lg.pop()
            end
        end
    end
end

--- Pings hors écran : flèche au bord de l'écran avec le nom de l'arme / objet.
function Hud:drawPings(session)
    local lg = love.graphics
    local Effects = require("src.modules.session.effects")
    local now = love.timer.getTime()
    for _, ping in ipairs(session.effects.pings) do
        local px, py, angle = edge(session, ping.x, ping.y)
        if px then
            local age = now - ping.time
            local fade = age > Effects.PING_LIFE - 1 and max(0, Effects.PING_LIFE - age) or 1
            local c = Effects.pingColor(ping)
            lg.push()
            lg.translate(px, py)
            lg.push()
            lg.rotate(angle)
            color(c, fade)
            lg.polygon("fill", 16, 0, 8, 6, 8, -6)
            lg.setLineWidth(2)
            lg.circle("line", 0, 0, 9)
            lg.setLineWidth(1)
            lg.pop()
            if ping.label and ping.label ~= "" then
                local w = font(13):getWidth(ping.label)
                local tx = clamp(-w / 2, -px + 8, love.graphics.getWidth() - px - w - 8)
                text(ping.label, 13, tx, py > love.graphics.getHeight() / 2 and -34 or 16, INK, fade)
            end
            lg.pop()
        end
    end
end

function Hud:drawNoises(session)
    if #self.noises == 0 then return end
    local now = love.timer.getTime()
    local lg = love.graphics
    for _, noise in ipairs(self.noises) do
        local px, py, angle = edge(session, noise.x, noise.y)
        if px then
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

function Hud:drawKillcam(session, cam)
    local W, H = love.graphics.getDimensions()
    local lg = love.graphics
    local d = math.min(W, H) * 0.05
    Kit.color(RED, 0.9)
    lg.setLineWidth(4)
    lg.rectangle("line", d * 0.4, d * 0.4, W - d * 0.8, H - d * 0.8, 18, 18)
    lg.setLineWidth(1)
    local name = session:nameOf(cam.killer)
    local def = Weapons.def(cam.killerView.weapon)
    local weapon = def and (def.name:sub(1, 1) .. def.name:sub(2):lower()) or "Fists"
    local w = 380
    local x, y = (W - w) / 2, H - 150
    card(x, y, w, 96, 1, 16)
    dot(x + 24, y + 26, 5, RED, love.timer.getTime() % 1 < 0.6 and 1 or 0.3)
    text("Killcam", 13, x + 36, y + 17, RED, 1)
    text(Keys.label("dash") .. " to skip", 12, x + w - 20, y + 18, INK, 0.45, "right")
    local nw = text(name, 22, x + 20, y + 40, RED, 1)
    text("with " .. weapon, 15, x + 30 + nw, y + 46, INK, 0.6)
    bar(x + 20, y + 80, w - 40, 4, cam.progress, RED, 0.8)
end

function Hud:drawDeath(session)
    local cam = session:killcam()
    if cam then
        self:drawKillcam(session, cam)
        return
    end
    if self.death < 0.01 then return end
    local W, H = love.graphics.getDimensions()
    local me = session.world.me
    local a = self.death
    love.graphics.setColor(Kit.PAPER[1], Kit.PAPER[2], Kit.PAPER[3], 0.55 * a)
    love.graphics.rectangle("fill", 0, 0, W, H)
    local t = easeOutBack(a)
    local y = H * 0.3 + (1 - t) * 20
    text("Eliminated", 48, 0, y, RED, a, "center", W)
    local seconds = me.dead / Config.tickRate
    local progress = 1 - me.dead / Config.respawnTicks
    if session.world.round and session.world.phase == "playing" then
        text("Out until the next round", 16, 0, y + 80, INK, 0.65 * a, "center", W)
        text("Your team plays on without you", 13, 0, y + 108, INK, 0.45 * a, "center", W)
    elseif me.dead > 0 then
        ring(W / 2, y + 112, 26, progress, 5, INK, a)
        text(tostring(math.ceil(seconds)), 22, W / 2 - 40, y + 99, INK, a, "center", 80)
        text("Respawning", 14, 0, y + 150, INK, 0.55 * a, "center", W)
    end
end

function Hud:drawHelp(session)
    if self.help < 0.01 then return end
    local W, H = love.graphics.getDimensions()
    local a = self.help
    local function both(id)
        local keys = Keys.keys(id)
        local first = Keys.name(keys[1] or keys[2])
        return keys[1] and keys[2] and (first .. " / " .. Keys.name(keys[2])) or first
    end
    local rows = {
        { Keys.label("forward") .. " " .. Keys.label("left") .. " " .. Keys.label("back") .. " " .. Keys.label("right"), "Move" },
        { "Mouse", "Aim and turn" },
        { "Left click", "Fire, or strike when unarmed" },
        { both("dash"), "Dash, slide while running" },
        { both("quiet"), "Walk quietly" },
        { Keys.label("reload"), "Reload" },
        { Keys.label("throw"), "Throw your weapon" },
        { Keys.label("ping"), "Ping, also middle click" },
        { Keys.label("gadget"), "Use your gadget" },
        { Keys.label("pickup"), "Swap with a weapon on the floor" },
        { Keys.label("scoreboard"), "Hold for the scoreboard" },
        { Keys.label("ready"), "Ready up during the warmup" },
        { Keys.label("chat"), "Chat, Tab for your team" },
        { Keys.label("help"), "Show or hide controls" }
    }
    local w, rowH = 360, 34
    local h = 64 + #rows * rowH
    local x = MARGIN + self:leftShift(session)
    local y = (H - h) / 2 + (1 - easeOutCubic(a)) * 12
    card(x, y, w, h, a, 16)
    text("Controls", 18, x + 20, y + 18, INK, a)
    for k, row in ipairs(rows) do
        local ry = y + 52 + (k - 1) * rowH
        local kw = keycap(row[1], x + 20, ry, a, 12)
        text(row[2], 14, x + 30 + max(kw, 92), ry + 4, INK, 0.75 * a)
    end
end

--- @param seconds number
--- @return string
local function clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

--- The matchmaking card shown while the server looks for players.
--- @param mp table the multiplayer module
--- @param c number fade
function Hud:drawSearch(mp, c)
    local W, H = love.graphics.getDimensions()
    local now = love.timer.getTime()
    local search = mp.search
    if search ~= self.searchSeen then
        self.searchSeen, self.searchAt = search, now
    end
    local waited = (tonumber(search.t) or 0) + (now - (self.searchAt or now))
    local board = mp.leaderboard or {}
    local rows = math.min(5, #board)
    local server = mp.server or {}
    local motd = server.motd
    local w = 460
    local h = 214 + (motd and 40 or 0) + (rows > 0 and 40 + rows * 26 or 0)
    local x, y = (W - w) / 2, (H - h) / 2
    card(x, y, w, h, c, 18)
    local rules = Config.modes[search.m or ""] or Config.modes.duel
    text(server.name or "Kyma", 14, x, y + 20, INK, 0.45 * c, "center", w)
    text("Looking for a " .. rules.name:lower(), 24, x, y + 44, INK, c, "center", w)
    local lg = love.graphics
    lg.setLineWidth(3)
    color(RED, c)
    local start = now * 5
    lg.arc("line", "open", W / 2, y + 104, 12, start, start + pi * 1.3, 24)
    lg.setLineWidth(1)
    local line = string.format("%s  -  %d / %d in queue  -  %d online", clock(waited), tonumber(search.q) or 1, tonumber(search.s) or 2, tonumber(search.o) or 1)
    text(line, 14, x, y + 132, INK, 0.6 * c, "center", w)
    local rating = mp.rating and mp.rating.r or search.r
    if rating then
        text("Your rating " .. tostring(rating), 14, x, y + 154, INK, 0.8 * c, "center", w)
    end
    local ty = y + 186
    if motd then
        lg.setFont(font(13))
        color(INK, 0.55 * c)
        lg.printf(motd, math.floor(x + 24), math.floor(ty), w - 48, "center")
        ty = ty + 40
    end
    if rows > 0 then
        text("Top players", 12, x + 24, ty, RED, c)
        ty = ty + 26
        for k = 1, rows do
            local entry = board[k]
            text(k .. ".", 14, x + 24, ty, INK, 0.4 * c)
            text(tostring(entry.n), 14, x + 52, ty, INK, 0.85 * c)
            text(string.format("%d  -  %dW %dL", entry.r or 0, entry.w or 0, entry.l or 0), 13, x + w - 24, ty + 1, INK, 0.6 * c, "right")
            ty = ty + 26
        end
    end
    hint("Esc", "Leave the queue", x + (w - measureHint("Esc", "Leave the queue", 13)) / 2, y + h - 36, 0.6 * c, 13)
end

function Hud:drawOverlay(session)
    local W, H = love.graphics.getDimensions()
    local c = self.connecting
    if c > 0.01 then
        local status = session.status
        local mp = GM.Multiplayer
        love.graphics.setColor(Kit.PAPER[1], Kit.PAPER[2], Kit.PAPER[3], c)
        love.graphics.rectangle("fill", 0, 0, W, H)
        if session.world then
            if self.loadingShown then Loading.draw(session.pending, "Ready", false, c) end
            return
        end
        self.loadingShown = nil
        if require("src.modules.session.tournament").active(session) then
            love.graphics.setColor(1, 1, 1, 1)
            require("src.modules.session.tournament").draw(session)
            return
        end
        if mp.search and not mp.error and status == "queued" then
            self:drawSearch(mp, c)
            return
        end
        local failed = mp.error ~= nil or status == "offline"
        local line = failed and (mp.error or "Disconnected") or (status == "queued" and "Looking for a room" or "Connecting")
        Loading.draw(session.pending, line, failed, c)
        self.loadingShown = true
        return
    end

    local o = self.overlay
    if o > 0.01 and session.world and not session:paused() then
        love.graphics.setColor(Kit.PAPER[1], Kit.PAPER[2], Kit.PAPER[3], 0.6 * o)
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

--- Mini-map en haut à droite (touche Tab/overlay non concernés)
--- @param session table
function Hud:drawMinimap(session)
    local x, y = Livemap.box(session)
    if x then Livemap.draw(session, x, y) end
end

--- Cadre de la mini-map à l'écran (nil si elle est masquée).
--- @return number?, number?, number?, number?
function Hud:mapBox(session)
    if not session or not session.world or session.world.spectator then return nil end
    return Livemap.box(session)
end

--- Décalage horizontal à appliquer aux éléments posés sur le bord gauche
--- pour qu'ils ne passent pas sous la mini-map.
--- @param session table
--- @param zone string  "top" ou "bottom"
--- @return number
function Hud:leftShift(session, zone)
    local x, y, w, h = self:mapBox(session)
    if not x or x > MARGIN + 1 then return 0 end
    local isTop = y < love.graphics.getHeight() / 2
    if zone == nil or (zone == "top") == isTop then return w + 16 end
    return 0
end

--- @param session table
function Hud:draw(session)
    if session.world and session.world.spectator then
        self:drawScore(session)
        self:drawFeed(session, self:drawStats(session))
        self:drawMatchOver(session)
        self:drawBoard(session)
        self:drawStatus(session)
        self:drawRound(session)
        self:drawBanner()
        self:drawSpectator(session)
        self:drawChat(session)
        self:drawOverlay(session)
        return
    end
    if session.world then
        self:drawBlind(session)
        self:drawDamage(session)
        self:drawNoises(session)
        self:drawSpotted(session)
        self:drawPings(session)
        self:drawScore(session)
        self:drawRound(session)
        self:drawBanner()
        self:drawVitals(session)
        self:drawPlates(session)
        self:drawMinimap(session)
        self:drawWeapon(session)
        self:drawGadget(session)
        self:drawPrompt()
        self:drawFeed(session, self:drawStats(session))
        self:drawDeath(session)
        local replay = session:killcam() ~= nil
        if not replay then self:drawLobby(session) end
        self:drawMatchOver(session)
        self:drawBoard(session)
        self:drawStatus(session)
        if not replay then self:drawHelp(session) end
        self:drawChat(session)
    end
    self:drawOverlay(session)
end

return Hud
