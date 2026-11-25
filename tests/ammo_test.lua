local Arena = require("src.game.arena")
local Player = require("src.game.player")
local World = require("src.game.world")
local Weapons = require("src.game.weapons")
local Combat = require("src.game.combat")
local WeaponConfig = require("src.config.weapons")

local function solo()
    local world = World.new(Arena.new({ width = 4000, height = 4000, walls = {}, spawns = { { x = 1000, y = 1000, angle = 0 } } }))
    world:add(1, "a")
    return world, world.players[1]
end

local s = 0
local function idle(world, fields)
    s = s + 1
    local c = { s = s, f = 0, r = 0, a = 0, d = 0, b = 0, l = 0, t = 0, e = 0, k = 0 }
    for k, v in pairs(fields or {}) do c[k] = v end
    world:queue(1, { c })
    world:step()
end

local function count(world, kind)
    local n = 0
    for _, item in ipairs(world.items) do
        if item.kind == kind then n = n + 1 end
    end
    return n
end

return {
    {
        name = "walking over an ammo pack adds a magazine to the reserve",
        run = function()
            local world, p = solo()
            Weapons.give(p, "rifle", 24, 10)
            Combat.spawnItem(world, "ammo", nil, nil, p.x + 10, p.y)
            idle(world)
            assert(p.reserve == 10 + WeaponConfig.rifle.magazine and count(world, "ammo") == 0)
        end
    },
    {
        name = "the reserve is capped and a full reserve leaves the pack",
        run = function()
            local world, p = solo()
            local cap = Weapons.reserveCap(WeaponConfig.pistol)
            Weapons.give(p, "pistol", 8, cap - 3)
            Combat.spawnItem(world, "ammo", nil, nil, p.x, p.y)
            idle(world)
            assert(p.reserve == cap)
            Combat.spawnItem(world, "ammo", nil, nil, p.x, p.y)
            idle(world)
            assert(count(world, "ammo") == 1, "nothing to refill")
        end
    },
    {
        name = "an empty-handed player gets a pistol, and E never swaps for ammo",
        run = function()
            local world, p = solo()
            Weapons.give(p, nil)
            idle(world)
            assert(p.weapon == "pistol", "the fallback pistol")
            world.items = {}
            Combat.spawnItem(world, "ammo", nil, nil, p.x, p.y)
            Weapons.give(p, "pistol", 8, Weapons.reserveCap(WeaponConfig.pistol))
            idle(world, { e = 1 })
            assert(p.weapon == "pistol" and count(world, "ammo") == 1)
        end
    },
    {
        name = "ammo pads are part of the loot",
        run = function()
            local world = World.new()
            world:step()
            assert(count(world, "ammo") == 2)
        end
    }
}
