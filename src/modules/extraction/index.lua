--- The extraction mode on the client: connects to the official server, shows the hub
--- between raids and plays the raids (prediction, rendering, HUD, inventory).
local GM = require("src.core.index")
local Camera = require("src.core.camera")
local Keys = require("src.input.keybinds")
local Kit = require("src.ui.kit")
local Effects = require("src.modules.session.effects")
local Character = require("src.modules.session.character")
local Feel = require("src.config.feel")
local GameConfig = require("src.config.game")
local NetConfig = require("src.net.config")
local Config = require("src.config.extraction")
local ItemConfig = require("src.config.items")
local Items = require("src.game.extraction.items")
local Inventory = require("src.game.extraction.inventory")
local Weapons = require("src.game.weapons")
local Raid = require("src.modules.extraction.raid")
local Render = require("src.modules.extraction.render")
local Hud = require("src.modules.extraction.hud")
local Hub = require("src.modules.extraction.hub")
local UI = require("src.modules.extraction.inventory")

GM.Extraction = {}

GM.Modules:Register("Extraction", 42)

local DT = 1 / NetConfig.tickRate
local CORRECTION_DECAY = 18
local TRACER = { 0.88, 0.14, 0.12 }
local TRACER_SELF = require("src.ui.theme").colors.tracerSelf

local function sound(name, gain)
    if GM.Audio then GM.Audio:Play(name, gain) end
end

local function soundAt(name, x, y, gain)
    if GM.Audio then GM.Audio:PlayAt(name, x, y, gain) end
end

