--- The persistent world of the extraction mode, simulated by the official server:
--- players with grid inventories, loot containers, monsters, random events and
--- extraction points on a 40k x 40k procedural map.
local Worldgen = require("src.game.extraction.worldgen")
local Terrain = require("src.game.extraction.terrain")
local Items = require("src.game.extraction.items")
local Inventory = require("src.game.extraction.inventory")
local Loot = require("src.game.extraction.loot")
local Fight = require("src.game.extraction.fight")
local Monsters = require("src.game.extraction.monsters")
local Events = require("src.game.extraction.events")
local Player = require("src.game.player")
local Vision = require("src.game.vision")
local Random = require("src.core.random")
local Config = require("src.config.extraction")
local GameConfig = require("src.config.game")
local NetConfig = require("src.net.config")
local ItemConfig = require("src.config.items")

local Wilds = {}
Wilds.__index = Wilds

local floor, sqrt, min, max = math.floor, math.sqrt, math.min, math.max

local CELL = 1000
local HISTORY = 32

--- @param options table? { seed, def, alloc, random }
--- @return table
function Wilds.new(options)
    options = options or {}
    local def = options.def or Worldgen.generate(options.seed or Config.seed)
    local terrain = Terrain.new(def, Config.cell)
    local counter = 1000000
    local w = setmetatable({
        def = def,
        terrain = terrain,
        arena = terrain,
        seed = def.seed,
        tick = 0,
        dt = 1 / NetConfig.tickRate,
        players = {},
        inputs = {},
        containers = {},
        containerCells = {},
        drops = {},
        nextDrop = 1,
        ground = {},
        nextGround = 1,
        history = {},
        shots = {},
        noises = {},
        outbox = {},
        extracts = {},
        rng = Random.new(options.random or os.time()),
        alloc = options.alloc or function()
            counter = counter + 1
            return counter
        end
    }, Wilds)
    for _, c in ipairs(def.containers) do
        local state = { id = c.id, x = c.x, y = c.y, kind = c.kind, tier = c.tier, items = nil, refill = 0 }
        w.containers[c.id] = state
        local key = floor(c.y / CELL) * 1000 + floor(c.x / CELL)
        w.containerCells[key] = w.containerCells[key] or {}
        table.insert(w.containerCells[key], state)
    end
    for _, e in ipairs(def.extracts) do
        w.extracts[#w.extracts + 1] = { id = e.id, name = e.name, x = e.x, y = e.y }
    end
    Fight.setup(w)
    Monsters.setup(w)
    Events.setup(w)
    return w
end

--- Queues a message for one player (slot) or everyone (nil).
function Wilds:send(slot, kind, data)
    self.outbox[#self.outbox + 1] = { to = slot, kind = kind, data = data }
end

--- @param x number
--- @param y number
--- @param radius number
--- @param fn function
function Wilds:eachContainer(x, y, radius, fn)
    for cy = floor((y - radius) / CELL), floor((y + radius) / CELL) do
        for cx = floor((x - radius) / CELL), floor((x + radius) / CELL) do
            for _, c in ipairs(self.containerCells[cy * 1000 + cx] or {}) do
                if (c.x - x) ^ 2 + (c.y - y) ^ 2 <= radius * radius then fn(c) end
            end
        end
    end
end

--- Picks a spawn point on a road crossing near the edge, away from other players.
--- @return table
function Wilds:spawnPoint()
    local spawns = self.def.spawns
    local best, bestScore
    for _ = 1, 12 do
        local spawn = spawns[self.rng:random(#spawns)]
        local nearest = math.huge
        for _, p in pairs(self.players) do
            if p.hp > 0 then nearest = min(nearest, (p.x - spawn.x) ^ 2 + (p.y - spawn.y) ^ 2) end
        end
        for _, m in pairs(self.monsters) do
            nearest = min(nearest, (m.x - spawn.x) ^ 2 + (m.y - spawn.y) ^ 2 * 4)
        end
        if nearest > Config.spawnClearance ^ 2 then return spawn end
        if not bestScore or nearest > bestScore then best, bestScore = spawn, nearest end
    end
    return best
end

--- Puts a character in the world with the gear it brought.
--- @param slot number
--- @param name string
--- @param gear table
--- @param key string? identity of the owner
--- @param at table? position to resume at
--- @return table player
function Wilds:add(slot, name, gear, key, at)
    local spawn = at or self:spawnPoint()
    local p = Player.new(slot, name, { x = spawn.x, y = spawn.y, angle = spawn.angle or 0 })
    p.key = key
    p.gear = gear
    p.hp = at and at.hp or GameConfig.health
    p.hand = gear.primary and "primary" or (gear.secondary and "secondary" or nil)
    p.kills, p.monsterKills, p.extract, p.joinedAt = 0, 0, 0, self.tick
    p.marks, p.effects = {}, {}
    self.players[slot] = p
    self.inputs[slot] = { queue = {}, last = 0, acked = 0, credit = 0 }
    self:refresh(p)
    self:arm(p)
    p.invDirty = true
    return p
end

--- Takes a character out of the world (extracted, gone after a disconnect, or dead).
--- @param slot number
--- @return table? player
function Wilds:remove(slot)
    local p = self.players[slot]
    if p and p.open then self:close(p) end
    self.players[slot] = nil
    self.inputs[slot] = nil
    return p
end

--- Rebuilds the places of a player's inventory (after a backpack change or opening a container).
--- @param p table
function Wilds:refresh(p)
    local extra = {}
    local open = p.open and self:openPlace(p.open)
    if open then extra.ct = open end
    p.places = Inventory.places(p.gear, extra)
end

--- @param ref table { t = "c"|"d", id }
--- @return table? grid place
function Wilds:openPlace(ref)
    local target = ref.t == "c" and self.containers[ref.id] or (ref.t == "d" and self.drops[ref.id]) or nil
    if not target or not target.items then return nil end
    local def = Loot.containers[target.kind] or Loot.containers.crate
    return { kind = "grid", w = target.w or def.w, h = target.h or def.h, list = target.items }
end

local function signature(inst)
    if not inst then return "" end
    local parts = { inst.i, inst.r }
    for _, slot in ipairs(ItemConfig.slots.order) do
        local m = inst.m and inst.m[slot]
        parts[#parts + 1] = m and (m.i .. ":" .. m.r) or "-"
    end
    return table.concat(parts, ",")
end

--- Puts the weapon of the current hand in the player's hands and recomputes stats.
--- @param p table
function Wilds:arm(p)
    local inst = p.hand and p.gear[p.hand] or nil
    if not inst then
        p.hand = p.gear.primary and "primary" or (p.gear.secondary and "secondary" or nil)
        inst = p.hand and p.gear[p.hand] or nil
    end
    p.armed, p.armedSig = inst, signature(inst)
    if inst then
        p.def = Items.weaponStats(inst)
        p.weapon = inst.d
        p.ammo = min(inst.a or 0, p.def.magazine)
        p.ammoId = "ammo_" .. p.def.ammo
    else
        p.def, p.weapon, p.ammo, p.ammoId = nil, nil, 0, nil
    end
    p.reserve = p.ammoId and Inventory.count(p.places, p.ammoId) or 0
    p.reload = 0
    p.fireCooldown = 20
    self:stats(p)
end

--- Vision range, thermal radius and movement factor from gear and effects.
--- @param p table
function Wilds:stats(p)
    local def = p.def or {}
    local helmet = Items.def(p.gear.helmet)
    p.range = Config.vision.range + (def.sight or 0) + (helmet and helmet.sight or 0)
    if def.light then p.range = max(p.range, Config.vision.flashlight + (def.sight or 0)) end
    p.thermal = def.thermal and floor(def.thermal) or nil
    local haste = def.haste or 1
    for _, slot in ipairs({ "vest", "backpack" }) do
        local gear = Items.def(p.gear[slot])
        if gear and gear.haste then haste = haste * gear.haste end
    end
    local e = p.effects
    if (e.haste or 0) > 0 then haste = haste * 1.25 end
    if (e.chill or 0) > 0 then haste = haste * 0.6 end
    if p.use then haste = haste * Config.use.slow end
    p.haste = math.abs(haste - 1) > 1e-6 and haste or nil
    p.rush = (e.rush or 0) > 0 or nil
end

--- @param slot number
--- @param commands table[]
function Wilds:queue(slot, commands)
    local state = self.inputs[slot]
    if not state then return end
    for _, command in ipairs(commands) do
        if command.s > state.last then
            state.last = command.s
            state.queue[#state.queue + 1] = command
        end
    end
    while #state.queue > NetConfig.inputQueue do
        local dropped = table.remove(state.queue, 1)
        state.acked = dropped.s
    end
end

--- @param slot number
--- @return number
function Wilds:ack(slot)
    local state = self.inputs[slot]
    return state and state.acked or 0
end

--- @param p table
--- @param command table
function Wilds:apply(p, command)
    if p.use then
        if command.b == 1 or p.dead > 0 then
            p.use = nil
            self:stats(p)
        else
            command.b = 0
        end
    end
    if Player.step(p, command, self.terrain, self.dt) then
        if p.def then
            Fight.fire(self, p, command)
        else
            Fight.melee(self, p, command)
        end
    end
    if p.dead > 0 then return end
    self:footsteps(p, command)
    if command.e == 1 then self:pickNearest(p) end
end

--- @param p table
--- @param command table
function Wilds:footsteps(p, command)
    local noise = GameConfig.noise
    if p.dash == GameConfig.dash.ticks - 1 then return Fight.noise(self, "dash", p.x, p.y, p.slot) end
    if p.slide == GameConfig.slide.ticks - 1 then return Fight.noise(self, "slide", p.x, p.y, p.slot) end
    if command.k == 1 then return end
    p.stride = (p.stride or 0) + 1
    local speed = sqrt(p.vx * p.vx + p.vy * p.vy)
    if speed < noise.stepSpeed then
        p.stride = 0
    elseif p.stride >= noise.stepTicks then
        p.stride = 0
        Fight.noise(self, "step", p.x, p.y, p.slot)
    end
end

--- Keeps the loaded rounds on the weapon item and takes the rounds a reload used
--- out of the inventory.
--- @param p table
function Wilds:syncAmmo(p)
    if p.armed then p.armed.a = p.ammo end
    if not p.ammoId then return end
    local have = Inventory.count(p.places, p.ammoId)
    if p.reserve < have then
        Inventory.consume(p.places, p.ammoId, have - p.reserve)
        p.invDirty = true
    elseif p.reserve > have then
        p.reserve = have
    end
end

--- @param p table
function Wilds:effects(p)
    local e = p.effects
    for key, value in pairs(e) do
        if type(value) == "number" and value > 0 then e[key] = value - 1 end
    end
    if (e.burn or 0) > 0 and e.burn % 30 == 0 then Fight.hurtPlayer(self, p, e.burnDamage or 3, e.burnBy, { status = true }) end
    if (e.poison or 0) > 0 and e.poison % 45 == 0 then Fight.hurtPlayer(self, p, e.poisonDamage or 4, e.poisonBy, { status = true }) end
    if (e.regen or 0) > 0 and e.regen % 15 == 0 then p.hp = min(GameConfig.health, p.hp + (e.regenAmount or 1)) end
    if (p.blind or 0) > 0 then p.blind = p.blind - 1 end
    for key, ticks in pairs(p.marks) do
        if ticks <= 1 then p.marks[key] = nil else p.marks[key] = ticks - 1 end
    end
    if p.use then
        p.use.ticks = p.use.ticks - 1
        if p.use.ticks <= 0 then
            local use = p.use
            p.use = nil
            self:finishUse(p, use)
        end
    end
    self:stats(p)
end

function Wilds:step()
    self.tick = self.tick + 1
    local slots = {}
    for slot in pairs(self.players) do slots[#slots + 1] = slot end
    table.sort(slots)
    for _, slot in ipairs(slots) do
        local p = self.players[slot]
        local state = self.inputs[slot]
        state.credit = min(state.credit + 1, NetConfig.inputCredit)
        while state.credit >= 1 and #state.queue > 0 and self.players[slot] do
            local command = table.remove(state.queue, 1)
            self:apply(p, command)
            state.acked = command.s
            state.credit = state.credit - 1
        end
        if self.players[slot] then
            if p.dead == 0 then
                self:effects(p)
                self:syncAmmo(p)
                self:extraction(p)
                if p.open then self:checkOpen(p) end
            end
        end
    end
    Fight.update(self)
    Monsters.update(self)
    Events.update(self)
    local actors = {}
    for _, p in pairs(self.players) do actors[#actors + 1] = p end
    for _, m in pairs(self.monsters) do actors[#actors + 1] = m end
    self.terrain:updateDoors(actors)
    self.terrain:updateGlass(actors)
    self:record()
    if self.tick % 60 == 0 then self:cleanup() end
end

function Wilds:record()
    local entry = { tick = self.tick, players = {} }
    for slot, p in pairs(self.players) do
        entry.players[slot] = { x = p.x, y = p.y, alive = p.hp > 0 and p.dead == 0, evading = Player.evading(p) }
    end
    self.history[self.tick % HISTORY] = entry
end

--- Where a player was at a past tick, for lag compensation.
--- @param slot number
--- @param tick number
--- @return table
function Wilds:rewound(slot, tick)
    local entry = self.history[tick % HISTORY]
    if entry and entry.tick == tick and entry.players[slot] then return entry.players[slot] end
    local p = self.players[slot]
    return { x = p.x, y = p.y, alive = p.hp > 0 and p.dead == 0, evading = Player.evading(p) }
end

function Wilds:cleanup()
    for id, item in pairs(self.ground) do
        item.ticks = item.ticks - 60
        if item.ticks <= 0 then self.ground[id] = nil end
    end
    for id, drop in pairs(self.drops) do
        drop.ticks = drop.ticks - 60
        if drop.ticks <= 0 or (drop.items and #drop.items == 0 and drop.kind ~= "corpse" and not drop.event) then
            self:closeAll("d", id)
            self.drops[id] = nil
        end
    end
    for _, c in pairs(self.containers) do
        if c.items and #c.items == 0 then
            c.refill = c.refill + 60
            if c.refill >= Config.containerRefill then
                c.items, c.refill = nil, 0
            end
        end
    end
end

--- Extraction: stand in an extraction zone long enough to leave with your loot.
--- @param p table
function Wilds:extraction(p)
    local r2 = Config.extractRadius ^ 2
    local inside = false
    for _, e in ipairs(self.extracts) do
        if (not e.owner or e.owner == p.slot) and (not e.ready or e.ready <= self.tick) and (p.x - e.x) ^ 2 + (p.y - e.y) ^ 2 < r2 then
            inside = true
        end
    end
    if inside then
        p.extract = p.extract + 1
        if p.extract >= Config.extractTicks then
            p.extracted = true
            self:send(p.slot, "xextracted", {})
        end
    else
        p.extract = 0
    end
end

--- Drops a loot box (corpse, monster remains, supply drop).
--- @return table
function Wilds:drop(x, y, kind, name, items, w, h, ticks)
    local id = self.nextDrop
    self.nextDrop = id + 1
    local drop = { id = id, x = x, y = y, kind = kind, name = name, items = items, w = w, h = h, ticks = ticks or Config.corpseTicks }
    self.drops[id] = drop
    return drop
end

--- @param x number
--- @param y number
--- @param inst table
function Wilds:spill(x, y, inst)
    local id = self.nextGround
    self.nextGround = id + 1
    local angle = self.rng:random() * math.pi * 2
    local px, py = self.terrain:resolve(x + math.cos(angle) * 18, y + math.sin(angle) * 18, 8)
    self.ground[id] = { id = id, x = px, y = py, inst = inst, ticks = Config.groundTicks }
end

--- @param p table
--- @param inst table
--- @return boolean put in the inventory (or equipped)
function Wilds:take(p, inst)
    local def = Items.def(inst)
    local refs = { "pk", "bp" }
    if def.kind == "weapon" then refs = { "primary", "secondary", "pk", "bp" } end
    if def.kind == "armor" then refs = { def.slot, "bp", "pk" } end
    if def.kind == "backpack" then refs = { "backpack", "pk" } end
    local before = inst.n
    local ref = Inventory.give(p.places, inst, refs)
    if ref then
        if ref == "backpack" then self:refresh(p) end
        if ref == "primary" or ref == "secondary" then
            if not p.armed then p.hand = ref end
            self:arm(p)
        end
        if p.ammoId and inst.d == p.ammoId then p.reserve = Inventory.count(p.places, p.ammoId) end
        p.invDirty = true
        return true
    end
    if inst.n ~= before then p.invDirty = true end
    return false
end

--- Picks up the nearest item on the ground.
--- @param p table
function Wilds:pickNearest(p)
    local best, bestD
    for _, item in pairs(self.ground) do
        local d = (item.x - p.x) ^ 2 + (item.y - p.y) ^ 2
        if d < Config.pickupRadius ^ 2 and (not bestD or d < bestD) then best, bestD = item, d end
    end
    if not best then return end
    if self:take(p, best.inst) then
        self.ground[best.id] = nil
        Fight.noise(self, "clank", p.x, p.y, p.slot)
    else
        self:send(p.slot, "xtoast", { t = "No room for " .. Items.name(best.inst) })
    end
end

--- Opens a container or a loot box next to the player and sends its contents.
--- @param p table
--- @param t string "c" (container) or "d" (drop)
--- @param id number
--- @return boolean, string?
function Wilds:open(p, t, id)
    local target = t == "c" and self.containers[id] or (t == "d" and self.drops[id]) or nil
    if not target then return false, "Nothing there" end
    if (target.x - p.x) ^ 2 + (target.y - p.y) ^ 2 > Config.interactRadius ^ 2 then return false, "Too far" end
    if t == "c" and not target.items then
        target.items = Loot.roll(target.kind, target.tier, self.rng, self.alloc)
        target.refill = 0
    end
    if p.open then self:close(p) end
    p.open = { t = t, id = id }
    target.openers = target.openers or {}
    target.openers[p.slot] = true
    self:refresh(p)
    p.invDirty = true
    Fight.noise(self, "clank", target.x, target.y, p.slot)
    return true
end

--- @param p table
function Wilds:close(p)
    local ref = p.open
    if not ref then return end
    local target = ref.t == "c" and self.containers[ref.id] or self.drops[ref.id]
    if target and target.openers then target.openers[p.slot] = nil end
    p.open = nil
    self:refresh(p)
    p.invDirty = true
end

--- Closes a container for everyone (it is gone).
function Wilds:closeAll(t, id)
    for _, p in pairs(self.players) do
        if p.open and p.open.t == t and p.open.id == id then self:close(p) end
    end
end

--- @param p table
function Wilds:checkOpen(p)
    local ref = p.open
    local target = ref.t == "c" and self.containers[ref.id] or self.drops[ref.id]
    if not target or (target.x - p.x) ^ 2 + (target.y - p.y) ^ 2 > (Config.interactRadius + 40) ^ 2 then
        self:close(p)
    end
end

--- Marks every player with this container open so they get its new contents.
--- @param p table the player who changed it
function Wilds:touchOpen(p)
    if not p.open then return end
    local target = p.open.t == "c" and self.containers[p.open.id] or self.drops[p.open.id]
    for slot in pairs(target and target.openers or {}) do
        if self.players[slot] then self.players[slot].invDirty = true end
    end
end

--- Starts using a utility from a quick slot.
--- @param p table
--- @param k number quick slot
--- @return boolean, string?
function Wilds:useQuick(p, k)
    local uid = p.gear.quick[k]
    if not uid or uid == 0 then return false, "Empty quick slot" end
    local loc = Inventory.locate(p.places, uid)
    if not loc or (loc.ref ~= "pk" and loc.ref ~= "bp") then
        p.gear.quick[k] = 0
        p.invDirty = true
        return false, "That item is gone"
    end
    local def = Items.def(loc.inst)
    if def.kind ~= "utility" then return false, "Not usable" end
    if p.use then return false, "Busy" end
    if def.throw or def.place then
        if (p.useCooldown or 0) > self.tick then return false, "Busy" end
        p.useCooldown = self.tick + 30
        Fight.throw(self, p, def, loc.inst)
        self:spend(p, loc.inst)
        return true
    end
    if def.repair and not (p.gear.vest and p.gear.vest.u < Items.armorStats(p.gear.vest).durability) then
        return false, "Your vest is not damaged"
    end
    p.use = { uid = uid, ticks = def.useTicks or 30, total = def.useTicks or 30, d = def.id }
    self:stats(p)
    return true
end

--- Removes one use of a stackable (or the item).
function Wilds:spend(p, inst)
    local def = Items.def(inst)
    if def.charges then
        inst.n = (inst.n or def.charges) - 1
    else
        inst.n = (inst.n or 1) - 1
    end
    if inst.n <= 0 then
        Inventory.take(p.places, inst.i)
        for k, uid in ipairs(p.gear.quick) do
            if uid == inst.i then p.gear.quick[k] = 0 end
        end
    end
    p.invDirty = true
end

--- @param p table
--- @param use table
function Wilds:finishUse(p, use)
    local loc = Inventory.locate(p.places, use.uid)
    if not loc then return end
    local def = Items.def(loc.inst)
    local e = p.effects
    if def.heal then
        local power = Items.rarity(loc.inst).power
        p.hp = min(GameConfig.health, p.hp + floor(def.heal * power + 0.5))
    end
    if def.regen then e.regen, e.regenAmount = 600, max(1, floor(def.regen / 40 + 0.5)) end
    if def.haste then e.haste = def.haste end
    if def.rush then e.rush = def.rush end
    if def.fortify then e.fortify = def.fortify end
    if def.cure then e.burn, e.poison, e.chill = 0, 0, 0 end
    if def.repair and p.gear.vest then
        local stats = Items.armorStats(p.gear.vest)
        p.gear.vest.u = min(stats.durability, (p.gear.vest.u or 0) + floor(def.repair * Items.rarity(loc.inst).power))
    end
    if def.scan then
        self:scan(p, def.scan)
    end
    if def.beacon then
        self.extracts[#self.extracts + 1] = {
            id = 1000 + self.tick, name = "Your flare", x = p.x, y = p.y, owner = p.slot,
            ready = self.tick + def.beacon, expires = self.tick + def.beacon + 60 * 60
        }
        self:send(p.slot, "xtoast", { t = "Extraction called: hold here in 45 s" })
    end
    self:spend(p, loc.inst)
    self:stats(p)
end

--- Reveals bodies around a player for a few seconds.
function Wilds:scan(p, radius)
    for slot, other in pairs(self.players) do
        if slot ~= p.slot and other.dead == 0 and (other.x - p.x) ^ 2 + (other.y - p.y) ^ 2 < radius * radius then
            p.marks["p" .. slot] = 240
        end
    end
    for id, m in pairs(self.monsters) do
        if (m.x - p.x) ^ 2 + (m.y - p.y) ^ 2 < radius * radius then p.marks["m" .. id] = 240 end
    end
    self:send(p.slot, "xscan", { x = floor(p.x), y = floor(p.y), r = radius })
end

--- An inventory or interaction request from a player. Everything is checked here:
--- the client only asks.
--- @param slot number
--- @param op table
--- @return boolean, string?
function Wilds:act(slot, op)
    local p = self.players[slot]
    if not p or p.dead > 0 or p.hp <= 0 or type(op) ~= "table" then return false, "You can't do that now" end
    local kind = op.o
    local uid = tonumber(op.i)
    local ok, err
    if kind == "move" then
        local to = type(op.to) == "string" and op.to or ""
        if to == "ct" and not p.places.ct then return false, "Nothing open" end
        local from = uid and Inventory.locate(p.places, uid)
        if from and p.use and from.inst.i == p.use.uid then return false, "In use" end
        ok, err = Inventory.move(p.places, uid or -1, to, op.x, op.y, op.r)
        if ok and from and (from.ref == "ct" or to == "ct") then self:touchOpen(p) end
    elseif kind == "attach" then
        ok, err = Inventory.attach(p.places, uid or -1, tonumber(op.w) or -1)
        if ok then self:touchOpen(p) end
    elseif kind == "drop" then
        local loc = uid and Inventory.locate(p.places, uid)
        if not loc then return false, "Item not found" end
        if loc.ref == "ct" then return false, "Take it first" end
        local inst = Inventory.take(p.places, uid)
        self:spill(p.x, p.y, inst)
        ok = true
    elseif kind == "take" then
        local item = self.ground[tonumber(op.g) or -1]
        if not item or (item.x - p.x) ^ 2 + (item.y - p.y) ^ 2 > Config.interactRadius ^ 2 then return false, "Too far" end
        if not self:take(p, item.inst) then return false, "No room" end
        self.ground[item.id] = nil
        ok = true
    elseif kind == "lootall" then
        local place = p.places.ct
        if not place then return false, "Nothing open" end
        local moved = 0
        for k = #place.list, 1, -1 do
            local inst = place.list[k]
            table.remove(place.list, k)
            if self:take(p, inst) then
                moved = moved + 1
            else
                table.insert(place.list, k, inst)
            end
        end
        self:touchOpen(p)
        ok, err = moved > 0, moved == 0 and "No room" or nil
    elseif kind == "quick" then
        local k = tonumber(op.k)
        if not k or k < 1 or k > Config.quickSlots then return false, "Bad slot" end
        if uid and uid ~= 0 then
            local loc = Inventory.locate(p.places, uid)
            if not loc or Items.def(loc.inst).kind ~= "utility" then return false, "Only utilities go in quick slots" end
        end
        p.gear.quick[k] = uid or 0
        ok = true
    elseif kind == "hand" then
        local hand = op.h == "primary" and "primary" or (op.h == "secondary" and "secondary" or nil)
        if hand and not p.gear[hand] then return false, "Nothing in that slot" end
        if hand ~= p.hand then
            p.hand = hand
            self:arm(p)
        end
        ok = true
    elseif kind == "use" then
        ok, err = self:useQuick(p, tonumber(op.k) or 0)
    elseif kind == "open" then
        ok, err = self:open(p, op.t == "d" and "d" or "c", tonumber(op.id) or -1)
    elseif kind == "close" then
        self:close(p)
        ok = true
    else
        return false, "Unknown action"
    end
    if ok then
        if p.places.bp and p.places.bp.list ~= (p.gear.backpack and p.gear.backpack.c) or (not p.gear.backpack and p.places.bp) or (p.gear.backpack and not p.places.bp) then
            self:refresh(p)
        end
        local inst = p.hand and p.gear[p.hand] or nil
        if inst ~= p.armed or signature(inst) ~= p.armedSig then
            self:arm(p)
        elseif p.ammoId then
            p.reserve = Inventory.count(p.places, p.ammoId)
        end
        self:stats(p)
        for k, q in ipairs(p.gear.quick) do
            if q ~= 0 then
                local loc = Inventory.locate(p.places, q)
                if not loc or (loc.ref ~= "pk" and loc.ref ~= "bp") then p.gear.quick[k] = 0 end
            end
        end
        p.invDirty = true
    end
    return ok, err
end

--- What the inventory screen of a player shows.
--- @param slot number
--- @return table?
function Wilds:inventoryView(slot)
    local p = self.players[slot]
    if not p then return nil end
    local view = { g = p.gear, hd = p.hand }
    if p.open then
        local target = p.open.t == "c" and self.containers[p.open.id] or self.drops[p.open.id]
        local place = p.places.ct
        if target and place then
            local def = Loot.containers[target.kind] or Loot.containers.crate
            view.ct = { t = p.open.t, id = p.open.id, n = target.name or def.name, w = place.w, h = place.h, items = place.list }
        end
    end
    return view
end

--- Can the viewer see a point (players and monsters)?
--- @param viewer table player
--- @return boolean
function Wilds:sees(viewer, x, y, radius, key)
    if viewer.dead > 0 then return false end
    if key and viewer.marks[key] then return (viewer.x - x) ^ 2 + (viewer.y - y) ^ 2 < 2000 * 2000 end
    if (viewer.blind or 0) > 0 then return false end
    local vision = GameConfig.vision
    local near = max(vision.serverNearRadius, viewer.thermal or 0)
    return Vision.sees(self.terrain, viewer, x, y, radius, vision.serverMargin, near)
end

--- @param viewer number
--- @param shot table
--- @return boolean
function Wilds:shows(viewer, shot)
    if shot.o == viewer then return true end
    if shot.hd then return false end
    if shot.q ~= 1 then return true end
    local p, shooter = self.players[viewer], self.players[shot.o or -1]
    return p ~= nil and shooter ~= nil and self:sees(p, shooter.x, shooter.y, GameConfig.player.radius, "p" .. shot.o)
end

--- @param listener number
--- @param noise table
--- @return boolean
function Wilds:hears(listener, noise)
    if noise.source == listener then return false end
    local p = self.players[listener]
    if not p or p.dead > 0 then return false end
    if (noise.x - p.x) ^ 2 + (noise.y - p.y) ^ 2 > noise.radius * noise.radius then return false end
    local source = noise.source and self.players[noise.source]
    if source and self:sees(p, source.x, source.y, GameConfig.player.radius, "p" .. noise.source) then return false end
    return true
end

--- @return table[], table[], table[]
function Wilds:drain()
    local outbox, shots, noises = self.outbox, self.shots, self.noises
    self.outbox, self.shots, self.noises = {}, {}, {}
    return outbox, shots, noises
end

local function round(v) return floor(v * 10 + 0.5) / 10 end

--- What one player receives every snapshot.
--- @param slot number
--- @return table
function Wilds:snapshot(slot)
    local me = self.players[slot]
    local interest = Config.interest
    local players, monsters, items, drops, empty = {}, {}, {}, {}, {}
    local radius = GameConfig.player.radius
    for other, p in pairs(self.players) do
        local close = (p.x - me.x) ^ 2 + (p.y - me.y) ^ 2 < interest * interest
        if other == slot or (close and (p.dead > 0 or self:sees(me, p.x, p.y, radius, "p" .. other))) then
            local entry = {
                i = other, x = round(p.x), y = round(p.y), a = Player.packAngle(p.angle), u = round(p.vx), v = round(p.vy),
                e = p.dash, j = p.slide, o = p.dead, h = floor(p.hp + 0.5), g = p.weapon, gr = p.armed and p.armed.r or nil,
                nm = p.name, st = p.stun, us = p.use and 1 or nil,
                ar = (p.gear.vest and 1 or 0) + (p.gear.helmet and 2 or 0), mk = (other ~= slot and me.marks["p" .. other]) and 1 or nil
            }
            if other == slot then
                entry.w, entry.m, entry.n = p.cooldown, p.dashX, p.dashY
                entry.sx, entry.sy, entry.mc = p.slideX, p.slideY, p.meleeCooldown
                entry.q, entry.r, entry.l, entry.c, entry.z = p.ammo, p.reserve, p.reload, p.fireCooldown, p.trigger and 1 or 0
                entry.hs, entry.rs = p.haste, p.rush and 1 or nil
                entry.ex = p.extract > 0 and p.extract or nil
                entry.ut = p.use and { p.use.ticks, p.use.total, p.use.d } or nil
                entry.bl = (p.blind or 0) > 0 and p.blind or nil
                entry.rg, entry.th = p.range, p.thermal
                local e = p.effects
                entry.fx = {
                    b = (e.burn or 0) > 0 and 1 or nil, p = (e.poison or 0) > 0 and 1 or nil, c = (e.chill or 0) > 0 and 1 or nil,
                    h = (e.haste or 0) > 0 and e.haste or nil, f = (e.fortify or 0) > 0 and e.fortify or nil, r = (e.rush or 0) > 0 and e.rush or nil
                }
            end
            players[#players + 1] = entry
        end
    end
    for id, m in pairs(self.monsters) do
        if (m.x - me.x) ^ 2 + (m.y - me.y) ^ 2 < interest * interest and self:sees(me, m.x, m.y, m.def.radius, "m" .. id) then
            monsters[#monsters + 1] = {
                i = id, k = m.kind, x = round(m.x), y = round(m.y), a = Player.packAngle(m.angle),
                h = floor(m.hp / m.max * 100 + 0.5), s = m.swing and 1 or nil, b = (m.burn or 0) > 0 and 1 or nil,
                c = (m.chill or 0) > 0 and 1 or nil, mk = me.marks["m" .. id] and 1 or nil
            }
        end
    end
    for id, item in pairs(self.ground) do
        if (item.x - me.x) ^ 2 + (item.y - me.y) ^ 2 < 900 * 900 then
            items[#items + 1] = { i = id, x = round(item.x), y = round(item.y), d = item.inst.d, r = item.inst.r }
        end
    end
    for id, drop in pairs(self.drops) do
        if (drop.x - me.x) ^ 2 + (drop.y - me.y) ^ 2 < interest * interest then
            drops[#drops + 1] = { i = id, x = floor(drop.x), y = floor(drop.y), k = drop.kind, n = drop.name, e = drop.items and #drop.items == 0 and 1 or nil }
        end
    end
    self:eachContainer(me.x, me.y, interest, function(c)
        if c.items and #c.items == 0 then empty[#empty + 1] = c.id end
    end)
    local doors, glass = self.terrain:stateNear(me.x, me.y, interest)
    local fx = Fight.snapshot(self, me)
    local extracts = {}
    for _, e in ipairs(self.extracts) do
        if not e.owner or e.owner == slot then
            extracts[#extracts + 1] = { i = e.id, x = floor(e.x), y = floor(e.y), n = e.name, r = e.ready and max(0, e.ready - self.tick) or nil }
        end
    end
    return {
        players = players, monsters = monsters, items = items, drops = drops, empty = empty,
        doors = doors, glass = glass, fx = fx, events = Events.snapshot(self), extracts = extracts
    }
end

return Wilds
