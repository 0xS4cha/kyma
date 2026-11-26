local Host = require("src.server.host")
local NetKit = require("tests.netkit")
local NetConfig = require("src.net.config")

return {
    {
        name = "a hosted game keeps its settings and shows up in the server browser",
        run = function()
            local port = 6880
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 8 })
            assert(server:Start())
            local a = NetKit.client(port, "Alice")
            local browser = NetKit.client(port, "Browser")
            a.queue = { host = true, mode = "ffa", map = "atrium", title = "Alice's arena" }
            NetKit.run(server, { a, browser }, function()
                NetKit.pump(server, { a, browser }, 0.3)
                local room = server.rooms[a.room]
                assert(room and room.hosted and room.mode == "ffa" and room.map == "atrium" and room.title == "Alice's arena")
                NetKit.send(browser, "rooms", { v = NetConfig.version })
                NetKit.pump(server, { a, browser }, 0.2)
                local list = NetKit.last(browser, "rooms").list
                assert(#list == 1 and list[1].id == room.id and list[1].t == "Alice's arena" and list[1].m == "ffa" and list[1].p == 1)
                assert(not list[1].lk, "an open game is not locked")
                NetKit.send(browser, "rooms", { v = -1 })
                NetKit.pump(server, { a, browser }, 0.2)
                assert(NetKit.last(browser, "rooms").error, "an old client is told the versions differ")
            end)
        end
    },
    {
        name = "a game with a password only lets in players who know it",
        run = function()
            local port = 6881
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 8 })
            assert(server:Start())
            local a = NetKit.client(port, "Alice")
            local b = NetKit.client(port, "Bob")
            local c = NetKit.client(port, "Carol")
            local d = NetKit.client(port, "Dan")
            a.queue = { host = true, mode = "ffa", password = "secret" }
            NetKit.run(server, { a, b, c, d }, function()
                NetKit.pump(server, { a }, 0.3)
                local id = a.room
                assert(id and server.rooms[id]:Locked())
                b.queue = { room = id }
                c.queue = { room = id, password = "nope" }
                d.queue = { room = id, password = "secret" }
                NetKit.pump(server, { a, b, c, d }, 0.4)
                assert(not b.room and NetKit.last(b, "error").password, "no password")
                assert(not c.room and NetKit.last(c, "error").message == "Wrong password")
                assert(d.room == id, "the right password opens the game")
                assert(server.rooms[id]:Count() == 2)
            end)
        end
    },
    {
        name = "locked games are never picked for a quick join",
        run = function()
            local port = 6882
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 8 })
            assert(server:Start())
            local a = NetKit.client(port, "Alice")
            local b = NetKit.client(port, "Bob")
            a.queue = { host = true, mode = "ffa", password = "secret" }
            NetKit.run(server, { a, b }, function()
                NetKit.pump(server, { a }, 0.3)
                b.queue = { mode = "ffa" }
                NetKit.pump(server, { a, b }, 0.3)
                assert(b.room and b.room ~= a.room, "Bob gets a game of his own")
            end)
        end
    },
    {
        name = "players join a game that already started and play right away",
        run = function()
            local port = 6883
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 8 })
            assert(server:Start())
            local a = NetKit.client(port, "Alice")
            local b = NetKit.client(port, "Bob")
            local c = NetKit.client(port, "Carol")
            a.queue = { host = true, mode = "ffa" }
            NetKit.run(server, { a, b, c }, function()
                NetKit.pump(server, { a, b }, 0.3)
                local room = server.rooms[a.room]
                room.world.phase = "playing"
                c.queue = { room = room.id }
                NetKit.pump(server, { a, c }, 0.3)
                assert(c.room == room.id and c.slot and room.world.players[c.slot], "joined mid-game")
                assert(room.world.phase == "playing", "the game goes on")
                NetKit.send(b, "rooms", { v = NetConfig.version })
                NetKit.pump(server, { a, b, c }, 0.2)
                local list = NetKit.last(b, "rooms").list
                assert(list[1].p == 2 and list[1].ph == "playing")
            end)
        end
    },
    {
        name = "a 42 game only lets in 42 students, under their login",
        run = function()
            local port = 6884
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 8 })
            assert(server:Start())
            local a = NetKit.client(port, "Alice", { school = { login = "alogin", host = "z4r11p1.42lyon.fr" } })
            local b = NetKit.client(port, "Bob", { school = { login = "bob", host = "bobs-laptop" } })
            local c = NetKit.client(port, "Carol", { school = { login = "clogin", host = "e1r2p3.42.fr" } })
            local d = NetKit.client(port, "Dan")
            local e = NetKit.client(port, "Eve")
            a.queue = { host = true, mode = "ffa", school = true }
            e.queue = { host = true, mode = "ffa", school = true }
            NetKit.run(server, { a, b, c, d, e }, function()
                NetKit.pump(server, { a, e }, 0.3)
                local room = server.rooms[a.room]
                assert(room and room.school and room.title == "alogin's game", "a 42 game named after the host's login")
                assert(not e.room and NetKit.last(e, "error"), "only 42 students can open one")
                b.queue = { room = room.id }
                c.queue = { room = room.id }
                d.queue = { mode = "ffa" }
                NetKit.pump(server, { a, b, c, d }, 0.4)
                assert(not b.room and NetKit.last(b, "error").school, "a computer outside 42 is turned away")
                assert(c.room == room.id, "a 42 student joins")
                assert(d.room and d.room ~= room.id, "a quick join never lands in a 42 game")
                local names = {}
                for _, member in ipairs(room.members) do names[member.name] = true end
                assert(names.alogin and names.clogin and not names.Alice and not names.Carol, "everyone plays under their login")
                NetKit.send(d, "rooms", { v = NetConfig.version })
                NetKit.pump(server, { a, c, d }, 0.2)
                local listed
                for _, game in ipairs(NetKit.last(d, "rooms").list) do
                    if game.id == room.id then listed = game end
                end
                assert(listed and listed.s42, "the browser shows it as a 42 game")
                NetKit.send(c, "leave")
                NetKit.pump(server, { a, c }, 0.2)
                local carol
                for _, client in pairs(server.server.clients) do
                    if client.nick == "Carol" then carol = client end
                end
                assert(carol and carol.name == "Carol", "back to the picked name after leaving")
            end)
        end
    }
}
