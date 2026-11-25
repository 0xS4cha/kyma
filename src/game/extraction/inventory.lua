--- Grid inventories in the style of Tarkov: every item takes w x h cells, can be
--- rotated, stacks merge, weapons hold attachments and a backpack holds a grid.
--- The functions work on "places": a table of ref -> place, where a place is a grid
--- { kind = "grid", w, h, list } or an equipment slot { kind = "slot", accept, get, set }.
local Items = require("src.game.extraction.items")
local Config = require("src.config.extraction")

local Inventory = {}

local EQUIPMENT = { "primary", "secondary", "helmet", "vest", "backpack" }
Inventory.EQUIPMENT = EQUIPMENT

--- @return table empty gear
function Inventory.newGear()
    local quick = {}
    for k = 1, Config.quickSlots do quick[k] = 0 end
    return { pockets = {}, quick = quick }
end

local ACCEPT = {
    primary = function(def) return def.kind == "weapon" end,
    secondary = function(def) return def.kind == "weapon" end,
    helmet = function(def) return def.kind == "armor" and def.slot == "helmet" end,
    vest = function(def) return def.kind == "armor" and def.slot == "vest" end,
    backpack = function(def) return def.kind == "backpack" end
}

--- @param gear table
--- @param name string
--- @return table
local function slotPlace(gear, name)
    return {
        kind = "slot", name = name,
        accept = function(inst)
            local def = Items.def(inst)
            if def and ACCEPT[name](def) then return true end
            return false, "That does not go there"
        end,
        get = function() return gear[name] end,
        set = function(inst) gear[name] = inst end
    }
end

--- The places of a character: pockets, backpack grid and equipment slots, plus extra
--- places such as the stash or an open container.
--- @param gear table
--- @param extra table? ref -> place
--- @return table
function Inventory.places(gear, extra)
    local places = {}
    places.pk = { kind = "grid", w = Config.pockets.w, h = Config.pockets.h, list = gear.pockets }
    local bag = gear.backpack
    local bagDef = Items.def(bag)
    if bagDef then
        bag.c = bag.c or {}
        places.bp = { kind = "grid", w = bagDef.grid[1], h = bagDef.grid[2], list = bag.c, bag = true }
    end
    for _, name in ipairs(EQUIPMENT) do places[name] = slotPlace(gear, name) end
    for ref, place in pairs(extra or {}) do places[ref] = place end
    return places
end

--- @param list table[]
--- @param w number
--- @param h number
--- @param iw number
--- @param ih number
--- @param x number
--- @param y number
--- @param ignore table?
--- @return boolean
function Inventory.fits(list, w, h, iw, ih, x, y, ignore)
    if x < 0 or y < 0 or x + iw > w or y + ih > h then return false end
    for _, other in ipairs(list) do
        if other ~= ignore then
            local ow, oh = Items.size(other)
            if x < other.x + ow and other.x < x + iw and y < other.y + oh and other.y < y + ih then
                return false
            end
        end
    end
    return true
end

--- First free spot for an item in a grid, trying both orientations.
--- @param place table grid place
--- @param inst table
--- @return number?, number?, number? x, y, rotation
function Inventory.free(place, inst)
    local def = Items.def(inst)
    for _, o in ipairs(def.w ~= def.h and { 0, 1 } or { 0 }) do
        local iw, ih = def.w, def.h
        if o == 1 then iw, ih = ih, iw end
        for y = 0, place.h - ih do
            for x = 0, place.w - iw do
                if Inventory.fits(place.list, place.w, place.h, iw, ih, x, y) then return x, y, o end
            end
        end
    end
    return nil
end

--- Finds an item anywhere in the places, attachments included.
--- @param places table
--- @param uid number
--- @return table? location { inst, ref, place, index, weapon, slot }
function Inventory.locate(places, uid)
    local function inWeapon(weapon, ref, place)
        for slot, attached in pairs(weapon.m or {}) do
            if attached.i == uid then return { inst = attached, ref = ref, place = place, weapon = weapon, slot = slot } end
        end
    end
    for ref, place in pairs(places) do
        if place.kind == "grid" then
            for k, inst in ipairs(place.list) do
                if inst.i == uid then return { inst = inst, ref = ref, place = place, index = k } end
                local found = inWeapon(inst, ref, place)
                if found then return found end
            end
        else
            local inst = place.get()
            if inst then
                if inst.i == uid then return { inst = inst, ref = ref, place = place } end
                local found = inWeapon(inst, ref, place)
                if found then return found end
            end
        end
    end
    return nil
end

--- @param loc table
local function detach(loc)
    if loc.weapon then
        loc.weapon.m[loc.slot] = nil
    elseif loc.place.kind == "grid" then
        for k, inst in ipairs(loc.place.list) do
            if inst == loc.inst then
                table.remove(loc.place.list, k)
                loc.index = k
                return
            end
        end
    else
        loc.place.set(nil)
    end
