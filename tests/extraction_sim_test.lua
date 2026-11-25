local Wilds = require("src.game.extraction.world")
local Inventory = require("src.game.extraction.inventory")
local Items = require("src.game.extraction.items")
local Monsters = require("src.game.extraction.monsters")
local Events = require("src.game.extraction.events")
local Player = require("src.game.player")
local Config = require("src.config.extraction")

local uid = 5000
local function item(d, fields)
    uid = uid + 1
    local inst = { i = uid, d = d, r = 1, x = 0, y = 0 }
    local def = require("src.config.items").all[d]
    if def.kind == "backpack" then inst.c = {} end
    if def.kind == "armor" then inst.u = Items.armorStats(inst).durability end
    for k, v in pairs(fields or {}) do inst[k] = v end
    return inst
end

--- A small flat world: one wall, a container, a nest far away and an extract.
local function small(extra)
    local def = {
        id = "test", width = 8000, height = 8000, seed = 1, count = 4, chunk = 2000,
        walls = { { x = 3000, y = 900, w = 40, h = 400 } }, doors = {}, glass = {}, cover = {}, pits = {},
        spawns = { { x = 1000, y = 1000, angle = 0 } },
        containers = { { id = 1, x = 1060, y = 1000, kind = "crate", tier = 3 } },
        nests = { { id = 1, x = 6000, y = 6000, tier = 2, biome = "forest" } },
        extracts = { { id = 1, name = "Gate", x = 2000, y = 2000 } },
        chunks = {}
    }
    for k = 1, 16 do def.chunks[k] = { biome = "forest", tier = 2 } end
    for k, v in pairs(extra or {}) do def[k] = v end
    return Wilds.new({ def = def, random = 3 })
end

local function gear(list)
    local g = Inventory.newGear()
    for slot, inst in pairs(list or {}) do
        if slot == "pockets" then g.pockets = inst else g[slot] = inst end
    end
    return g
end

local s = 0
local function command(fields)
    s = s + 1
    local c = { s = s, f = 0, r = 0, a = Player.packAngle(fields and fields.angle or 0), d = 0, b = 0, l = 0, t = 0, e = 0, k = 0, x = 0 }
    for k, v in pairs(fields or {}) do if k ~= "angle" then c[k] = v end end
    return c
end

local function run(w, ticks, slot, fields)
    for _ = 1, ticks do
        if slot then w:queue(slot, { command(fields) }) end
        w:step()
        w:drain()
    end
end

