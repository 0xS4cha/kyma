--- Single elimination bracket with seeding, byes, best-of series and walkovers.
--- Entrants are numbered from 1 in seed order; the caller keeps what they stand for.
local Bracket = {}
Bracket.__index = Bracket

Bracket.SIZES = { 4, 8, 16 }
Bracket.BEST_OF = { 1, 3, 5 }

--- Seed positions for a bracket of `size`, so that seed 1 and 2 can only meet in the final.
--- @param size number power of two
--- @return number[]
function Bracket.seeds(size)
    local order = { 1 }
    while #order < size do
        local count = #order * 2
        local nextOrder = {}
        for _, seed in ipairs(order) do
            nextOrder[#nextOrder + 1] = seed
            nextOrder[#nextOrder + 1] = count + 1 - seed
        end
        order = nextOrder
    end
    return order
end

--- @param count number entrants
--- @return number
function Bracket.sizeFor(count)
    local size = 2
    while size < count do size = size * 2 end
    return size
end

--- @param round number
--- @param rounds number
--- @return string
function Bracket.roundName(round, rounds)
    local left = rounds - round
    if left == 0 then return "Final" end
    if left == 1 then return "Semi-finals" end
    if left == 2 then return "Quarter-finals" end
    return "Round of " .. 2 ^ (left + 1)
end

--- @param count number entrants, at least 2
--- @param bestOf number? games per series, odd
--- @return table
function Bracket.new(count, bestOf)
    assert(count >= 2, "a bracket needs two entrants")
    bestOf = math.max(1, math.floor(tonumber(bestOf) or 1))
    if bestOf % 2 == 0 then bestOf = bestOf + 1 end
    local size = Bracket.sizeFor(count)
    local self = setmetatable({
        count = count, size = size, bestOf = bestOf, rounds = math.floor(math.log(size) / math.log(2) + 0.5),
        matches = {}, out = {}, champion = nil
    }, Bracket)
    for round = 1, self.rounds do
        self.matches[round] = {}
        for index = 1, size / 2 ^ round do
            self.matches[round][index] = { round = round, index = index, wins = { 0, 0 }, sides = {} }
        end
    end
    local order = Bracket.seeds(size)
    for index, match in ipairs(self.matches[1]) do
        for side = 1, 2 do
            local seed = order[(index - 1) * 2 + side]
            match.sides[side] = seed <= count and seed or nil
        end
    end
    for _, match in ipairs(self.matches[1]) do
        if not match.sides[1] or not match.sides[2] then
            self:decide(match, match.sides[1] and 1 or 2, true)
        end
    end
    return self
end

--- @return number
function Bracket:needed()
    return math.floor(self.bestOf / 2) + 1
end

--- @param match table
--- @return boolean
function Bracket:ready(match)
    return match.winner == nil and match.sides[1] ~= nil and match.sides[2] ~= nil
end

--- @return table[] matches that can be played now
function Bracket:Playable()
    local list = {}
    for round = 1, self.rounds do
        for _, match in ipairs(self.matches[round]) do
            if self:ready(match) then list[#list + 1] = match end
        end
    end
    return list
end

--- @param match table
--- @param side number 1 or 2
--- @param bye boolean?
function Bracket:decide(match, side, bye)
    match.winner = side
    match.bye = bye or nil
    local entrant = match.sides[side]
    if match.round == self.rounds then
        self.champion = entrant
        return
    end
    local parent = self.matches[match.round + 1][math.ceil(match.index / 2)]
    parent.sides[match.index % 2 == 1 and 1 or 2] = entrant
    self:walkover(parent)
end

--- Settles a match at once when an entrant in it already left.
--- @param match table
function Bracket:walkover(match)
    if not self:ready(match) then return end
    local outA, outB = self.out[match.sides[1]], self.out[match.sides[2]]
    if outA and not outB then
        self:decide(match, 2, true)
    elseif outB and not outA then
        self:decide(match, 1, true)
    elseif outA and outB then
        self:decide(match, 1, true)
    end
end

--- Counts a won game in a series.
--- @param match table
--- @param side number 1 or 2
--- @return boolean true once the series is decided
function Bracket:Report(match, side)
    if not self:ready(match) or (side ~= 1 and side ~= 2) then return false end
    match.wins[side] = match.wins[side] + 1
    if match.wins[side] >= self:needed() then
        self:decide(match, side)
        return true
    end
    return false
end

--- An entrant leaves: their current match goes to the opponent, and any later
--- match they would have reached too.
--- @param entrant number
--- @return table? the match that was decided by this, if any
function Bracket:Forfeit(entrant)
    if self.out[entrant] then return nil end
    self.out[entrant] = true
    for round = 1, self.rounds do
        for _, match in ipairs(self.matches[round]) do
            if self:ready(match) and (match.sides[1] == entrant or match.sides[2] == entrant) then
                self:walkover(match)
                return match
            end
        end
    end
    return nil
end

--- @param entrant number
--- @return table? the match this entrant plays or waits for next
function Bracket:Current(entrant)
    for round = 1, self.rounds do
        for _, match in ipairs(self.matches[round]) do
            if match.winner == nil and (match.sides[1] == entrant or match.sides[2] == entrant) then
                return match
            end
        end
    end
end

--- @return boolean
function Bracket:Done()
    return self.champion ~= nil
end

--- Compact form sent to clients: per match { a, b, wins a, wins b, winner side, bye }.
--- @return table
function Bracket:Pack()
    local rounds = {}
    for round = 1, self.rounds do
        local list = {}
        for index, match in ipairs(self.matches[round]) do
            list[index] = { match.sides[1] or 0, match.sides[2] or 0, match.wins[1], match.wins[2], match.winner or 0, match.bye and 1 or 0 }
        end
        rounds[round] = list
    end
    return { n = self.count, s = self.size, b = self.bestOf, r = rounds, c = self.champion }
end

return Bracket
