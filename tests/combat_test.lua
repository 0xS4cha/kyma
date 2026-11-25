local Arena = require("src.game.arena")
local Player = require("src.game.player")
local World = require("src.game.world")
local Weapons = require("src.game.weapons")
local Vision = require("src.game.vision")
local Inputs = require("src.net.inputs")
local Config = require("src.config.game")
local WeaponConfig = require("src.config.weapons")
local NetConfig = require("src.net.config")

local DT = 1 / NetConfig.tickRate

local function open(extra)
    local def = {
        width = 4000, height = 4000, walls = extra or {},
        spawns = { { x = 1000, y = 1000, angle = 0 }, { x = 1300, y = 1000, angle = math.pi } }
    }
    return World.new(Arena.new(def))
end

local function duel(extra)
    local world = open(extra)
    world:add(1, "a")
    world:add(2, "b")
    return world, world.players[1], world.players[2]
end

local sequences = {}

local function command(slot, fields)
    sequences[slot] = (sequences[slot] or 0) + 1
    local c = { s = sequences[slot], f = 0, r = 0, a = Player.packAngle(fields.angle or 0), d = 0, b = 0, l = 0, t = 0, e = 0 }
    for k, v in pairs(fields) do
        if k ~= "angle" then c[k] = v end
    end
    return c
end

local function tick(world, a, b)
    sequences = sequences or {}
    world:queue(1, { a or command(1, {}) })
    world:queue(2, { b or command(2, { angle = math.pi }) })
    world:step()
end

