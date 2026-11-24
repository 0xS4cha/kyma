local Vision = require("src.game.vision")
local Arena = require("src.game.arena")
local Config = require("src.config.game")

local function open()
    return Arena.new({ id = "open", name = "Open", width = 3000, height = 3000, walls = {}, spawns = { { x = 100, y = 100, angle = 0 } } })
end

return {
    {
        name = "you only see as far as the view range",
        run = function()
            local arena = open()
            local me = { x = 500, y = 1500, angle = 0 }
            local range = Config.vision.range
            assert(Vision.sees(arena, me, me.x + range - 40, me.y, Config.player.radius))
            assert(not Vision.sees(arena, me, me.x + range + 40, me.y, Config.player.radius))
            assert(not Vision.sees(arena, me, me.x + 1200, me.y, Config.player.radius), "far enemies stay hidden")
        end
    },
    {
        name = "the view cone stops at the range",
        run = function()
            local arena = open()
            local cone = Vision.fans(arena, 1500, 1500, 0)
            for k = 3, #cone, 2 do
                local d = math.sqrt((cone[k] - 1500) ^ 2 + (cone[k + 1] - 1500) ^ 2)
                assert(d <= Config.vision.range + 1e-6)
            end
            assert(Config.vision.fade > 0 and Config.vision.fade < 1)
        end
    }
}
