--- Recognizes players on a 42 school computer from the machine's hostname
--- (z4r11p1.42lyon.fr, e1r2p3.42.fr...) and reads their 42 login from the session.
--- Hosts can open games only 42 students can join, where everyone plays under
--- their login.
local School = {}

School.LOGIN_LENGTH = 24

--- @param host any
--- @return boolean
function School.isHost(host)
    if type(host) ~= "string" or #host > 253 then return false end
    host = host:lower():gsub("%.$", "")
    -- a domain of the school network: .42.fr, .42lyon.fr, .42madrid.com, .42-tokyo.jp...
    if host:match("%.42[%w%-]*%.%a+$") then return true end
    -- a cluster computer seen without its domain: z4r11p1, e1r2p3, c3r5s4...
    return host:match("^%a%d+r%d+[ps]%d+$") ~= nil
end

--- @param login any
--- @return boolean
function School.isLogin(login)
    return type(login) == "string" and #login >= 2 and #login <= School.LOGIN_LENGTH and login:match("^[a-z][a-z0-9%-_]*$") ~= nil
end

--- Checks what a client says about itself, the login it plays under, nil when it is not from 42.
--- @param claim any { login, host }
--- @return string?
function School.verify(claim)
    if type(claim) ~= "table" or not School.isHost(claim.host) or not School.isLogin(claim.login) then return nil end
    return claim.login
end

local function trim(value)
    return type(value) == "string" and value:match("^%s*(.-)%s*$") or nil
end

--- @return string?
local function hostname()
    local ok, socket = pcall(require, "socket")
    if ok and type(socket) == "table" and socket.dns and socket.dns.gethostname then
        local name = trim(socket.dns.gethostname())
        if name and name:find("%.") then return name end
        -- the short name only: the full one tells the campus domain
        local full = name and socket.dns.toip and select(2, socket.dns.toip(name))
        if type(full) == "table" and type(full.name) == "string" and full.name:find("%.") then return full.name end
        if name and name ~= "" then return name end
    end
    local env = trim(os.getenv("HOSTNAME"))
    if env and env ~= "" then return env end
    local file = io.open("/etc/hostname", "r")
    if file then
        local name = trim(file:read("*l"))
        file:close()
        if name and name ~= "" then return name end
    end
    return nil
end

--- What this computer says about its player, read once: { login, host } on a
--- 42 computer, nil anywhere else.
--- @return table?
function School.detect()
    if School.cached ~= nil then return School.cached or nil end
    local claim = { host = hostname(), login = trim(os.getenv("USER") or os.getenv("LOGNAME")) }
    School.cached = School.verify(claim) and claim or false
    return School.cached or nil
end

--- @return string? the 42 login of this computer's player
function School.login()
    local claim = School.detect()
    return claim and claim.login or nil
end

return School
