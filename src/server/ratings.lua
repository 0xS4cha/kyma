local Class = require("src.core.class")
local json = require("libs.json")

--- Elo ratings for matchmade games, keyed by the hashed identity of each player.
local Ratings = Class()

Ratings.START = 1000
Ratings.K = 32
Ratings.SAVE_EVERY = 10

--- @param path string? file the ratings are kept in, nil keeps them in memory only
function Ratings:init(path)
    self.path = path
    self.players = {}
    self.dirty = false
    self.clock = 0
    self:load()
end

--- @return string?
function Ratings:read()
    if not self.path then return nil end
    if self.path:sub(1, 1) == "/" then
        local file = io.open(self.path, "r")
        if not file then return nil end
        local content = file:read("*a")
        file:close()
        return content
    end
    return love.filesystem.getInfo(self.path) and love.filesystem.read(self.path) or nil
end

--- @param content string
--- @return boolean
function Ratings:write(content)
    if self.path:sub(1, 1) == "/" then
        local temp = self.path .. ".tmp"
        local file = io.open(temp, "w")
        if not file then return false end
        file:write(content)
        file:close()
        return os.rename(temp, self.path) == true
    end
    return love.filesystem.write(self.path, content) == true
end

function Ratings:load()
    local content = self:read()
    if not content then return end
    local ok, data = pcall(json.decode, content)
    if not ok or type(data) ~= "table" or type(data.players) ~= "table" then
        Logger:warn("ratings", "Ignoring unreadable ratings file " .. tostring(self.path))
        return
    end
    for key, entry in pairs(data.players) do
        if type(key) == "string" and type(entry) == "table" and tonumber(entry.r) then
            self.players[key] = {
                r = tonumber(entry.r), w = tonumber(entry.w) or 0, l = tonumber(entry.l) or 0,
                n = type(entry.n) == "string" and entry.n or "Player"
            }
        end
    end
end

--- @return boolean
function Ratings:Save()
    if not self.path or not self.dirty then return true end
    local ok = self:write(json.encode({ version = 1, players = self.players }))
    if ok then
        self.dirty = false
    else
        Logger:warn("ratings", "Could not save ratings to " .. self.path)
    end
    return ok
end

--- @param dt number
function Ratings:Update(dt)
    self.clock = self.clock + dt
    if self.clock >= Ratings.SAVE_EVERY then
        self.clock = 0
        self:Save()
    end
end

--- @param key string?
--- @return number
function Ratings:Rating(key)
    local entry = key and self.players[key]
    return entry and entry.r or Ratings.START
end

--- @param key string?
--- @return table
function Ratings:Get(key)
    local entry = key and self.players[key]
    if not entry then return { r = Ratings.START, w = 0, l = 0 } end
    return { r = entry.r, w = entry.w, l = entry.l }
end

--- @param key string
--- @param name string?
--- @return table
function Ratings:entry(key, name)
    local entry = self.players[key]
    if not entry then
        entry = { r = Ratings.START, w = 0, l = 0, n = "Player" }
        self.players[key] = entry
    end
    if name then entry.n = name end
    return entry
end

--- @param list table[] { key, name }
--- @return number
function Ratings:average(list)
    local sum = 0
    for _, player in ipairs(list) do sum = sum + self:Rating(player.key) end
    return sum / math.max(1, #list)
end

--- Rates a finished game between a winning side and a losing side. Every player
--- of a side moves by the same amount, from the average rating of each side.
--- @param winners table[] { key, name }
--- @param losers table[] { key, name }
--- @return table<string, number> rating change per key
function Ratings:Record(winners, losers)
    local changes = {}
    if #winners == 0 or #losers == 0 then return changes end
    local rw, rl = self:average(winners), self:average(losers)
    local expected = 1 / (1 + 10 ^ ((rl - rw) / 400))
    local delta = math.max(1, math.floor(Ratings.K * (1 - expected) + 0.5))
    for _, player in ipairs(winners) do
        if player.key then
            local entry = self:entry(player.key, player.name)
            entry.r, entry.w = entry.r + delta, entry.w + 1
            changes[player.key] = delta
        end
    end
    for _, player in ipairs(losers) do
        if player.key then
            local entry = self:entry(player.key, player.name)
            entry.r, entry.l = math.max(0, entry.r - delta), entry.l + 1
            changes[player.key] = -delta
        end
    end
    self.dirty = true
    return changes
end

--- @param count number
--- @return table[]
function Ratings:Top(count)
    local list = {}
    for _, entry in pairs(self.players) do
        if entry.w + entry.l > 0 then list[#list + 1] = entry end
    end
    table.sort(list, function(a, b)
        if a.r ~= b.r then return a.r > b.r end
        return a.n < b.n
    end)
    local out = {}
    for k = 1, math.min(count, #list) do
        local entry = list[k]
        out[k] = { n = entry.n, r = entry.r, w = entry.w, l = entry.l }
    end
    return out
end

return Ratings
