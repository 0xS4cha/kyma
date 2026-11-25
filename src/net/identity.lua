local UUID = require("src.core.uuid")

local Identity = {}

local FILE = "kyma_identity.txt"

--- @param token any
--- @return boolean
function Identity.valid(token)
    return type(token) == "string" and #token >= 16 and #token <= 64 and token:match("^[%w%-]+$") ~= nil
end

--- Turns a client token into the key a server stores, so the token itself is never written to disk.
--- @param token any
--- @return string?
function Identity.key(token)
    if not Identity.valid(token) then return nil end
    return love.data.encode("string", "hex", love.data.hash("sha256", "kyma:" .. token))
end

--- Loads the token that identifies this player on servers, creating it on first launch.
--- @return string
function Identity.token()
    if Identity.cached then return Identity.cached end
    local saved = love.filesystem.getInfo(FILE) and love.filesystem.read(FILE) or nil
    saved = saved and saved:match("^%s*(.-)%s*$") or nil
    if not Identity.valid(saved) then
        saved = UUID.getUUID()
        love.filesystem.write(FILE, saved .. "\n")
    end
    Identity.cached = saved
    return saved
end

return Identity
