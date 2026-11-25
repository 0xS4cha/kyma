--- Performance and network measurements for the stats overlay: frame rate,
--- frame time, the server tick rate seen from the snapshots, round trip time,
--- jitter, packet loss and bandwidth. Values are refreshed every INTERVAL
--- seconds and the last HISTORY values of each are kept for the graphs.
local NetStats = {}
NetStats.__index = NetStats

NetStats.INTERVAL = 0.5
NetStats.HISTORY = 60
--- Seconds of snapshots the tick rate, loss and jitter are measured over.
NetStats.WINDOW = 2

NetStats.KEYS = { "fps", "frame", "tick", "rtt", "jitter", "loss", "down", "up" }

--- @param tickRate number server ticks per second
--- @param snapshotTicks number ticks between two snapshots
--- @return table
function NetStats.new(tickRate, snapshotTicks)
    local self = setmetatable({}, NetStats)
    self.tickRate = tickRate
    self.snapshotTicks = snapshotTicks
    self.history = {}
    for _, key in ipairs(NetStats.KEYS) do self.history[key] = {} end
    self:reset()
    return self
end

--- Forgets everything, for a new connection.
function NetStats:reset()
    self.values = {}
    for _, list in pairs(self.history) do
        for k = #list, 1, -1 do list[k] = nil end
    end
    self.sampleAt = nil
    self.frames, self.frameTime, self.worstFrame = 0, 0, 0
    self.bytesIn, self.bytesOut = 0, 0
    self.arrivals = {}
    self.lastTick = nil
end

--- @param dt number seconds the last frame took
function NetStats:frame(dt)
    self.frames = self.frames + 1
    self.frameTime = self.frameTime + dt
    if dt > self.worstFrame then self.worstFrame = dt end
end

--- @param bytes number
function NetStats:received(bytes)
    self.bytesIn = self.bytesIn + bytes
end

--- @param bytes number
function NetStats:sent(bytes)
    self.bytesOut = self.bytesOut + bytes
end

--- Records a snapshot: the server tick it carries and when it arrived.
--- Snapshots skipped between two ticks count as lost; a snapshot older than
--- the last one was dropped by the sequenced channel and is ignored.
--- @param tick number
--- @param now number
function NetStats:snapshot(tick, now)
    if type(tick) ~= "number" then return end
    local last = self.lastTick
    if last and tick <= last then return end
    local entry = { time = now, tick = tick, lost = 0 }
    if last then
        local steps = math.floor((tick - last) / self.snapshotTicks + 0.5)
        entry.lost = math.max(0, steps - 1)
    end
    self.lastTick = tick
    local list = self.arrivals
    list[#list + 1] = entry
    while #list > 1 and now - list[1].time > NetStats.WINDOW do table.remove(list, 1) end
end

--- Tick rate, packet loss and jitter over the snapshots of the last WINDOW.
--- @return number? tick, number? loss, number? jitter
function NetStats:network()
    local list = self.arrivals
    if #list < 3 then return nil end
    local first, last = list[1], list[#list]
    local span = last.time - first.time
    if span <= 0 then return nil end
    local tick = (last.tick - first.tick) / span
    local lost, deviation = 0, 0
    for k = 2, #list do
        local a, b = list[k - 1], list[k]
        lost = lost + b.lost
        deviation = deviation + math.abs((b.time - a.time) - (b.tick - a.tick) / self.tickRate)
    end
    local received = #list - 1
    local loss = lost / (lost + received) * 100
    local jitter = deviation / received * 1000
    return tick, loss, jitter
end

--- @param key string
--- @param value number?
function NetStats:push(key, value)
    self.values[key] = value
    local list = self.history[key]
    list[#list + 1] = value or false
    if #list > NetStats.HISTORY then table.remove(list, 1) end
end

--- Refreshes the values once per INTERVAL.
--- @param now number
--- @param rtt number? round trip time in milliseconds, nil when offline
--- @return boolean refreshed
function NetStats:sample(now, rtt)
    if not self.sampleAt then
        self.sampleAt = now
        return false
    end
    local elapsed = now - self.sampleAt
    if elapsed < NetStats.INTERVAL then return false end
    self.sampleAt = now
    local online = rtt ~= nil
    local latest = self.arrivals[#self.arrivals]
    if latest and now - latest.time > NetStats.WINDOW then
        self.arrivals = {}
    end
    local tick, loss, jitter = self:network()
    self:push("fps", self.frames > 0 and self.frames / self.frameTime or nil)
    self:push("frame", self.frames > 0 and self.worstFrame * 1000 or nil)
    self:push("tick", online and tick or nil)
    self:push("rtt", rtt)
    self:push("jitter", online and jitter or nil)
    self:push("loss", online and loss or nil)
    self:push("down", online and self.bytesIn / elapsed / 1024 or nil)
    self:push("up", online and self.bytesOut / elapsed / 1024 or nil)
    self.frames, self.frameTime, self.worstFrame = 0, 0, 0
    self.bytesIn, self.bytesOut = 0, 0
    return true
end

return NetStats
