local Class = require("src.core.class")
local Server = require("src.server.server")
local Room = require("src.server.room")
local Config = require("src.net.config")
local Profile = require("src.config.profile")
local GameConfig = require("src.config.game")
local Identity = require("src.net.identity")
local Text = require("src.core.text")
local Maps = require("src.maps.index")
local Ratings = require("src.server.ratings")
local Matchmaker = require("src.server.matchmaker")
local Tournaments = require("src.server.tournaments")
local Realm = require("src.server.extraction.realm")

local Host = Class()

function Host:init(options)
    options = options or {}
    self.server = Server({ address = options.address, port = options.port, maxPeers = options.maxPeers, channels = Config.channels })
    self.name = Text.clean(options.name, 40) or ""
    if self.name == "" then self.name = "Kyma server" end
    self.motd = Text.clean(options.motd, 160) or ""
    self.dedicated = options.dedicated == true
    self.rooms = {}
    self.nextRoomId = 1
    self.ratings = Ratings(Host.ratingsPath(options))
    self.matchmaker = Matchmaker(self)
    self.tournaments = Tournaments(self)
    self.official = options.official == true
    if self.official then
        self.realm = Realm(self, { path = Host.dataPath(options, "extraction.json"), seed = options.seed })
    end
    self:bind()
end

--- Where a dedicated server keeps a data file, nil for servers started by the game.
--- @param options table
--- @param file string
--- @return string?
function Host.dataPath(options, file)
    if type(options.data) == "string" and options.data ~= "" then
        return (options.data:gsub("/+$", "")) .. "/" .. file
    end
    if options.dedicated then return file end
    return nil
end

--- Dedicated servers keep ratings on disk, in --data when given. Servers started by
--- the game itself keep them in memory.
--- @param options table
--- @return string?
function Host.ratingsPath(options)
    if type(options.data) == "string" and options.data ~= "" then
        return (options.data:gsub("/+$", "")) .. "/ratings.json"
    end
    if options.dedicated then return "ratings.json" end
    return nil
end

function Host:Start()
    return self.server:Start()
end

function Host:Stop()
    self.ratings:Save()
    if self.realm then self.realm:Save() end
    self.server:Stop()
end

--- @param options table
--- @return table
function Host:CreateRoom(options)
    local room = Room(self.nextRoomId, options)
    self.nextRoomId = self.nextRoomId + 1
    self.rooms[room.id] = room
    Logger:info("server", "Room created", room.id)
    return room
end

