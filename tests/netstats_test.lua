local NetStats = require("src.net.netstats")

local TICK_RATE, SNAPSHOT_TICKS = 60, 2
local STEP = SNAPSHOT_TICKS / TICK_RATE

--- Feeds snapshots every STEP seconds for a duration, skipping the ones `drop` says.
--- @return table stats, number now
local function stream(seconds, drop, delay)
    local stats = NetStats.new(TICK_RATE, SNAPSHOT_TICKS)
    local now, tick, n = 0, 0, 0
    stats:sample(now, 20)
    while now < seconds do
        n = n + 1
        tick = tick + SNAPSHOT_TICKS
        now = now + STEP
        if not (drop and drop(n)) then
            stats:snapshot(tick, now + (delay and delay(n) or 0))
        end
        stats:frame(1 / 120)
        stats:sample(now, 20)
    end
    return stats, now
end

local function near(a, b, tolerance, label)
    assert(a and math.abs(a - b) <= tolerance, ("%s: %s, expected %s"):format(label, tostring(a), tostring(b)))
end

return {
    {
        name = "a steady server reads 60 ticks per second with no loss or jitter",
        run = function()
            local stats = stream(3)
            near(stats.values.tick, 60, 0.5, "tick rate")
            near(stats.values.loss, 0, 0.001, "loss")
            near(stats.values.jitter, 0, 0.001, "jitter")
            near(stats.values.rtt, 20, 0, "round trip")
        end
    },
    {
        name = "missing snapshots count as packet loss",
        run = function()
            local stats = stream(3, function(n) return n % 10 == 0 end)
            near(stats.values.loss, 10, 1.5, "one snapshot in ten lost")
            near(stats.values.tick, 60, 1, "the tick rate is unaffected")
        end
    },
    {
        name = "a slow server shows a lower tick rate",
        run = function()
            local stats = NetStats.new(TICK_RATE, SNAPSHOT_TICKS)
            local now, tick = 0, 0
            stats:sample(now, 20)
            for _ = 1, 90 do
                tick = tick + SNAPSHOT_TICKS
                now = now + STEP * 2
                stats:snapshot(tick, now)
                stats:sample(now, 20)
            end
            near(stats.values.tick, 30, 0.5, "half speed")
            near(stats.values.loss, 0, 0.001, "slow is not lost")
        end
    },
    {
        name = "irregular arrivals show up as jitter",
        run = function()
            local stats = stream(3, nil, function(n) return n % 2 == 0 and 0.010 or 0 end)
            near(stats.values.jitter, 10, 0.5, "10 ms back and forth")
        end
    },
    {
        name = "late snapshots dropped by the channel are ignored",
        run = function()
            local stats = NetStats.new(TICK_RATE, SNAPSHOT_TICKS)
            stats:snapshot(10, 1)
            stats:snapshot(12, 1.03)
            stats:snapshot(8, 1.04)
            stats:snapshot(14, 1.07)
            assert(stats.lastTick == 14, "the old tick is skipped")
            assert(#stats.arrivals == 3, "three arrivals kept")
        end
    },
    {
        name = "frame rate, frame time and bandwidth per interval",
        run = function()
            local stats = NetStats.new(TICK_RATE, SNAPSHOT_TICKS)
            stats:sample(0, 30)
            for k = 1, 30 do stats:frame(k == 10 and 0.05 or 1 / 60) end
            stats:received(2048)
            stats:sent(512)
            assert(stats:sample(0.5, 30), "a new sample after the interval")
            near(stats.values.fps, 30 / (29 / 60 + 0.05), 0.01, "frames over time spent")
            near(stats.values.frame, 50, 0.001, "the slowest frame")
            near(stats.values.down, 4, 0.001, "2 KB in half a second")
            near(stats.values.up, 1, 0.001, "0.5 KB in half a second")
            assert(not stats:sample(0.6, 30), "no new sample before the interval")
        end
    },
    {
        name = "offline shows no network values and the history stays bounded",
        run = function()
            local stats = NetStats.new(TICK_RATE, SNAPSHOT_TICKS)
            for k = 0, 100 do
                stats:frame(1 / 60)
                stats:sample(k * NetStats.INTERVAL, nil)
            end
            assert(stats.values.fps, "fps still measured")
            assert(stats.values.rtt == nil and stats.values.tick == nil and stats.values.loss == nil, "no network values offline")
            assert(#stats.history.fps == NetStats.HISTORY, "history capped at " .. NetStats.HISTORY)
        end
    },
    {
        name = "updates that stop clear the network values instead of failing",
        run = function()
            local stats, now = stream(1)
            for k = 1, 10 do stats:sample(now + k * NetStats.INTERVAL, 20) end
            assert(stats.values.tick == nil, "no tick rate without recent updates")
            stats:snapshot(stats.lastTick + SNAPSHOT_TICKS, now + 6)
            stats:sample(now + 6, 20)
        end
    },
    {
        name = "stats settings are clamped when loaded",
        run = function()
            local Settings = require("src.modules.menu.settings")
            local values = Settings.parse("statFps=4\nstatLoss=9\nstatTick=0\n")
            assert(values.statFps == 4, "both")
            assert(values.statLoss == #Settings.STAT_MODES, "clamped high")
            assert(values.statTick == 1, "clamped low")
            assert(values.statRtt == 1, "hidden by default")
        end
    }
}
