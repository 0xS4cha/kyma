local Arena = require("src.game.arena")
local Player = require("src.game.player")
local World = require("src.game.world")
local Vision = require("src.game.vision")
local Nav = require("src.game.nav")
local Combat = require("src.game.combat")
local Config = require("src.config.game")
local NetConfig = require("src.net.config")

local DT = 1 / NetConfig.tickRate

local function arena(extra)
    local def = { width = 2000, height = 1200, walls = {}, spawns = { { x = 300, y = 600, angle = 0 }, { x = 1700, y = 600, angle = math.pi } } }
    for k, v in pairs(extra or {}) do def[k] = v end
    return Arena.new(def)
end

local function input(fields)
    local c = { s = 1, f = 0, r = 0, a = 0, d = 0, b = 0, l = 0, t = 0, e = 0, k = 0 }
    for k, v in pairs(fields or {}) do c[k] = v end
    return c
end

return {
    {
        name = "a closed door blocks movement, bullets and vision",
        run = function()
            local a = arena({ doors = { { x = 990, y = 0, w = 20, h = 1200 } } })
            assert(a:raycast(900, 600, 1, 0, 400) < 100)
            assert(a:raycast(900, 600, 1, 0, 400, "vision") < 100)
            local x = a:resolve(995, 600, 14)
            assert(x < 990 or x > 1010, "pushed out of the door")
            a.doors[1].open = true
            assert(a:raycast(900, 600, 1, 0, 400) == 400)
        end
    },
    {
        name = "doors open when a player comes close and close after they leave",
        run = function()
            local a = arena({ doors = { { x = 990, y = 500, w = 20, h = 200 } } })
            local p = Player.new(1, "a", { x = 930, y = 600, angle = 0 })
            local opened = a:updateDoors({ p })
            assert(#opened == 1 and a.doors[1].open and opened[1].opener == 1)
            p.x = 400
            for _ = 1, 60 do a:updateDoors({ p }) end
            assert(not a.doors[1].open)
        end
    },
    {
        name = "glass lets vision through but stops bullets, which break it",
        run = function()
            local world = World.new(arena({ glass = { { x = 990, y = 0, w = 12, h = 1200 } } }))
            world:add(1, "a")
            world:add(2, "b")
            local a = world.players[1]
            a.x, a.y = 900, 600
            world.players[2].x, world.players[2].y = 1100, 600
            assert(Vision.sees(world.arena, a, 1100, 600, 14), "seen through the glass")
            world:queue(1, { input({ b = 1 }) })
            world:step()
            local _, shots = world:drain()
            assert(shots[1].h == 3 and world.players[2].hp == Config.health, "the glass took the bullet")
            assert(world.arena.glass[1].broken)
        end
    },
    {
        name = "low cover blocks movement but not bullets or vision",
        run = function()
            local a = arena({ cover = { { x = 990, y = 500, w = 30, h = 200 } } })
            assert(a:raycast(900, 600, 1, 0, 400) == 400 and a:raycast(900, 600, 1, 0, 400, "vision") == 400)
            local p = Player.new(1, "a", { x = 960, y = 600, angle = 0 })
            for _ = 1, 60 do Player.step(p, input({ f = 1 }), a, DT) end
            assert(p.x <= 990 - 14 + 1e-6, "stopped by the cover, x = " .. p.x)
        end
    },
    {
        name = "health packs heal hurt players only",
        run = function()
            local world = World.new(arena())
            world:add(1, "a")
            local p = world.players[1]
            Combat.spawnItem(world, "health", nil, nil, p.x, p.y)
            world:step()
            assert(#world.items == 1, "full health leaves the pack")
            p.hp = 30
            world:step()
            assert(p.hp == 80 and #world.items == 0)
        end
    },
    {
        name = "doors and glass state survive the network",
        run = function()
            local a = arena({ doors = { { x = 0, y = 0, w = 10, h = 10 }, { x = 20, y = 0, w = 10, h = 10 } }, glass = { { x = 40, y = 0, w = 10, h = 10 } } })
            a.doors[2].open = true
            a.glass[1].broken = true
            local doors, glass = a:state()
            local b = arena({ doors = { { x = 0, y = 0, w = 10, h = 10 }, { x = 20, y = 0, w = 10, h = 10 } }, glass = { { x = 40, y = 0, w = 10, h = 10 } } })
            b:applyState(doors, glass)
            assert(not b.doors[1].open and b.doors[2].open and b.glass[1].broken)
        end
    },
    {
        name = "pathfinding goes around walls and through doors",
        run = function()
            local a = arena({
                walls = { { x = 990, y = 0, w = 20, h = 1000 } },
                doors = { { x = 990, y = 1000, w = 20, h = 200 } }
            })
            local path = Nav.path(a, 300, 300, 1700, 300)
            assert(path and #path > 2, "a path exists")
            local low = false
            for _, point in ipairs(path) do
                if point.y > 1000 then low = true end
            end
            assert(low, "the path goes through the door at the bottom")
        end
    },
    {
        name = "a bot finds its way through a corridor to a weapon",
        run = function()
            local Bot = require("src.game.bot")
            local world = World.new(arena({
                walls = { { x = 990, y = 0, w = 20, h = 1000 }, { x = 0, y = 0, w = 2000, h = 20 }, { x = 0, y = 1180, w = 2000, h = 20 } },
                doors = { { x = 990, y = 1000, w = 20, h = 180 } },
                spawns = { { x = 300, y = 300, angle = 0 } }
            }))
            world:add(1, "bot")
            world.players[1].weapon = nil
            Combat.spawnItem(world, "rifle", nil, nil, 1700, 300)
            local bot = Bot.new(1, "medium", 4)
            for _ = 1, 60 * 20 do
                world:queue(1, { bot:command(world) })
                world:step()
                if world.players[1].weapon then break end
            end
            assert(world.players[1].weapon == "rifle", "stuck at " .. world.players[1].x .. ", " .. world.players[1].y)
        end
    }
}
