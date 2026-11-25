local Class = require("src.core.class")
local Config = require("src.net.config")
local GameConfig = require("src.config.game")

--- Groups queued players of close ratings into fresh rooms, one queue per mode.
local Matchmaker = Class()

--- @param host table the Host that owns the rooms
function Matchmaker:init(host)
    self.host = host
    self.queues = {}
    self.clock = 0
    self.statusAt = 0
    for _, mode in ipairs(GameConfig.modes.order) do
        self.queues[mode] = {}
    end
end

--- @param mode string
--- @return number
function Matchmaker.size(mode)
    local rules = GameConfig.modes[mode]
    return math.min(rules.players, Config.matchmaking.sizes[mode] or 2)
end

--- @param mode string?
--- @return number
function Matchmaker:Count(mode)
    if mode then return #(self.queues[mode] or {}) end
    local total = 0
    for _, queue in pairs(self.queues) do total = total + #queue end
    return total
end

--- @param client table
--- @param mode string?
function Matchmaker:Enqueue(client, mode)
    self:Remove(client)
    mode = GameConfig.modes[mode or ""] and mode or "duel"
    local entry = { client = client, mode = mode, rating = self.host.ratings:Rating(client.key), since = self.clock }
    client.searching = entry
    table.insert(self.queues[mode], entry)
    Logger:info("matchmaker", string.format("%s queued for %s (%d)", client.name, mode, entry.rating))
    self:status(entry)
end

--- @param client table
function Matchmaker:Remove(client)
    local entry = client.searching
    if not entry then return end
    client.searching = nil
    local queue = self.queues[entry.mode]
    for k, other in ipairs(queue) do
        if other == entry then
            table.remove(queue, k)
            return
        end
    end
end

--- @param entry table
function Matchmaker:status(entry)
    entry.client:Send("searching", {
        m = entry.mode, q = #self.queues[entry.mode], t = math.floor(self.clock - entry.since),
        s = Matchmaker.size(entry.mode), r = entry.rating, o = self.host.server.count
    })
end

--- Finds a group in a queue that is kept oldest first. The rating window of the
--- oldest player widens while they wait, and after a while a game starts with
--- fewer players than the mode wants.
--- @param queue table[]
--- @param size number
--- @return table[]?
function Matchmaker:pick(queue, size)
    local settings = Config.matchmaking
    for _, anchor in ipairs(queue) do
        local waited = self.clock - anchor.since
        local window = settings.window + settings.widen * waited
        local candidates = {}
        for _, other in ipairs(queue) do
            if other ~= anchor and math.abs(other.rating - anchor.rating) <= window then
                candidates[#candidates + 1] = other
            end
        end
        table.sort(candidates, function(a, b)
            local da, db = math.abs(a.rating - anchor.rating), math.abs(b.rating - anchor.rating)
            if da ~= db then return da < db end
            return a.since < b.since
        end)
        local count
        if #candidates + 1 >= size then
            count = size - 1
        elseif waited >= settings.fillAfter and #candidates >= 1 then
            count = #candidates
        end
        if count then
            local group = { anchor }
            for k = 1, count do group[#group + 1] = candidates[k] end
            return group
        end
    end
end

--- @param dt number
function Matchmaker:Update(dt)
    self.clock = self.clock + dt
    for mode, queue in pairs(self.queues) do
        local size = Matchmaker.size(mode)
        local group = self:pick(queue, size)
        while group do
            for _, entry in ipairs(group) do self:Remove(entry.client) end
            self.host:StartMatch(mode, group)
            group = self:pick(queue, size)
        end
    end
    if self.clock - self.statusAt >= Config.matchmaking.statusInterval then
        self.statusAt = self.clock
        for _, queue in pairs(self.queues) do
            for _, entry in ipairs(queue) do self:status(entry) end
        end
    end
end

return Matchmaker
