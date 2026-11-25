local json = require("libs.json")

local function egg()
    return json.decode(assert(love.filesystem.read("pterodactyl/egg-kyma.json"), "egg file missing"))
end

return {
    {
        name = "the egg embeds the install script as it is in the repository",
        run = function()
            local data = egg()
            assert(data.meta.version == "PTDL_v2")
            local script = assert(love.filesystem.read("pterodactyl/install.sh"))
            assert(data.scripts.installation.script == script, "regenerate pterodactyl/egg-kyma.json from install.sh")
        end
    },
    {
        name = "the egg variables are the ones the server and installer read",
        run = function()
            local data = egg()
            local run = assert(love.filesystem.read("src/server/run.lua"))
            local install = assert(love.filesystem.read("pterodactyl/install.sh"))
            for _, variable in ipairs(data.variables) do
                local env = variable.env_variable
                assert(run:find('"' .. env .. '"', 1, true) or install:find("${" .. env, 1, true), env .. " is not used")
            end
            assert(data.startup:find("{{SERVER_PORT}}", 1, true), "the server listens on the allocated port")
            assert(json.decode(data.config.startup).done and data.config.stop == "^C")
        end
    }
}
