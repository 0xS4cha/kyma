local B = require("src.maps.builder")
local Arena = require("src.game.arena")

local m = B.new("atrium", "Atrium", 1800, 1200, "The original hall: pillars, half walls and every weapon in reach. Balanced for any mode.")
local def = Arena.DEFAULT
for _, wall in ipairs(def.walls) do B.box(m, wall.x, wall.y, wall.w, wall.h) end
for _, item in ipairs(def.loot) do B.loot(m, item.x, item.y, item.kind) end
B.loot(m, 900, 440, "health")
B.loot(m, 900, 760, "health")
B.spawn(m, 160, 380, 0, 1)
B.spawn(m, 160, 820, 0, 1)
B.spawn(m, 280, 160, math.pi / 4, 1)
B.spawn(m, 280, 1040, -math.pi / 4, 1)
m.spawns[#m.spawns + 1] = { x = 1640, y = 820, angle = math.pi, team = 2 }
m.spawns[#m.spawns + 1] = { x = 1640, y = 380, angle = math.pi, team = 2 }
m.spawns[#m.spawns + 1] = { x = 1520, y = 1040, angle = -3 * math.pi / 4, team = 2 }
m.spawns[#m.spawns + 1] = { x = 1520, y = 160, angle = 3 * math.pi / 4, team = 2 }
return m
