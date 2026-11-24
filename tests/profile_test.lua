local Profile = require("src.config.profile")
local Settings = require("src.modules.menu.settings")
local Room = require("src.server.room")

local fakeClient = {}
fakeClient.__index = fakeClient
function fakeClient:Send() end
function fakeClient:SendRaw() end
function fakeClient:Stream() end

return {
    {
        name = "looks are sanitized to valid head and accent indices",
        run = function()
            local look = Profile.sanitize({ h = 3, a = 5 })
            assert(look.h == 3 and look.a == 5)
            look = Profile.sanitize({ h = 99, a = -1 })
            assert(look.h == 1 and look.a == 1)
            look = Profile.sanitize("nope")
            assert(look.h == 1 and look.a == 1)
        end
    },
    {
        name = "profile choices are saved and clamped with the settings",
        run = function()
            local values = Settings.defaults()
            values.body, values.accent, values.head = 4, 7, 3
            local back = Settings.parse(Settings.serialize(values))
            assert(back.body == 4 and back.accent == 7 and back.head == 3)
            local broken = Settings.parse("body=40\naccent=0\nhead=9")
            assert(broken.body == #Profile.bodies and broken.accent == 1 and broken.head == #Profile.heads)
        end
    },
    {
        name = "rooms share every player's look, bots included",
        run = function()
            local room = Room(1, { bot = "easy", mode = "ffa" })
            local client = setmetatable({ id = "c", name = "Alice", look = { h = 2, a = 6 } }, fakeClient)
            room:Add(client)
            for _, player in ipairs(room:Info().players) do
                assert(player.look and player.look.h and player.look.a, player.name .. " has a look")
                if player.id == "c" then assert(player.look.h == 2 and player.look.a == 6) end
            end
        end
    }
}