function GM.Extraction:Initialize()
    self.active = false
    self.state = "idle"
    self.camera = Camera(GameConfig.camera)
    self.effects = Effects.new()
    self.toasts, self.feed, self.hurts = {}, {}, {}
    local mp = GM.Multiplayer
    mp:On("xhub", function(data)
        if not self.active then return end
        self.hub = data
        self.hubState = self.hubState or Hub.new(self)
        if self.state ~= "summary" then self.state = "hub" end
        if self.raid then
            self.raid = nil
            self:capture(false)
        end
        if GM.Flags and GM.Flags.deploy and not self.autoDeployed then
            self.autoDeployed = true
            self:send("xhub", { o = "deploy" })
        end
    end)
    mp:On("xjoin", function(data)
        if not self.active then return end
        self.raid = Raid.new(data)
        self.raidUI = self:newRaidUI()
        self.state = "raid"
        self.showInventory, self.showMap, self.paused = false, false, false
        self.killer, self.banner = nil, nil
        self.effects = Effects.new()
        self.camera.scale = GameConfig.camera.scale
        self.camera:follow(data.x, data.y, self.raid.aim)
        self:capture(true)
        sound("start")
        local show = GM.Flags and GM.Flags.show
        if show == "inventory" then self.showInventory = true end
        if show == "map" then self.showMap = true end
    end)
    mp:On("xs", function(data) self:receive(data) end)
    mp:On("xinv", function(data)
        if self.raid then self.raid:setInventory(data) end
    end)
    mp:On("xtoast", function(data) self:toast(tostring(data.t)) end)
    mp:On("xhit", function(data)
        self.hitAt = love.timer.getTime()
        if data.k == 1 then
            self.killAt = self.hitAt
            sound("kill")
        else
            sound("hit", 0.6)
        end
    end)
    mp:On("xhurt", function(data)
        self.hurts[#self.hurts + 1] = { x = data.x, y = data.y, time = love.timer.getTime() }
        self.effects:hurtFlash()
        self.camera:shake(math.min(0.6, (data.d or 10) / 60))
        sound("hurt", 0.7)
    end)
    mp:On("xdied", function(data)
        self.killer = data.k
        sound("lose")
    end)
    mp:On("xfeed", function(data)
        self.feed[#self.feed + 1] = { k = tostring(data.k), v = tostring(data.v), m = data.m == 1, time = love.timer.getTime() }
    end)
    mp:On("xevent", function(data)
        local colors = { start = Kit.AMBER, live = Kit.RED, ["end"] = Kit.GREEN }
        self.banner = { title = tostring(data.n), text = data.t, color = colors[data.s], time = love.timer.getTime() }
        sound(data.s == "end" and "win" or "beep")
    end)
    mp:On("xextracted", function() sound("win") end)
    mp:On("xscan", function(data)
        if self.raid then self.raid.booms[#self.raid.booms + 1] = { k = "arc", x = data.x, y = data.y, r = data.r, time = love.timer.getTime() } end
    end)
    mp:On("xend", function(data)
        if not self.active then return end
        self.ending = data
        self.state = "summary"
        self.raid = nil
        self:capture(false)
    end)
    mp:On("disconnected", function(data)
        if not self.active then return end
        self.state = "error"
        self.error = data.message or "Connection lost"
        self.raid = nil
        self:capture(false)
    end)
    mp:On("error", function(data)
        if self.active and data.fatal then
            self.state = "error"
            self.error = tostring(data.message)
        elseif self.active then
            self:toast(tostring(data.message))
        end
    end)
end

--- @param address string? the official server when nil
--- @param name string
function GM.Extraction:Start(address, name)
    if GM.Session.active then GM.Session:Stop() end
    local mp = GM.Multiplayer
    self.active = true
    self.state = "connecting"
    self.error = nil
    self.hub, self.raid, self.ending = nil, nil, nil
    self.hubState = nil
    GM.State = "extraction"
    mp.queueOptions = { extraction = true }
    mp.lanHost = false
    mp:Connect(address or mp:OfficialAddress(), name)
end

function GM.Extraction:Stop()
    if not self.active then return end
    GM.Multiplayer:Leave()
    self.active = false
    self.state = "idle"
    self.raid, self.hub = nil, nil
    self:capture(false)
    GM.State = "menu"
    if GM.Menu then GM.Menu:Open("online") end
end

--- @param on boolean
function GM.Extraction:capture(on)
    self.captured = on
    if love.mouse then love.mouse.setRelativeMode(on) end
end

--- @param kind string
--- @param data table
function GM.Extraction:send(kind, data)
    GM.Multiplayer:Send(kind, data)
    GM.Multiplayer:Flush()
end

--- @param text string
function GM.Extraction:toast(text)
    self.toasts[#self.toasts + 1] = { text = text, time = love.timer.getTime() }
    if #self.toasts > 4 then table.remove(self.toasts, 1) end
end

function GM.Extraction:drawToasts()
    local W, H = love.graphics.getDimensions()
    local now = love.timer.getTime()
    for k = #self.toasts, 1, -1 do
        local toast = self.toasts[k]
        if now - toast.time > 3 then table.remove(self.toasts, k) end
    end
    for k, toast in ipairs(self.toasts) do
        local a = math.min(1, (3 - (now - toast.time)) * 2)
        Kit.card(W / 2 - 220, H - 80 - (k - 1) * 50, 440, 40, 0.95 * a, 10)
        Kit.text(toast.text, 15, W / 2 - 220, H - 70 - (k - 1) * 50, Kit.RED, a, "center", 440)
    end
end

--- The inventory screen of a raid: gear on the left, the open container on the right.
function GM.Extraction:newRaidUI()
    local ui = UI.new(function(op) self:send("xact", op) end)
    ui.onOutside = function(inst) self:send("xact", { o = "drop", i = inst.i }) end
    ui.extraMenu = function(inst, ref)
        local list = {}
        local def = Items.def(inst)
        if def.kind == "utility" and (ref == "pk" or ref == "bp") then
            for k, uid in ipairs(self.raid.inventory.g.quick) do
                if uid == inst.i then list[#list + 1] = { "Use", function() self:send("xact", { o = "use", k = k }) end } end
            end
        end
        if ref ~= "ct" then list[#list + 1] = { "Drop on the ground", function() self:send("xact", { o = "drop", i = inst.i }) end } end
        return list
    end
    ui.quickMove = function(inst, ref)
        local raid = self.raid
        local places = raid.places
        local to = { "pk", "bp" }
        local def = Items.def(inst)
        if ref == "ct" then
            if def.kind == "weapon" then to = { "primary", "secondary", "bp", "pk" } end
            if def.kind == "armor" then to = { def.slot, "bp", "pk" } end
            if def.kind == "backpack" then to = { "backpack" } end
        elseif ref ~= "detach" and places.ct then
            to = { "ct" }
        end
        for _, target in ipairs(to) do
            local place = places[target]
            if place and place.kind == "grid" then
                local x, y, o = Inventory.free(place, inst)
                if x then
                    self:send("xact", { o = "move", i = inst.i, to = target, x = x, y = y, r = o })
                    return
                end
            elseif place and place.kind == "slot" and not place.get() and place.accept(inst) then
                self:send("xact", { o = "move", i = inst.i, to = target })
                return
            end
        end
        self:toast("No room")
    end
    return ui
end

--- @param data table
function GM.Extraction:receive(data)
    local raid = self.raid
    if not raid then return end
    local beforeHp = raid.me.hp
    local own = raid:receive(data)
    if not own then return end
    local me = raid.me
    for _, noise in ipairs(data.n or {}) do
        self.effects:echo(noise.x, noise.y, noise.k)
        local names = { step = "step", dash = "dash", slide = "slide", throw = "throw", clank = "clank", melee = "swing", blast = "bang", scream = "death" }
        if names[noise.k] then soundAt(names[noise.k], noise.x, noise.y, 0.8) end
    end
    for _, shot in ipairs(data.s or {}) do
        if shot.o ~= raid.slot then
            if shot.g == "arc" then
                self.effects:tracer(shot.x, shot.y, shot.X, shot.Y, { 0.6, 0.8, 1 }, 0)
            else
                self.effects:tracer(shot.x, shot.y, shot.X, shot.Y, TRACER, shot.h)
                if Weapons.def(shot.g) then soundAt(shot.g, shot.x, shot.y) end
                if shot.o then
                    local recoil = Feel.recoil[shot.g or ""]
                    if recoil then Character.fire(shot.o, recoil.gun) end
                end
            end
        elseif shot.h == 2 then
            self.effects:spray(shot.X, shot.Y, TRACER, 8)
        elseif shot.h == 1 then
            self.effects:impact(shot.X, shot.Y, shot.X - shot.x, shot.Y - shot.y)
        end
    end
    local seen = raid.seenBooms or {}
    raid.seenBooms = seen
    for _, b in ipairs(raid.fx.bx or {}) do
        if not seen[b.i] then
            seen[b.i] = true
            raid.booms[#raid.booms + 1] = { k = b.k, x = b.x, y = b.y, r = b.r, time = love.timer.getTime() }
            if b.k == "blast" then
                local d = math.sqrt((b.x - me.x) ^ 2 + (b.y - me.y) ^ 2)
                self.camera:shake(math.max(0, 0.8 - d / 900))
                soundAt("bang", b.x, b.y)
            end
        end
    end
    if me.hp > beforeHp + 1 and me.dead == 0 then sound("heal") end
end

--- @return table input of this tick
function GM.Extraction:input()
    local raid = self.raid
    local forward, strafe, fire, quiet = 0, 0, false, false
    if not self.paused then
        local down = Keys.down
        if down("forward") then forward = forward + 1 end
        if down("back") then forward = forward - 1 end
        if down("right") then strafe = strafe + 1 end
        if down("left") then strafe = strafe - 1 end
        if down("turnLeft") then raid.aim = raid.aim - GameConfig.turnSpeed * DT end
        if down("turnRight") then raid.aim = raid.aim + GameConfig.turnSpeed * DT end
        fire = self.captured and not self.showInventory and not self.showMap and love.mouse.isDown(1)
        quiet = down("quiet")
    end
    return { forward = forward, strafe = strafe, fire = fire, quiet = quiet }
end

function GM.Extraction:tickRaid()
    local raid = self.raid
    local me = raid.me
    local reloading = me.reload > 0
    local fired, command = raid:tick(self:input())
    if fired then
        if me.def then
            local look = me.def.look
            for _, ray in ipairs(Weapons.rays(me, command.s)) do
                local length = raid.terrain:raycast(ray.x, ray.y, ray.dx, ray.dy, ray.range)
                self.effects:tracer(ray.x, ray.y, ray.x + ray.dx * length, ray.y + ray.dy * length, TRACER_SELF, length < ray.range - 1e-6 and 1 or 0, 0.5)
            end
            sound(me.def.silent and "silencer" or look)
            self.camera:shake(Feel.shake[look] or 0.1)
            local recoil = Feel.recoil[look]
            if recoil then
                Character.fire(raid.slot, recoil.gun)
                self.camera:kick(recoil.camera)
            end
        else
            self.effects:swing(me.x, me.y, me.angle)
            sound("swing")
        end
    elseif command.b == 1 and me.def and me.ammo == 0 and me.reserve == 0 and not me.trigger then
        sound("empty")
    end
    if not reloading and me.reload > 0 then sound("reload") end
    if me.dash == GameConfig.dash.ticks - 1 then sound("dash") end
    GM.Multiplayer:Stream("input", { c = raid:batch() })
end

function GM.Extraction:Think(dt)
    if not self.active then return end
    local raid = self.raid
    if self.state ~= "raid" or not raid then
        if self.state == "connecting" and GM.Multiplayer.error then
            self.state = "error"
            self.error = GM.Multiplayer.error
        end
        return
    end
    raid.clock = raid.clock + dt * NetConfig.tickRate
    raid.accumulator = math.min(raid.accumulator + dt, DT * 8)
    while raid.accumulator >= DT do
        raid.accumulator = raid.accumulator - DT
        self:tickRaid()
    end
    GM.Multiplayer:Flush()
    self.effects:update(dt)
    local decay = math.exp(-CORRECTION_DECAY * dt)
    raid.correctionX, raid.correctionY = raid.correctionX * decay, raid.correctionY * decay
    local view = raid:view()
    self.camera:follow(view.x, view.y, view.angle)
    self.camera:update(dt, 1)
    if raid.inventory and raid.inventory.ct and self.showInventory == false and self.autoOpen then
        self.showInventory = true
        self.autoOpen = nil
        self:capture(false)
    end
end

local function center(title, text, buttonLabel)
    local W, H = love.graphics.getDimensions()
    love.graphics.clear(Kit.PAPER)
    Kit.card(W / 2 - 260, H / 2 - 110, 520, 220, 1, 16)
    Kit.text(title, 26, 0, H / 2 - 86, Kit.INK, 1, "center", W)
    Kit.text(text or "", 15, W / 2 - 230, H / 2 - 36, Kit.INK, 0.7, "center", 460)
    if buttonLabel then
        Kit.button("ext:center", W / 2 - 120, H / 2 + 40, 240, 48, buttonLabel, { primary = true, align = "center", hint = "Enter" })
    end
end

function GM.Extraction:drawRaidInventory()
    local raid = self.raid
    local view = raid.inventory
    if not view then return end
    local W, H = love.graphics.getDimensions()
    love.graphics.setColor(Kit.PAPER[1], Kit.PAPER[2], Kit.PAPER[3], 0.9)
    love.graphics.rectangle("fill", 0, 0, W, H)
    local ui = self.raidUI
    local places = raid.places
    ui:begin(places)
    local cell = math.max(30, math.min(46, math.floor((H - 160) / 16)))
    local x, y = 40, 90
    Kit.text("Inventory", 26, x, 30, Kit.INK, 1)
    local g = view.g
    ui:slot("primary", g.primary, x, y + 20, cell * 5, cell * 2)
    ui:slot("secondary", g.secondary, x, y + 30 + cell * 2, cell * 5, cell * 2)
    local ax = x + cell * 5 + 16
    ui:slot("helmet", g.helmet, ax, y + 20, cell * 2, cell * 2)
    ui:slot("vest", g.vest, ax + cell * 2 + 8, y + 20, cell * 2, cell * 3)
    ui:slot("backpack", g.backpack, ax, y + 28 + cell * 2, cell * 2, cell * 2)
    local qy = y + 50 + cell * 4
    ui:quick(g, x, qy, cell)
    local py = qy + cell + 40
    ui:grid("pk", places.pk, x, py, cell, "Pockets")
    if places.bp then ui:grid("bp", places.bp, x, py + cell + 40, cell, Items.name(g.backpack)) end
    local rx = x + cell * 10 + 60
    if view.ct and places.ct then
        Kit.text(view.ct.n, 22, rx, 30, Kit.INK, 1)
        ui:grid("ct", places.ct, rx, y + 20, cell, "Shift click to take, or drag", math.floor((H - y - 60) / cell))
        Kit.button("ext:lootall", rx, y + 30 + math.min(places.ct.h, math.floor((H - y - 60) / cell)) * cell, 200, 40, "Take all", { size = 14, align = "center" })
        self.lootAllButton = { x = rx, y = y + 30 + math.min(places.ct.h, math.floor((H - y - 60) / cell)) * cell, w = 200, h = 40 }
    else
        self.lootAllButton = nil
        Kit.text("Open a crate or a body with F to loot it.", 15, rx, y + 20, Kit.INK, 0.5)
        Kit.text("Drag an item out of the panels to drop it on the ground.", 13, rx, y + 46, Kit.INK, 0.45)
    end
    ui:finish()
    ui:overlay()
    Kit.hint("Tab", "Close", W - 140, 30, 0.8, 13)
end

function GM.Extraction:drawPause()
    local W, H = love.graphics.getDimensions()
    love.graphics.setColor(Kit.PAPER[1], Kit.PAPER[2], Kit.PAPER[3], 0.85)
    love.graphics.rectangle("fill", 0, 0, W, H)
    Kit.text("Paused", 30, 0, H / 2 - 140, Kit.INK, 1, "center", W)
    Kit.text("The world does not stop: you are still in it.", 14, 0, H / 2 - 96, Kit.INK, 0.6, "center", W)
    local mx, my = love.mouse.getPosition()
    self.pauseButtons = {
        { label = "Resume", y = H / 2 - 50, run = function() self.paused = false self:capture(true) end },
        { label = "Leave the world", sub = "Your character stays " .. Config.lingerTicks / 60 .. " s, vulnerable", y = H / 2 + 10, run = function() self:Stop() end }
    }
    for k, b in ipairs(self.pauseButtons) do
        local hot = mx >= W / 2 - 160 and mx < W / 2 + 160 and my >= b.y and my < b.y + 52
        Kit.button("ext:pause" .. k, W / 2 - 160, b.y, 320, 52, b.label, { hot = hot, primary = k == 1, sublabel = b.sub, size = 17 })
    end
end

function GM.Extraction:drawSummary()
    local W, H = love.graphics.getDimensions()
    local e = self.ending or {}
    love.graphics.clear(Kit.PAPER)
    local titles = { extracted = "Extracted", died = "Killed in action", left = "Back from the wilds" }
    local colors = { extracted = Kit.GREEN, died = Kit.RED, left = Kit.INK }
    Kit.card(W / 2 - 300, H / 2 - 180, 600, 360, 1, 18)
    Kit.text(titles[e.r] or "Raid over", 34, 0, H / 2 - 150, colors[e.r] or Kit.INK, 1, "center", W)
    local lines = {}
    if e.r == "died" then lines[#lines + 1] = "Killed by " .. tostring(e.k or "the wilds") .. ". Everything you carried is lost." end
    if e.r == "extracted" then lines[#lines + 1] = "You made it out with gear worth " .. Hub.money(e.v or 0) .. "." end
    if e.r == "left" then lines[#lines + 1] = "Your character survived your absence and came back." end
    lines[#lines + 1] = string.format("Time in the world: %d:%02d", math.floor((e.time or 0) / 60), (e.time or 0) % 60)
    lines[#lines + 1] = string.format("Players killed: %d   Monsters killed: %d", e.kills or 0, e.monsters or 0)
    for k, line in ipairs(lines) do
        Kit.text(line, 16, W / 2 - 270, H / 2 - 80 + (k - 1) * 30, Kit.INK, 0.8, "center", 540)
    end
    Kit.button("ext:summary", W / 2 - 130, H / 2 + 100, 260, 52, "Back to the hub", { primary = true, align = "center", hint = "Enter" })
end

function GM.Extraction:Draw()
    if not self.active then return end
    local state = self.state
    if state == "connecting" then
        center("Connecting", "Joining the wilds on " .. tostring(GM.Multiplayer.address) .. "...", nil)
    elseif state == "error" then
        center("Can't play extraction", self.error, "Back")
    elseif state == "summary" then
        self:drawSummary()
    elseif state == "hub" and self.hub then
        Hub.draw(self)
    elseif state == "raid" and self.raid then
        Render.draw(self)
        self.effects:drawScreen()
        Hud.draw(self)
        if self.showMap then Hud.map(self) end
        if self.showInventory then self:drawRaidInventory() end
        if self.paused then self:drawPause() end
        self:drawToasts()
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function GM.Extraction:closeOverlays()
    self.showInventory, self.showMap = false, false
    if self.raid and self.raid.inventory and self.raid.inventory.ct then self:send("xact", { o = "close" }) end
    self:capture(true)
end

function GM.Extraction:KeyPressed(key, scancode)
    if not self.active then return end
    local state = self.state
    if state == "error" then
        if key == "return" or key == "escape" or key == "kpenter" then self:Stop() end
        return
    end
    if state == "summary" then
        if key == "return" or key == "escape" or key == "kpenter" then self.state = "hub" end
        return
    end
    if state == "hub" and self.hub then
        if key == "escape" and not (self.hubState.ui.drag or self.hubState.ui.menu) then
            self:Stop()
            return
        end
        Hub.keypressed(self, key)
        return
    end
    if state ~= "raid" or not self.raid then
        if key == "escape" then self:Stop() end
        return
    end
    local raid = self.raid
    if self.showInventory and self.raidUI:keypressed(key) then return end
    if key == "escape" then
        if self.showInventory or self.showMap then
            self:closeOverlays()
        else
            self.paused = not self.paused
            self:capture(not self.paused)
        end
        return
    end
    if self.paused then return end
    if key == "tab" then
        self.showInventory = not self.showInventory
        self.showMap = false
        if self.showInventory then self:capture(false) else self:closeOverlays() end
        return
    end
    if key == "m" then
        self.showMap = not self.showMap
        self.showInventory = false
        self:capture(not self.showMap)
        return
    end
    if key == "f" then
        if raid.inventory and raid.inventory.ct then
            self:send("xact", { o = "close" })
        else
            local target = raid:interactable()
            if target then
                self:send("xact", { o = "open", t = target.t, id = target.id })
                self.showInventory = true
                self:capture(false)
            end
        end
        return
    end
    if key == "1" or key == "2" then
        local hand = key == "1" and "primary" or "secondary"
        if raid.inventory and raid.inventory.hd ~= hand and raid.inventory.g[hand] then
            self:send("xact", { o = "hand", h = hand })
            sound("pickup")
        end
        return
    end
    local quick = tonumber(key)
    if quick and quick >= 3 and quick <= 2 + Config.quickSlots then
        self:send("xact", { o = "use", k = quick - 2 })
        return
    end
    if Keys.is("dash", scancode) then
        raid.requests.dash = true
    elseif Keys.is("reload", scancode) then
        raid.requests.reload = true
    elseif Keys.is("pickup", scancode) then
        raid.requests.pickup = true
    end
end

function GM.Extraction:MousePressed(x, y, button)
    if not self.active then return end
    local state = self.state
    local W, H = love.graphics.getDimensions()
    if state == "error" then
        if button == 1 then self:Stop() end
        return
    end
    if state == "summary" then
        if button == 1 then self.state = "hub" end
        return
    end
    if state == "hub" and self.hub then
        Hub.mousepressed(self, x, y, button)
        return
    end
    if state ~= "raid" then return end
    if self.paused then
        for _, b in ipairs(self.pauseButtons or {}) do
            if button == 1 and x >= W / 2 - 160 and x < W / 2 + 160 and y >= b.y and y < b.y + 52 then b.run() return end
        end
        return
    end
    if self.showInventory then
        local b = self.lootAllButton
        if button == 1 and b and x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
            self:send("xact", { o = "lootall" })
            return
        end
        self.raidUI:mousepressed(x, y, button)
        return
    end
    if self.showMap then return end
    if not self.captured then
        self:capture(true)
    elseif button == 2 then
        self.raid.requests.dash = true
    end
end

function GM.Extraction:MouseReleased(x, y, button)
    if not self.active then return end
    if self.state == "hub" and self.hub then
        Hub.mousereleased(self, x, y, button)
    elseif self.state == "raid" and self.showInventory then
        self.raidUI:mousereleased(x, y, button)
    end
end

function GM.Extraction:MouseMoved(_, _, dx)
    if self.active and self.state == "raid" and self.raid and self.captured and not self.paused and not self.showInventory and not self.showMap then
        self.raid.aim = self.raid.aim + dx * GameConfig.mouseSensitivity
    end
end

function GM.Extraction:WheelMoved(_, y)
    if not self.active then return end
    if self.state == "hub" and self.hub then
        Hub.wheelmoved(self, y)
    elseif self.state == "raid" then
        if self.showInventory then
            self.raidUI:wheelmoved(y)
        elseif self.showMap then
            self.mapZoom = math.max(1, math.min(10, (self.mapZoom or 1) * (y > 0 and 1.25 or 0.8)))
        elseif y ~= 0 then
            self.camera:zoom(y > 0 and 1.1 or 1 / 1.1)
        end
    end
end

return GM.Extraction
