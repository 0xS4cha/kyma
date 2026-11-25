local Arena = require("src.game.arena")
local World = require("src.game.world")
local Combat = require("src.game.combat")
local Player = require("src.game.player")
local Config = require("src.config.game")

local function duel()
    local world = World.new(Arena.new({
        width = 3000, height = 3000, walls = {},
        spawns = { { x = 1000, y = 1000, angle = 0 }, { x = 1300, y = 1000, angle = math.pi } }
    }))
    world:add(1, "killer")
    world:add(2, "victim")
    return world
end

return {
    {
        name = "a killcam records the last two seconds of both players and the killer's shots",
        run = function()
            local world = duel()
            local s = 0
            for tick = 1, Config.killcamTicks + 30 do
                s = s + 1
                local fire = tick % 30 == 0 and 1 or 0
                world:queue(1, { { s = s, f = 0, r = 1, a = 0, d = 0, b = fire, l = 0, t = 0, e = 0, k = 0, v = world.tick } })
                world:step()
            end
            local recording = Combat.killcam(world, 1, 2)
            assert(recording and recording.k == 1)
            assert(#recording.f >= Config.killcamTicks / 2, "frames " .. #recording.f)
            local first, last = recording.f[1], recording.f[#recording.f]
            assert(last.t - first.t <= Config.killcamTicks and last.t == world.tick)
            assert(last.ky > first.ky, "the killer's strafe is recorded")
            assert(#recording.s >= 3, "shots " .. #recording.s)
            assert(last.kg > 0 and Player.unpackAngle(last.ka) == Player.unpackAngle(Player.packAngle(0)))
        end
    },
    {
        name = "a fresh world has no recording to send",
        run = function()
            local world = duel()
            assert(Combat.killcam(world, 1, 2) == nil)
        end
    },
    {
        name = "the replay darkens in quickly and stays dark",
        run = function()
            local Renderer = require("src.modules.session.renderer")
            assert(Renderer.replayAmount(0) == 0)
            local early = Renderer.replayAmount(0.05)
            assert(early > 0 and early < 1)
            assert(Renderer.replayAmount(0.3) == 1 and Renderer.replayAmount(1) == 1)
        end
    }
}
