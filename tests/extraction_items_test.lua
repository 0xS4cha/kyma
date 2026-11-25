local Items = require("src.game.extraction.items")
local Inventory = require("src.game.extraction.inventory")
local ItemConfig = require("src.config.items")
local Weapons = require("src.game.weapons")

local uid = 0
local function item(d, fields)
    uid = uid + 1
    local inst = { i = uid, d = d, r = 1, x = 0, y = 0 }
    for k, v in pairs(fields or {}) do inst[k] = v end
    return inst
end

local function gearWith(backpack)
    local gear = Inventory.newGear()
    gear.backpack = backpack and item(backpack, { c = {} }) or nil
    return gear
end

return {
    {
        name = "there are many weapons, attachments and utilities, each with a size",
        run = function()
            assert(#ItemConfig.weaponOrder >= 35 and #ItemConfig.modOrder >= 45 and #ItemConfig.utilityOrder >= 20)
            assert(#ItemConfig.materialOrder >= 18)
            for id, def in pairs(ItemConfig.all) do
                assert(def.w >= 1 and def.h >= 1 and def.price > 0, id)
                if def.kind == "weapon" then
                    assert(Weapons.def(def.look), id .. " has a model")
                    assert(ItemConfig.calibers[def.ammo], id .. " has a caliber")
                end
            end
            for id, parts in pairs(ItemConfig.salvage) do
                assert(ItemConfig.valuable[id], id)
                for _, part in ipairs(parts) do assert(ItemConfig.material[part.id], id .. " gives unknown " .. part.id) end
            end
            for _, id in ipairs(ItemConfig.craftOrder) do
                assert(#ItemConfig.recipes[id] > 0, id .. " has a recipe")
                for _, part in ipairs(ItemConfig.recipes[id]) do assert(ItemConfig.material[part.id], id .. " needs unknown " .. part.id) end
                if ItemConfig.all[id].kind ~= "ammo" then assert(ItemConfig.all["plan_" .. id], id .. " has a plan") end
            end
            for _, id in ipairs(ItemConfig.known) do assert(ItemConfig.recipes[id], id) end
            assert(#ItemConfig.rarities.order == 6)
        end
    },
    {
        name = "rarity and attachments change the weapon stats",
        run = function()
            local common = Items.weaponStats(item("ar", { r = 1 }))
            local legendary = Items.weaponStats(item("ar", { r = 5 }))
            assert(legendary.damage > common.damage and legendary.spread < common.spread and legendary.magazine >= common.magazine)
            local modded = item("ar", { r = 3, m = { mag = item("extended"), rounds = item("bouncing"), under = item("flashlight") } })
            local stats = Items.weaponStats(modded)
            assert(stats.magazine > Items.weaponStats(item("ar", { r = 3 })).magazine, "extended mag")
            assert(stats.bounce == 2 and stats.light == true)
            local suppressed = Items.weaponStats(item("hornet", { m = { muzzle = item("suppressor") } }))
            assert(suppressed.silent == true)
            local strong = Items.weaponStats(item("ar", { m = { mag = item("extended", { r = 5 }) } }))
            local weak = Items.weaponStats(item("ar", { m = { mag = item("extended", { r = 1 }) } }))
            assert(strong.magazine > weak.magazine, "a rarer attachment is stronger")
        end
    },
    {
        name = "the weapon stats drive the shared simulation",
        run = function()
            local p = { weapon = "ar", ammo = 3, reserve = 0, reload = 0, fireCooldown = 0, trigger = false, dash = 0, stun = 0, dead = 0, meleeCooldown = 0, angle = 0, x = 0, y = 0, slot = 1 }
            p.def = Items.weaponStats(item("ar", { m = { mag = item("drum") } }))
            assert(Weapons.stat(p, "magazine") == p.def.magazine)
            assert(Weapons.update(p, { b = 1 }) and p.ammo == 2 and p.fireCooldown == p.def.fireTicks)
        end
    },
    {
        name = "attachments need a free slot the weapon has, and rarity limits how many",
        run = function()
            local pistol = item("p9", { r = 1 })
            assert(not Items.canAttach(pistol, item("longbarrel")), "pistols have no barrel slot")
            assert(Items.canAttach(pistol, item("reddot")))
            pistol.m = { optic = item("reddot") }
            local ok, err = Items.canAttach(pistol, item("grip"))
            assert(not ok and err:find("Common"), "a common weapon takes one attachment")
            local rare = item("ar", { r = 3, m = { optic = item("reddot") } })
            assert(not Items.canAttach(rare, item("scope")), "slot taken")
            assert(Items.canAttach(rare, item("grip")))
        end
    },
    {
        name = "items move, rotate and stack in grids",
        run = function()
            local gear = gearWith("raid")
            local places = Inventory.places(gear)
            local rifle = item("ar")
            assert(Inventory.give(places, rifle, { "bp" }) == "bp")
            assert(rifle.x == 0 and rifle.y == 0)
            local ok = Inventory.move(places, rifle.i, "bp", 4, 0, 1)
            assert(not ok, "a rotated 2x4 rifle does not fit at column 4 of a 5 wide bag")
            assert(Inventory.move(places, rifle.i, "bp", 0, 1, 1), "rotated at 0,1")
            local w, h = Items.size(rifle)
            assert(w == 2 and h == 4)
            local a, b = item("ammo_medium", { n = 30 }), item("ammo_medium", { n = 20 })
            assert(Inventory.give(places, a, { "pk" }) == "pk")
            assert(Inventory.give(places, b, { "pk" }) == "pk")
            assert(a.n == 40 and Inventory.count(places, "ammo_medium") == 50, "stacks merge up to 40")
            assert(Inventory.consume(places, "ammo_medium", 25) == 25 and Inventory.count(places, "ammo_medium") == 25)
            assert(not Inventory.move(places, gear.backpack.i, "bp", 0, 0), "a backpack does not go in itself")
        end
    },
    {
        name = "equipping swaps with what was in the slot",
        run = function()
            local gear = gearWith("sling")
            local places = Inventory.places(gear)
            local first, second = item("p9"), item("revolver")
            Inventory.give(places, first, { "primary" })
            assert(gear.primary == first)
            Inventory.give(places, second, { "pk" })
            assert(Inventory.move(places, second.i, "primary"))
            assert(gear.primary == second, "equipped")
            assert(gear.pockets[1] == first, "the old weapon went where the new one was")
            assert(not Inventory.move(places, first.i, "helmet"), "a weapon is not a helmet")
            local mod = item("reddot")
            Inventory.give(places, mod, { "pk" })
            assert(Inventory.attach(places, mod.i, second.i))
            assert(second.m.optic == mod and #gear.pockets == 1)
            assert(Inventory.move(places, mod.i, "pk", 2, 0), "detaching moves it out")
            assert(not second.m.optic)
        end
    },
    {
        name = "crafting a rarer item costs more and needs rare parts",
        run = function()
            local common, epic, legendary = Items.recipe("ar", 1), Items.recipe("ar", 4), Items.recipe("ar", 5)
            local function count(list, id)
                for _, part in ipairs(list) do if part.id == id then return part.n end end
                return 0
            end
            assert(count(epic, "scrap") > count(common, "scrap"))
            assert(count(common, "alloy") == 0 and count(epic, "alloy") == 1 and count(legendary, "core") == 1)
            assert(#Items.recipe("ammo_light", 5) == #Items.recipe("ammo_light", 1), "ammo has no rarity")
            local railgun = Items.weaponStats(item("railgun"))
            assert(railgun.pierce >= 3 and railgun.chain, "built-in traits")
            local mythic = Items.weaponStats(item("ar", { m = { rounds = item("bouncing", { r = 6 }) } }))
            assert(mythic.bounce == 3, "a mythic attachment adds a bounce")
        end
    },
    {
        name = "recycling gives back part of the recipe, rarer items give rarer parts",
        run = function()
            local function count(list, id)
                for _, part in ipairs(list) do if part.id == id then return part.n end end
                return 0
            end
            local common, legendary = Items.salvage(item("ar", { r = 1 })), Items.salvage(item("ar", { r = 5 }))
            assert(count(common, "scrap") > 0 and count(common, "alloy") == 0)
            assert(count(legendary, "alloy") >= 1 and count(legendary, "scrap") > count(common, "scrap"))
            local modded = Items.salvage(item("ar", { m = { optic = item("scope") } }))
            assert(count(modded, "lens") > 0, "attachments are recycled with the weapon")
            assert(count(Items.salvage(item("gpu", { n = 1 })), "circuit") == 3)
            assert(count(Items.salvage(item("ammo_light", { n = 40 })), "powder") == 5)
            assert(Items.salvage(item("scrap", { n = 3 })) == nil and Items.salvage(item("plan_ar")) == nil)
        end
    },
    {
        name = "values, copies and sanitizing",
        run = function()
            local weapon = item("ar", { r = 4, a = 12, m = { optic = item("scope") } })
            local copy = Items.copy(weapon)
            assert(copy ~= weapon and copy.m.optic ~= weapon.m.optic and copy.m.optic.d == "scope")
            assert(Items.sanitize({ i = 1, d = "nope" }) == nil)
            local clean = Items.sanitize({ i = 4, d = "ammo_light", n = 9999, r = 99 })
            assert(clean.n == 40 and clean.r == 6)
            local gear = Inventory.sanitizeGear({ primary = { i = 5, d = "vest" }, helmet = { i = 6, d = "helmet" }, quick = { "x", 7 } })
            assert(gear.primary == nil and gear.helmet.d == "helmet" and gear.quick[1] == 0 and gear.quick[2] == 7)
        end
    }
}
