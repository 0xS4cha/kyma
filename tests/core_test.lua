local Random = require("src.core.random")
local Address = require("src.net.address")

return {
    {
        name = "random is deterministic for a given seed",
        run = function()
            local a, b = Random.new(42), Random.new(42)
            for _ = 1, 100 do
                assert(a:next() == b:next(), "sequences diverged")
            end
        end
    },
    {
        name = "a server address without a port gets the default one",
        run = function()
            local cases = {
                { "play.example.com", "play.example.com:6789" },
                { "192.168.1.20", "192.168.1.20:6789" },
                { "192.168.1.20:", "192.168.1.20:6789" },
                { "  localhost  ", "localhost:6789" },
                { "localhost:7000", "localhost:7000" },
                { " host:7000 ", "host:7000" }
            }
            for _, case in ipairs(cases) do
                local got = Address.normalize(case[1])
                assert(got == case[2], ("%q gave %q, expected %q"):format(case[1], tostring(got), case[2]))
            end
            assert(Address.normalize("") == nil, "an empty address is nil")
            assert(Address.normalize("   ") == nil, "a blank address is nil")
            assert(Address.normalize(nil) == nil, "no address is nil")
        end
    }
}
