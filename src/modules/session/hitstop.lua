local Hitstop = {}
Hitstop.__index = Hitstop

local BLEND = 0.09
local pi = math.pi

--- @return table
function Hitstop.new()
    return setmetatable({ ending = -1, poses = nil }, Hitstop)
end

--- @param now number
--- @return number
function Hitstop:weight(now)
    if now < self.ending then return 1 end
    local t = (now - self.ending) / BLEND
    if t >= 1 then return 0 end
    return (1 - t) * (1 - t)
end

--- @param now number
--- @param duration number
function Hitstop:start(now, duration)
    if self:weight(now) <= 0 then self.poses = nil end
    self.ending = math.max(self.ending, now + duration)
end

--- @param now number
--- @return boolean
function Hitstop:frozen(now)
    return now < self.ending
end

--- @param slot any
--- @param live table
--- @param now number
--- @return table
function Hitstop:pose(slot, live, now)
    local k = self:weight(now)
    if k <= 0 then
        self.poses = nil
        return live
    end
    self.poses = self.poses or {}
    local frozen = self.poses[slot]
    if not frozen then
        frozen = { x = live.x, y = live.y, angle = live.angle }
        self.poses[slot] = frozen
    end
    local out = {}
    for key, value in pairs(live) do out[key] = value end
    out.x = live.x + (frozen.x - live.x) * k
    out.y = live.y + (frozen.y - live.y) * k
    local turn = ((frozen.angle or 0) - (live.angle or 0) + pi) % (2 * pi) - pi
    out.angle = (live.angle or 0) + turn * k
    out.vx, out.vy = (live.vx or 0) * (1 - k), (live.vy or 0) * (1 - k)
    return out
end

return Hitstop
