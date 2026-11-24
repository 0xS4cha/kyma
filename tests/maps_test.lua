local Maps = require("src.maps.index")
local Arena = require("src.game.arena")
local Nav = require("src.game.nav")

local function overlap(a, b)
    local w = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x)
    local h = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
    return w > 0.5 and h > 0.5
end

local function each(fn)
    for _, id in ipairs(Maps.order) do
        fn(id, Maps.get(id), Arena.new(Maps.get(id)))
    end
end

return {
    {
        name = "there are fourteen maps with a name and a description",
        run = function()
            assert(#Maps.order == 14)
            each(function(id, def)
                assert(def.id == id and def.name and def.description, id)
            end)
        end
    },
    {
        name = "every map has at least four spawns per team, clear of obstacles",
        run = function()
            each(function(id, def, arena)
                local teams = { 0, 0 }
                for k, spawn in ipairs(def.spawns) do
                    if spawn.team then teams[spawn.team] = teams[spawn.team] + 1 end
                    local x, y = arena:resolve(spawn.x, spawn.y, 14)
                    assert(math.abs(x - spawn.x) < 0.01 and math.abs(y - spawn.y) < 0.01, id .. " spawn " .. k .. " is inside an obstacle")
                    assert(spawn.x > 0 and spawn.y > 0 and spawn.x < def.width and spawn.y < def.height, id .. " spawn " .. k .. " is outside")
                end
                assert(teams[1] >= 4 and teams[2] >= 4, id .. " needs 4 spawns per team")
            end)
        end
    },
    {
        name = "every loot spot is clear of obstacles",
        run = function()
            each(function(id, def, arena)
                for k, item in ipairs(def.loot) do
                    local x, y = arena:resolve(item.x, item.y, 8)
                    assert(math.abs(x - item.x) < 0.01 and math.abs(y - item.y) < 0.01, id .. " loot " .. k .. " (" .. item.kind .. ") is inside an obstacle")
                end
            end)
        end
    },
    {
        name = "doors are not buried in walls",
        run = function()
            each(function(id, def)
                for k, door in ipairs(def.doors) do
                    for _, wall in ipairs(def.walls) do
                        assert(not overlap(door, wall), id .. " door " .. k .. " overlaps a wall")
                    end
                end
            end)
        end
    },
    {
        name = "every spawn and every loot spot can be reached from the first spawn",
        run = function()
            each(function(id, def, arena)
                local from = def.spawns[1]
                for k, spawn in ipairs(def.spawns) do
                    assert(Nav.path(arena, from.x, from.y, spawn.x, spawn.y), id .. " spawn " .. k .. " is unreachable")
                end
                for k, item in ipairs(def.loot) do
                    assert(Nav.path(arena, from.x, from.y, item.x, item.y), id .. " loot " .. k .. " (" .. item.kind .. ") is unreachable")
                end
            end)
        end
    },
    {
        name = "unknown map names fall back to the default",
        run = function()
            assert(Maps.valid("nope") == Maps.default and Maps.get(nil).id == Maps.default)
        end
    },
    {
        name = "teammates never spawn on top of each other",
        run = function()
            local World = require("src.game.world")
            for _, id in ipairs(Maps.order) do
                local world = World.new(Arena.new(Maps.get(id)), "teams", true)
                for slot = 1, 8 do world:add(slot, "P" .. slot, slot % 2 + 1) end
                world:restart("playing")
                for a = 1, 8 do
                    for b = a + 1, 8 do
                        local p, q = world.players[a], world.players[b]
                        assert((p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 >= 60 * 60, id .. ": " .. a .. " and " .. b)
                    end
                end
            end
        end
    }
}
