local Arena = require("src.game.arena")
local Player = require("src.game.player")
local World = require("src.game.world")

local function duel(walls, second)
    local world = World.new(Arena.new({
        width = 4000, height = 4000, walls = walls or {},
        spawns = { { x = 1000, y = 1000, angle = 0 }, second or { x = 1300, y = 1000, angle = math.pi } }
    }))
    world:add(1, "a")
    world:add(2, "b")
    return world
end

local function fire(world, angle)
    world:queue(1, { { s = 1, f = 0, r = 0, a = Player.packAngle(angle), d = 0, b = 1, l = 0, t = 0, e = 0, k = 0 } })
    world:step()
    local _, shots = world:drain()
    return shots[1]
end

return {
    {
        name = "shots report a player hit",
        run = function()
            local shot = fire(duel(), 0)
            assert(shot.h == 2 and math.abs(shot.X - (1300 - 14)) < 1, "end " .. shot.X)
        end
    },
    {
        name = "shots report a wall hit where the bullet stopped",
        run = function()
            local shot = fire(duel({ { x = 1100, y = 0, w = 20, h = 4000 } }), 0)
            assert(shot.h == 1 and math.abs(shot.X - 1100) < 1e-6)
        end
    },
    {
        name = "shots into the void report nothing",
        run = function()
            local shot = fire(duel(), math.pi)
            assert(shot.h == 0)
        end
    }
}
