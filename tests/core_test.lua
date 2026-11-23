local Random = require("src.core.random")

return {
    {
        name = "random is deterministic for a given seed",
        run = function()
            local a, b = Random.new(42), Random.new(42)
            for _ = 1, 100 do
                assert(a:next() == b:next(), "sequences diverged")
            end
        end
    }
}
