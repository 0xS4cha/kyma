--- The extraction mode on the official server: one persistent world shared by up to
--- 64 players, and the hub (stash, trader, workbench) where they are between raids.
--- Everything is decided here; clients only send requests.
local Class = require("src.core.class")
local Protocol = require("src.net.protocol")
local NetConfig = require("src.net.config")
local Inputs = require("src.net.inputs")
local Player = require("src.game.player")
local Wilds = require("src.game.extraction.world")
local Inventory = require("src.game.extraction.inventory")
local Items = require("src.game.extraction.items")
local Store = require("src.server.extraction.store")
local ItemConfig = require("src.config.items")
local Config = require("src.config.extraction")

local Realm = Class()

local DEATH_DELAY = 60 * 3

--- @param host table?
--- @param options table { path, seed }
function Realm:init(host, options)
    options = options or {}
    self.host = host
    self.store = Store(options.path)
    self.world = Wilds.new({ seed = options.seed or Config.seed, alloc = function() return self.store:alloc() end, random = options.random })
    self.members = {}
    self.slots = {}
    self.accumulator = 0
    self.shots, self.noises = {}, {}
    Logger:info("extraction", string.format("World ready: seed %d, %d containers, %d nests", self.world.seed, #self.world.def.containers, #self.world.def.nests))
end

--- @return number players in the world, lingering ones included
function Realm:Count()
    local n = 0
    for _ in pairs(self.slots) do n = n + 1 end
    return n
end

--- @param key string
--- @return table? member
function Realm:memberByKey(key)
    for _, member in pairs(self.members) do
        if member.key == key then return member end
    end
    for _, member in pairs(self.slots) do
        if member.key == key then return member end
    end
end

--- @param client table
function Realm:Join(client)
    if not client.key then
        client:Send("error", { message = "Extraction needs a player identity", fatal = true })
        return
    end
    local existing = self:memberByKey(client.key)
    if existing and existing.client and existing.client ~= client then
        client:Send("error", { message = "You are already connected", fatal = true })
        return
    end
    local member = existing or { key = client.key }
    member.client = client
    member.name = client.name
    member.linger = nil
    member.profile = self.store:Get(client.key, client.name)
    self.members[client] = member
    client.realm = self
    if member.slot and self.world.players[member.slot] then
        self:sendJoin(member)
        Logger:info("extraction", client.name .. " is back in the world")
    else
        member.slot = nil
        self:sendHub(member)
    end
end

--- The client left or lost its connection. A character in the world stays there,
--- vulnerable, for a while: logging out does not save your loot.
--- @param client table
function Realm:Leave(client)
    local member = self.members[client]
    if not member then return end
    self.members[client] = nil
    client.realm = nil
    member.client = nil
    if member.slot and self.world.players[member.slot] then
        member.linger = Config.lingerTicks
        local p = self.world.players[member.slot]
        self.world.inputs[member.slot].queue = {}
        p.trigger = false
        Logger:info("extraction", member.name .. " left the world, the character stays " .. Config.lingerTicks / 60 .. " s")
    end
end

--- @param member table
--- @return table
function Realm:hubView(member)
    local profile = member.profile
    local now = os.time()
    return {
        money = profile.money, stash = profile.stash, g = profile.gear, known = profile.known, stats = profile.stats,
        kit = math.max(0, profile.kitAt + Config.kitCooldown - now),
        players = self:Count(), max = Config.players, seed = self.world.seed
    }
end

--- @param member table
function Realm:sendHub(member)
    if member.client then member.client:Send("xhub", self:hubView(member)) end
end

--- @param member table
function Realm:sendJoin(member)
    local p = self.world.players[member.slot]
    member.client:Send("xjoin", {
        slot = member.slot, seed = self.world.seed, tick = self.world.tick, tickRate = NetConfig.tickRate,
        x = p.x, y = p.y, angle = Player.packAngle(p.angle), hp = p.hp
    })
    p.invDirty = true
end

--- @param profile table
--- @return table places of the hub: the gear plus the stash
local function hubPlaces(profile)
    return Inventory.places(profile.gear, { st = { kind = "grid", w = Config.stash.w, h = Config.stash.h, list = profile.stash } })
end

--- Counts a material in the stash.
local function stashCount(profile, id)
    local total = 0
    for _, inst in ipairs(profile.stash) do
        if inst.d == id then total = total + (inst.n or 1) end
    end
    return total
end

local function stashConsume(profile, id, n)
    return Inventory.consume({ pk = { kind = "grid", w = Config.stash.w, h = Config.stash.h, list = profile.stash } }, id, n)
end

--- A request from the hub screen.
--- @param client table
--- @param op table
function Realm:Hub(client, op)
    local member = self.members[client]
    if not member or member.slot or type(op) ~= "table" then return end
    local ok, err = self:hubAction(member, op)
    if not ok and err then client:Send("xtoast", { t = err }) end
    self:sendHub(member)
end

--- @param member table
--- @param op table
--- @return boolean, string?
function Realm:hubAction(member, op)
    local profile = member.profile
    local places = hubPlaces(profile)
    local uid = tonumber(op.i)
    local kind = op.o
    self.store.dirty = true
    if kind == "move" then
        return Inventory.move(places, uid or -1, type(op.to) == "string" and op.to or "", op.x, op.y, op.r)
    elseif kind == "attach" then
        return Inventory.attach(places, uid or -1, tonumber(op.w) or -1)
    elseif kind == "quick" then
        local k = tonumber(op.k)
        if not k or k < 1 or k > Config.quickSlots then return false, "Bad slot" end
        if uid and uid ~= 0 then
            local loc = Inventory.locate(places, uid)
            if not loc or Items.def(loc.inst).kind ~= "utility" then return false, "Only utilities go in quick slots" end
        end
        profile.gear.quick[k] = uid or 0
        return true
    elseif kind == "sell" then
        local loc = uid and Inventory.locate(places, uid)
        if not loc then return false, "Item not found" end
        local price = Items.value(loc.inst, Config.sellRate)
        Inventory.take(places, uid)
        profile.money = profile.money + price
        profile.stats.earned = profile.stats.earned + price
        return true
    elseif kind == "buy" then
        local entry
        for _, e in ipairs(ItemConfig.shop) do
            if e.id == op.d then entry = e end
        end
        if not entry then return false, "Not for sale" end
        local rarity = math.max(1, math.floor(tonumber(op.r) or 1))
        if rarity > (entry.rarity or 1) then return false, "The trader does not sell that rarity" end
        local price = Items.price(entry.id, rarity)
        if profile.money < price then return false, "Not enough money" end
        local def = ItemConfig.all[entry.id]
        local inst = self.store:item(entry.id, rarity, def.kind == "ammo" and def.stack or (def.stack > 1 and 1 or nil))
        if not Inventory.give(places, inst, { "st" }) then return false, "Your stash is full" end
        profile.money = profile.money - price
        return true
    elseif kind == "learn" then
        local loc = uid and Inventory.locate(places, uid)
        if not loc then return false, "Item not found" end
        local def = Items.def(loc.inst)
        if def.kind ~= "blueprint" then return false, "Not a blueprint" end
        if (profile.known[def.target] or 0) >= loc.inst.r then return false, "You already know this plan at that rarity" end
        Inventory.take(places, uid)
        profile.known[def.target] = loc.inst.r
        return true
    elseif kind == "craft" then
        local id = type(op.d) == "string" and op.d or ""
        local known = profile.known[id] or 0
        local rarity = math.max(1, math.floor(tonumber(op.r) or 1))
        if known < 1 then return false, "You need the plan first" end
        if rarity > known then return false, "Your plan only goes up to " .. ItemConfig.rarities[ItemConfig.rarities.order[known]].name end
        local recipe = Items.recipe(id, rarity)
        for _, part in ipairs(recipe) do
            if stashCount(profile, part.id) < part.n then
                return false, "Missing " .. (part.n - stashCount(profile, part.id)) .. " " .. ItemConfig.all[part.id].name
            end
        end
        local def = ItemConfig.all[id]
        local inst = self.store:item(id, def.kind == "ammo" and 1 or rarity, def.stack > 1 and ItemConfig.yield(id) or nil)
        if def.kind == "weapon" then inst.a = 0 end
        local x, y = Inventory.free(places.st, inst)
        if not x then return false, "Your stash is full" end
        for _, part in ipairs(recipe) do stashConsume(profile, part.id, part.n) end
        Inventory.give(places, inst, { "st" })
        profile.stats.crafted = profile.stats.crafted + 1
        return true
    elseif kind == "kit" then
        local now = os.time()
        if profile.kitAt + Config.kitCooldown > now then return false, "The free kit is not ready yet" end
        local left = self.store:equip(profile.gear, self.store:starterKit())
        for _, inst in ipairs(left) do Inventory.give(places, inst, { "st" }) end
        profile.kitAt = now
        return true
    elseif kind == "deploy" then
        return self:deploy(member)
    end
    return false, "Unknown action"
end

--- Sends a character into the world with the gear it wears.
--- @param member table
--- @return boolean, string?
function Realm:deploy(member)
    if self:Count() >= Config.players then return false, "The world is full, try again in a moment" end
    local slot
    for k = 1, Config.players do
        if not self.slots[k] then slot = k break end
    end
    local profile = member.profile
    self.world:add(slot, member.name, profile.gear, member.key)
    member.slot = slot
    self.slots[slot] = member
    profile.raid = true
    profile.stats.raids = profile.stats.raids + 1
    self.store.dirty = true
    self:sendJoin(member)
    Logger:info("extraction", string.format("%s deployed as slot %d (%d in the world)", member.name, slot, self:Count()))
    return true
end

--- @param client table
--- @param data any
function Realm:Input(client, data)
    local member = self.members[client]
    if not member or not member.slot then return end
    self.world:queue(member.slot, Inputs.batch(data))
end

--- @param client table
--- @param op any
function Realm:Act(client, op)
    local member = self.members[client]
    if not member or not member.slot then return end
    local ok, err = self.world:act(member.slot, op)
    if not ok and err then client:Send("xtoast", { t = err }) end
end

--- Ends the raid of a member: extracted (keeps the gear), dead (lost it) or timed out
--- after a disconnect (keeps it).
--- @param member table
--- @param reason string
function Realm:finish(member, reason)
    local slot = member.slot
    local p = self.world:remove(slot)
    self.slots[slot] = nil
    member.slot = nil
    local profile = member.profile
    profile.raid = nil
    if p then
        profile.stats.kills = profile.stats.kills + (p.kills or 0)
        profile.stats.monsters = profile.stats.monsters + (p.monsterKills or 0)
    end
    if reason == "extracted" then
        profile.stats.extracts = profile.stats.extracts + 1
    elseif reason == "died" then
        profile.stats.deaths = profile.stats.deaths + 1
        profile.gear = Inventory.newGear()
    end
    self.store.dirty = true
    local value = 0
    for _, inst in ipairs(Inventory.all(profile.gear)) do value = value + Items.value(inst, Config.sellRate) end
    if member.client then
        member.client:Send("xend", {
            r = reason, k = p and p.killer or nil, kills = p and p.kills or 0, monsters = p and p.monsterKills or 0,
            v = value, time = p and math.floor((self.world.tick - p.joinedAt) / 60) or 0
        })
        self:sendHub(member)
    end
    Logger:info("extraction", string.format("%s left the world: %s", member.name, reason))
end

function Realm:flush()
    local outbox, shots, noises = self.world:drain()
    for _, shot in ipairs(shots) do self.shots[#self.shots + 1] = shot end
    for _, noise in ipairs(noises) do self.noises[#self.noises + 1] = noise end
    for _, message in ipairs(outbox) do
        if message.to then
            local member = self.slots[message.to]
            if member and member.client then member.client:Send(message.kind, message.data) end
            if message.kind == "xdied" and self.world.players[message.to] then
                local p = self.world.players[message.to]
                p.deadAt, p.killer = self.world.tick, message.data.k
            end
        else
            local raw = Protocol.Encode(message.kind, message.data)
            for _, member in pairs(self.slots) do
                if member.client then member.client:SendRaw(raw) end
            end
        end
    end
end

function Realm:sendState()
    local world = self.world
    local shots, noises = self.shots, self.noises
    self.shots, self.noises = {}, {}
    for slot, member in pairs(self.slots) do
        local p = world.players[slot]
        if member.client and p then
            local view = world:snapshot(slot)
            local seen, heard = {}, {}
            local r2 = Config.interest ^ 2 * 1.5
            for _, shot in ipairs(shots) do
                if (shot.x - p.x) ^ 2 + (shot.y - p.y) ^ 2 < r2 and world:shows(slot, shot) then
                    seen[#seen + 1] = {
                        o = shot.o, x = math.floor(shot.x), y = math.floor(shot.y), X = math.floor(shot.X), Y = math.floor(shot.Y),
                        h = shot.h, g = shot.g, mo = shot.mo
                    }
                end
            end
            for _, noise in ipairs(noises) do
                if world:hears(slot, noise) then heard[#heard + 1] = { x = math.floor(noise.x), y = math.floor(noise.y), k = noise.kind } end
            end
            member.client:Stream("xs", {
                t = world.tick, k = world:ack(slot), p = view.players, m = view.monsters, d = view.items, b = view.drops,
                e = view.empty, dd = view.doors, gg = view.glass, fx = view.fx, ev = view.events, x = view.extracts,
                s = seen, n = heard
            })
        end
    end
end

--- @param dt number
function Realm:Update(dt)
    local step = 1 / NetConfig.tickRate
    self.accumulator = math.min(self.accumulator + dt, step * 8)
    while self.accumulator >= step do
        self.accumulator = self.accumulator - step
        self.world:step()
        self:flush()
        for slot, member in pairs(self.slots) do
            local p = self.world.players[slot]
            if not p then
                self.slots[slot] = nil
            elseif p.extracted then
                self:finish(member, "extracted")
            elseif p.dead > 0 then
                p.deadAt = p.deadAt or self.world.tick
                if self.world.tick - p.deadAt >= DEATH_DELAY then self:finish(member, "died") end
            elseif member.linger then
                member.linger = member.linger - 1
                if member.linger <= 0 then self:finish(member, "left") end
            elseif p.invDirty and member.client then
                p.invDirty = false
                member.client:Send("xinv", self.world:inventoryView(slot))
            end
        end
        if self.world.tick % NetConfig.snapshotTicks == 0 then self:sendState() end
    end
    self.store:Update(dt)
end

function Realm:Save()
    self.store:Save()
end

return Realm
