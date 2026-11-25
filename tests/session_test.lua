local Player = require("src.game.player")
local Config = require("src.config.game")
require("src.modules.index")
local Session = require("src.modules.session.index")

local function snapshot(t, x)
    return { t = t, players = { [1] = { i = 1, x = 0, y = 0, a = 0 }, [2] = { i = 2, x = x, y = 50, a = Player.packAngle(1) } } }
end

return {
    {
        name = "opponent is interpolated between the two snapshots around the render time",
        run = function()
            local fake = setmetatable({
                room = { players = { { slot = 2, name = "Bob" } } },
                world = { slot = 1, rules = { teams = false }, clock = 100 + Config.interpolationTicks, snapshots = { snapshot(98, 0), snapshot(100, 100), snapshot(102, 300) } }
            }, { __index = Session })
            local list = fake:opponents()
            assert(#list == 1 and list[1].slot == 2 and list[1].name == "Bob")
            assert(math.abs(list[1].x - 100) < 1e-6, "at the snapshot time, x = " .. list[1].x)

            fake.world.clock = 101 + Config.interpolationTicks
            assert(math.abs(fake:opponents()[1].x - 200) < 1e-6, "halfway between snapshots")

            fake.world.clock = 200
            assert(fake:opponents()[1].x == 300, "holds the latest snapshot when none is newer")
        end
    }
}
