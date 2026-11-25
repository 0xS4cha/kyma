local Host = require("src.server.host")
local Identity = require("src.net.identity")
local NetKit = require("tests.netkit")

return {
    {
        name = "identity tokens are validated and hashed",
        run = function()
            assert(not Identity.valid(nil) and not Identity.valid("short") and not Identity.valid(("x"):rep(65)))
            assert(not Identity.valid("has spaces in the token"))
            local token = "D91F4DDB-A02A-4DD0-BD8B-90AD4A46BF31"
            assert(Identity.valid(token))
            local key = Identity.key(token)
            assert(key and #key == 64 and key:match("^%x+$"), "sha256 hex key")
            assert(key == Identity.key(token) and key ~= Identity.key(token .. "0"))
            assert(not key:find(token, 1, true), "the token is not stored in clear")
        end
    },
    {
        name = "the welcome message carries the server name and message of the day",
        run = function()
            local port = 6860
            local server = Host({ address = "127.0.0.1", port = port, maxPeers = 4, name = "Official EU", motd = "Be nice", dedicated = true })
            assert(server:Start())
            local a = NetKit.client(port, "Alice", { token = "D91F4DDB-A02A-4DD0-BD8B-90AD4A46BF31" })
            NetKit.run(server, { a }, function()
                NetKit.pump(server, { a }, 0.3)
                local welcome = NetKit.last(a, "welcome")
                assert(welcome and welcome.server, "welcome received")
                assert(welcome.server.name == "Official EU" and welcome.server.motd == "Be nice")
                assert(welcome.server.dedicated == true and welcome.server.players == 1)
                local client
                for _, c in pairs(server.server.clients) do client = c end
                assert(client.key == Identity.key("D91F4DDB-A02A-4DD0-BD8B-90AD4A46BF31"))
            end)
        end
    }
}
