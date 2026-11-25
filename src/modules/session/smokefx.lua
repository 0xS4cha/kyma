--- What disturbs the smoke clouds, on the client only: bullets punch
--- tunnels through them that slowly close, players walking through leave a
--- wake, flashbangs blow a hole, and muzzle flashes light them from inside.
--- The server still decides what the smoke hides, so the holes only thin the
--- cloud, they never clear it.
local SmokeFx = {}
SmokeFx.__index = SmokeFx

local MAX_CUTS = 12
local MAX_GLOWS = 4
local BULLET = { radius = 15, grow = 0.7, life = 1.6, strength = 0.9 }
local WAKE = { radius = 24, grow = 0.4, life = 0.9, strength = 0.6 }
local BLAST = { life = 1.8, strength = 1 }

--- @return table
function SmokeFx.new()
    return setmetatable({ cuts = {}, wakes = {} }, SmokeFx)
end

--- @param ax number
--- @param ay number
--- @param bx number
--- @param by number
--- @param radius number
--- @param def table
function SmokeFx:add(ax, ay, bx, by, radius, def)
    self.cuts[#self.cuts + 1] = {
        ax = ax, ay = ay, bx = bx, by = by, radius = radius, grow = def.grow or 0.5,
        life = def.life, strength = def.strength, time = love.timer.getTime()
    }
    if #self.cuts > 64 then table.remove(self.cuts, 1) end
end

--- A bullet's path, from the muzzle to where it stopped.
function SmokeFx:bullet(x1, y1, x2, y2)
    self:add(x1, y1, x2, y2, BULLET.radius, BULLET)
end

--- A player moving through a cloud, at most every few hundredths of a second
--- for each player.
--- @param key any
--- @param x number
--- @param y number
function SmokeFx:wake(key, x, y)
    local now = love.timer.getTime()
    if self.wakes[key] and now - self.wakes[key] < 0.06 then return end
    self.wakes[key] = now
    self:add(x, y, x, y, WAKE.radius, WAKE)
end

--- @param x number
--- @param y number
--- @param radius number
function SmokeFx:blast(x, y, radius)
    self:add(x, y, x, y, radius, BLAST)
end

function SmokeFx:update()
    local now = love.timer.getTime()
    for k = #self.cuts, 1, -1 do
        local cut = self.cuts[k]
        if now - cut.time > cut.life then table.remove(self.cuts, k) end
    end
end

--- Distance from a point to a segment.
local function distance(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len = dx * dx + dy * dy
    local t = len > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / len)) or 0
    local qx, qy = ax + dx * t - px, ay + dy * t - py
    return math.sqrt(qx * qx + qy * qy)
end

--- Sends the disturbances near one cloud to the smoke shader, in the
--- cloud's own coordinates (-1 to 1 across the drawn square).
--- @param shader love.Shader
--- @param smoke table { x, y, r }
--- @param half number half the drawn size
--- @param lights table[]? muzzle lights { x, y, time, strength }
--- @param lightLife number
function SmokeFx:send(shader, smoke, half, lights, lightLife)
    local now = love.timer.getTime()
    local cuts, infos = {}, {}
    for k = #self.cuts, 1, -1 do
        local cut = self.cuts[k]
        local age = now - cut.time
        local radius = cut.radius * (1 + cut.grow * age / cut.life)
        if #cuts < MAX_CUTS and distance(smoke.x, smoke.y, cut.ax, cut.ay, cut.bx, cut.by) < half + radius then
            local open = math.min(1, age / 0.06)
            local strength = cut.strength * open * (1 - age / cut.life) ^ 1.5
            cuts[#cuts + 1] = { (cut.ax - smoke.x) / half, (cut.ay - smoke.y) / half, (cut.bx - smoke.x) / half, (cut.by - smoke.y) / half }
            infos[#infos + 1] = { radius / half, strength }
        end
    end
    while #cuts < MAX_CUTS do
        cuts[#cuts + 1] = { 0, 0, 0, 0 }
        infos[#infos + 1] = { 0, 0 }
    end
    local glows = {}
    for _, light in ipairs(lights or {}) do
        local t = (now - light.time) / lightLife
        if #glows < MAX_GLOWS and t < 1 then
            local dx, dy = light.x - smoke.x, light.y - smoke.y
            if dx * dx + dy * dy < (half + 60) ^ 2 then
                glows[#glows + 1] = { dx / half, dy / half, (1 - t) ^ 1.6 * math.min(1.3, light.strength) }
            end
        end
    end
    while #glows < MAX_GLOWS do glows[#glows + 1] = { 0, 0, 0 } end
    shader:send("cuts", unpack(cuts))
    shader:send("cutInfo", unpack(infos))
    shader:send("glows", unpack(glows))
end

return SmokeFx
