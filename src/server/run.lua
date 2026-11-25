require("src.core.logger")
local ArgParser = require("src.core.args")
local Host = require("src.server.host")
local Config = require("src.net.config")

local host

--- @param value any
--- @param name string
--- @return any
local function fromEnv(value, name)
    if value ~= nil then return value end
    local env = os.getenv(name)
    if env and env ~= "" then return env end
    return nil
end

function love.load(args)
    local parser = ArgParser.new()
    parser:add_argument("port", { default = nil, type = "value" })
    parser:add_argument("peers", { default = nil, type = "value" })
    parser:add_argument("name", { default = nil, type = "value" })
    parser:add_argument("motd", { default = nil, type = "value" })
    parser:add_argument("data", { default = nil, type = "value" })
    local flags = parser:parse(args)

    math.randomseed(os.time())
    host = Host({
        port = tonumber(fromEnv(flags.port, "PORT")) or Config.port,
        maxPeers = tonumber(fromEnv(flags.peers, "MAX_PEERS")) or Config.maxPeers,
        name = fromEnv(flags.name and tostring(flags.name), "SERVER_NAME"),
        motd = fromEnv(flags.motd and tostring(flags.motd), "SERVER_MOTD"),
        data = fromEnv(flags.data and tostring(flags.data), "DATA_DIR"),
        dedicated = true
    })
    local ok, err = host:Start()
    if not ok then
        error(err)
    end
    Logger:info("server", "Dedicated server \"" .. host.name .. "\" ready")
end

function love.update(dt)
    host:Think(dt)
end

function love.quit()
    if host then
        host:Stop()
    end
end
