--- Random events of the persistent world: supply drops guarded by sentinels, hordes
--- that leave a cache, the Warden boss, rifts that restock containers with better loot
--- and helicopter extractions. Every player sees them on the map.
local Config = require("src.config.extraction")
local Worldgen = require("src.game.extraction.worldgen")
local Loot = require("src.game.extraction.loot")

local Events = {}

local floor, min, max = math.floor, math.min, math.max

Events.KINDS = {
    airdrop = { name = "Supply drop", text = "A supply drop is coming down. Sentinels guard it." },
    horde = { name = "Horde", text = "A horde gathers. Clear it for its cache." },
    boss = { name = "The Warden", text = "The Warden walks the wilds. Mythic loot on its body." },
    rift = { name = "Rift", text = "A rift restocked every container around it with rare loot." },
    heli = { name = "Helicopter", text = "A helicopter waits for passengers for two minutes." }
}

Events.ORDER = { "airdrop", "horde", "boss", "rift", "heli", "airdrop", "horde", "rift" }

function Events.setup(w)
    w.events = {}
    w.nextEvent = 1
    w.eventTimer = Config.events.first
end

--- A road crossing in a chunk of at least the given tier.
--- @return number, number, number x, y, tier
local function location(w, minTier)
    local points = w.def.roadPoints
    for _ = 1, 60 do
        local p = points[w.rng:random(#points)]
        if p.tier >= minTier then
            local busy = false
            for _, ev in ipairs(w.events) do
                if (ev.x - p.x) ^ 2 + (ev.y - p.y) ^ 2 < 4000 ^ 2 then busy = true end
            end
            if not busy and w.terrain:clear(p.x, p.y, 40) then return p.x, p.y, p.tier end
        end
    end
    return floor(w.def.width / 2), floor(w.def.height / 2), 4
end

--- Starts an event.
--- @param w table
--- @param kind string?
--- @return table
function Events.start(w, kind)
    kind = kind or Events.ORDER[w.rng:random(#Events.ORDER)]
    local x, y, tier = location(w, kind == "heli" and 1 or 2)
    if kind == "boss" and w.def.citadel and w.rng:random() < 0.5 then
        x, y, tier = w.def.citadel.x, w.def.citadel.y, 4
    end
    local ev = {
        id = w.nextEvent, kind = kind, x = x, y = y, tier = tier, phase = "warn",
        timer = Config.events.warn, ticks = 0, alive = 0
    }
    w.nextEvent = w.nextEvent + 1
    w.events[#w.events + 1] = ev
    w:send(nil, "xevent", { k = kind, x = x, y = y, s = "start", n = Events.KINDS[kind].name, t = Events.KINDS[kind].text })
    return ev
end

local function finish(w, ev, message)
    ev.phase, ev.overAt = "over", w.tick
    if ev.extract then
        for k, e in ipairs(w.extracts) do
            if e == ev.extract then table.remove(w.extracts, k) break end
        end
    end
    if message then w:send(nil, "xevent", { k = ev.kind, x = ev.x, y = ev.y, s = "end", n = Events.KINDS[ev.kind].name, t = message }) end
end

local function spawnAround(w, ev, kind, count, radius)
    local Monsters = require("src.game.extraction.monsters")
    for _ = 1, count do
        local a, r = w.rng:random() * math.pi * 2, w.rng:random(60, radius)
        if Monsters.spawn(w, kind, ev.x + math.cos(a) * r, ev.y + math.sin(a) * r, max(3, ev.tier), { event = ev.id, force = true, home = ev }) then
            ev.alive = ev.alive + 1
        end
    end
end

--- The warning is over: the event happens.
local function begin(w, ev)
    ev.phase, ev.timer = "live", Config.events.last
    if ev.kind == "airdrop" then
        local items = Loot.roll("supply", min(4, ev.tier + 1), w.rng, w.alloc)
        ev.drop = w:drop(ev.x, ev.y, "supply", "Supply drop", items, 8, 6, Config.events.last)
        ev.drop.event = true
        spawnAround(w, ev, "sentinel", 3, 260)
        w:send(nil, "xevent", { k = ev.kind, x = ev.x, y = ev.y, s = "live", n = "Supply drop landed", t = "Guarded by sentinels." })
    elseif ev.kind == "horde" then
        spawnAround(w, ev, "crawler", 12, 420)
        spawnAround(w, ev, "stalker", 3, 420)
        spawnAround(w, ev, "brute", 2, 300)
    elseif ev.kind == "boss" then
        spawnAround(w, ev, "warden", 1, 80)
        spawnAround(w, ev, "stalker", 4, 300)
        w:send(nil, "xevent", { k = ev.kind, x = ev.x, y = ev.y, s = "live", n = "The Warden has arrived", t = "Kill it for mythic loot." })
    elseif ev.kind == "rift" then
        w:eachContainer(ev.x, ev.y, 900, function(c)
            c.items, c.refill = nil, 0
            c.tier = min(4, c.tier + 1)
            c.boosted = true
        end)
        spawnAround(w, ev, "stalker", 5, 500)
    elseif ev.kind == "heli" then
        ev.timer = 60 * 120
        ev.extract = { id = 2000 + ev.id, name = "Helicopter", x = ev.x, y = ev.y }
        w.extracts[#w.extracts + 1] = ev.extract
        w:send(nil, "xevent", { k = ev.kind, x = ev.x, y = ev.y, s = "live", n = "The helicopter has landed", t = "Two minutes to get on board." })
    end
end

--- A monster of an event died.
function Events.onDeath(w, m, attacker)
    for _, ev in ipairs(w.events) do
        if ev.id == m.event then
            ev.alive = max(0, ev.alive - 1)
            if ev.kind == "boss" and m.def.boss then
                local items = Loot.roll("supply", "boss", w.rng, w.alloc)
                local drop = w:drop(m.x, m.y, "supply", "Warden's hoard", items, 8, 6, Config.events.last)
                drop.event = true
                finish(w, ev, (attacker and attacker.name or "Someone") .. " killed the Warden.")
            elseif ev.kind == "horde" and ev.alive == 0 and ev.phase == "live" then
                local items = Loot.roll("cache", min(4, ev.tier + 1), w.rng, w.alloc)
                local drop = w:drop(ev.x, ev.y, "cache", "Horde cache", items, 6, 6, Config.events.last)
                drop.event = true
                finish(w, ev, "The horde is gone. Its cache is up for grabs.")
            end
        end
    end
end

--- @param w table
function Events.update(w)
    w.eventTimer = w.eventTimer - 1
    if w.eventTimer <= 0 then
        local live = 0
        for _, ev in ipairs(w.events) do
            if ev.phase ~= "over" then live = live + 1 end
        end
        if live < Config.events.max and next(w.players) then Events.start(w) end
        w.eventTimer = Config.events.every + w.rng:random(0, floor(Config.events.every / 2))
    end
    for k = #w.events, 1, -1 do
        local ev = w.events[k]
        ev.ticks = ev.ticks + 1
        ev.timer = ev.timer - 1
        if ev.phase == "warn" and ev.timer <= 0 then
            begin(w, ev)
        elseif ev.phase == "live" and ev.timer <= 0 then
            finish(w, ev, ev.kind == "heli" and "The helicopter took off." or nil)
        end
        if ev.phase == "over" and w.tick - ev.overAt > 60 * 5 then table.remove(w.events, k) end
    end
    for k = #w.extracts, 1, -1 do
        local e = w.extracts[k]
        if e.expires and e.expires < w.tick then table.remove(w.extracts, k) end
    end
end

--- @param w table
--- @return table[]
function Events.snapshot(w)
    local out = {}
    for _, ev in ipairs(w.events) do
        if ev.phase ~= "over" then
            out[#out + 1] = { i = ev.id, k = ev.kind, x = floor(ev.x), y = floor(ev.y), p = ev.phase, t = max(0, ev.timer) }
        end
    end
    return out
end

return Events
