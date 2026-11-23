local GM = require("src.core.index")
local Camera = require("src.core.camera")
local Arena = require("src.game.arena")
local Player = require("src.game.player")
local Config = require("src.config.game")
local NetConfig = require("src.net.config")
local Renderer = require("src.modules.session.renderer")

GM.Session = {}

GM.Modules:Register("Session", 40)

local DT = 1 / NetConfig.tickRate
local SNAPSHOTS = 32
local CORRECTION_DECAY = 18
local pi = math.pi

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

    local mp = GM.Multiplayer
    mp:On("joined", function(data) self:join(data) end)
    mp:On("room", function(data) self.room = data end)
    mp:On("state", function(data) self:receive(data) end)
    mp:On("disconnected", function() self:leave() end)

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
        dashRequested = false,
        autoplayTurn = 1
    }
    self.status = "playing"
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
    local forward, strafe = 0, 0
    if self.autoplay then
        if world.sequence % 120 == 0 then
            world.autoplayTurn = -world.autoplayTurn
        end
        forward, strafe = 1, world.autoplayTurn
        world.aim = world.aim + 1.2 * DT * world.autoplayTurn
        world.dashRequested = world.sequence % 90 == 45
    else
        local down = love.keyboard.isScancodeDown
        if down("w") or down("up") then forward = forward + 1 end
        if down("s") or down("down") then forward = forward - 1 end
        if down("d") then strafe = strafe + 1 end
        if down("a") then strafe = strafe - 1 end
        if down("left") then world.aim = world.aim - Config.turnSpeed * DT end
        if down("right") then world.aim = world.aim + Config.turnSpeed * DT end
    end
    local dash = world.dashRequested and 1 or 0
    world.dashRequested = false
    world.sequence = world.sequence + 1
    return { s = world.sequence, f = forward, r = strafe, a = Player.packAngle(world.aim), d = dash }
end

function GM.Session:tick()
    local world = self.world
    local command = self:sample()
    Player.copy(world.me, world.previous)
    Player.step(world.me, command, world.arena, DT)
    world.pending[#world.pending + 1] = command

    local batch = {}
    for k = math.max(1, #world.pending - NetConfig.inputRedundancy + 1), #world.pending do
        batch[#batch + 1] = world.pending[k]
    end
    GM.Multiplayer:Stream("input", { c = batch })
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
        name = GM.Multiplayer.name
    }
end

--- @return number
function GM.Session:dashCharge()
    local world = self.world
    if not world then return 0 end
    return 1 - world.me.cooldown / Config.dash.cooldown
end

function GM.Session:requestDash()
    if self.world and self.captured and not self.autoplay then
        self.world.dashRequested = true
    end
end

function GM.Session:Think(dt)
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
        self:requestDash()
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
        self:requestDash()
    elseif key == "escape" then
        if self.captured then
            self:capture(false)
        else
            love.event.quit()
        end
    end
end

return GM.Session
