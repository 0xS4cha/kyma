--- Extraction profiles kept on the official server, keyed by the hashed identity of
--- each player: stash, the gear they carry (also while in the world, so a
--- crash never duplicates or deletes loot), learned blueprints and stats.
local Class = require("src.core.class")
local json = require("libs.json")
local Inventory = require("src.game.extraction.inventory")
local Items = require("src.game.extraction.items")
local ItemConfig = require("src.config.items")
local Config = require("src.config.extraction")

local Store = Class()

Store.SAVE_EVERY = Config.saveEvery

--- @param path string? nil keeps everything in memory
--- Puts the pockets and backpack contents of a gear back inside their grids.
--- @param gear table
function Store.repack(gear)
    local places = Inventory.places(gear)
    for _, ref in ipairs({ "pk", "bp" }) do
        local place = places[ref]
        if place then
            local items = place.list
            local keep, left = {}, {}
            for _, inst in ipairs(items) do
                local iw, ih = Items.size(inst)
                if Inventory.fits(keep, place.w, place.h, iw, ih, inst.x, inst.y) then keep[#keep + 1] = inst else left[#left + 1] = inst end
            end
            for k = #items, 1, -1 do items[k] = nil end
            for k, inst in ipairs(keep) do items[k] = inst end
            for _, inst in ipairs(left) do
                if not Inventory.give(places, inst, { ref, "pk", "bp" }) then
                    -- No room anywhere: it stays listed so nothing is ever deleted.
                    items[#items + 1] = inst
                end
            end
        end
    end
end

function Store:init(path)
    self.path = path
    self.players = {}
    self.nextId = 1
    self.dirty = false
    self.clock = 0
    self:load()
end

function Store:read()
    if not self.path then return nil end
    if self.path:sub(1, 1) == "/" then
        local file = io.open(self.path, "r")
        if not file then return nil end
        local content = file:read("*a")
        file:close()
        return content
    end
    return love.filesystem.getInfo(self.path) and love.filesystem.read(self.path) or nil
end

function Store:write(content)
    if self.path:sub(1, 1) == "/" then
        local temp = self.path .. ".tmp"
        local file = io.open(temp, "w")
        if not file then return false end
        file:write(content)
        file:close()
        return os.rename(temp, self.path) == true
    end
    return love.filesystem.write(self.path, content) == true
end

--- @param raw table
--- @return table
local function sanitize(raw)
    local profile = {
        n = type(raw.n) == "string" and raw.n or "Player",
        stash = {},
        gear = Inventory.sanitizeGear(raw.gear),
        known = {},
        stats = {},
        kitAt = tonumber(raw.kitAt) or 0,
        raid = raw.raid == true or nil
    }
    -- Items are placed again so a smaller grid (or smaller stacks) never leaves one
    -- outside: what fits keeps its spot, the rest is packed where there is room.
    local place = { kind = "grid", w = Config.stash.w, h = Config.stash.h, list = profile.stash }
    local left = {}
    for _, inst in ipairs(type(raw.stash) == "table" and raw.stash or {}) do
        local clean = Items.sanitize(inst)
        if clean then
            local iw, ih = Items.size(clean)
            if Inventory.fits(place.list, place.w, place.h, iw, ih, clean.x, clean.y) then
                place.list[#place.list + 1] = clean
            else
                left[#left + 1] = clean
            end
        end
    end
    for _, inst in ipairs(left) do Inventory.give({ st = place }, inst, { "st" }) end
    Store.repack(profile.gear)
    for id, rarity in pairs(type(raw.known) == "table" and raw.known or {}) do
        if ItemConfig.recipes[id] and tonumber(rarity) then profile.known[id] = math.max(1, math.min(6, math.floor(rarity))) end
    end
    for _, key in ipairs({ "raids", "extracts", "deaths", "kills", "monsters", "recycled", "crafted" }) do
        profile.stats[key] = math.max(0, math.floor(tonumber(type(raw.stats) == "table" and raw.stats[key]) or 0))
    end
    return profile
end

function Store:load()
    local content = self:read()
    if not content then return end
    local ok, data = pcall(json.decode, content)
    if not ok or type(data) ~= "table" or type(data.players) ~= "table" then
        Logger:warn("extraction", "Ignoring unreadable profiles file " .. tostring(self.path))
        return
    end
    self.nextId = math.max(1, math.floor(tonumber(data.nextId) or 1))
    for key, raw in pairs(data.players) do
        if type(key) == "string" and type(raw) == "table" then
            self.players[key] = sanitize(raw)
        end
    end
end

--- @return boolean
function Store:Save()
    if not self.path or not self.dirty then return true end
    local ok, content = pcall(json.encode, { version = 1, nextId = self.nextId, players = self.players })
    if not ok then
        Logger:warn("extraction", "Could not encode profiles: " .. tostring(content))
        return false
    end
    ok = self:write(content)
    if ok then self.dirty = false else Logger:warn("extraction", "Could not save profiles to " .. self.path) end
    return ok
end

--- @param dt number
function Store:Update(dt)
    self.clock = self.clock + dt
    if self.clock >= Store.SAVE_EVERY then
        self.clock = 0
        self:Save()
    end
end

--- A new unique item id, persisted with the profiles.
--- @return number
function Store:alloc()
    local id = self.nextId
    self.nextId = id + 1
    self.dirty = true
    return id
end

--- @param id string
--- @param rarity number?
--- @param n number?
--- @return table
function Store:item(id, rarity, n)
    local def = ItemConfig.all[id]
    local inst = { i = self:alloc(), d = id, r = rarity or 1, x = 0, y = 0 }
    if def.stack > 1 then inst.n = n or def.stack end
    if def.kind == "armor" then inst.u = Items.armorStats(inst).durability end
    if def.kind == "backpack" then inst.c = {} end
    if def.kind == "weapon" then inst.a = Items.weaponStats(inst).magazine end
    return inst
end

--- The free kit: enough to go out and find better.
--- @return table[]
function Store:starterKit()
    return {
        self:item("p9", 1), self:item("ammo_light", 1, 48), self:item("bandage", 1, 2), self:item("sling", 1),
        self:item("frag", 1, 1)
    }
end

--- Equips a kit: weapons and bags in their slots, the rest in pockets and bag, and
--- utilities on the quick slots.
--- @param gear table
--- @param items table[]
--- @return table[] what did not fit
function Store:equip(gear, items)
    local places = Inventory.places(gear)
    local left = {}
    table.sort(items, function(a, b) return ItemConfig.all[a.d].kind == "backpack" and ItemConfig.all[b.d].kind ~= "backpack" end)
    for _, inst in ipairs(items) do
        local def = ItemConfig.all[inst.d]
        local refs = { "pk", "bp" }
        if def.kind == "weapon" then refs = { "primary", "secondary", "bp", "pk" } end
        if def.kind == "armor" then refs = { def.slot, "bp" } end
        if def.kind == "backpack" then refs = { "backpack" } end
        if not Inventory.give(places, inst, refs) then left[#left + 1] = inst end
        if def.kind == "backpack" then places = Inventory.places(gear) end
        if def.kind == "utility" then
            for k = 1, Config.quickSlots do
                if gear.quick[k] == 0 then gear.quick[k] = inst.i break end
                if gear.quick[k] == inst.i then break end
            end
        end
    end
    return left
end

--- @param key string
--- @param name string?
--- @return table
function Store:Get(key, name)
    local profile = self.players[key]
    if not profile then
        profile = sanitize({ n = name })
        local place = { kind = "grid", w = Config.stash.w, h = Config.stash.h, list = profile.stash }
        self:equip(profile.gear, self:starterKit())
        for _, extra in ipairs({ { "cap" }, { "scrap", 10 }, { "screws", 10 }, { "string", 6 }, { "cloth", 6 }, { "powder", 12 }, { "tape", 2 } }) do
            Inventory.give({ st = place }, self:item(extra[1], 1, extra[2]), { "st" })
        end
        self.players[key] = profile
    end
    for _, id in ipairs(ItemConfig.known) do
        profile.known[id] = math.max(profile.known[id] or 0, 1)
    end
    if name then profile.n = name end
    self.dirty = true
    return profile
end

return Store
