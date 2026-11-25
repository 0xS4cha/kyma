local Arena = require("src.game.arena")
local Player = require("src.game.player")
local World = require("src.game.world")
local Weapons = require("src.game.weapons")

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
        name = "excessive displacement causes a server violation",
        run = function()
            local w, p = world()
            p.x = p.x + 100
            local violation = tick(w)
            assert(violation and violation.field == "displacement")
        end
    }
}
