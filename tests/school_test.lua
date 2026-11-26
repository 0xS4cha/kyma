local School = require("src.net.school")

return {
    {
        name = "42 computers are recognized from their hostname",
        run = function()
            for _, host in ipairs({ "z4r11p1.42lyon.fr", "e1r2p3.42.fr", "c3r5s4.42madrid.com", "z4r11p1", "Z4R11P1.42LYON.FR." }) do
                assert(School.isHost(host), host)
            end
            for _, host in ipairs({ "laptop", "my42.fr", "42lyon.fr.evil.com", "r1p2", "", 42 }) do
                assert(not School.isHost(host), tostring(host))
            end
        end
    },
    {
        name = "a client is from 42 only with a 42 hostname and a valid login",
        run = function()
            assert(School.verify({ login = "habretag", host = "z4r11p1.42lyon.fr" }) == "habretag")
            assert(School.verify({ login = "jean-luc", host = "e1r2p3.42.fr" }) == "jean-luc")
            assert(not School.verify({ login = "habretag", host = "laptop" }), "not a 42 computer")
            assert(not School.verify({ login = "Bad Name", host = "z4r11p1.42lyon.fr" }), "not a login")
            assert(not School.verify({ login = string.rep("a", 40), host = "z4r11p1.42lyon.fr" }), "too long")
            assert(not School.verify("habretag"), "not a claim")
        end
    },
    {
        name = "42-only games are listed on 42 computers only",
        run = function()
            local games = { { name = "open" }, { name = "school", school = true } }
            assert(#School.visible(games, false) == 1 and School.visible(games, false)[1].name == "open", "hidden elsewhere")
            assert(#School.visible(games, "habretag") == 2, "shown at 42")
        end
    }
}