end

--- @param loc table
local function restore(loc)
    if loc.weapon then
        loc.weapon.m[loc.slot] = loc.inst
    elseif loc.place.kind == "grid" then
        table.insert(loc.place.list, math.min(loc.index or 1, #loc.place.list + 1), loc.inst)
    else
        loc.place.set(loc.inst)
    end
end

--- Takes an item out of wherever it is.
--- @param places table
--- @param uid number
--- @return table? inst, table? loc
function Inventory.take(places, uid)
    local loc = Inventory.locate(places, uid)
    if not loc then return nil end
    detach(loc)
    return loc.inst, loc
end

--- @param place table grid
--- @param inst table
--- @param x number
--- @param y number
--- @return number moved count merged into a stack at x, y
local function mergeAt(place, inst, x, y)
    local def = Items.def(inst)
    if def.stack <= 1 then return 0 end
    for _, other in ipairs(place.list) do
        if other ~= inst and other.d == inst.d and other.x == x and other.y == y and (other.n or 1) < def.stack then
            local moved = math.min(def.stack - (other.n or 1), inst.n or 1)
            other.n = (other.n or 1) + moved
            return moved
        end
    end
    return 0
end

--- Can this item go into this grid? Backpacks never go in the equipped backpack.
--- @param place table
--- @param inst table
--- @return boolean, string?
local function allowed(place, inst)
    if place.bag and Items.def(inst).kind == "backpack" then return false, "A backpack cannot go in a backpack" end
    if place.accept then return place.accept(inst) end
    return true
end

--- Moves an item to a grid cell or an equipment slot. Dropping a stack on a stack of
--- the same item merges them; dropping on an occupied slot swaps when the old item
--- fits where the new one came from.
--- @param places table
--- @param uid number
--- @param to string ref of the destination
--- @param x number?
--- @param y number?
--- @param o number? 1 rotated
--- @return boolean, string?
function Inventory.move(places, uid, to, x, y, o)
    local dst = places[to]
    if not dst then return false, "Nowhere to put it" end
    local loc = Inventory.locate(places, uid)
    if not loc then return false, "Item not found" end
    local inst = loc.inst
    if dst.kind == "slot" then
        local ok, err = dst.accept(inst)
        if not ok then return false, err end
        local current = dst.get()
        if current == inst then return true end
        detach(loc)
        if current then
            if current.c and loc.place.bag then
                restore(loc)
                return false, "Empty the slot first"
            end
            dst.set(nil)
            local back = false
            if loc.weapon then
                back = false
            elseif loc.place.kind == "grid" then
                local fx, fy, fo = Inventory.free(loc.place, current)
                if fx and allowed(loc.place, current) then
                    current.x, current.y, current.o = fx, fy, fo == 1 and 1 or nil
                    loc.place.list[#loc.place.list + 1] = current
                    back = true
                end
            elseif loc.place.accept(current) then
                loc.place.set(current)
                back = true
            end
            if not back then
                dst.set(current)
                restore(loc)
                return false, "No room to swap"
            end
        end
        inst.x, inst.y, inst.o = 0, 0, nil
        dst.set(inst)
        return true
    end
    local ok, err = allowed(dst, inst)
    if not ok then return false, err end
    if inst.c and dst.list == inst.c then return false, "Not inside itself" end
    x, y = math.floor(tonumber(x) or -1), math.floor(tonumber(y) or -1)
    local merged = mergeAt(dst, inst, x, y)
    if merged > 0 then
        inst.n = (inst.n or 1) - merged
        if inst.n <= 0 then detach(loc) end
        return true
    end
    local oldX, oldY, oldO = inst.x, inst.y, inst.o
    detach(loc)
    inst.o = o == 1 and 1 or nil
    local iw, ih = Items.size(inst)
    if not Inventory.fits(dst.list, dst.w, dst.h, iw, ih, x, y) then
        inst.x, inst.y, inst.o = oldX, oldY, oldO
        restore(loc)
        return false, "It does not fit there"
    end
    inst.x, inst.y = x, y
    dst.list[#dst.list + 1] = inst
    return true
end

--- Puts an item in the first place that takes it, merging stacks first.
--- @param places table
--- @param inst table
--- @param refs string[] places to try, in order
--- @return string? ref where it went (nil when some or all of it did not fit)
function Inventory.give(places, inst, refs)
    local def = Items.def(inst)
    if not def then return nil end
    if def.stack > 1 then
        for _, ref in ipairs(refs) do
            local place = places[ref]
            if place and place.kind == "grid" and allowed(place, inst) then
                for _, other in ipairs(place.list) do
                    if other.d == inst.d and (other.n or 1) < def.stack and (inst.n or 1) > 0 then
                        local moved = math.min(def.stack - (other.n or 1), inst.n or 1)
                        other.n = (other.n or 1) + moved
                        inst.n = (inst.n or 1) - moved
                    end
                end
                if (inst.n or 1) <= 0 then return ref end
            end
        end
    end
    for _, ref in ipairs(refs) do
        local place = places[ref]
        if place and place.kind == "grid" and allowed(place, inst) then
            local x, y, o = Inventory.free(place, inst)
            if x then
                inst.x, inst.y, inst.o = x, y, o == 1 and 1 or nil
                place.list[#place.list + 1] = inst
                return ref
            end
        elseif place and place.kind == "slot" and not place.get() and place.accept(inst) then
            inst.x, inst.y, inst.o = 0, 0, nil
            place.set(inst)
            return ref
        end
    end
    return nil
end

--- Attaches a mod to a weapon. The mod comes from any place.
--- @param places table
--- @param modUid number
--- @param weaponUid number
--- @return boolean, string?
function Inventory.attach(places, modUid, weaponUid)
    local wloc, mloc = Inventory.locate(places, weaponUid), Inventory.locate(places, modUid)
    if not wloc or not mloc then return false, "Item not found" end
    local ok, err = Items.canAttach(wloc.inst, mloc.inst)
    if not ok then return false, err end
    detach(mloc)
    wloc.inst.m = wloc.inst.m or {}
    wloc.inst.m[Items.def(mloc.inst).slot] = mloc.inst
    return true
end

--- Total count of an item definition in the carried grids.
--- @param places table
--- @param id string
--- @return number
function Inventory.count(places, id)
    local total = 0
    for _, ref in ipairs({ "pk", "bp" }) do
        local place = places[ref]
        if place then
            for _, inst in ipairs(place.list) do
                if inst.d == id then total = total + (inst.n or 1) end
            end
        end
    end
    return total
end

--- Removes up to n of an item definition from the carried grids, smallest stacks first.
--- @param places table
--- @param id string
--- @param n number
--- @return number removed
function Inventory.consume(places, id, n)
    local stacks = {}
    for _, ref in ipairs({ "pk", "bp" }) do
        local place = places[ref]
        if place then
            for _, inst in ipairs(place.list) do
                if inst.d == id then stacks[#stacks + 1] = { inst = inst, place = place } end
            end
        end
    end
    table.sort(stacks, function(a, b) return (a.inst.n or 1) < (b.inst.n or 1) end)
    local removed = 0
    for _, entry in ipairs(stacks) do
        if removed >= n then break end
        local take = math.min(n - removed, entry.inst.n or 1)
        entry.inst.n = (entry.inst.n or 1) - take
        removed = removed + take
        if entry.inst.n <= 0 then
            for k, inst in ipairs(entry.place.list) do
                if inst == entry.inst then table.remove(entry.place.list, k) break end
            end
        end
    end
    return removed
end

--- Every instance carried by a gear: equipment, grids and attachments.
--- @param gear table
--- @return table[]
function Inventory.all(gear)
    local out = {}
    local function add(inst)
        if not inst then return end
        out[#out + 1] = inst
        for _, attached in pairs(inst.m or {}) do out[#out + 1] = attached end
        for _, inner in ipairs(inst.c or {}) do add(inner) end
    end
    for _, name in ipairs(EQUIPMENT) do add(gear[name]) end
    for _, inst in ipairs(gear.pockets or {}) do add(inst) end
    return out
end

--- The gear stripped of everything into a flat list (for a corpse or a summary).
--- @param gear table
--- @return table[]
function Inventory.empty(gear)
    local out = {}
    for _, name in ipairs(EQUIPMENT) do
        if gear[name] then out[#out + 1] = gear[name] end
        gear[name] = nil
    end
    for _, inst in ipairs(gear.pockets or {}) do out[#out + 1] = inst end
    gear.pockets = {}
    for k = 1, Config.quickSlots do gear.quick[k] = 0 end
    return out
end

--- Sanitizes a gear table read from disk or the network.
--- @param raw any
--- @return table
function Inventory.sanitizeGear(raw)
    local gear = Inventory.newGear()
    if type(raw) ~= "table" then return gear end
    for _, name in ipairs(EQUIPMENT) do
        local inst = Items.sanitize(raw[name])
        if inst and ACCEPT[name](Items.def(inst)) then gear[name] = inst end
    end
    for _, inst in ipairs(type(raw.pockets) == "table" and raw.pockets or {}) do
        local clean = Items.sanitize(inst)
        if clean then gear.pockets[#gear.pockets + 1] = clean end
    end
    for k = 1, Config.quickSlots do
        local uid = type(raw.quick) == "table" and tonumber(raw.quick[k]) or nil
        gear.quick[k] = uid and math.floor(uid) or 0
    end
    return gear
end

return Inventory
