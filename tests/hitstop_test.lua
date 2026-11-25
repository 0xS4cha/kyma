local Hitstop = require("src.modules.session.hitstop")

local function near(a, b) return math.abs(a - b) < 1e-6 end

return {
    {
        name = "a hitstop holds every pose where it was, then eases back",
        run = function()
            local stop = Hitstop.new()
            stop:start(10, 0.1)
            local held = stop:pose(1, { x = 100, y = 50, angle = 0, vx = 200, vy = 0, hp = 80 }, 10)
            assert(near(held.x, 100) and held.hp == 80)
            local still = stop:pose(1, { x = 120, y = 50, angle = 0.5, vx = 200, vy = 0 }, 10.05)
            assert(near(still.x, 100) and near(still.angle, 0) and still.vx == 0, "frozen while it lasts")
            local easing = stop:pose(1, { x = 130, y = 50, angle = 0.5, vx = 200, vy = 0 }, 10.14)
            assert(easing.x > 100 and easing.x < 130, "eases back to the live pose")
            local live = { x = 140, y = 50, angle = 0.5 }
            assert(stop:pose(1, live, 10.3) == live, "back to live")
            assert(stop.poses == nil)
        end
    },
    {
        name = "a hitstop never shortens one already running",
        run = function()
            local stop = Hitstop.new()
            stop:start(0, 0.12)
            stop:start(0.02, 0.05)
            assert(stop:frozen(0.11) and not stop:frozen(0.13))
            stop:start(0.1, 0.1)
            assert(stop:frozen(0.19))
        end
    },
    {
        name = "angles ease the short way round",
        run = function()
            local stop = Hitstop.new()
            stop:start(0, 0.1)
            stop:pose(2, { x = 0, y = 0, angle = math.pi - 0.1 }, 0)
            local turned = stop:pose(2, { x = 0, y = 0, angle = -math.pi + 0.1 }, 0.05)
            assert(near(turned.angle, -math.pi + 0.1 - 0.2), "held through the wrap")
        end
    },
    {
        name = "a hitstop does not touch the live tables",
        run = function()
            local stop = Hitstop.new()
            stop:start(0, 0.1)
            local live = { x = 5, y = 5, angle = 0 }
            stop:pose(3, live, 0)
            live.x = 50
            local held = stop:pose(3, live, 0.05)
            assert(live.x == 50 and held ~= live and near(held.x, 5))
        end
    }
}
