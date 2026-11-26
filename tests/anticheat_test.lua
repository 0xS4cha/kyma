local Arena = require("src.game.arena")
local Player = require("src.game.player")
local World = require("src.game.world")
local Weapons = require("src.game.weapons")
local AntiCheat = require("src.game.anticheat")

local function world()
    local w = World.new(Arena.new({
        width = 4000, height = 4000, walls = {},
        spawns = { { x = 1000, y = 1000, angle = 0 } }
    }))
    w:add(1, "a")
    return w, w.players[1]
end

local sequence = 0
local function tick(w)
    sequence = sequence + 1
    w:queue(1, { { s = sequence, f = 0, r = 0, a = Player.packAngle(0) } })
    return w:step()
end

return {
    {
        name = "valid authoritative ammo and position pass validation",
        run = function()
            local w, p = world()
            Weapons.give(p, "rifle")
            assert(tick(w) == nil)
            assert(p.ammo == 24 and p.reserve == 48)
        end
    },
    {
        name = "invalid ammo causes a server violation",
        run = function()
            local w, p = world()
            p.ammo = -1
            local violation = tick(w)
            assert(violation and violation.field == "ammo")
        end
    },
    {
        name = "invalid reserve causes a server violation",
        run = function()
            local w, p = world()
            p.reserve = 9999
            local violation = tick(w)
            assert(violation and violation.field == "reserve")
        end
    },
    {
        name = "non-finite ammo causes a server violation",
        run = function()
            local w, p = world()
            p.ammo = 0 / 0
            local violation = tick(w)
            assert(violation and violation.field == "ammo")
        end
    },
    {
        name = "invalid position causes a server violation",
        run = function()
            local w, p = world()
            p.x = -100
            local violation = tick(w)
            assert(violation and violation.field == "position")
        end
    },
    {
        name = "a door closing over a dead player's body is not a violation",
        run = function()
            local w = World.new(Arena.new({
                width = 4000, height = 4000, walls = {},
                doors = { { x = 990, y = 900, w = 24, h = 200 } },
                spawns = { { x = 3000, y = 3000, angle = 0 } }
            }))
            w:add(1, "a")
            local p = w.players[1]
            p.x, p.y, p.hp, p.dead = 1020, 1000, 0, 2
            assert(not w.arena.doors[1].open)
            assert(tick(w) == nil, "a corpse in a doorway is not a collision")
            assert(p.dead == 1 and not w.arena.doors[1].open)
            -- the command that ends the death timer still runs at the body
            assert(tick(w) == nil, "respawning from a doorway is not a collision")
        end
    },
    {
        name = "a living player inside a closed door is still a violation",
        run = function()
            local w = World.new(Arena.new({
                width = 4000, height = 4000, walls = {},
                doors = { { x = 990, y = 900, w = 24, h = 200 } },
                spawns = { { x = 3000, y = 3000, angle = 0 } }
            }))
            w:add(1, "a")
            local p = w.players[1]
            p.x, p.y = 1002, 1000
            local violation = AntiCheat.validate(p, { x = p.x, y = p.y }, w)
            assert(violation and violation.field == "collision")
        end
    },
    {
        name = "excessive displacement causes a server violation",
        run = function()
            local w, p = world()
            local violation = AntiCheat.validate(p, { x = p.x - 100, y = p.y }, w)
            assert(violation and violation.field == "displacement")
        end
    },
    {
        name = "a violation does not freeze the world for the other players",
        run = function()
            local w, p = world()
            w:add(2, "b")
            p.ammo = -1
            sequence = sequence + 1
            local other = sequence
            w:queue(2, { { s = other, f = 0, r = 0, a = Player.packAngle(0) } })
            local violation = tick(w)
            assert(violation and violation.slot == 1 and violation.field == "ammo")
            assert(w.inputs[2].acked == other, "the other player's command still ran")
            p.ammo = 0
            assert(tick(w) == nil, "the next tick is clean once the state is valid")
        end
    },
    {
        name = "picking up a weapon dropped by a player with an extended mag is not a violation",
        run = function()
            local Combat = require("src.game.combat")
            local w, p = world()
            Weapons.give(p, nil)
            local magazine = Weapons.def("rifle").magazine
            local item = Combat.spawnItem(w, "rifle", math.floor(magazine * 1.5 + 0.5), 48, p.x, p.y)
            assert(item)
            assert(Combat.pickup(w, p), "picked up")
            assert(tick(w) == nil, "no violation after the pickup")
            assert(p.ammo == magazine, "the magazine is capped at " .. magazine .. ": " .. p.ammo)
            assert(p.reserve == 48 + math.floor(magazine * 1.5 + 0.5) - magazine, "the extra rounds go to the reserve")
        end
    },
    {
        name = "picking up a weapon dropped with an ammo pouch reserve is not a violation",
        run = function()
            local Combat = require("src.game.combat")
            local w, p = world()
            Weapons.give(p, nil)
            local cap = Weapons.reserveCap(Weapons.def("rifle"))
            Combat.spawnItem(w, "rifle", 10, cap * 2, p.x, p.y)
            assert(Combat.pickup(w, p), "picked up")
            assert(tick(w) == nil, "no violation after the pickup")
            assert(p.reserve == cap, "the reserve is capped")
        end
    }
}
