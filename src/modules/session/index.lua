local GM = require("src.core.index")
local Camera = require("src.core.camera")
local Arena = require("src.game.arena")
local Player = require("src.game.player")
local Weapons = require("src.game.weapons")
local Vision = require("src.game.vision")
local Config = require("src.config.game")
local WeaponConfig = require("src.config.weapons")
local Effects = require("src.modules.session.effects")
local Hud = require("src.modules.session.hud")
local NetConfig = require("src.net.config")
local Renderer = require("src.modules.session.renderer")

GM.Session = {}

GM.Modules:Register("Session", 40)

local DT = 1 / NetConfig.tickRate
local SNAPSHOTS = 32
local CORRECTION_DECAY = 18
local pi = math.pi

local SELF_COLOR = { 0.24, 0.25, 0.28 }
local OPPONENT_COLOR = { 0.88, 0.14, 0.12 }
local TRACER_SELF = { 0.15, 0.15, 0.17 }
local TRACER_OPPONENT = { 0.88, 0.14, 0.12 }

local function lerpAngle(a, b, t)
    local d = (b - a + pi) % (2 * pi) - pi
    return a + d * t
end

function GM.Session:Initialize()
    self.status = "connecting"
    self.world = nil
    self.camera = Camera(Config.camera)
    self.captured = false
    self.autoplay = GM.Flags and GM.Flags.autoplay or false
    self.effects = Effects.new()
    self.hud = Hud.new()

    local mp = GM.Multiplayer
    mp:On("joined", function(data) self:join(data) end)
    mp:On("room", function(data) self.room = data end)
    mp:On("state", function(data) self:receive(data) end)
    mp:On("disconnected", function() self:leave() end)
    mp:On("hit", function(data) self:onHit(data) end)
    mp:On("kill", function(data) self:onKill(data) end)

    local flags = GM.Flags or {}
    local name = flags.name and tostring(flags.name) or "Player"
    if flags.connect then
        mp:Connect(flags.connect, name)
    else
        mp:PlayLocal(name, flags.host == true)
    end
end

--- @param data table
function GM.Session:join(data)
    local arena = Arena.new()
    local slot = data.slot
    local me = Player.new(slot, GM.Multiplayer.name, arena:spawn(slot))
    self.world = {
        arena = arena,
        slot = slot,
        me = me,
        previous = Player.copy(me),
        aim = me.angle,
        sequence = 0,
        pending = {},
        accumulator = 0,
        snapshots = {},
        lastTick = data.tick,
        clock = data.tick,
        correctionX = 0,
        correctionY = 0,
        requests = {},
        items = {},
        score = {},
        lastSeen = {},
        autoplayTurn = 1
    }
    self.status = "playing"
    self.hud:joined()
    self.camera:follow(me.x, me.y, me.angle)
    self:capture(true)
end

function GM.Session:leave()
    self.world = nil
    self.room = nil
    self.status = "offline"
    self:capture(false)
end

--- @param on boolean
function GM.Session:capture(on)
    self.captured = on
    if love.mouse then
        love.mouse.setRelativeMode(on)
    end
end

