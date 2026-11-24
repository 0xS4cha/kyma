local Maps = {}

Maps.order = { "atrium", "offices", "greenhouse", "crossroads", "vault", "colonnade", "labyrinth", "chasm", "courtyard", "warehouse", "rooftops", "metro", "bunker", "gallery", "embassy" }
Maps.default = "atrium"

local cache = {}

--- @param id string?
--- @return string
function Maps.valid(id)
    for _, name in ipairs(Maps.order) do
        if name == id then return id end
    end
    return Maps.default
end

--- @param id string?
--- @return table
function Maps.get(id)
    id = Maps.valid(id)
    if not cache[id] then
        cache[id] = require("src.maps." .. id)
    end
    return cache[id]
end

return Maps
