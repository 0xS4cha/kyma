--- The client side of a raid: the world rebuilt from the seed, the local player
--- predicted with the shared simulation and reconciled with the server, and the
--- other players and monsters interpolated between snapshots.
local Worldgen = require("src.game.extraction.worldgen")
local Terrain = require("src.game.extraction.terrain")
local Items = require("src.game.extraction.items")
local Inventory = require("src.game.extraction.inventory")
local Player = require("src.game.player")
local Config = require("src.config.extraction")
local GameConfig = require("src.config.game")
local NetConfig = require("src.net.config")

local Raid = {}
Raid.__index = Raid

local DT = 1 / NetConfig.tickRate
local SNAPSHOTS = 32
local pi = math.pi

local worlds = {}

--- The generated world and terrain for a seed, built once per seed.
--- @param seed number
--- @return table def, table terrain
function Raid.world(seed)
    if not worlds[seed] then
        local def = Worldgen.generate(seed)
        local terrain = Terrain.new(def, Config.cell)
        local cells = {}
        for _, c in ipairs(def.containers) do
            local key = math.floor(c.y / 1000) * 1000 + math.floor(c.x / 1000)
            cells[key] = cells[key] or {}
            table.insert(cells[key], c)
        end
        worlds[seed] = { def = def, terrain = terrain, containerCells = cells }
    end
    return worlds[seed].def, worlds[seed].terrain, worlds[seed].containerCells
end

--- @param data table the "xjoin" message
--- @return table
function Raid.new(data)
    local def, terrain, cells = Raid.world(data.seed)
    local me = Player.new(data.slot, "", { x = data.x, y = data.y, angle = Player.unpackAngle(data.angle or 0) })
    me.weapon, me.def, me.ammo, me.reserve = nil, nil, 0, 0
    me.hp = data.hp or 100
    local raid = setmetatable({
        def = def, terrain = terrain, containerCells = cells, slot = data.slot, me = me,
        previous = Player.copy(me), aim = me.angle, sequence = 0, pending = {}, accumulator = 0,
        snapshots = {}, lastTick = data.tick, clock = data.tick, correctionX = 0, correctionY = 0,
        requests = {}, items = {}, drops = {}, empty = {}, events = {}, extracts = {}, fx = {},
        own = nil, inventory = nil, booms = {}
    }, Raid)
    return raid
end

--- Applies the inventory view from the server and the stats of the weapon in hand.
--- @param view table
function Raid:setInventory(view)
    self.inventory = view
    self.places = Inventory.places(view.g, view.ct and { ct = { kind = "grid", w = view.ct.w, h = view.ct.h, list = view.ct.items } } or nil)
    self:arm()
end

function Raid:arm()
    local view = self.inventory
    if not view then return end
    local inst = view.hd and view.g[view.hd] or nil
    local me = self.me
    if inst then
        me.def = Items.weaponStats(inst)
        me.weapon = inst.d
    else
        me.def, me.weapon = nil, nil
    end
end

--- @param input table { forward, strafe, fire, quiet }
--- @return table command
function Raid:sample(input)
    local requests = self.requests
    self.requests = {}
    self.sequence = self.sequence + 1
    local command = {
        s = self.sequence, f = input.forward, r = input.strafe, a = Player.packAngle(self.aim),
        d = requests.dash and 1 or 0, b = input.fire and 1 or 0, l = requests.reload and 1 or 0,
        t = 0, e = requests.pickup and 1 or 0, k = input.quiet and 1 or 0, x = 0
    }
    if input.fire then
        command.v = math.max(0, math.floor(self.clock - GameConfig.interpolationTicks + 0.5))
    end
    return command
end

