local Host = require("src.server.host")
local NetKit = require("tests.netkit")

local function tokens(k)
    return { token = string.format("BBBBBBBB-0000-4000-8000-%012d", k) }
end

local function players(port, names)
    local list = {}
    for k, name in ipairs(names) do list[k] = NetKit.client(port, name, tokens(k)) end
    return list
end

--- Ends the current game of a client's room with that client as the winner.
local function win(server, client)
    local room = server.rooms[client.room]
    assert(room, "client is in a room")
    room.world:finish(client.slot, false)
    room:flushEvents()
end

return {
    {
        name = "players create, join and start a tournament",
        run = function()
            local port = 6870
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 8 })
            assert(server:Start())
            local list = players(port, { "Alice", "Bob", "Carol" })
            local a, b, c = list[1], list[2], list[3]
            a.queue = { tournament = { a = "create", name = "Friday cup", mode = "ffa", size = 4, bestOf = 3, map = "vault" } }
            NetKit.run(server, list, function()
                NetKit.pump(server, list, 0.3)
                local state = NetKit.last(a, "tournament")
                assert(state and state.n == "Friday cup" and state.m == "ffa" and state.s == 4 and state.b == 3 and state.map == "vault")
                assert(state.st == "lobby" and state.own == true and #state.pl == 1)

                NetKit.send(b, "tournament", { a = "list" })
                NetKit.pump(server, list, 0.2)
                local found = NetKit.last(b, "tournaments")
                assert(found and #found.list == 1 and found.list[1].n == "Friday cup" and found.list[1].p == 1)

                NetKit.send(b, "tournament", { a = "join", id = state.id })
                NetKit.send(c, "tournament", { a = "join", id = state.id })
                NetKit.pump(server, list, 0.3)
                assert(#NetKit.last(a, "tournament").pl == 3, "three in the lobby")

                NetKit.send(b, "tournament", { a = "start" })
                NetKit.pump(server, list, 0.2)
                assert(NetKit.last(b, "error").message:find("organiser"), "only the owner starts")

                NetKit.send(a, "tournament", { a = "start" })
                NetKit.pump(server, list, 0.3)
                local running = NetKit.last(a, "tournament")
                assert(running.st == "running" and running.br and running.br.s == 4 and #running.e == 3)
                local playing = 0
                for _, client in ipairs(list) do
                    if client.room then playing = playing + 1 end
                end
                assert(playing == 2, "the two lower seeds play, the top seed has a bye")
                local room = server.rooms[a.room or b.room or c.room]
                assert(room.tournament and room.mode == "ffa" and room.map == "vault")
                assert(room.label == "Semi-finals  -  game 1 of 3")

                NetKit.send(c, "queue", { mode = "duel" })
                NetKit.pump(server, list, 0.2)
                assert(server:RoomCount() == 1, "casual players never land in a tournament room")
            end)
        end
    },
    {
        name = "series winners move up until a champion is crowned",
        run = function()
            local port = 6871
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 8 })
            assert(server:Start())
            local list = players(port, { "Alice", "Bob" })
            local a, b = list[1], list[2]
            a.queue = { tournament = { a = "create", mode = "duel", size = 4, bestOf = 3 } }
            NetKit.run(server, list, function()
                NetKit.pump(server, list, 0.3)
                local id = NetKit.last(a, "tournament").id
                assert(NetKit.last(a, "tournament").n == "Alice's cup", "default name")
                NetKit.send(b, "tournament", { a = "join", id = id })
                NetKit.pump(server, list, 0.2)
                NetKit.send(a, "tournament", { a = "start" })
                NetKit.pump(server, list, 0.3)
                assert(a.room and a.room == b.room, "a two player tournament is a final")

                win(server, a)
                NetKit.pump(server, list, 0.2)
                local state = NetKit.last(a, "tournament")
                assert(state.st == "running" and state.br.r[1][1][3] + state.br.r[1][1][4] == 1, "one game counted")
                assert(server.rooms[a.room].label == "Final  -  game 2 of 3")

                win(server, b)
                win(server, b)
                NetKit.pump(server, list, 0.2)
                state = NetKit.last(b, "tournament")
                assert(state.st == "done" and state.e[state.br.c].n == "Bob", "Bob is champion")

                server.tournaments:Update(10)
                NetKit.pump(server, list, 0.3)
                assert(NetKit.count(a, "left") == 1 and NetKit.count(b, "left") == 1, "both are sent back to the bracket")
                assert(server:RoomCount() == 0, "the room is closed")
            end)
        end
    },
    {
        name = "a player who disconnects forfeits and the tournament goes on",
        run = function()
            local port = 6872
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 8 })
            assert(server:Start())
            local list = players(port, { "Alice", "Bob", "Carol", "Dave" })
            list[1].queue = { tournament = { a = "create", mode = "duel", size = 4 } }
            NetKit.run(server, list, function()
                NetKit.pump(server, list, 0.3)
                local id = NetKit.last(list[1], "tournament").id
                for k = 2, 4 do NetKit.send(list[k], "tournament", { a = "join", id = id }) end
                NetKit.pump(server, list, 0.3)
                NetKit.send(list[1], "tournament", { a = "start" })
                NetKit.pump(server, list, 0.3)
                assert(server:RoomCount() == 2, "two semi-finals")

                local quitter = list[4]
                local opponent
                for k = 1, 3 do
                    if list[k].room == quitter.room then opponent = list[k] end
                end
                quitter.peer:disconnect_now()
                local rest = { list[1], list[2], list[3] }
                NetKit.pump(server, rest, 0.3)
                server.tournaments:Update(5)
                NetKit.pump(server, rest, 0.3)
                assert(NetKit.count(opponent, "left") == 1, "the opponent goes back to the bracket")
                local state = NetKit.last(opponent, "tournament")
                local quitterEntry
                for _, entrant in ipairs(state.e) do
                    if entrant.n == "Dave" then quitterEntry = entrant end
                end
                assert(quitterEntry and quitterEntry.l, "Dave is shown as gone")

                local other
                for k = 1, 3 do
                    if list[k] ~= opponent and list[k].room then other = list[k] end
                end
                win(server, other)
                server.tournaments:Update(10)
                NetKit.pump(server, rest, 0.3)
                assert(other.room ~= nil and opponent.room == other.room, "the final starts once both semi-finals are over")
            end)
        end
    },
    {
        name = "an empty tournament lobby closes",
        run = function()
            local port = 6873
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 8 })
            assert(server:Start())
            local list = players(port, { "Alice" })
            list[1].queue = { tournament = { a = "create", size = 16, bestOf = 5 } }
            NetKit.run(server, list, function()
                NetKit.pump(server, list, 0.3)
                assert(server.tournaments:Open() == 1)
                NetKit.send(list[1], "tournament", { a = "leave" })
                NetKit.pump(server, list, 0.2)
                assert(server.tournaments:Open() == 0)
            end)
        end
    }
}
