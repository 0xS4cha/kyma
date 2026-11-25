--- Item instances of the extraction mode: sizes, rarities, prices and the effective
--- stats of a weapon once its rarity and attachments are applied. Shared by the
--- server and the client, so the client predicts with the same numbers.
local Config = require("src.config.items")

local Items = {}

local floor, max, min = math.floor, math.max, math.min

Items.config = Config

--- @param inst table?
--- @return table?
function Items.def(inst)
    return inst and Config.all[inst.d] or nil
end

--- @param inst table
--- @return table
function Items.rarity(inst)
    local order = Config.rarities.order
    return Config.rarities[order[min(#order, max(1, inst.r or 1))]]
end

--- @param inst table
--- @return number, number width and height in grid cells, rotation applied
function Items.size(inst)
    local def = Items.def(inst)
    if not def then return 1, 1 end
    if inst.o == 1 then return def.h, def.w end
    return def.w, def.h
end

--- @param inst table
--- @return string
function Items.name(inst)
    local def = Items.def(inst)
    return def and def.name or "?"
end

--- How much an attachment's effect is multiplied by its rarity.
--- @param inst table
--- @return number
function Items.strength(inst)
    return 1 + (Items.rarity(inst).power - 1) * 2.5
end

local INTEGER = { magazine = true, reloadTicks = true, fireTicks = true, pellets = true }
-- Counts that a mythic attachment raises by one instead of scaling.
local INTEGER_TRAIT = { bounce = true, pierce = true }
local BASE = { "damage", "pellets", "spread", "range", "fireTicks", "auto", "magazine", "reloadTicks", "muzzle", "silent", "exposed", "speed" }

--- The stats a weapon shoots with: the base definition, scaled by rarity, then by
--- every attachment (whose effect itself grows with the attachment's rarity).
--- @param inst table weapon instance
--- @return table?
function Items.weaponStats(inst)
    local def = Items.def(inst)
    if not def or def.kind ~= "weapon" then return nil end
    local stats = { id = def.id, look = def.look, ammo = def.ammo, name = def.name }
    for _, key in ipairs(BASE) do stats[key] = def[key] end
    local power = Items.rarity(inst).power
    stats.damage = stats.damage * power
    stats.spread = stats.spread / power
    stats.reloadTicks = stats.reloadTicks / (1 + (power - 1) * 0.6)
    stats.magazine = stats.magazine * (1 + (power - 1) * 0.5)
    stats.range = stats.range * (1 + (power - 1) * 0.3)
    local sources = {}
    if def.set then sources[1] = { mod = { set = def.set }, s = 1 } end
    for _, slot in ipairs(Config.slots.order) do
        local attached = inst.m and inst.m[slot]
        local mod = Items.def(attached)
        if mod and mod.kind == "mod" then sources[#sources + 1] = { mod = mod, s = Items.strength(attached) } end
    end
    for _, source in ipairs(sources) do
        local mod, s = source.mod, source.s
        do
            for key, factor in pairs(mod.mul or {}) do
                if stats[key] then
                    local scaled = factor >= 1 and 1 + (factor - 1) * s or factor ^ s
                    stats[key] = stats[key] * scaled
                end
            end
            for key, value in pairs(mod.set or {}) do
                if type(value) == "number" and INTEGER_TRAIT[key] then
                    stats[key] = math.max(stats[key] or 0, value + (s >= 2 and 1 or 0))
                elseif type(value) == "number" then
                    if key == "haste" or key == "flesh" then
                        stats[key] = (stats[key] or 1) * (1 + (value - 1) * s)
                    elseif key == "armorPierce" and value < 0 then
                        stats[key] = value
                    else
                        stats[key] = value * s
                    end
                else
                    stats[key] = value
                end
            end
        end
    end
    for key in pairs(INTEGER) do
        stats[key] = floor(stats[key] + 0.5)
    end
    stats.fireTicks = max(2, stats.fireTicks)
    stats.magazine = max(1, stats.magazine)
    stats.reserve = 0
    return stats
end

--- @param weapon table
--- @param mod table
--- @return boolean, string?
function Items.canAttach(weapon, mod)
    local wdef, mdef = Items.def(weapon), Items.def(mod)
    if not wdef or wdef.kind ~= "weapon" or not mdef or mdef.kind ~= "mod" then return false, "Not an attachment" end
    local allowed = false
    for _, slot in ipairs(wdef.slots) do
        if slot == mdef.slot then allowed = true end
    end
    if not allowed then return false, "This weapon has no " .. Config.slots[mdef.slot]:lower() .. " slot" end
    if weapon.m and weapon.m[mdef.slot] then return false, "The " .. Config.slots[mdef.slot]:lower() .. " slot is taken" end
    local used = 0
    for _ in pairs(weapon.m or {}) do used = used + 1 end
    if used >= Items.rarity(weapon).slots then
        return false, Items.rarity(weapon).name .. " weapons take " .. Items.rarity(weapon).slots .. " attachment" .. (Items.rarity(weapon).slots > 1 and "s" or "")
    end
    return true
end

local SALVAGE_RATE = require("src.config.extraction").salvageRate

--- What recycling an item at the workbench gives back: part of its recipe at its
--- rarity (so rare items give rare parts), its attachments too; valuables have their
--- own table, ammo turns back into gunpowder. Materials and plans can't be recycled.
--- @param inst table
--- @return table[]? { id, n } materials, nil when it can't be recycled
function Items.salvage(inst)
    local def = Items.def(inst)
    if not def or def.kind == "material" or def.kind == "blueprint" then return nil end
    local totals, order = {}, {}
    local function add(id, n)
        if n <= 0 then return end
        if not totals[id] then order[#order + 1] = id end
        totals[id] = (totals[id] or 0) + n
    end
    local count = inst.n or 1
    if def.kind == "ammo" then
        add(def.caliber == "cell" and "battery" or (def.caliber == "fuel" and "fuelcan" or "powder"), math.max(1, floor(count / 8)))
    elseif def.kind == "valuable" then
        for _, part in ipairs(Config.salvage[def.id] or { { id = "scrap", n = 1 } }) do add(part.id, part.n * count) end
    else
        local recipe = Items.recipe(def.id, inst.r)
        for k, part in ipairs(recipe or {}) do
            add(part.id, math.max(k == 1 and 1 or 0, floor(part.n * SALVAGE_RATE)) * count)
        end
    end
    for _, attached in pairs(inst.m or {}) do
        for _, part in ipairs(Items.salvage(attached) or {}) do add(part.id, part.n) end
    end
    local out = {}
    for _, id in ipairs(order) do out[#out + 1] = { id = id, n = totals[id] } end
    return out
end

--- @param inst table
--- @return table armor stats, scaled by rarity
function Items.armorStats(inst)
    local def = Items.def(inst)
    if not def or def.kind ~= "armor" then return nil end
    local power = Items.rarity(inst).power
    return {
        reduce = min(0.75, def.reduce * power),
        durability = floor(def.durability * power + 0.5),
        flash = def.flash,
        haste = def.haste
    }
end

--- What crafting an item of a rarity costs: the base recipe scaled by rarity, plus
--- rare alloy from epic and glowing cores from legendary.
--- @param id string
--- @param rarity number
--- @return table[] { id, n }
function Items.recipe(id, rarity)
    local base = Config.recipes[id]
    if not base then return nil end
    local def = Config.all[id]
    rarity = def.kind == "ammo" and 1 or max(1, min(#Config.rarities.order, rarity or 1))
    local out = {}
    for _, part in ipairs(base) do
        out[#out + 1] = { id = part.id, n = math.ceil(part.n * (1 + (rarity - 1) * 0.75)) }
    end
    local function add(material, n)
        for _, part in ipairs(out) do
            if part.id == material then part.n = part.n + n return end
        end
        out[#out + 1] = { id = material, n = n }
    end
    if rarity >= 4 then add("alloy", rarity - 3) end
    if rarity >= 5 then add("core", rarity - 4) end
    return out
end

--- A deep copy of an instance, safe to send or store.
--- @param inst table
--- @return table
function Items.copy(inst)
    local out = {}
    for key, value in pairs(inst) do
        if key == "m" then
            out.m = {}
            for slot, attached in pairs(value) do out.m[slot] = Items.copy(attached) end
        elseif key == "c" then
            out.c = {}
            for k, inner in ipairs(value) do out.c[k] = Items.copy(inner) end
        else
            out[key] = value
        end
    end
    return out
end

--- Checks an instance read from disk or the network: known definition, sane numbers.
--- @param inst any
--- @param depth number?
--- @return table?
function Items.sanitize(inst, depth)
    depth = depth or 0
    if type(inst) ~= "table" or depth > 3 then return nil end
    local def = Config.all[inst.d]
    if not def or type(inst.i) ~= "number" then return nil end
    local out = {
        i = floor(inst.i), d = inst.d,
        r = max(1, min(#Config.rarities.order, floor(tonumber(inst.r) or 1))),
        x = floor(tonumber(inst.x) or 0), y = floor(tonumber(inst.y) or 0),
        o = inst.o == 1 and 1 or nil
    }
    if def.stack > 1 then out.n = max(1, min(def.stack, floor(tonumber(inst.n) or 1))) end
    if def.kind == "weapon" then
        out.a = max(0, floor(tonumber(inst.a) or 0))
        if type(inst.m) == "table" then
            out.m = {}
            for _, slot in ipairs(Config.slots.order) do
                local attached = Items.sanitize(inst.m[slot], depth + 1)
                if attached and Items.def(attached).kind == "mod" and Items.def(attached).slot == slot then
                    out.m[slot] = attached
                end
            end
        end
    elseif def.kind == "armor" then
        local stats = Items.armorStats(out)
        out.u = max(0, min(stats.durability, floor(tonumber(inst.u) or stats.durability)))
    elseif def.kind == "backpack" then
        out.c = {}
        for _, inner in ipairs(type(inst.c) == "table" and inst.c or {}) do
            local clean = Items.sanitize(inner, depth + 1)
            if clean and Items.def(clean).kind ~= "backpack" then out.c[#out.c + 1] = clean end
        end
    end
    return out
end

return Items
