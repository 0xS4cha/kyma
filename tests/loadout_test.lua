local World = require("src.game.world")
local Arena = require("src.game.arena")
local Maps = require("src.maps.index")
local Weapons = require("src.game.weapons")
local WeaponConfig = require("src.config.weapons")
local Loadout = require("src.config.loadout")
local Settings = require("src.modules.menu.settings")

local function index(kind)
    for k, id in ipairs(WeaponConfig.order) do if id == kind then return k end end
end

local function mod(id)
    for k, m in ipairs(Loadout.mods) do if m.id == id then return k end end
end

local function world(rules, mode)
    return World.new(Arena.new(Maps.get("atrium")), mode or "duel", false, rules)
end

return {
    {
        name = "by default players start with a pistol and weapons on the floor",
        run = function()
            local w = world(nil)
            local p = w:add(1, "A", nil, { w = index("rifle"), m = 1 })
            assert(p.weapon == "pistol" and not p.mod)
            local weapons = 0
            for _, pad in ipairs(w.pads) do if Weapons.def(pad.kind) then weapons = weapons + 1 end end
            assert(weapons > 0)
        end
    },
    {
        name = "own loadout gives each player their weapon and mod",
        run = function()
            local w = world({ s = 2 })
            local a = w:add(1, "A", nil, { w = index("shotgun"), m = mod("extended") })
            local b = w:add(2, "B", nil, { w = index("sniper"), m = 1 })
            assert(a.weapon == "shotgun" and a.ammo == math.floor(WeaponConfig.shotgun.magazine * 1.5 + 0.5))
            assert(b.weapon == "sniper" and b.ammo == WeaponConfig.sniper.magazine and not b.mod)
        end
    },
    {
        name = "a set loadout overrides what players bring",
        run = function()
            local w = world({ s = 3, p = { w = index("lmg"), m = mod("hands") } })
            local a = w:add(1, "A", nil, { w = index("pistol"), m = 1 })
            assert(a.weapon == "lmg" and Weapons.stat(a, "reloadTicks") < WeaponConfig.lmg.reloadTicks)
        end
    },
    {
        name = "without floor weapons only ammo and health stay on the map",
        run = function()
            local w = world({ f = false, s = 2 })
            assert(#w.pads > 0)
            for _, pad in ipairs(w.pads) do assert(not Weapons.def(pad.kind), pad.kind) end
        end
    },
    {
        name = "mods change the weapon only while you hold it",
        run = function()
            local p = { weapon = "rifle", mod = mod("steady"), modWeapon = "rifle" }
            assert(Weapons.stat(p, "spread") == WeaponConfig.rifle.spread * 0.5)
            p.weapon = "pistol"
            assert(Weapons.stat(p, "spread") == WeaponConfig.pistol.spread)
            local pouch = { weapon = "pistol", mod = mod("pouch"), modWeapon = "pistol" }
            assert(Weapons.stat(pouch, "reserve") == WeaponConfig.pistol.reserve * 1.5)
        end
    },
    {
        name = "you get your loadout back when you respawn and your mod in your snapshot",
        run = function()
            local w = world({ s = 2 })
            local a = w:add(1, "A", nil, { w = index("rifle"), m = mod("extended") })
            Weapons.give(a, nil)
            w:loadout(a)
            assert(a.weapon == "rifle")
            local view = w:snapshot(1)
            assert(view.players[1].md == mod("extended") and Weapons.unpack(view.players[1].mw) == "rifle")
        end
    },
    {
        name = "gun game ignores the loadout rules",
        run = function()
            local w = world({ s = 2 }, "gungame")
            local a = w:add(1, "A", nil, { w = index("sniper"), m = 1 })
            assert(a.weapon == "pistol")
        end
    },
    {
        name = "broken loadouts and rules are cleaned up",
        run = function()
            local kit = Loadout.sanitize({ w = 99, m = -3 })
            assert(kit.w == 1 and kit.m == 1)
            local rules = Loadout.rules({ s = 9, f = "yes" })
            assert(rules.spawn == "pistol" and rules.loot == true)
            local values = Settings.parse("kitWeapon=40\nspawnWith=7\nfloorWeapons=false\n")
            assert(values.kitWeapon == 1 and values.spawnWith == 1 and values.floorWeapons == false)
            local packed = Settings.matchRules(values)
            assert(packed.f == false and packed.s == 1)
        end
    },
    {
        name = "each weapon keeps its own mod",
        run = function()
            local values = Settings.parse(nil)
            values.kitMods = Settings.withMod(values.kitMods, index("rifle"), mod("extended"))
            values.kitMods = Settings.withMod(values.kitMods, index("shotgun"), mod("steady"))
            assert(Settings.modAt(values.kitMods, index("rifle")) == mod("extended"))
            assert(Settings.modAt(values.kitMods, index("shotgun")) == mod("steady"))
            assert(Settings.modAt(values.kitMods, index("pistol")) == 1, "others untouched")
            values.kitWeapon = index("shotgun")
            local kit = Settings.kit(values)
            assert(kit.w == index("shotgun") and kit.m == mod("steady"))
            local saved = Settings.parse(Settings.serialize(values))
            assert(saved.kitMods == values.kitMods, "saved per weapon")
            assert(Settings.cleanMods("9,x,3") == "1,1,3" .. string.rep(",1", #WeaponConfig.order - 3))
        end
    },
    {
        name = "the set loadout keeps its own mods too",
        run = function()
            local values = Settings.parse(nil)
            values.presetWeapon = index("lmg")
            values.presetMods = Settings.withMod(values.presetMods, index("lmg"), mod("hands"))
            local rules = Settings.matchRules(values)
            assert(rules.p.w == index("lmg") and rules.p.m == mod("hands"))
            assert(Settings.kit(values).m == 1, "your own loadout is separate")
        end
    },
    {
        name = "a loadout changed during the match applies at the next respawn",
        run = function()
            local Room = require("src.server.room")
            local Combat = require("src.game.combat")
            local Config = require("src.config.game")
            local w = world({ s = 2 })
            local p = w:add(1, "A", nil, { w = index("rifle"), m = 1 })
            w:add(2, "B", nil, { w = index("pistol"), m = 1 })
            local client = { slot = 1, loadout = Loadout.sanitize({ w = index("sniper"), m = mod("extended") }) }
            Room.Kit({ world = w }, client)
            assert(p.weapon == "rifle" and not p.mod, "nothing changes until the player respawns")
            Combat.kill(w, p, 2)
            for k = 1, Config.respawnTicks + 2 do
                w:queue(1, { { s = k, f = 0, r = 0, a = 0, d = 0, b = 0, l = 0, t = 0, e = 0, k = 0 } })
                w:step()
            end
            assert(p.dead == 0, "respawned")
            assert(p.weapon == "sniper" and p.ammo == math.floor(WeaponConfig.sniper.magazine * 1.5 + 0.5),
                "the new loadout: " .. tostring(p.weapon) .. " " .. tostring(p.ammo))
        end
    },
    {
        name = "trade-off mods give something and cost something",
        run = function()
            local rifle = WeaponConfig.rifle
            local drum = { weapon = "rifle", mod = mod("drum"), modWeapon = "rifle" }
            assert(Weapons.stat(drum, "magazine") == rifle.magazine * 2)
            assert(Weapons.stat(drum, "reloadTicks") > rifle.reloadTicks)
            local hair = { weapon = "rifle", mod = mod("hair"), modWeapon = "rifle" }
            assert(Weapons.stat(hair, "fireTicks") < rifle.fireTicks and Weapons.stat(hair, "spread") > rifle.spread)
            local heavy = { weapon = "rifle", mod = mod("heavy"), modWeapon = "rifle" }
            assert(Weapons.stat(heavy, "damage") > rifle.damage and Weapons.stat(heavy, "fireTicks") > rifle.fireTicks)
            -- Damage per second stays close: more per shot, fewer shots.
            local dps = rifle.damage / rifle.fireTicks
            local heavyDps = Weapons.stat(heavy, "damage") / Weapons.stat(heavy, "fireTicks")
            assert(math.abs(heavyDps - dps) / dps < 0.15, dps .. " vs " .. heavyDps)
            for _, kind in ipairs(WeaponConfig.order) do
                local p = { weapon = kind, mod = mod("hair"), modWeapon = kind }
                assert(Weapons.stat(p, "fireTicks") >= 1)
            end
        end
    },
    {
        name = "a heavy rounds rifle fires at its own pace without tripping the anticheat",
        run = function()
            local w = world({ s = 2 })
            local p = w:add(1, "A", nil, { w = index("rifle"), m = mod("heavy") })
            p.ammo = Weapons.stat(p, "magazine")
            local AntiCheat = require("src.game.anticheat")
            local shots = 0
            for k = 1, 60 do
                local previous = { x = p.x, y = p.y }
                if require("src.game.player").step(p, { s = k, f = 0, r = 0, a = 0, d = 0, b = 1, l = 0, t = 0, e = 0, k = 0, x = 0, y = 0 }, w.arena, w.dt) then shots = shots + 1 end
                assert(not AntiCheat.validate(p, previous, w), "tick " .. k)
            end
            assert(shots > 0 and shots <= math.ceil(60 / Weapons.stat(p, "fireTicks")), "shots " .. shots)
        end
    }
}