return {
    {
        name = "a shot kills a monster, which leaves its remains",
        run = function()
            local w = small()
            local p = w:add(1, "Ann", gear({ primary = item("bolt", { a = 5, r = 5 }), pockets = { item("ammo_sniper", { n = 20 }) } }))
            p.x, p.y = 1000, 1000
            local m = Monsters.spawn(w, "crawler", 1300, 1000, 1)
            assert(m and p.def and p.def.id == "bolt")
            m.stun = 999
            run(w, 25, 1)
            w:queue(1, { command({ b = 1 }) })
            w:step()
            local outbox = w:drain()
            assert(m.hp <= 0 and not w.monsters[m.id], "one sniper shot kills a crawler")
            local hit = false
            for _, message in ipairs(outbox) do if message.kind == "xhit" and message.data.k == 1 then hit = true end end
            assert(hit, "the shooter is told about the kill")
            assert(p.monsterKills == 1)
        end
    },
    {
        name = "bouncing rounds ricochet off walls",
        run = function()
            local w = small()
            local p = w:add(1, "Ann", gear({ primary = item("p9", { a = 12, m = { rounds = item("bouncing") } }) }))
            p.x, p.y = 2900, 1100
            run(w, 25, 1)
            w:queue(1, { command({ b = 1 }) })
            w:step()
            local _, shots = w:drain()
            assert(#shots >= 2, "the bullet goes on after the wall: " .. #shots)
            assert(shots[2].X < shots[2].x, "and comes back")
        end
    },
    {
        name = "armor absorbs damage and wears down",
        run = function()
            local w = small()
            local vest = item("carrier")
            local a = w:add(1, "Ann", gear({ vest = vest }))
            local b = w:add(2, "Bob", gear())
            local Fight = require("src.game.extraction.fight")
            Fight.hurtPlayer(w, a, 40, b)
            Fight.hurtPlayer(w, b, 40, a)
            assert(a.hp > b.hp, "the vest took part of the hit")
            assert(vest.u < Items.armorStats(vest).durability)
            local hp = a.hp
            Fight.hurtPlayer(w, a, 20, b, { armorPierce = 1 })
            assert(hp - a.hp > 19, "full armor piercing ignores the vest")
        end
    },
    {
        name = "a dead player leaves a corpse with all their gear",
        run = function()
            local w = small()
            local g = gear({ primary = item("ar"), backpack = item("daypack"), pockets = { item("bandage", { n = 2 }) } })
            table.insert(g.backpack.c, item("gpu"))
            local p = w:add(1, "Ann", g)
            local Fight = require("src.game.extraction.fight")
            Fight.hurtPlayer(w, p, 500, nil)
            assert(p.dead > 0 and g.primary == nil and g.backpack == nil and #g.pockets == 0, "the gear is gone")
            local corpse
            for _, drop in pairs(w.drops) do corpse = drop end
            assert(corpse and corpse.kind == "corpse" and corpse.name == "Ann")
            assert(#corpse.items == 3, "rifle, backpack (with its gpu) and bandages")
            local outbox = w:drain()
            local died = false
            for _, m in ipairs(outbox) do if m.kind == "xdied" and m.to == 1 then died = true end end
            assert(died)
        end
    },
    {
        name = "containers are rolled when opened and looted from close by only",
        run = function()
            local w = small()
            local p = w:add(1, "Ann", gear({ backpack = item("raid") }))
            p.x, p.y = 1000, 1000
            local far = w:add(2, "Far", gear({ backpack = item("raid") }))
            far.x, far.y = 3000, 3000
            assert(not w:act(2, { o = "open", t = "c", id = 1 }), "too far")
            assert(w:act(1, { o = "open", t = "c", id = 1 }))
            local view = w:inventoryView(1)
            assert(view.ct and #view.ct.items > 0, "the crate has loot")
            local count = #view.ct.items
            assert(w:act(1, { o = "lootall" }))
            assert(#w.containers[1].items < count, "items moved to the player")
            assert(#Inventory.all(p.gear) > 1)
        end
    },
    {
        name = "reloading takes rounds out of the inventory",
        run = function()
            local w = small()
            local ammo = item("ammo_light", { n = 30 })
            local p = w:add(1, "Ann", gear({ primary = item("p9", { a = 0 }), pockets = { ammo } }))
            assert(p.reserve == 30 and p.ammo == 0)
            run(w, 25)
            run(w, 1, 1, { l = 1 })
            run(w, 80, 1)
            assert(p.ammo == p.def.magazine and ammo.n == 30 - p.def.magazine, "reload used " .. (30 - ammo.n))
            assert(p.reserve == ammo.n)
        end
    },
    {
        name = "standing in an extraction zone gets you out",
        run = function()
            local w = small()
            local p = w:add(1, "Ann", gear())
            p.x, p.y = 2000, 2000
            run(w, Config.extractTicks - 1)
            assert(not p.extracted and p.extract > 0)
            run(w, 2)
            assert(p.extracted)
        end
    },
    {
        name = "quick slots use bandages and throw grenades",
        run = function()
            local w = small()
            local bandage, frag = item("bandage", { n = 2 }), item("frag", { n = 1 })
            local p = w:add(1, "Ann", gear({ pockets = { bandage, frag } }))
            p.gear.quick[1], p.gear.quick[2] = bandage.i, frag.i
            p.hp = 50
            assert(w:act(1, { o = "use", k = 1 }))
            assert(p.use and p.haste and p.haste < 1, "slowed while bandaging")
            run(w, 95)
            assert(p.hp == 70 and bandage.n == 1 and not p.use)
            local m = Monsters.spawn(w, "crawler", 1200, 1000, 1)
            p.x, p.y, p.angle = 1000, 1000, 0
            m.stun = 999
            assert(w:act(1, { o = "use", k = 2 }))
            assert(p.gear.quick[2] == 0, "the last grenade left the quick slot")
            run(w, 120)
            assert(m.hp < m.max, "the frag hurt the monster")
        end
    },
    {
        name = "nests wake up near players and monsters chase them",
        run = function()
            local w = small()
            local p = w:add(1, "Ann", gear())
            p.x, p.y = 5000, 5000
            p.joinedAt = -1e6
            run(w, 31)
            local count = 0
            for _, m in pairs(w.monsters) do
                count = count + 1
                m.x, m.y = 5300, 5000
            end
            assert(count > 0 and w.nests[1].awake, "the nest woke up")
            local hp = p.hp
            run(w, 200)
            assert(p.hp < hp, "monsters came and hit")
        end
    },
    {
        name = "random events happen and drop loot",
        run = function()
            local w = Wilds.new({ random = 9 })
            w:add(1, "Ann", gear())
            local ev = Events.start(w, "airdrop")
            ev.timer = 1
            run(w, 2)
            assert(ev.phase == "live" and ev.drop and #ev.drop.items > 0, "the supply drop landed with loot")
            local snapshot = w:snapshot(1)
            assert(#snapshot.events >= 1 and snapshot.events[1].k == "airdrop")
            local boss = Events.start(w, "boss")
            boss.timer = 1
            run(w, 2)
            local warden
            for _, m in pairs(w.monsters) do if m.kind == "warden" then warden = m end end
            assert(warden, "the Warden walks")
            Monsters.hurt(w, warden, 1e9, w.players[1])
            local hoard
            for _, drop in pairs(w.drops) do if drop.name == "Warden's hoard" then hoard = drop end end
            assert(hoard and #hoard.items > 0 and boss.phase == "over")
        end
    },
    {
        name = "snapshots only carry what the player can see",
        run = function()
            local w = small()
            local p = w:add(1, "Ann", gear())
            p.x, p.y, p.angle = 2800, 1100, 0
            local behind = Monsters.spawn(w, "crawler", 3200, 1100, 1)
            local front = Monsters.spawn(w, "crawler", 2950, 1400, 1)
            behind.stun, front.stun = 999, 999
            local view = w:snapshot(1)
            local ids = {}
            for _, m in ipairs(view.monsters) do ids[m.i] = true end
            assert(not ids[behind.id], "hidden behind the wall")
            p.angle = math.atan2(300, 150)
            view = w:snapshot(1)
            ids = {}
            for _, m in ipairs(view.monsters) do ids[m.i] = true end
            assert(ids[front.id], "in the view cone")
            p.marks["m" .. behind.id] = 100
            view = w:snapshot(1)
            ids = {}
            for _, m in ipairs(view.monsters) do ids[m.i] = true end
            assert(ids[behind.id], "a marked monster shows through walls")
        end
    },
    {
        name = "a busy world steps fast enough",
        run = function()
            local w = Wilds.new({ random = 5 })
            for slot = 1, 64 do
                local p = w:add(slot, "P" .. slot, gear({ primary = item("ar", { a = 30 }), pockets = { item("ammo_medium", { n = 60 }) } }))
                p.x, p.y = 4000 + (slot % 8) * 3500, 4000 + math.floor(slot / 8) * 3500
            end
            run(w, 60)
            local started = love.timer.getTime()
            for _ = 1, 60 do
                for slot = 1, 64 do w:queue(slot, { command({ f = 1, b = slot % 3 == 0 and 1 or 0, angle = slot }) }) end
                w:step()
                w:drain()
                for slot = 1, 64, 2 do w:snapshot(slot) end
            end
            local elapsed = love.timer.getTime() - started
            local monsters = 0
            for _ in pairs(w.monsters) do monsters = monsters + 1 end
            print(string.format("    64 players, %d monsters: %.1f ms per tick", monsters, elapsed / 60 * 1000))
            assert(monsters > 50, "nests woke up around players")
            assert(elapsed / 60 < 0.05, "a tick takes " .. elapsed / 60 * 1000 .. " ms")
        end
    }
}
