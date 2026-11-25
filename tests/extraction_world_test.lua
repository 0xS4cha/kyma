local Worldgen = require("src.game.extraction.worldgen")
local Terrain = require("src.game.extraction.terrain")
local Arena = require("src.game.arena")
local Config = require("src.config.extraction")

local cached

local function world()
    if not cached then
        local def = Worldgen.generate(Config.seed)
        cached = { def = def, terrain = Terrain.new(def, Config.cell) }
    end
    return cached.def, cached.terrain
end

return {
    {
        name = "the world is huge and the same for the same seed",
        run = function()
            local started = love.timer.getTime()
            local def = world()
            local elapsed = love.timer.getTime() - started
            assert(def.width == 40000 and def.height == 40000)
            assert(elapsed < 4, "generation took " .. elapsed .. " s")
            local again = Worldgen.generate(Config.seed)
            assert(#again.walls == #def.walls and #again.doors == #def.doors and #again.containers == #def.containers)
            for k = 1, #def.walls, 97 do
                local a, b = def.walls[k], again.walls[k]
                assert(a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h, "wall " .. k .. " differs")
            end
            local other = Worldgen.generate(Config.seed + 1)
            assert(#other.walls ~= #def.walls or other.walls[500].x ~= def.walls[500].x, "another seed gives another world")
            assert(#def.containers > 600, "lots of loot containers: " .. #def.containers)
            print(string.format("    %d walls, %d doors, %d glass, %d cover, %d pits, %d containers, %d nests in %.2f s",
                #def.walls, #def.doors, #def.glass, #def.cover, #def.pits, #def.containers, #def.nests, elapsed))
            assert(#def.nests > 300 and #def.extracts >= 8 and #def.spawns > 40)
        end
    },
    {
        name = "every biome and danger tier shows up",
        run = function()
            local def = world()
            local biomes, tiers = {}, {}
            for _, chunk in ipairs(def.chunks) do
                biomes[chunk.biome] = true
                tiers[chunk.tier] = true
            end
            for biome in pairs(Worldgen.BIOMES) do assert(biomes[biome], biome .. " missing") end
            for tier = 1, 4 do assert(tiers[tier], "tier " .. tier .. " missing") end
            assert(Worldgen.chunkAt(def, 20000, 20000).tier == 4, "the centre is the most dangerous")
            assert(Worldgen.chunkAt(def, 500, 500).tier == 1, "the edges are the safest")
        end
    },
    {
        name = "spawns, extracts and containers are clear of walls",
        run = function()
            local def, terrain = world()
            for _, spawn in ipairs(def.spawns) do
                assert(terrain:clear(spawn.x, spawn.y, 20), "spawn blocked at " .. spawn.x .. "," .. spawn.y)
            end
            for _, extract in ipairs(def.extracts) do
                assert(terrain:clear(extract.x, extract.y, 40), "extract blocked: " .. extract.name)
                for _, spawn in ipairs(def.spawns) do
                    assert((spawn.x - extract.x) ^ 2 + (spawn.y - extract.y) ^ 2 > 2000 ^ 2, "a spawn sits on " .. extract.name)
                end
            end
            local blocked = 0
            for _, c in ipairs(def.containers) do
                if not terrain:clear(c.x, c.y, 8) then blocked = blocked + 1 end
            end
            assert(blocked <= #def.containers * 0.03, blocked .. " containers inside walls")
        end
    },
    {
        name = "the spatial index answers like a full scan",
        run = function()
            local def, terrain = world()
            local flat = Arena.new({ width = def.width, height = def.height, walls = def.walls, doors = {}, glass = {}, cover = def.cover, pits = def.pits })
            local rng = love.math.newRandomGenerator(4)
            for _ = 1, 300 do
                local x, y = rng:random(1000, 39000), rng:random(1000, 39000)
                local a = rng:random() * math.pi * 2
                local dx, dy = math.cos(a), math.sin(a)
                local t1 = terrain:raycast(x, y, dx, dy, 1600, "vision")
                local t2 = flat:raycast(x, y, dx, dy, 1600, "vision")
                local closed = true
                terrain:query("doors", math.min(x, x + dx * t1) - 1, math.min(y, y + dy * t1) - 1, math.max(x, x + dx * t1) + 1, math.max(y, y + dy * t1) + 1, function() closed = false end)
                if closed then assert(math.abs(t1 - t2) < 1e-6, "raycast mismatch " .. t1 .. " vs " .. t2) else assert(t1 <= t2 + 1e-6) end
                local rx, ry = terrain:resolve(x, y, 14)
                local fx, fy = flat:resolve(x, y, 14)
                -- Overlapping walls can push in another order, but never far apart.
                assert((rx - fx) ^ 2 + (ry - fy) ^ 2 < 40 * 40, "resolve mismatch")
            end
        end
    },
    {
        name = "doors open for actors near them and close after",
        run = function()
            local _, terrain = world()
            local door = terrain.doors[1]
            local actor = { x = door.x + door.w / 2, y = door.y + door.h / 2 + 40, hp = 100, dead = 0 }
            local opened = terrain:updateDoors({ actor })
            assert(door.open and #opened >= 1)
            local doors = terrain:stateNear(actor.x, actor.y, 1000)
            local listed = false
            for _, k in ipairs(doors) do if k == door.index then listed = true end end
            assert(listed, "the open door is in the snapshot state")
            actor.x = actor.x + 5000
            for _ = 1, 60 do terrain:updateDoors({ actor }) end
            assert(not door.open and next(terrain.open) == nil)
        end
    }
}
