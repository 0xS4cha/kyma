local Arena = require("src.game.arena")
local World = require("src.game.world")
local Combat = require("src.game.combat")
local Config = require("src.config.game")

local LADDER = Config.modes.gungame.ladder

local function game()
    local world = World.new(Arena.new({
        width = 3000, height = 3000, walls = {},
        spawns = { { x = 500, y = 500, angle = 0 }, { x = 2500, y = 2500, angle = 0 } },
        loot = { { x = 1500, y = 1500, kind = "rifle" }, { x = 1600, y = 1500, kind = "health" } }
    }), "gungame")
    world:add(1, "a")
    world:add(2, "b")
    return world, world.players[1], world.players[2]
end

return {
    {
        name = "everyone starts on the first weapon of the ladder with endless ammo",
        run = function()
            local _, a = game()
            assert(a.weapon == LADDER[1] and a.reserve >= 999)
        end
    },
    {
        name = "each kill moves the killer to the next weapon",
        run = function()
            local world, a, b = game()
            for level = 2, #LADDER - 1 do
                Combat.kill(world, b, 1)
                assert(a.weapon == LADDER[level], "level " .. level .. " gives " .. tostring(a.weapon))
                b.dead, b.hp = 0, 100
            end
            Combat.kill(world, b, 1)
            assert(a.weapon == nil, "the last step is your fists")
            assert(not world.over)
        end
    },
    {
        name = "a kill with your fists at the last step wins",
        run = function()
            local world, a, b = game()
            world.score[1] = #LADDER - 1
            Combat.kill(world, b, 1)
            assert(world.over and world.over.winner == 1)
        end
    },
    {
        name = "weapons can't be dropped, thrown, picked up or knocked out",
        run = function()
            local world, a, b = game()
            Combat.kill(world, b, 1)
            assert(#world.items == 0, "the dead drop nothing")
            Combat.throw(world, a)
            assert(a.weapon == LADDER[2], "no throwing")
            Combat.spawnItem(world, "sniper", nil, nil, a.x, a.y)
            assert(not Combat.pickup(world, a) and a.weapon == LADDER[2], "no pickups")
        end
    },
    {
        name = "only health pads spawn and respawns keep your level",
        run = function()
            local world, a, b = game()
            world:step()
            local kinds = {}
            for _, item in ipairs(world.items) do kinds[item.kind] = true end
            assert(kinds.health and not kinds.rifle)
            world.score[2] = 3
            Combat.kill(world, b, 1)
            for _ = 1, Config.respawnTicks + 2 do
                world:queue(2, { { s = _, f = 0, r = 0, a = 0, d = 0, b = 0, l = 0, t = 0, e = 0, k = 0 } })
                world:step()
            end
            assert(b.dead == 0 and b.weapon == LADDER[4], "respawned with level 4: " .. tostring(b.weapon))
        end
    }
}
