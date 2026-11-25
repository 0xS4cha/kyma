local NetConfig = require("src.net.config")

local Address = {}

--- Completes a server address typed by a player: trims spaces and adds the
--- default port when none is given ("host" or "host:" become "host:6789").
--- @param address string?
--- @return string? nil when the address is empty
function Address.normalize(address)
    if type(address) ~= "string" then return nil end
    address = address:match("^%s*(.-)%s*$"):gsub(":$", "")
    if address == "" then return nil end
    if not address:find(":", 1, true) then address = address .. ":" .. NetConfig.port end
    return address
end

function Address.lan()
    local ok, socket = pcall(require, "socket")
    if not ok then return nil end
    local probe = (socket.udp4 or socket.udp)()
    if not probe then return nil end
    local connected = pcall(probe.setpeername, probe, "192.0.2.1", 9)
    local address = connected and probe:getsockname() or nil
    probe:close()
    if not address or address == "0.0.0.0" then return nil end
    return address
end

return Address
