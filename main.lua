for _, value in ipairs(arg or {}) do
    if value == "--server" then
        require("src.server.run")
        return
    elseif value == "--test" then
        require("tests.runner")
        return
    end
end

local env = require("src.core.env")
local modules = require("src.modules.index")
local GM = require("src.core.index")
local ArgParser = require("src.core.args")
local Threads = require("src.core.thread")
local Transition = require("src.modules.menu.transition")

local BACKGROUND = { 0.93, 0.95, 0.97 }

local flags
local frames = 0
local defaultErrorHandler = love.errorhandler

function love.errorhandler(msg)
    print(debug.traceback(tostring(msg), 3))
    if flags and flags.frames then
        return nil
    end
    return defaultErrorHandler(msg)
end

local function screenshot(path)
    local canvas = love.graphics.newCanvas()
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(BACKGROUND)
    love.draw()
    love.graphics.setCanvas()
    canvas:newImageData():encode("png", path)
    Logger:info("main", "Screenshot saved to " .. love.filesystem.getSaveDirectory() .. "/" .. path)
end

function love.load(args)
    env:Load(".env")
    modules:Load("src/modules")

    local parser = ArgParser.new()
    parser:add_argument("frames", { default = nil, type = "value" })
    parser:add_argument("screenshot", { default = nil, type = "value" })
    parser:add_argument("connect", { default = nil, type = "value" })
    parser:add_argument("host", { default = false, type = "boolean" })
    parser:add_argument("name", { default = nil, type = "value" })
    parser:add_argument("autoplay", { default = false, type = "boolean" })
    parser:add_argument("play", { default = false, type = "boolean" })
    parser:add_argument("practice", { default = nil, type = "value" })
    parser:add_argument("screen", { default = nil, type = "value" })
    parser:add_argument("mode", { default = nil, type = "value" })
    parser:add_argument("map", { default = nil, type = "value" })
    parser:add_argument("watch", { default = false, type = "boolean" })
    parser:add_argument("theme", { default = nil, type = "value" })
    parser:add_argument("find", { default = nil, type = "value" })
    parser:add_argument("tournament", { default = nil, type = "value" })
    parser:add_argument("extraction", { default = false, type = "boolean" })
    parser:add_argument("profile", { default = nil, type = "value" })
    parser:add_argument("deploy", { default = false, type = "boolean" })
    parser:add_argument("show", { default = nil, type = "value" })
    flags = parser:parse(args)
    GM.Flags = flags

    GM:InitializeModules()
    love.graphics.setBackgroundColor(BACKGROUND)

    if flags.profile then require("src.net.identity").use(tostring(flags.profile)) end
    local name = flags.name and tostring(flags.name) or GM.Menu.settings.name
    local game = flags.mode and tostring(flags.mode) or nil
    local map = flags.map and tostring(flags.map) or nil
    if flags.extraction then
        GM.Extraction:Start(flags.connect and tostring(flags.connect) or nil, name)
    elseif flags.tournament then
        local id = tonumber(flags.tournament)
        local request = id and { a = "join", id = id } or { a = "list" }
        GM.Session:Start({ mode = "tournament", address = flags.connect and tostring(flags.connect) or nil, name = name, request = request })
    elseif flags.find then
        GM.Session:Start({ mode = "matchmaking", address = flags.connect and tostring(flags.connect) or nil, name = name, game = tostring(flags.find) })
    elseif flags.connect then
        GM.Session:Start({ mode = "connect", address = tostring(flags.connect), name = name, spectate = flags.watch })
    elseif flags.host then
        GM.Session:Start({ mode = "host", name = name, game = game, map = map })
    elseif flags.practice then
        GM.Session:Start({ mode = "practice", bot = tostring(flags.practice), name = name, game = game, map = map, spectate = flags.watch })
    elseif flags.play or flags.autoplay then
        GM.Session:Start({ mode = "local", name = name, game = game, map = map })
    else
        GM.Menu:Open(flags.screen)
    end
end

function love.update(dt)
    Threads.updateScheduler()
    GM:Think(dt)
    if flags.frames then
        frames = frames + 1
        if frames >= tonumber(flags.frames) then
            if flags.screenshot then
                screenshot(flags.screenshot)
            end
            love.event.quit()
        end
    end
end

local function drawFrame()
    GM:Draw()
end

function love.draw()
    if not Transition.draw(drawFrame) then drawFrame() end
end

function love.wheelmoved(x, y)
    GM:WheelMoved(x, y)
end

function love.textinput(text)
    GM:TextInput(text)
end

function love.keypressed(key, scancode, isrepeat)
    GM:KeyPressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button, istouch, presses)
    GM:MousePressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    GM:MouseReleased(x, y, button, istouch, presses)
end

function love.mousemoved(x, y, dx, dy, istouch)
    GM:MouseMoved(x, y, dx, dy, istouch)
end

function love.quit()
    if GM.Multiplayer then
        GM.Multiplayer:Shutdown()
    end
end