--- @return table
function GM.Session:sample()
    local world = self.world
    local forward, strafe, fire, quiet = 0, 0, false, false
    if self.autoplay then
        if world.sequence % 120 == 0 then
            world.autoplayTurn = -world.autoplayTurn
        end
        forward, strafe = 1, world.autoplayTurn
        world.aim = world.aim + 1.2 * DT * world.autoplayTurn
        world.requests.dash = world.sequence % 90 == 45
        world.requests.throw = world.sequence % 600 == 300
        fire = world.sequence % 20 < 2
    else
        local down = love.keyboard.isScancodeDown
        if down("w") or down("up") then forward = forward + 1 end
        if down("s") or down("down") then forward = forward - 1 end
        if down("d") then strafe = strafe + 1 end
        if down("a") then strafe = strafe - 1 end
        if down("left") then world.aim = world.aim - Config.turnSpeed * DT end
        if down("right") then world.aim = world.aim + Config.turnSpeed * DT end
        fire = self.captured and love.mouse.isDown(1)
        quiet = down("c") or down("lctrl")
    end
    local requests = world.requests
    world.requests = {}
    world.sequence = world.sequence + 1
    local command = {
        s = world.sequence, f = forward, r = strafe, a = Player.packAngle(world.aim),
        d = requests.dash and 1 or 0,
        b = fire and 1 or 0,
        l = requests.reload and 1 or 0,
        t = requests.throw and 1 or 0,
        e = requests.pickup and 1 or 0,
        k = quiet and 1 or 0
    }
    world.quiet = quiet
    if fire then
        command.v = math.max(0, math.floor(world.clock - Config.interpolationTicks + 0.5))
    end
    return command
end

