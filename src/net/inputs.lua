local Player = require("src.game.player")
local NetConfig = require("src.net.config")

local Inputs = {}

local floor = math.floor

local function axis(v)
    if v == 1 or v == -1 then return v end
    return 0
end

--- @param raw any
--- @return table?
function Inputs.sanitize(raw)
    if type(raw) ~= "table" then return nil end
    local s, a = raw.s, raw.a
    if type(s) ~= "number" or s ~= floor(s) or s < 1 or s >= 2 ^ 31 then return nil end
    if type(a) ~= "number" or a ~= floor(a) or a < 0 or a >= Player.ANGLE_STEPS then return nil end
    local v = raw.v
    if type(v) ~= "number" or v ~= floor(v) or v < 0 or v >= 2 ^ 31 then v = nil end
    return {
        s = s, f = axis(raw.f), r = axis(raw.r), a = a, v = v,
        d = raw.d == 1 and 1 or 0,
        b = raw.b == 1 and 1 or 0,
        l = raw.l == 1 and 1 or 0,
        t = raw.t == 1 and 1 or 0,
        e = raw.e == 1 and 1 or 0,
        k = raw.k == 1 and 1 or 0,
        x = raw.x == 1 and 1 or 0,
        y = raw.y == 1 and 1 or 0
    }
end

--- @param data any
--- @return table[]
function Inputs.batch(data)
    local out = {}
    if type(data) ~= "table" or type(data.c) ~= "table" then return out end
    for k = 1, math.min(#data.c, NetConfig.inputRedundancy * 2) do
        local command = Inputs.sanitize(data.c[k])
        if command then out[#out + 1] = command end
    end
    table.sort(out, function(a, b) return a.s < b.s end)
    return out
end

return Inputs
