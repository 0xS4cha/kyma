local Bracket = require("src.game.bracket")

local function play(bracket, pick)
    local guard = 0
    while not bracket:Done() do
        guard = guard + 1
        assert(guard < 200, "bracket never finishes")
        local match = bracket:Playable()[1]
        assert(match, "a match is always playable until the end")
        bracket:Report(match, pick(match))
    end
end

return {
    {
        name = "seeds keep the top two apart until the final",
        run = function()
            local order = Bracket.seeds(8)
            assert(table.concat(order, ",") == "1,8,4,5,2,7,3,6", table.concat(order, ","))
            local sixteen = Bracket.seeds(16)
            local half
            for position, seed in ipairs(sixteen) do
                if seed == 2 then half = position > 8 end
            end
            assert(sixteen[1] == 1 and sixteen[2] == 16 and half, "seed 2 sits in the other half")
            assert(Bracket.sizeFor(2) == 2 and Bracket.sizeFor(5) == 8 and Bracket.sizeFor(16) == 16)
        end
    },
    {
        name = "missing entrants become byes for the top seeds",
        run = function()
            local bracket = Bracket.new(6)
            assert(bracket.size == 8 and bracket.rounds == 3)
            local first = bracket.matches[1]
            assert(first[1].winner == 1 and first[1].bye, "seed 1 skips the first round")
            assert(first[3].winner == 1 and first[3].sides[1] == 2, "seed 2 too")
            assert(#bracket:Playable() == 2, "only the two real first round matches are playable")
            assert(bracket.matches[2][1].sides[1] == 1, "seed 1 already waits in the semi-final")
        end
    },
    {
        name = "the better seed wins every match and becomes champion",
        run = function()
            local bracket = Bracket.new(8)
            play(bracket, function(match) return match.sides[1] < match.sides[2] and 1 or 2 end)
            assert(bracket.champion == 1)
            assert(Bracket.roundName(3, 3) == "Final" and Bracket.roundName(1, 3) == "Quarter-finals" and Bracket.roundName(1, 4) == "Round of 16")
        end
    },
    {
        name = "a best of three needs two wins",
        run = function()
            local bracket = Bracket.new(2, 3)
            local final = bracket:Playable()[1]
            assert(not bracket:Report(final, 2), "one win is not enough")
            assert(not bracket:Report(final, 1))
            assert(bracket:Report(final, 2), "second win takes the series")
            assert(bracket.champion == 2 and final.wins[1] == 1 and final.wins[2] == 2)
            assert(not bracket:Report(final, 1), "a decided match takes no more results")
            assert(Bracket.new(2, 4).bestOf == 5, "even series are rounded up")
        end
    },
    {
        name = "leaving gives the match to the opponent, even one not known yet",
        run = function()
            local bracket = Bracket.new(4)
            local semi = bracket:Current(1)
            assert(semi.sides[2] == 4)
            local decided = bracket:Forfeit(4)
            assert(decided == semi and semi.winner == 1, "seed 1 wins by walkover")
            local final = bracket.matches[2][1]
            assert(final.sides[1] == 1 and not final.sides[2])
            bracket:Forfeit(1)
            assert(final.winner == nil, "the final waits for the other semi-final")
            local other = bracket:Playable()[1]
            bracket:Report(other, 1)
            assert(final.winner == 2 and bracket.champion == other.sides[1], "the walkover lands once the opponent is known")
            assert(bracket:Forfeit(1) == nil, "forfeiting twice does nothing")
        end
    },
    {
        name = "the packed bracket carries every match",
        run = function()
            local bracket = Bracket.new(5, 3)
            local packed = bracket:Pack()
            assert(packed.n == 5 and packed.s == 8 and packed.b == 3 and #packed.r == 3)
            assert(#packed.r[1] == 4 and #packed.r[2] == 2 and #packed.r[3] == 1)
            local m = packed.r[1][1]
            assert(m[1] == 1 and m[2] == 0 and m[5] == 1 and m[6] == 1, "bye packed")
        end
    }
}
