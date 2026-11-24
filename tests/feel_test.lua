local Camera = require("src.core.camera")
local Settings = require("src.modules.menu.settings")
local Feel = require("src.config.feel")
local Character = require("src.modules.session.character")

local function step(camera, seconds, strength)
    for _ = 1, math.floor(seconds * 60) do camera:update(1 / 60, strength) end
end

return {
    {
        name = "a shake moves the camera within bounds and settles",
        run = function()
            local camera = Camera()
            camera:shake(5)
            assert(camera.trauma == 1, "trauma is capped")
            local moved = false
            for _ = 1, 20 do
                camera:update(1 / 60)
                assert(math.abs(camera.shakeX) <= 14 and math.abs(camera.shakeY) <= 14 and math.abs(camera.roll) <= 0.035)
                if math.abs(camera.shakeX) + math.abs(camera.shakeY) > 0.5 then moved = true end
            end
            assert(moved, "the camera moves")
            step(camera, 1)
            assert(camera.trauma == 0 and camera.shakeX == 0 and camera.shakeY == 0 and camera.roll == 0)
        end
    },
    {
        name = "screen shake off keeps the camera still",
        run = function()
            local camera = Camera()
            camera:shake(1)
            for _ = 1, 20 do
                camera:update(1 / 60, Feel.strength[1])
                assert(camera.shakeX == 0 and camera.shakeY == 0 and camera.roll == 0)
            end
        end
    },
    {
        name = "screen and world positions stay consistent while shaking",
        run = function()
            local graphics = love.graphics
            love.graphics = graphics or { getDimensions = function() return 1280, 720 end }
            local camera = Camera({ scale = 2 })
            camera:follow(300, 200, 0.7)
            camera:shake(1)
            camera:update(0.1)
            local sx, sy = camera:toScreen(340, 150)
            local wx, wy = camera:toWorld(sx, sy)
            love.graphics = graphics
            assert(math.abs(wx - 340) < 1e-6 and math.abs(wy - 150) < 1e-6)
        end
    },
    {
        name = "heavy weapons shake more than light ones",
        run = function()
            assert(Feel.shake.sniper > Feel.shake.shotgun and Feel.shake.shotgun > Feel.shake.pistol)
            assert(Feel.shake.pistol > Feel.shake.silencer and Feel.shake.death > Feel.shake.hurt)
        end
    },
    {
        name = "the screen shake setting defaults to full and is clamped",
        run = function()
            assert(Settings.parse(nil).shake == #Feel.strength)
            assert(Settings.parse("shake=9\n").shake == #Feel.strength)
            assert(Settings.parse("shake=1\n").shake == 1)
            assert(Settings.serialize(Settings.parse("shake=2\n")):find("shake=2", 1, true))
        end
    },
    {
        name = "a shot kicks the gun back, then it recovers",
        run = function()
            Character.reset()
            Character.fire(4, Feel.recoil.sniper.gun, 100)
            assert(Character.recoil(4, 100) == Feel.recoil.sniper.gun)
            local mid = Character.recoil(4, 100.05)
            assert(mid > 0 and mid < Feel.recoil.sniper.gun)
            assert(Character.recoil(4, 101) == 0 and Character.recoil(9, 100) == 0)
            Character.reset()
        end
    },
    {
        name = "camera recoil pushes back then springs home",
        run = function()
            local camera = Camera()
            camera:kick(Feel.recoil.sniper.camera)
            local peak = 0
            for _ = 1, 12 do
                camera:update(1 / 60)
                peak = math.max(peak, camera.shakeY)
            end
            assert(peak > 4 and peak < 30, "peak " .. peak)
            step(camera, 1)
            assert(camera.recoil == 0 and camera.shakeY == 0)
            camera:kick(10)
            camera:update(1 / 60, Feel.strength[1])
            assert(camera.shakeY == 0, "off keeps it still")
        end
    },
    {
        name = "heavier guns kick harder",
        run = function()
            local r = Feel.recoil
            assert(r.sniper.gun > r.shotgun.gun and r.shotgun.gun > r.pistol.gun and r.pistol.gun > r.silencer.gun)
            assert(r.sniper.camera > r.shotgun.camera and r.shotgun.camera > r.pistol.camera)
        end
    }
}