function GM.Session:tick()
    local world = self.world
    local command = self:sample()
    world.lastCommand = command
    Player.copy(world.me, world.previous)
    if Player.step(world.me, command, world.arena, DT) then
        self:shoot(world.me, command.s, TRACER_SELF)
    end
    world.pending[#world.pending + 1] = command

    local batch = {}
    for k = math.max(1, #world.pending - NetConfig.inputRedundancy + 1), #world.pending do
        batch[#batch + 1] = world.pending[k]
    end
    GM.Multiplayer:Stream("input", { c = batch })
end

--- @param p table
--- @param sequence number
--- @param color table
function GM.Session:shoot(p, sequence, color)
    local arena = self.world.arena
    for _, ray in ipairs(Weapons.rays(p, sequence)) do
        local length = arena:raycast(ray.x, ray.y, ray.dx, ray.dy, ray.range)
        local hit = length < ray.range - 1e-6 and 1 or 0
        self.effects:tracer(ray.x, ray.y, ray.x + ray.dx * length, ray.y + ray.dy * length, color, hit, 0.5)
    end
end

--- @param data table
function GM.Session:onHit(data)
    local world = self.world
    if not world then return end
    if data.t == world.slot then
        self.effects:hurtFlash()
        if data.x and data.y then
            self.hud:damageFrom(world.me.x, world.me.y, data.x, data.y)
        end
    elseif data.a == world.slot then
        self.effects:hitMarker()
    end
end

--- @param data table
function GM.Session:onKill(data)
    local world = self.world
    if not world then return end
    local victim = data.v
    if victim == world.slot then
        self.effects:shatter(world.me.x, world.me.y, SELF_COLOR)
    else
        local seen = world.lastSeen[victim]
        if seen then
            self.effects:shatter(seen.x, seen.y, OPPONENT_COLOR)
        end
    end
    local function name(slot)
        return slot == world.slot and "You" or self:nameOf(slot)
    end
    local killer = data.k and data.k ~= victim and name(data.k) or nil
    self.hud:announce(killer, name(victim), data.k == world.slot, victim == world.slot)
end

--- @param data table
function GM.Session:receive(data)
    local world = self.world
    if not world or type(data.t) ~= "number" or data.t <= world.lastTick then return end
    world.lastTick = data.t

    local players = {}
    for _, entry in ipairs(data.p or {}) do
        players[entry.i] = entry
    end
    world.snapshots[#world.snapshots + 1] = { t = data.t, players = players }
    world.items = type(data.d) == "table" and data.d or {}
    for _, entry in ipairs(data.sc or {}) do
        world.score[entry.i] = entry.k
    end
    for _, noise in ipairs(data.n or {}) do
        self.effects:echo(noise.x, noise.y, noise.k)
        self.hud:noise(noise.x, noise.y, noise.k)
    end
    for _, shot in ipairs(data.s or {}) do
        if shot.o ~= world.slot then
            self.effects:tracer(shot.x, shot.y, shot.X, shot.Y, TRACER_OPPONENT, shot.h)
        elseif shot.h == 2 then
            self.effects:spray(shot.X, shot.Y, OPPONENT_COLOR, 8)
        end
    end
    if #world.snapshots > SNAPSHOTS then
        table.remove(world.snapshots, 1)
    end

    if math.abs(world.clock - data.t) > 10 then
        world.clock = data.t
    end

    local own = players[world.slot]
    if not own then return end
    local ack = data.k or 0
    local kept = {}
    for _, command in ipairs(world.pending) do
        if command.s > ack then kept[#kept + 1] = command end
    end
    world.pending = kept

    local me = world.me
    local beforeX, beforeY = me.x, me.y
    me.x, me.y, me.vx, me.vy = own.x, own.y, own.u, own.v
    me.dash, me.cooldown, me.dashX, me.dashY = own.e or 0, own.w or 0, own.m or 0, own.n or 0
    me.slide, me.slideX, me.slideY = own.j or 0, own.sx or 0, own.sy or 0
    me.hp, me.dead = own.h or me.hp, own.o or 0
    me.weapon = Weapons.unpack(own.g)
    me.ammo, me.reserve, me.reload, me.fireCooldown = own.q or 0, own.r or 0, own.l or 0, own.c or 0
    me.trigger = own.z == 1
    for _, command in ipairs(kept) do
        Player.step(me, command, world.arena, DT)
    end
    world.previous.x = world.previous.x + me.x - beforeX
    world.previous.y = world.previous.y + me.y - beforeY
    world.correctionX = world.correctionX + beforeX - me.x
    world.correctionY = world.correctionY + beforeY - me.y
    if world.correctionX * world.correctionX + world.correctionY * world.correctionY > 120 * 120 then
        world.correctionX, world.correctionY = 0, 0
    end
end

--- @return table[]
function GM.Session:opponents()
    local world = self.world
    local list = {}
    local snapshots = world.snapshots
    if #snapshots == 0 then return list end
    local target = world.clock - Config.interpolationTicks
    local from, to = snapshots[1], snapshots[#snapshots]
    for k = #snapshots - 1, 1, -1 do
        if snapshots[k].t <= target then
            from, to = snapshots[k], snapshots[k + 1]
            break
        end
    end
    local t = to.t > from.t and math.max(0, math.min(1, (target - from.t) / (to.t - from.t))) or 1
    for slot, b in pairs(to.players) do
        if slot ~= world.slot then
            local a = from.players[slot] or b
            local angleA, angleB = Player.unpackAngle(a.a), Player.unpackAngle(b.a)
            list[#list + 1] = {
                slot = slot,
                x = a.x + (b.x - a.x) * t,
                y = a.y + (b.y - a.y) * t,
                angle = lerpAngle(angleA, angleB, t),
                vx = (a.u or 0) + ((b.u or 0) - (a.u or 0)) * t,
                vy = (a.v or 0) + ((b.v or 0) - (a.v or 0)) * t,
                dashing = (b.e or 0) > 0,
                sliding = (b.j or 0) > 0,
                weapon = Weapons.unpack(b.g),
                dead = b.o or 0,
                name = self:nameOf(slot)
            }
        end
    end
    return list
end

--- @param slot number
--- @return string
function GM.Session:nameOf(slot)
    for _, player in ipairs(self.room and self.room.players or {}) do
        if player.slot == slot then return player.name end
    end
    return "Player " .. slot
end

--- @return table
function GM.Session:localView()
    local world = self.world
    local alpha = world.accumulator / DT
    local a, b = world.previous, world.me
    return {
        slot = world.slot,
        x = a.x + (b.x - a.x) * alpha + world.correctionX,
        y = a.y + (b.y - a.y) * alpha + world.correctionY,
        angle = world.aim,
        vx = b.vx,
        vy = b.vy,
        dashing = b.dash > 0,
        sliding = b.slide > 0,
        weapon = b.weapon,
        dead = b.dead,
        hp = b.hp,
        name = GM.Multiplayer.name
    }
end

--- @return table[]
function GM.Session:visibleOpponents()
    local world = self.world
    local me = self:localView()
    local list = {}
    for _, p in ipairs(self:opponents()) do
        if p.dead == 0 then
            world.lastSeen[p.slot] = { x = p.x, y = p.y }
            if me.dead == 0 and Vision.sees(world.arena, me, p.x, p.y, Config.player.radius) then
                list[#list + 1] = p
            end
        end
    end
    return list
end

--- @return table?
function GM.Session:nearbyItem()
    local world = self.world
    if not world or world.me.dead > 0 then return nil end
    local best, bestDistance
    for _, item in ipairs(world.items) do
        if item.f == 0 and item.k ~= 0 then
            local d = math.sqrt((item.x - world.me.x) ^ 2 + (item.y - world.me.y) ^ 2)
            if d <= WeaponConfig.pickupRadius and (not bestDistance or d < bestDistance) then
                best, bestDistance = item, d
            end
        end
    end
    return best
end

--- @return boolean
function GM.Session:canSlide()
    local world = self.world
    return world ~= nil and world.lastCommand ~= nil and Player.running(world.me, world.lastCommand)
end

--- @return number
function GM.Session:dashCharge()
    local world = self.world
    if not world then return 0 end
    return 1 - world.me.cooldown / Config.dash.cooldown
end

--- @param action string
function GM.Session:request(action)
    if self.world and self.captured and not self.autoplay then
        self.world.requests[action] = true
    end
end

function GM.Session:Think(dt)
    self.hud:update(self, dt)
    local world = self.world
    if not world then
        local mp = GM.Multiplayer
        self.status = mp.error and "error" or (mp.state == "online" and "queued" or "connecting")
        return
    end
    world.clock = world.clock + dt * NetConfig.tickRate
    world.accumulator = math.min(world.accumulator + dt, DT * 8)
    while world.accumulator >= DT do
        world.accumulator = world.accumulator - DT
        self:tick()
    end
    GM.Multiplayer:Flush()

    self.effects:update(dt)
    local dustColor = { 0.6, 0.63, 0.68 }
    local views = self:visibleOpponents()
    views[#views + 1] = self:localView()
    for _, view in ipairs(views) do
        if view.sliding and love.math.random() < 0.6 then
            local ca, sa = math.cos(view.angle), math.sin(view.angle)
            self.effects:spray(view.x + ca * 10, view.y + sa * 10, dustColor, 1)
        end
    end
    local decay = math.exp(-CORRECTION_DECAY * dt)
    world.correctionX, world.correctionY = world.correctionX * decay, world.correctionY * decay

    local view = self:localView()
    self.camera:follow(view.x, view.y, view.angle)
end

function GM.Session:Draw()
    Renderer.draw(self)
end

function GM.Session:MouseMoved(_, _, dx)
    if self.world and self.captured and not self.autoplay then
        self.world.aim = self.world.aim + dx * Config.mouseSensitivity
    end
end

function GM.Session:MousePressed(_, _, button)
    if self.world and not self.captured then
        self:capture(true)
    elseif button == 2 then
        self:request("dash")
    elseif button == 3 then
        self:request("throw")
    end
end

function GM.Session:WheelMoved(_, y)
    if y > 0 then
        self.camera:zoom(1.1)
    elseif y < 0 then
        self.camera:zoom(1 / 1.1)
    end
end

function GM.Session:KeyPressed(key, scancode)
    if scancode == "space" or scancode == "lshift" or scancode == "rshift" then
        self:request("dash")
    elseif scancode == "r" then
        self:request("reload")
    elseif scancode == "g" then
        self:request("throw")
    elseif scancode == "e" then
        self:request("pickup")
    elseif scancode == "h" then
        self.hud:toggleHelp()
    elseif key == "escape" then
        if self.captured then
            self:capture(false)
        else
            love.event.quit()
        end
    end
end

return GM.Session
