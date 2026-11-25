local Class = require("src.core.class")
local Text = require("src.core.text")
local Config = require("src.net.config")
local GameConfig = require("src.config.game")
local Maps = require("src.maps.index")
local Bracket = require("src.game.bracket")

--- Tournaments hosted by a server: a lobby players join, then a bracket whose
--- matches are played in private rooms, one series at a time per pair.
local Tournaments = Class()

--- @param host table the Host that owns the rooms
function Tournaments:init(host)
    self.host = host
    self.list = {}
    self.nextId = 1
end

--- @param value any
--- @param allowed number[]
--- @param default number
--- @return number
local function pick(value, allowed, default)
    value = tonumber(value)
    for _, option in ipairs(allowed) do
        if option == value then return option end
    end
    return default
end

--- @param list table[]
--- @param item any
local function remove(list, item)
    for k = #list, 1, -1 do
        if list[k] == item then table.remove(list, k) end
    end
end

--- @param client table
--- @param message string
local function refuse(client, message)
    client:Send("error", { message = message })
end

--- @return number
function Tournaments:Open()
    local count = 0
    for _, t in pairs(self.list) do
        if t.state ~= "done" then count = count + 1 end
    end
    return count
end

--- Routes a tournament request from a client.
--- @param client table
--- @param data any
function Tournaments:Handle(client, data)
    if type(data) ~= "table" or not client.name then return end
    local action = data.a
    if action == "list" then
        self:SendList(client)
    elseif action == "create" then
        self:Create(client, data)
    elseif action == "join" then
        self:Join(client, tonumber(data.id))
    elseif action == "start" then
        self:Start(client)
    elseif action == "leave" then
        self:Leave(client)
    end
end

--- @param client table
function Tournaments:SendList(client)
    local list = {}
    for _, t in pairs(self.list) do
        if t.state ~= "done" then
            list[#list + 1] = {
                id = t.id, n = t.name, m = t.mode, map = t.map, p = #t.players, s = t.size, b = t.bestOf,
                st = t.state, o = t.owner and t.owner.name or ""
            }
        end
    end
    table.sort(list, function(a, b)
        if (a.st == "lobby") ~= (b.st == "lobby") then return a.st == "lobby" end
        return a.id < b.id
    end)
    client:Send("tournaments", { list = list, server = self.host.name })
end

--- @param client table
--- @param data table
--- @return table?
function Tournaments:Create(client, data)
    if client.room then return refuse(client, "Leave your game before creating a tournament") end
    if self:Open() >= Config.tournament.maxOpen then return refuse(client, "This server already runs too many tournaments") end
    self:Leave(client)
    local mode = GameConfig.modes[data.mode or ""] and data.mode or "duel"
    local name = Text.clean(data.name, Config.tournament.nameLength) or ""
    if name == "" then name = client.name .. "'s cup" end
    local t = {
        id = self.nextId, name = name, mode = mode,
        map = Maps.valid(GameConfig.modes[mode].map or data.map),
        size = pick(data.size, Bracket.SIZES, 8), bestOf = pick(data.bestOf, Bracket.BEST_OF, 1),
        rules = type(data.rules) == "table" and data.rules or nil,
        owner = client, players = {}, entrants = nil, bracket = nil, state = "lobby", rooms = {}
    }
    self.nextId = self.nextId + 1
    self.list[t.id] = t
    Logger:info("tournament", string.format("%s created \"%s\" (%s, %d players, best of %d)", client.name, t.name, mode, t.size, t.bestOf))
    self:Join(client, t.id)
    return t
end