--- Opens a room for a group found by the matchmaker. In team modes the players are
--- spread over both sides from the highest rating down, so the sides stay even.
--- @param mode string
--- @param group table[] matchmaker entries
--- @return table
function Host:StartMatch(mode, group)
    local rules = GameConfig.modes[mode]
    local map = rules.map or Maps.order[math.random(#Maps.order)]
    local room = self:CreateRoom({ mode = mode, map = map, matched = true })
    room.onOver = function(r, data) self:rate(r, data) end
    table.sort(group, function(a, b) return a.rating > b.rating end)
    local names = {}
    for k, entry in ipairs(group) do
        local team = rules.teams and ((k % 4 == 1 or k % 4 == 0) and 1 or 2) or nil
        room:Add(entry.client, team)
        names[#names + 1] = entry.client.name
    end
    Logger:info("matchmaker", string.format("Room %d: %s on %s for %s", room.id, mode, map, table.concat(names, ", ")))
    return room
end

--- Rates a finished game of a matchmade room and tells every player their new rating.
--- @param room table
--- @param data table the "over" event
function Host:rate(room, data)
    local winners, losers, players = {}, {}, {}
    for _, member in ipairs(room.members) do
        local player = member.slot and room.world.players[member.slot]
        if player and not member.spectator then
            local won = data.tm == 1 and player.team == data.w or data.tm ~= 1 and member.slot == data.w
            local side = won and winners or losers
            side[#side + 1] = { key = member.key, name = member.name }
            players[#players + 1] = member
        end
    end
    local changes = self.ratings:Record(winners, losers)
    for _, member in ipairs(players) do
        if member.key and changes[member.key] then
            local stats = self.ratings:Get(member.key)
            member:Send("rating", { r = stats.r, d = changes[member.key], w = stats.w, l = stats.l })
        end
    end
end

function Host:Think(dt)
    self.server:Think(dt)
end

--- @return table
function Host:Info()
    return {
        name = self.name, motd = self.motd ~= "" and self.motd or nil, dedicated = self.dedicated,
        players = self.server.count, rooms = self:RoomCount(), official = self.official or nil
    }
end

--- @return number
function Host:RoomCount()
    local count = 0
    for _ in pairs(self.rooms) do count = count + 1 end
    return count
end

function Host:leaveRoom(client)
    self.matchmaker:Remove(client)
    local room = client.room
    if not room then return end
    room:Remove(client)
    if room:Empty() then
        self.rooms[room.id] = nil
        if room.tournament then room.closing = 0 end
        Logger:info("server", "Room closed", room.id)
    end
end

--- @return table[] the rooms anyone can join, oldest first
function Host:Listings()
    local list = {}
    for _, room in pairs(self.rooms) do
        if room:Public() and room:Count() > 0 then list[#list + 1] = room:Listing() end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

--- Opens a room with the settings a player picked, listed in the server browser.
--- @param client table
--- @param options table
function Host:hostRoom(client, options)
    local mode = GameConfig.modes[options.mode or ""] and options.mode or "duel"
    local map = type(options.map) == "string" and options.map or nil
    local title = Text.clean(options.title, Config.titleLength) or ""
    if title == "" then title = client.name .. "'s game" end
    local password = Text.clean(options.password, Config.passwordLength)
    if password == "" then password = nil end
    local room = self:CreateRoom({ mode = mode, map = map, rules = options.rules, hosted = true, title = title, password = password })
    Logger:info("server", string.format("%s hosts room %d (%s)%s", client.name, room.id, mode, password and " with a password" or ""))
    local ok, err = room:Add(client)
    if not ok then client:Send("error", { message = err }) end
end

--- Joins one room picked from the server browser, as a player or to watch it.
--- @param client table
--- @param options table
function Host:joinRoom(client, options)
    local room = self.rooms[tonumber(options.room) or -1]
    if not room or not room:Public() then
        client:Send("error", { message = "This game is over" })
        return
    end
    local password = Text.clean(options.password, Config.passwordLength)
    if not room:Opens(password) then
        client:Send("error", { message = password and password ~= "" and "Wrong password" or "This game needs a password", password = true })
        return
    end
    if options.spectate == true or room:Full() then
        room:Watch(client)
        return
    end
    local ok, err = room:Add(client)
    if not ok then client:Send("error", { message = err }) end
end

function Host:matchmake(client, options)
    options = type(options) == "table" and options or {}
    if options.host == true then return self:hostRoom(client, options) end
    if options.room ~= nil then return self:joinRoom(client, options) end
    local practice = type(options.bot) == "string" and options.bot or nil
    local mode = type(options.mode) == "string" and options.mode or nil
    local map = type(options.map) == "string" and options.map or nil
    local forced = mode and GameConfig.modes[mode] and GameConfig.modes[mode].map
    if forced then map = forced end
    if options.spectate == true then
        local watched
        for _, room in pairs(self.rooms) do
            local fits = (not mode or room.mode == mode) and (not map or room.map == map)
            if fits and not room.practice and not room:Locked() and room:Count() > 0 and (not watched or room.id < watched.id) then
                watched = room
            end
        end
        if not watched and practice then
            watched = self:CreateRoom({ bot = practice, mode = mode, map = map, watch = true, rules = options.rules })
        end
        if not watched then
            client:Send("error", { message = "There is no game to watch" })
            return
        end
        watched:Watch(client)
        return
    end
    local best
    for _, room in pairs(self.rooms) do
        local fits = (not mode or room.mode == mode) and (not map or room.map == map)
        if not practice and not room.practice and not room.matched and not room.tournament and not room:Locked() and fits and not room:Full() and (not best or room.id < best.id) then
            best = room
        end
    end
    if not best then
        best = self:CreateRoom({ bot = practice, mode = mode, map = map, rules = options.rules, title = client.name .. "'s game" })
    end
    local ok, err = best:Add(client)
    if not ok then
        client:Send("error", { message = err })
    end
end

function Host:bind()
    local server = self.server

    server:On("hello", function(client, data)
        data = type(data) == "table" and data or {}
        if data.version ~= Config.version then
            client:Send("error", { message = "Version mismatch: server is v" .. Config.version, fatal = true })
            client:Disconnect()
            return
        end
        local name = type(data.name) == "string" and data.name:gsub("[%c]", ""):sub(1, 24) or ""
        client.name = name ~= "" and name or "Player"
        client.look = Profile.sanitize(data.look)
        client.loadout = require("src.config.loadout").sanitize(data.kit)
        client.key = Identity.key(data.token)
        local welcome = { id = client.id, server = self:Info() }
        if client.key then welcome.rating = self.ratings:Get(client.key) end
        client:Send("welcome", welcome)
    end)

    server:On("queue", function(client, data)
        if not client.name or client.room then return end
        if type(data) == "table" and type(data.tournament) == "table" then
            self.matchmaker:Remove(client)
            self.tournaments:Handle(client, data.tournament)
            return
        end
        if client.tournament then return end
        if type(data) == "table" and data.extraction == true then
            self.matchmaker:Remove(client)
            if not self.realm then
                client:Send("error", { message = "Extraction is only played on the official server", fatal = true })
                return
            end
            self.realm:Join(client)
            return
        end
        if client.realm then return end
        if type(data) == "table" and data.matchmaking == true then
            self.matchmaker:Enqueue(client, type(data.mode) == "string" and data.mode or nil)
            return
        end
        self.matchmaker:Remove(client)
        self:matchmake(client, data)
    end)

    server:On("tournament", function(client, data)
        self.tournaments:Handle(client, data)
    end)

    server:On("rooms", function(client, data)
        if type(data) ~= "table" or data.v ~= Config.version then
            client:Send("rooms", { error = "Version mismatch: server is v" .. Config.version })
            return
        end
        client:Send("rooms", { list = self:Listings(), server = self:Info() })
    end)

    server:On("leaderboard", function(client)
        if not client.name then return end
        client:Send("leaderboard", { top = self.ratings:Top(10), me = client.key and self.ratings:Get(client.key) or nil })
    end)

    server:On("chat", function(client, data)
        if client.room then
            client.room:Chat(client, data)
        end
    end)

    server:On("ping", function(client, data)
        if client.room then
            client.room:Ping(client, data)
        end
    end)

    server:On("hold", function(client, data)
        if client.room then
            client.room:Hold(client, data)
        end
    end)

    server:On("ready", function(client, data)
        if client.room then
            client.room:Ready(client, data)
        end
    end)

    server:On("leave", function(client)
        if client.realm then client.realm:Leave(client) end
        self:leaveRoom(client)
        self.tournaments:Leave(client)
    end)

    server:On("input", function(client, data)
        if client.room then
            client.room:Input(client, data)
        elseif client.realm then
            client.realm:Input(client, data)
        end
    end)

    server:On("xhub", function(client, data)
        if client.realm then client.realm:Hub(client, data) end
    end)

    server:On("xact", function(client, data)
        if client.realm then client.realm:Act(client, data) end
    end)

    server:On("update", function(_, dt)
        self.matchmaker:Update(dt)
        self.tournaments:Update(dt)
        for _, room in pairs(self.rooms) do
            room:Update(dt)
        end
        self.ratings:Update(dt)
        if self.realm then self.realm:Update(dt) end
    end)

    server:On("disconnect", function(client)
        if client.realm then client.realm:Leave(client) end
        self:leaveRoom(client)
        self.tournaments:Leave(client)
    end)
end

return Host
