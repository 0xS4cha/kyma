local Host = require("src.server.host")
local Ratings = require("src.server.ratings")
local Matchmaker = require("src.server.matchmaker")
local NetKit = require("tests.netkit")

local TOKENS = {
    "AAAAAAAA-0000-4000-8000-000000000001",
    "AAAAAAAA-0000-4000-8000-000000000002",
    "AAAAAAAA-0000-4000-8000-000000000003"
}

local function roomOf(server, id)
    return server.rooms[id]
end

return {
    {
        name = "elo moves both sides by the same amount and favours the underdog",
        run = function()
            local ratings = Ratings(nil)
            local even = ratings:Record({ { key = "a", name = "A" } }, { { key = "b", name = "B" } })
            assert(even.a == 16 and even.b == -16, "even game is worth 16")
            assert(ratings:Rating("a") == 1016 and ratings:Rating("b") == 984)
            local upset = ratings:Record({ { key = "b" } }, { { key = "a" } })
            assert(upset.b > 16, "beating a stronger player is worth more")
            local stats = ratings:Get("a")
            assert(stats.w == 1 and stats.l == 1)
            assert(ratings:Top(5)[1].n == "A" or ratings:Top(5)[1].n == "B")
            assert(next(ratings:Record({}, { { key = "a" } })) == nil, "no winner, nothing rated")
        end
    },
    {
        name = "ratings survive a restart of the server",
        run = function()
            local path = "test_ratings.json"
            love.filesystem.remove(path)
            local ratings = Ratings(path)
            ratings:Record({ { key = "k1", name = "Winner" } }, { { key = "k2", name = "Loser" } })
            assert(ratings:Save())
            local again = Ratings(path)
            assert(again:Rating("k1") == 1016 and again:Rating("k2") == 984)
            assert(again:Top(1)[1].n == "Winner")
            love.filesystem.remove(path)
        end
    },
    {
        name = "the rating window widens while a player waits",
        run = function()
            local fake = { ratings = Ratings(nil), server = { count = 0 } }
            local mm = Matchmaker(fake)
            local queue = {
                { rating = 1000, since = 0, client = {} },
                { rating = 1500, since = 0, client = {} }
            }
            assert(mm:pick(queue, 2) == nil, "500 points apart do not match at once")
            mm.clock = 30
            local group = mm:pick(queue, 2)
            assert(group and #group == 2, "they match after waiting")
        end
    },
    {
        name = "a short queue starts with fewer players after a while",
        run = function()
            local fake = { ratings = Ratings(nil), server = { count = 0 } }
            local mm = Matchmaker(fake)
            local queue = {
                { rating = 1000, since = 0, client = {} },
                { rating = 1010, since = 0, client = {} }
            }
            assert(mm:pick(queue, 4) == nil, "waits for four players")
            mm.clock = 26
            local group = mm:pick(queue, 4)
            assert(group and #group == 2, "starts with two")
        end
    },
    {
        name = "two queued players get their own rated duel",
        run = function()
            local port = 6862
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 8 })
            assert(server:Start())
            local a = NetKit.client(port, "Alice", { token = TOKENS[1] })
            local b = NetKit.client(port, "Bob", { token = TOKENS[2] })
            local c = NetKit.client(port, "Carol", { token = TOKENS[3] })
            a.queue = { matchmaking = true, mode = "duel" }
            NetKit.run(server, { a, b, c }, function()
                NetKit.pump(server, { a, b, c }, 0.3)
                local searching = NetKit.last(a, "searching")
                assert(searching and searching.m == "duel" and searching.q == 1 and searching.r == 1000)
                assert(not a.room, "alone in the queue")

                NetKit.send(b, "queue", { matchmaking = true, mode = "duel" })
                NetKit.pump(server, { a, b, c }, 0.3)
                assert(a.room and a.room == b.room, "matched together")
                local room = roomOf(server, a.room)
                assert(room.matched and room.mode == "duel")
                assert(server.matchmaker:Count() == 0, "queue emptied")

                NetKit.send(c, "queue", { mode = "duel" })
                NetKit.pump(server, { a, b, c }, 0.3)
                assert(c.room and c.room ~= a.room, "casual players never join a matchmade room")

                room.world:finish(a.slot, false)
                room:flushEvents()
                NetKit.pump(server, { a, b, c }, 0.3)
                local ra, rb = NetKit.last(a, "rating"), NetKit.last(b, "rating")
                assert(ra and ra.d == 16 and ra.r == 1016 and ra.w == 1, "winner gains")
                assert(rb and rb.d == -16 and rb.r == 984 and rb.l == 1, "loser drops")

                NetKit.send(a, "leaderboard")
                NetKit.pump(server, { a, b, c }, 0.2)
                local board = NetKit.last(a, "leaderboard")
                assert(board and board.top[1].n == "Alice" and board.me.r == 1016)
            end)
        end
    },
    {
        name = "leaving the queue or disconnecting removes the player",
        run = function()
            local port = 6863
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 8 })
            assert(server:Start())
            local a = NetKit.client(port, "Alice", { token = TOKENS[1] })
            local b = NetKit.client(port, "Bob", { token = TOKENS[2] })
            a.queue = { matchmaking = true, mode = "ffa" }
            b.queue = { matchmaking = true, mode = "ffa" }
            NetKit.run(server, { a, b }, function()
                NetKit.pump(server, { a, b }, 0.3)
                assert(server.matchmaker:Count("ffa") == 2, "both wait for a bigger game")
                NetKit.send(a, "leave")
                NetKit.pump(server, { a, b }, 0.2)
                assert(server.matchmaker:Count("ffa") == 1)
                b.peer:disconnect_now()
                NetKit.pump(server, { a }, 0.3)
                assert(server.matchmaker:Count() == 0)
            end)
        end
    },
    {
        name = "team games are split evenly by rating",
        run = function()
            local server = Host({ address = "127.0.0.1", port = 6864, maxPeers = 8 })
            local sent = {}
            local function fake(name, key)
                return { name = name, key = key, Send = function(_, kind, data) sent[#sent + 1] = { name, kind, data } end, SendRaw = function() end }
            end
            server.ratings.players = { k1 = { r = 1400, w = 0, l = 0, n = "A" }, k2 = { r = 1300, w = 0, l = 0, n = "B" }, k3 = { r = 1200, w = 0, l = 0, n = "C" }, k4 = { r = 1100, w = 0, l = 0, n = "D" } }
            local group = {}
            for k = 1, 4 do
                local client = fake("P" .. k, "k" .. k)
                group[k] = { client = client, rating = server.ratings:Rating(client.key) }
            end
            local room = server:StartMatch("teams", group)
            local sums = { 0, 0 }
            for _, entry in ipairs(group) do
                local p = room.world.players[entry.client.slot]
                sums[p.team] = sums[p.team] + entry.rating
            end
            assert(sums[1] == sums[2], "teams " .. sums[1] .. " vs " .. sums[2])
        end
    }
}
