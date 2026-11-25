require("src.core.logger")
local ArgParser = require("src.core.args")

local SUITES = {
    "tests.core_test",
    "tests.net_test",
    "tests.anticheat_test",
    "tests.session_test",
    "tests.dash_test",
    "tests.combat_test",
    "tests.noise_test",
    "tests.impacts_test",
    "tests.slide_test",
    "tests.ammo_test",
    "tests.weapons_test",
    "tests.bot_test",
    "tests.settings_test",
    "tests.map_systems_test",
    "tests.modes_test",
    "tests.maps_test",
    "tests.melee_test",
    "tests.gungame_test",
    "tests.warmup_test",
    "tests.killcam_test",
    "tests.audio_test",
    "tests.profile_test",
    "tests.chat_test",
    "tests.keybinds_test",
    "tests.spectator_test",
    "tests.feel_test",
    "tests.hitstop_test",
    "tests.laser_test",
    "tests.theme_test",
    "tests.vision_test",
    "tests.pause_test",
    "tests.loadout_test",
    "tests.gadgets_test",
    "tests.infiltration_test",
    "tests.server_test",
    "tests.matchmaking_test",
    "tests.bracket_test",
    "tests.tournament_test",
    "tests.pterodactyl_test"
}

local function run(filter)
    Logger.LogLevel = 2
    local passed, failed = 0, {}
    local started = love.timer.getTime()
    for _, path in ipairs(SUITES) do
        local suite = require(path)
        for _, case in ipairs(suite) do
            local name = path:gsub("^tests%.", "") .. " > " .. case.name
            if not filter or name:find(filter, 1, true) then
                local caseStarted = love.timer.getTime()
                local ok, err = xpcall(case.run, debug.traceback)
                local elapsed = love.timer.getTime() - caseStarted
                if ok then
                    passed = passed + 1
                    Logger:test_passed(string.format("%s (%.2fs)", name, elapsed))
                else
                    failed[#failed + 1] = { name = name, err = err }
                    Logger:test_fail(string.format("%s (%.2fs)", name, elapsed))
                end
            end
        end
    end
    print(string.format("\n%d passed, %d failed in %.1fs", passed, #failed, love.timer.getTime() - started))
    for _, failure in ipairs(failed) do
        print("  failed: " .. failure.name)
        print("    " .. tostring(failure.err):gsub("\n", "\n    "))
    end
    return #failed == 0
end

function love.load(args)
    local parser = ArgParser.new()
    parser:add_argument("filter", { default = nil, type = "value" })
    local flags = parser:parse(args)
    local ok, success = xpcall(run, debug.traceback, flags.filter)
    if not ok then
        print(success)
        success = false
    end
    love.event.quit(success and 0 or 1)
end