--- @param client table
--- @param id number?
function Tournaments:Join(client, id)
    local t = id and self.list[id]
    if not t then return refuse(client, "This tournament does not exist anymore") end
    if client.tournament == t then return self:send(t, client) end
    if client.room then return refuse(client, "Leave your game before joining a tournament") end
    if t.state ~= "lobby" then return refuse(client, "This tournament has already started") end
    if #t.players >= t.size then return refuse(client, "This tournament is full") end
    self:Leave(client)
    client.tournament = t
    t.players[#t.players + 1] = client
    self:Broadcast(t)
end

--- @param client table
function Tournaments:Start(client)
    local t = client.tournament
    if not t or t.state ~= "lobby" then return end
    if t.owner ~= client then return refuse(client, "Only the organiser can start the tournament") end
    if #t.players < 2 then return refuse(client, "A tournament needs at least two players") end
    local ratings = self.host.ratings
    local seeded = {}
    for k, player in ipairs(t.players) do
        seeded[k] = { client = player, name = player.name, rating = ratings:Rating(player.key), order = k }
    end
    table.sort(seeded, function(a, b)
        if a.rating ~= b.rating then return a.rating > b.rating end
        return a.order < b.order
    end)
    t.entrants = seeded
    for index, entrant in ipairs(seeded) do entrant.client.entrant = index end
    t.bracket = Bracket.new(#seeded, t.bestOf)
    t.state = "running"
    Logger:info("tournament", string.format("\"%s\" starts with %d players", t.name, #seeded))
    self:schedule(t)
    self:Broadcast(t)
end

--- @param client table
function Tournaments:Leave(client)
    local t = client.tournament
    if not t then return end
    client.tournament = nil
    remove(t.players, client)
    if t.state == "lobby" then
        if t.owner == client then t.owner = t.players[1] end
    elseif t.state == "running" then
        local entrant = client.entrant and t.entrants[client.entrant]
        if entrant and entrant.client == client then
            entrant.client, entrant.left = nil, true
            local match = t.bracket:Forfeit(client.entrant)
            if match and match.room then match.room.closing = Config.tournament.forfeitDelay end
            self:finish(t)
            self:schedule(t)
        end
    end
    client.entrant = nil
    if #t.players == 0 and next(t.rooms) == nil then
        self.list[t.id] = nil
        Logger:info("tournament", string.format("\"%s\" closed", t.name))
        return
    end
    self:Broadcast(t)
end

--- @param t table
--- @param match table
--- @return string
function Tournaments:label(t, match)
    local label = Bracket.roundName(match.round, t.bracket.rounds)
    if t.bestOf > 1 then
        label = label .. "  -  game " .. (match.wins[1] + match.wins[2] + 1) .. " of " .. t.bestOf
    end
    return label
end

--- Opens a room for every match whose two players are free.
--- @param t table
function Tournaments:schedule(t)
    if t.state ~= "running" then return end
    for _, match in ipairs(t.bracket:Playable()) do
        if not match.room then
            local a, b = t.entrants[match.sides[1]], t.entrants[match.sides[2]]
            if a.client and b.client and not a.client.room and not b.client.room then
                local room = self.host:CreateRoom({ mode = t.mode, map = t.map, rules = t.rules })
                room.tournament, room.bracketMatch, room.label = t, match, self:label(t, match)
                room.onOver = function(r, data) self:gameOver(t, match, r, data) end
                room.warmupFor = 0
                match.room = room
                t.rooms[room] = true
                room:Add(a.client, 1)
                room:Add(b.client, 2)
                Logger:info("tournament", string.format("\"%s\" %s: %s vs %s in room %d", t.name, room.label, a.name, b.name, room.id))
            end
        end
    end
end

--- @param t table
--- @param match table
--- @param room table
--- @param data table the "over" event
function Tournaments:gameOver(t, match, room, data)
    if room.closing or match.winner then return end
    local side
    for _, member in ipairs(room.members) do
        local player = member.slot and room.world.players[member.slot]
        if player and not member.spectator then
            local won = data.tm == 1 and player.team == data.w or data.tm ~= 1 and member.slot == data.w
            if won and member.entrant then
                side = match.sides[1] == member.entrant and 1 or match.sides[2] == member.entrant and 2 or nil
            end
        end
    end
    if not side then return end
    if t.bracket:Report(match, side) then
        room.closing = Config.tournament.resultDelay
        self:finish(t)
    else
        room.label = self:label(t, match)
        room:refresh()
    end
    self:Broadcast(t)
end

--- @param t table
function Tournaments:finish(t)
    if t.state == "running" and t.bracket:Done() then
        t.state = "done"
        local champion = t.entrants[t.bracket.champion]
        Logger:info("tournament", string.format("\"%s\" won by %s", t.name, champion and champion.name or "?"))
    end
end

--- Sends the players of a finished series back to the bracket.
--- @param t table
--- @param room table
function Tournaments:closeRoom(t, room)
    t.rooms[room] = nil
    if room.bracketMatch then room.bracketMatch.room = nil end
    local members = {}
    for k, member in ipairs(room.members) do members[k] = member end
    for _, member in ipairs(members) do
        room:Remove(member)
        member:Send("left", {})
    end
    self.host.rooms[room.id] = nil
    if #t.players == 0 and next(t.rooms) == nil then
        self.list[t.id] = nil
        return
    end
    self:schedule(t)
    self:Broadcast(t)
end

--- @param dt number
function Tournaments:Update(dt)
    local settings = Config.tournament
    for _, t in pairs(self.list) do
        for room in pairs(t.rooms) do
            if room.closing then
                room.closing = room.closing - dt
                if room.closing <= 0 then self:closeRoom(t, room) end
            elseif room.world.phase == "warmup" then
                room.warmupFor = room.warmupFor + dt
                if room.warmupFor >= settings.readyTimeout then
                    for slot in pairs(room.world.players) do room.world:setReady(slot, true) end
                end
            else
                room.warmupFor = 0
            end
        end
    end
end

--- @param t table
--- @return table
function Tournaments:pack(t)
    local entrants
    if t.entrants then
        entrants = {}
        for k, entrant in ipairs(t.entrants) do
            entrants[k] = { n = entrant.name, l = entrant.left or nil }
        end
    end
    local players = {}
    for k, player in ipairs(t.players) do players[k] = player.name end
    local live = {}
    for room in pairs(t.rooms) do
        local match = room.bracketMatch
        if match then live[#live + 1] = { match.round, match.index, room.id } end
    end
    return {
        id = t.id, n = t.name, m = t.mode, map = t.map, s = t.size, b = t.bestOf, st = t.state,
        o = t.owner and t.owner.name or "", pl = players, e = entrants, br = t.bracket and t.bracket:Pack() or nil,
        lv = live
    }
end

--- @param t table
--- @param client table
function Tournaments:send(t, client)
    local data = self:pack(t)
    data.me = client.entrant
    data.own = t.owner == client or nil
    client:Send("tournament", data)
end

--- @param t table
function Tournaments:Broadcast(t)
    for _, client in ipairs(t.players) do self:send(t, client) end
end

return Tournaments
