local Host = require("src.server.host")
local Realm = require("src.server.extraction.realm")
local Inventory = require("src.game.extraction.inventory")
local Items = require("src.game.extraction.items")
local ItemConfig = require("src.config.items")
local Config = require("src.config.extraction")
local NetKit = require("tests.netkit")

local function fake(name, key)
    local client = { name = name, key = key, inbox = {} }
    function client:Send(kind, data) self.inbox[#self.inbox + 1] = { kind = kind, data = data } end
    client.SendRaw = function() end
    client.Stream = client.Send
    function client:last(kind)
        for k = #self.inbox, 1, -1 do
            if self.inbox[k].kind == kind then return self.inbox[k].data end
        end
    end
    return client
end

local cachedRealm
local function realm()
    if not cachedRealm then cachedRealm = Realm(nil, { random = 1 }) end
    cachedRealm.store.players = {}
    for slot, member in pairs(cachedRealm.slots) do
        cachedRealm.world:remove(slot)
        cachedRealm.slots[slot] = nil
    end
    cachedRealm.members = {}
    return cachedRealm
end

local function tick(r, seconds)
    for _ = 1, math.floor(seconds * 60) do r:Update(1 / 60) end
end

local function find(list, id)
    for _, inst in ipairs(list) do if inst.d == id then return inst end end
end

return {
    {
        name = "only the official server runs extraction",
        run = function()
            local port = 6871
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 4, dedicated = true })
            assert(server:Start())
            local a = NetKit.client(port, "Ann", { token = "AAAAAAAA-0000-0000-0000-000000000001" })
            a.queue = { extraction = true }
            NetKit.run(server, { a }, function()
                NetKit.pump(server, { a }, 0.4)
                local err = NetKit.last(a, "error")
                assert(err and err.message:find("official"), "refused on a community server")
                assert(not NetKit.last(a, "xhub"))
            end)
        end
    },
    {
        name = "on the official server a player gets a hub, deploys and streams the world",
        run = function()
            local port = 6872
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 4, dedicated = false, official = true })
            assert(server:Start())
            local a = NetKit.client(port, "Ann", { token = "AAAAAAAA-0000-0000-0000-000000000002" })
            a.queue = { extraction = true }
            NetKit.run(server, { a }, function()
                NetKit.pump(server, { a }, 0.4)
                local welcome = NetKit.last(a, "welcome")
                assert(welcome and welcome.server.official == true)
                local hub = NetKit.last(a, "xhub")
                assert(hub and hub.money == Config.startMoney, "a new profile")
                assert(hub.g.primary and hub.g.primary.d == "p9", "starter kit equipped")
                local hubs = NetKit.count(a, "xhub")
                NetKit.send(a, "xhub", { o = "deploy" })
                NetKit.pump(server, { a }, 0.4)
                assert(NetKit.count(a, "xhub") == hubs, "no hub view after deploying, it would close the raid")
                local join = NetKit.last(a, "xjoin")
                assert(join and join.slot == 1 and join.seed == Config.seed)
                NetKit.send(a, "input", { c = { { s = 1, f = 1, r = 0, a = 0 } } })
                NetKit.pump(server, { a }, 0.4)
                local state = NetKit.last(a, "xs")
                assert(state and state.p and state.p[1].i == 1 and state.k >= 1, "snapshots of the world")
                assert(NetKit.last(a, "xinv"), "the inventory view came")
            end)
        end
    },
    {
        name = "the trader buys and sells, the workbench learns plans and crafts by rarity",
        run = function()
            local r = realm()
            local c = fake("Ann", "key-trade")
            r:Join(c)
            local profile = r.members[c].profile
            local money = profile.money
            r:Hub(c, { o = "buy", d = "hornet", r = 1 })
            local smg = find(profile.stash, "hornet")
            assert(smg and profile.money == money - Items.price("hornet", 1))
            r:Hub(c, { o = "buy", d = "hornet", r = 5 })
            assert(profile.money == money - Items.price("hornet", 1), "the trader only sells common hornets")
            r:Hub(c, { o = "sell", i = smg.i })
            assert(not find(profile.stash, "hornet") and profile.money > money - Items.price("hornet", 1))

            local before = profile.money
            profile.money = 0
            r:Hub(c, { o = "buy", d = "medkit" })
            assert(c:last("xtoast").t:find("money"))
            profile.money = before

            r:Hub(c, { o = "craft", d = "ar", r = 1 })
            assert(c:last("xtoast").t:find("plan"), "no plan, no craft")
            local plan = r.store:item("plan_ar", 4)
            Inventory.give({ st = { kind = "grid", w = Config.stash.w, h = Config.stash.h, list = profile.stash } }, plan, { "st" })
            r:Hub(c, { o = "learn", i = plan.i })
            assert(profile.known.ar == 4 and not find(profile.stash, "plan_ar"), "the epic plan was learned")
            r:Hub(c, { o = "craft", d = "ar", r = 5 })
            assert(c:last("xtoast").t:find("Epic"), "the plan caps the rarity")
            r:Hub(c, { o = "craft", d = "ar", r = 4 })
            assert(c:last("xtoast").t:find("Missing"), "not enough materials")
            local stash = { st = { kind = "grid", w = Config.stash.w, h = Config.stash.h, list = profile.stash } }
            for _, part in ipairs(Items.recipe("ar", 4)) do
                local need = part.n
                while need > 0 do
                    local n = math.min(need, ItemConfig.all[part.id].stack)
                    Inventory.give(stash, r.store:item(part.id, 1, n), { "st" })
                    need = need - n
                end
            end
            r:Hub(c, { o = "craft", d = "ar", r = 4 })
            local crafted = find(profile.stash, "ar")
            assert(crafted and crafted.r == 4, "an epic rifle")
            assert(not find(profile.stash, "alloy"), "the alloy was used")
            assert(profile.stats.crafted == 1)
            r:Hub(c, { o = "craft", d = "ammo_light" })
            local light = 0
            for _, inst in ipairs(profile.stash) do if inst.d == "ammo_light" then light = light + inst.n end end
            assert(light >= ItemConfig.yield("ammo_light"), "ammo recipes are known from the start")
        end
    },
    {
        name = "leaving the game leaves the character in the world for a while",
        run = function()
            local r = realm()
            local c = fake("Ann", "key-linger")
            r:Join(c)
            r:Hub(c, { o = "deploy" })
            assert(c:last("xjoin"))
            local slot = r.members[c].slot
            r:Leave(c)
            tick(r, 1)
            assert(r.world.players[slot], "still there after a second")
            local back = fake("Ann", "key-linger")
            r:Join(back)
            assert(back:last("xjoin") and back:last("xjoin").slot == slot, "reconnecting resumes the same character")
            r:Leave(back)
            tick(r, Config.lingerTicks / 60 + 0.2)
            assert(not r.world.players[slot], "gone after the grace time")
            local profile = r.store.players["key-linger"]
            assert(profile.gear.primary and not profile.raid, "a survivor keeps the gear")
        end
    },
    {
        name = "dying in the world loses the gear, extracting keeps the loot",
        run = function()
            local r = realm()
            local c = fake("Ann", "key-die")
            r:Join(c)
            r:Hub(c, { o = "deploy" })
            local slot = r.members[c].slot
            local Fight = require("src.game.extraction.fight")
            Fight.hurtPlayer(r.world, r.world.players[slot], 999, nil)
            tick(r, 3.2)
            local ending = c:last("xend")
            assert(ending and ending.r == "died")
            local profile = r.members[c].profile
            assert(not profile.gear.primary and profile.stats.deaths == 1)
            assert(c:last("xhub"), "back to the hub")

            r:Hub(c, { o = "kit" })
            assert(profile.gear.primary, "the free kit")
            r:Hub(c, { o = "deploy" })
            slot = r.members[c].slot
            local p = r.world.players[slot]
            local gpu = r.store:item("gpu")
            assert(r.world:take(p, gpu))
            local e = r.world.extracts[1]
            p.x, p.y = e.x, e.y
            tick(r, Config.extractTicks / 60 + 0.2)
            assert(c:last("xend").r == "extracted" and profile.stats.extracts == 1)
            local all = Inventory.all(profile.gear)
            assert(find(all, "gpu"), "the loot came home")
        end
    },
    {
        name = "profiles survive a restart",
        run = function()
            local path = "extraction_test_profiles.json"
            love.filesystem.remove(path)
            local Store = require("src.server.extraction.store")
            local store = Store(path)
            local profile = store:Get("key-save", "Ann")
            profile.money = 1234
            profile.known.railgun = 6
            local id = store:alloc()
            assert(store:Save())
            local again = Store(path)
            local loaded = again:Get("key-save")
            assert(loaded.money == 1234 and loaded.known.railgun == 6 and loaded.gear.primary.d == "p9")
            assert(again:alloc() > id, "item ids never repeat")
            love.filesystem.remove(path)
        end
    }
}