--- Runs one predicted tick of the local player.
--- @param input table
--- @return boolean fired, table command
function Raid:tick(input)
    local command = self:sample(input)
    self.lastCommand = command
    Player.copy(self.me, self.previous)
    local fired = false
    if self.me.dead == 0 then
        fired = Player.step(self.me, command, self.terrain, DT)
    end
    self.pending[#self.pending + 1] = command
    return fired, command
end

--- @return table[] the last commands to send
function Raid:batch()
    local out = {}
    for k = math.max(1, #self.pending - NetConfig.inputRedundancy + 1), #self.pending do
        out[#out + 1] = self.pending[k]
    end
    return out
end

--- @param data table "xs" snapshot
--- @return table? own entry
function Raid:receive(data)
    if type(data.t) ~= "number" or data.t <= self.lastTick then return nil end
    self.lastTick = data.t
    local players, monsters = {}, {}
    for _, entry in ipairs(data.p or {}) do players[entry.i] = entry end
    for _, entry in ipairs(data.m or {}) do monsters[entry.i] = entry end
    self.snapshots[#self.snapshots + 1] = { t = data.t, players = players, monsters = monsters }
    if #self.snapshots > SNAPSHOTS then table.remove(self.snapshots, 1) end
    self.items = data.d or {}
    self.drops = data.b or {}
    self.empty = {}
    for _, id in ipairs(data.e or {}) do self.empty[id] = true end
    self.events = data.ev or {}
    self.extracts = data.x or {}
    self.fx = data.fx or {}
    local smokes = {}
    for _, s in ipairs(self.fx.sm or {}) do smokes[#smokes + 1] = { x = s.x, y = s.y, r = s.r } end
    self.terrain.smokes = smokes
    if math.abs(self.clock - data.t) > 10 then self.clock = data.t end
    local own = players[self.slot]
    if not own then return nil end
    self.own = own
    local me = self.me
    self.terrain:applyNear(me.x, me.y, Config.interest, data.dd, data.gg)
    local ack = data.k or 0
    local kept = {}
    for _, command in ipairs(self.pending) do
        if command.s > ack then kept[#kept + 1] = command end
    end
    self.pending = kept
    local beforeX, beforeY = me.x, me.y
    me.x, me.y, me.vx, me.vy = own.x, own.y, own.u, own.v
    me.dash, me.cooldown, me.dashX, me.dashY = own.e or 0, own.w or 0, own.m or 0, own.n or 0
    me.slide, me.slideX, me.slideY = own.j or 0, own.sx or 0, own.sy or 0
    me.hp, me.dead, me.out = own.h or me.hp, own.o or 0, (own.o or 0) > 0
    if own.g ~= me.weapon then
        local view = self.inventory
        local inst = view and view.hd and view.g[view.hd]
        if inst and inst.d == own.g then
            me.def, me.weapon = Items.weaponStats(inst), inst.d
        else
            me.weapon = own.g
            me.def = own.g and me.def or nil
        end
    end
    me.ammo, me.reserve, me.reload, me.fireCooldown = own.q or 0, own.r or 0, own.l or 0, own.c or 0
    me.trigger = own.z == 1
    me.stun, me.meleeCooldown = own.st or 0, own.mc or 0
    me.haste, me.rush = own.hs, own.rs == 1 or nil
    me.range, me.thermal = own.rg, own.th
    me.blind = own.bl or 0
    for _, command in ipairs(kept) do
        if me.dead == 0 then Player.step(me, command, self.terrain, DT) end
    end
    self.previous.x = self.previous.x + me.x - beforeX
    self.previous.y = self.previous.y + me.y - beforeY
    self.correctionX = self.correctionX + beforeX - me.x
    self.correctionY = self.correctionY + beforeY - me.y
    if self.correctionX ^ 2 + self.correctionY ^ 2 > 120 * 120 then
        self.correctionX, self.correctionY = 0, 0
    end
    return own
end

local function lerpAngle(a, b, t)
    local d = (b - a + pi) % (2 * pi) - pi
    return a + d * t
end

--- Others and monsters, drawn 100 ms in the past between two snapshots.
--- @return table[] players, table[] monsters
function Raid:interpolated()
    local snapshots = self.snapshots
    if #snapshots == 0 then return {}, {} end
    local target = self.clock - GameConfig.interpolationTicks
    local from, to = snapshots[1], snapshots[#snapshots]
    for k = #snapshots - 1, 1, -1 do
        if snapshots[k].t <= target then
            from, to = snapshots[k], snapshots[k + 1]
            break
        end
    end
    local t = to.t > from.t and math.max(0, math.min(1, (target - from.t) / (to.t - from.t))) or 1
    local players, monsters = {}, {}
    for slot, b in pairs(to.players) do
        if slot ~= self.slot then
            local a = from.players[slot] or b
            players[#players + 1] = {
                slot = slot, x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t,
                angle = lerpAngle(Player.unpackAngle(a.a), Player.unpackAngle(b.a), t),
                vx = b.u or 0, vy = b.v or 0, dashing = (b.e or 0) > 0, sliding = (b.j or 0) > 0,
                hp = b.h, dead = b.o or 0, weapon = b.g, rarity = b.gr, name = b.nm, stun = b.st or 0,
                using = b.us == 1, armor = b.ar or 0, marked = b.mk == 1
            }
        end
    end
    for id, b in pairs(to.monsters) do
        local a = from.monsters[id] or b
        monsters[#monsters + 1] = {
            id = id, kind = b.k, x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t,
            angle = lerpAngle(Player.unpackAngle(a.a), Player.unpackAngle(b.a), t),
            hp = b.h, swing = b.s == 1, burn = b.b == 1, chill = b.c == 1, marked = b.mk == 1
        }
    end
    return players, monsters
end

--- The local player as drawn this frame.
--- @return table
function Raid:view()
    local alpha = self.accumulator / DT
    local a, b = self.previous, self.me
    return {
        slot = self.slot, x = a.x + (b.x - a.x) * alpha + self.correctionX, y = a.y + (b.y - a.y) * alpha + self.correctionY,
        angle = self.aim, vx = b.vx, vy = b.vy, dashing = b.dash > 0, sliding = b.slide > 0, stun = b.stun,
        weapon = b.def and b.def.look or nil, dead = b.dead, hp = b.hp, range = b.range, thermal = b.thermal
    }
end

--- Containers near a point (static, from the generated world).
function Raid:eachContainer(x, y, radius, fn)
    for cy = math.floor((y - radius) / 1000), math.floor((y + radius) / 1000) do
        for cx = math.floor((x - radius) / 1000), math.floor((x + radius) / 1000) do
            for _, c in ipairs(self.containerCells[cy * 1000 + cx] or {}) do
                if (c.x - x) ^ 2 + (c.y - y) ^ 2 <= radius * radius then fn(c) end
            end
        end
    end
end

--- What the interact key would do here: the nearest container or loot box.
--- @return table? { t, id, name, x, y }
function Raid:interactable()
    local me = self.me
    local best, bestD
    local r = Config.interactRadius
    self:eachContainer(me.x, me.y, r, function(c)
        local d = (c.x - me.x) ^ 2 + (c.y - me.y) ^ 2
        if not bestD or d < bestD then best, bestD = { t = "c", id = c.id, kind = c.kind, x = c.x, y = c.y }, d end
    end)
    for _, drop in ipairs(self.drops) do
        local d = (drop.x - me.x) ^ 2 + (drop.y - me.y) ^ 2
        if d < r * r and (not bestD or d < bestD) then best, bestD = { t = "d", id = drop.i, kind = drop.k, name = drop.n, x = drop.x, y = drop.y }, d end
    end
    return best
end

--- @return table? the nearest item on the ground in pickup range
function Raid:nearbyItem()
    local me = self.me
    local best, bestD
    for _, item in ipairs(self.items) do
        local d = (item.x - me.x) ^ 2 + (item.y - me.y) ^ 2
        if d < Config.pickupRadius ^ 2 and (not bestD or d < bestD) then best, bestD = item, d end
    end
    return best
end

return Raid