return {
    {
        name = "pistol fires once per click, spends ammo and needs the trigger released",
        run = function()
            sequences = {}
            local world, a = duel()
            tick(world, command(1, { b = 1 }))
            assert(a.ammo == WeaponConfig.pistol.magazine - 1, "ammo " .. a.ammo)
            for _ = 1, 30 do tick(world, command(1, { b = 1 })) end
            assert(a.ammo == WeaponConfig.pistol.magazine - 1, "holding does not fire again")
            tick(world, command(1, {}))
            tick(world, command(1, { b = 1 }))
            assert(a.ammo == WeaponConfig.pistol.magazine - 2, "fires again after release")
        end
    },
    {
        name = "rifle fires automatically at its fire rate",
        run = function()
            sequences = {}
            local world, a = duel()
            Weapons.give(a, "rifle")
            for _ = 1, 60 do tick(world, command(1, { b = 1, angle = math.pi / 2 })) end
            local shots = WeaponConfig.rifle.magazine - a.ammo
            assert(shots == math.ceil(60 / WeaponConfig.rifle.fireTicks), "shots " .. shots)
        end
    },
    {
        name = "reload moves ammo from the reserve after the reload time",
        run = function()
            sequences = {}
            local world, a = duel()
            Weapons.give(a, "pistol", 2, 10)
            tick(world, command(1, { l = 1 }))
            assert(a.reload > 0)
            for _ = 1, WeaponConfig.pistol.reloadTicks do tick(world) end
            assert(a.ammo == WeaponConfig.pistol.magazine and a.reserve == 4, a.ammo .. " / " .. a.reserve)
        end
    },
    {
        name = "an empty magazine reloads by itself and cannot fire meanwhile",
        run = function()
            sequences = {}
            local world, a = duel()
            Weapons.give(a, "pistol", 1, 8)
            tick(world, command(1, { b = 1, angle = math.pi / 2 }))
            assert(a.ammo == 0 and a.reload > 0, "auto reload")
            tick(world, command(1, {}))
            tick(world, command(1, { b = 1, angle = math.pi / 2 }))
            assert(a.ammo == 0, "no shot while reloading")
        end
    },
    {
        name = "a shot damages the opponent and three pistol hits kill",
        run = function()
            sequences = {}
            local world, a, b = duel()
            for _ = 1, 3 do
                tick(world, command(1, { b = 1 }))
                for _ = 1, WeaponConfig.pistol.fireTicks do tick(world, command(1, {})) end
            end
            assert(b.hp == 0 and b.dead > 0, "hp " .. b.hp)
            assert(world.score[1] == 1)
            local events = world:drain()
            local kinds = {}
            for _, e in ipairs(events) do kinds[e.kind] = (kinds[e.kind] or 0) + 1 end
            assert(kinds.hit == 3 and kinds.kill == 1)
            local kinds = {}
            for _, item in ipairs(world.items) do kinds[item.kind] = true end
            assert(not b.weapon and #world.items == 1 and kinds.ammo and not kinds.pistol, "the dead player drops ammo but not their pistol")
        end
    },
    {
        name = "dead players respawn with a pistol",
        run = function()
            sequences = {}
            local world, a, b = duel()
            b.hp = 1
            tick(world, command(1, { b = 1 }))
            assert(b.dead > 0)
            for _ = 1, Config.respawnTicks + 2 do tick(world, command(1, {})) end
            assert(b.hp == Config.health and b.dead == 0 and b.weapon == "pistol")
            assert(b.x == 1300 and b.y == 1000)
        end
    },
    {
        name = "dashing players can't shoot and bullets pass through them",
        run = function()
            sequences = {}
            local world, a, b = duel()
            tick(world, command(1, {}), command(2, { d = 1, f = 1, angle = math.pi }))
            assert(b.dash > 0 and math.abs(b.y - 1000) < Config.player.radius, "still in the line of fire")
            local shot = command(1, { b = 1 })
            shot.v = world.tick
            tick(world, shot, command(2, { angle = math.pi }))
            assert(a.ammo == WeaponConfig.pistol.magazine - 1, "the shot was fired")
            assert(b.hp == Config.health, "dashing target is not hit")

            for _ = 1, WeaponConfig.pistol.fireTicks do tick(world, command(1, {})) end
            tick(world, command(1, { d = 1, angle = math.pi / 2 }))
            local ammo = a.ammo
            tick(world, command(1, { b = 1, angle = math.pi / 2 }))
            assert(a.ammo == ammo, "no shot during the dash")
        end
    },
    {
        name = "lag compensation hits where the shooter saw the target",
        run = function()
            sequences = {}
            local world, a, b = duel()
            for _ = 1, 10 do tick(world) end
            local seen = world.tick
            for _ = 1, 12 do tick(world, command(1, {}), command(2, { angle = math.pi / 2, f = 1 })) end
            assert(b.y > 1000 + 30, "target moved out of the line")
            local fire = command(1, { b = 1 })
            fire.v = seen
            tick(world, fire, command(2, { angle = math.pi / 2 }))
            assert(b.hp < Config.health, "rewound hit")

            local miss = command(1, {})
            tick(world, miss, command(2, { angle = math.pi / 2 }))
            for _ = 1, WeaponConfig.pistol.fireTicks do tick(world, command(1, {}), command(2, { angle = math.pi / 2 })) end
            local hp = b.hp
            local late = command(1, { b = 1 })
            late.v = world.tick
            tick(world, late, command(2, { angle = math.pi / 2 }))
            assert(b.hp == hp, "a shot at the current time misses the moved target")
        end
    },
    {
        name = "walls stop bullets",
        run = function()
            sequences = {}
            local world, a, b = duel({ { x = 1140, y = 900, w = 20, h = 200 } })
            tick(world, command(1, { b = 1 }))
            assert(b.hp == Config.health)
        end
    },
    {
        name = "a thrown weapon hurts, lands and can be picked up again",
        run = function()
            sequences = {}
            local world, a, b = duel()
            Weapons.give(a, "rifle")
            tick(world, command(1, { t = 1 }))
            assert(a.weapon == "pistol" and #world.items == 1 and world.items[1].flying, "a pistol replaces the thrown weapon")
            for _ = 1, 40 do tick(world, command(1, {})) end
            assert(b.hp == Config.health - WeaponConfig.throw.damage, "hp " .. b.hp)
            local item = world.items[1]
            assert(item and not item.flying, "landed")
            a.x, a.y = item.x, item.y
            tick(world, command(1, { e = 1 }))
            assert(a.weapon == "rifle" and #world.items == 0, "E picks the weapon up again")
        end
    },
    {
        name = "E swaps the held weapon with the one on the floor",
        run = function()
            sequences = {}
            local world, a = duel()
            local Combat = require("src.game.combat")
            Combat.spawnItem(world, "shotgun", nil, nil, a.x + 10, a.y)
            tick(world, command(1, { e = 1 }))
            assert(a.weapon == "shotgun" and a.ammo == WeaponConfig.shotgun.magazine)
            assert(#world.items == 0, "the pistol does not drop")
        end
    },
    {
        name = "pistols can't be thrown or knocked away, and an empty-handed player gets one",
        run = function()
            sequences = {}
            local world, a = duel()
            tick(world, command(1, { t = 1 }))
            assert(a.weapon == "pistol" and #world.items == 0, "a pistol stays in hand")
            Weapons.give(a, "rifle")
            Weapons.give(a, nil)
            tick(world, command(1, {}))
            assert(a.weapon == "pistol", "no weapon means a pistol")
            for _, kind in ipairs({ "pistol", "silencer", "revolver" }) do
                assert(Weapons.sidearm(kind) and WeaponConfig[kind].sidearm, kind)
            end
            assert(not Weapons.sidearm("rifle") and not Weapons.sidearm(nil))
        end
    },
    {
        name = "loot pads spawn weapons and respawn them once taken",
        run = function()
            local world = World.new()
            world:add(1, "a")
            world:step()
            assert(#world.items == #world.arena.loot)
            local pad = world.arena.loot[1]
            local p = world.players[1]
            p.x, p.y = pad.x, pad.y
            world:queue(1, { { s = 1, f = 0, r = 0, a = 0, d = 0, b = 0, l = 0, t = 0, e = 1 } })
            world:step()
            assert(p.weapon == pad.kind)
            assert(world.pads[1].item == nil and world.pads[1].timer > 0)
            for _ = 1, WeaponConfig.padRespawn + 2 do world:step() end
            assert(world.pads[1].item ~= nil, "pad refilled")
        end
    },
    {
        name = "shotgun pellets spread the same way on client and server",
        run = function()
            local p = Player.new(1, "a", { x = 0, y = 0, angle = 0 })
            Weapons.give(p, "shotgun")
            local a, b = Weapons.rays(p, 42), Weapons.rays(p, 42)
            assert(#a == WeaponConfig.shotgun.pellets)
            local spread = false
            for k = 1, #a do
                assert(a[k].dx == b[k].dx and a[k].dy == b[k].dy)
                if math.abs(a[k].dy) > 0.01 then spread = true end
            end
            assert(spread)
        end
    },
    {
        name = "vision: cone, near circle and walls",
        run = function()
            local arena = Arena.new({ width = 4000, height = 4000, walls = { { x = 1200, y = 900, w = 20, h = 200 } }, spawns = {} })
            local viewer = { x = 1000, y = 1000, angle = 0 }
            assert(Vision.sees(arena, viewer, 1100, 1000, 14), "in front")
            assert(not Vision.sees(arena, viewer, 700, 1000, 14), "behind")
            assert(Vision.sees(arena, viewer, 940, 1000, 14), "close behind")
            assert(not Vision.sees(arena, viewer, 1400, 1000, 14), "behind a wall")
        end
    },
    {
        name = "the server hides opponents the player cannot see",
        run = function()
            sequences = {}
            local world, a, b = duel({ { x = 1140, y = 900, w = 20, h = 200 } })
            tick(world)
            assert(#world:snapshot(1).players == 1, "opponent behind the wall is not sent")
            world.arena.walls = {}
            assert(#world:snapshot(1).players == 2)
            assert(world:snapshot(1).players[2].q == nil, "opponent ammo stays private")
        end
    },
    {
        name = "prediction matches the server while shooting and reloading",
        run = function()
            sequences = {}
            local world = World.new()
            world:add(1, "a")
            local predicted = Player.new(1, "a", world.arena:spawn(1))
            for s = 1, 400 do
                local c = {
                    s = s, f = 1, r = s % 40 < 20 and 1 or -1, a = Player.packAngle(s * 0.015),
                    d = s % 70 == 0 and 1 or 0, b = s % 9 < 4 and 1 or 0, l = s % 150 == 0 and 1 or 0, t = 0, e = 0
                }
                Player.step(predicted, c, world.arena, DT)
                world:queue(1, { c })
                world:step()
            end
            local server = world.players[1]
            assert(server.x == predicted.x and server.y == predicted.y, "positions diverged")
            assert(server.ammo == predicted.ammo and server.reserve == predicted.reserve and server.reload == predicted.reload, "weapon state diverged")
        end
    },
    {
        name = "inputs keep only boolean action flags and a valid view tick",
        run = function()
            local c = Inputs.sanitize({ s = 1, a = 0, b = 1, l = 1, t = 1, e = 1, v = 12 })
            assert(c.b == 1 and c.l == 1 and c.t == 1 and c.e == 1 and c.v == 12)
            c = Inputs.sanitize({ s = 1, a = 0, b = 2, v = -3 })
            assert(c.b == 0 and c.v == nil)
        end
    },
    {
        name = "with heal on kill, each kill gives back 50 HP up to full health",
        run = function()
            local Combat = require("src.game.combat")
            local function arena(rules)
                local world = World.new(Arena.new({
                    width = 4000, height = 4000, walls = {},
                    spawns = { { x = 1000, y = 1000, angle = 0 }, { x = 1300, y = 1000, angle = math.pi } }
                }), "duel", false, rules)
                world:add(1, "a")
                world:add(2, "b")
                return world
            end
            local world = arena({ h = true })
            local a, b = world.players[1], world.players[2]
            a.hp = 30
            Combat.kill(world, b, 1)
            assert(a.hp == 80, "healed to " .. a.hp)
            Player.respawn(b, world:spawnPoint(b))
            a.hp = 90
            Combat.kill(world, b, 1)
            assert(a.hp == Config.health, "capped at full health")
            local plain = arena(nil)
            plain.players[1].hp = 30
            Combat.kill(plain, plain.players[2], 1)
            assert(plain.players[1].hp == 30, "off by default")
            assert(require("src.config.loadout").pack(world.options).h == true, "the rule travels to clients")
        end
    }
}
