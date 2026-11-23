local B = require("src.maps.builder")

local m = B.new("colonnade", "Colonnade", 2400, 1400, "A wide hall of columns and benches. Long sightlines: bring a sniper, or a dash.")
B.border(m)
for x = 300, 2100, 300 do
    for y = 250, 1150, 300 do
        B.box(m, x - 30, y - 30, 60, 60)
    end
end
for x = 450, 1950, 300 do
    local y = (x / 300) % 2 < 1 and 400 or 1000
    B.box(m, x - 80, y - 12, 160, 24, "cover")
end
B.box(m, 1180, 560, 40, 280, "cover")
for k, y in ipairs({ 160, 520, 880, 1240 }) do
    B.spawn(m, 110, y, 0, 1)
    B.spawn(m, 2290, y, math.pi, 2)
end
B.loot(m, 150, 700, "sniper")
B.loot(m, 2250, 700, "sniper")
B.loot(m, 1200, 400, "rifle")
B.loot(m, 1200, 1000, "rifle")
B.loot(m, 750, 700, "shotgun")
B.loot(m, 1650, 700, "shotgun")
B.loot(m, 600, 150, "ammo")
B.loot(m, 1800, 1250, "ammo")
B.loot(m, 900, 1250, "health")
B.loot(m, 1500, 150, "health")
B.loot(m, 1050, 700, "silencer")
B.loot(m, 1350, 700, "lmg")
return m
