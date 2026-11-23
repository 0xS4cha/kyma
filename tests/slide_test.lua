local Arena = require("src.game.arena")
local Player = require("src.game.player")
local World = require("src.game.world")
local Config = require("src.config.game")
local WeaponConfig = require("src.config.weapons")
local NetConfig = require("src.net.config")

local DT = 1 / NetConfig.tickRate

local function arena()
    return Arena.new({ width = 6000, height = 6000, walls = {}, spawns = { { x = 1000, y = 3000, angle = 0 }, { x = 3000, y = 3000, angle = math.pi } } })
end

local function input(fields)
    local c = { f = 0, r = 0, a = 0, d = 0, b = 0, l = 0, t = 0, e = 0, k = 0 }
    for k, v in pairs(fields) do c[k] = v end
    return c
end

local function runUp(p, a)
    for _ = 1, 40 do Player.step(p, input({ f = 1 }), a, DT) end
end

return {
    {
        name = "dash while running forward becomes a slide",
        run = function()
            local a = arena()
            local p = Player.new(1, "a", a:spawn(1))
            runUp(p, a)
            Player.step(p, input({ f = 1, d = 1 }), a, DT)
            assert(p.slide == Config.slide.ticks - 1 and p.dash == 0, "slide " .. p.slide)
            assert(p.cooldown == Config.dash.cooldown, "shares the dash cooldown")
        end
    },
    {
        name = "standing still, walking quietly or strafing still dashes",
        run = function()
            local a = arena()
            for _, fields in ipairs({ {}, { f = 1, k = 1 }, { r = 1 } }) do
                local p = Player.new(1, "a", a:spawn(1))
                for _ = 1, 40 do Player.step(p, input(fields), a, DT) end
                local dash = input(fields)
                dash.d = 1
                Player.step(p, dash, a, DT)
                assert(p.dash > 0 and p.slide == 0)
            end
        end
    },
    {
        name = "a slide goes further than a dash and slows down",
        run = function()
            local a = arena()
            local slider, dasher = Player.new(1, "a", a:spawn(1)), Player.new(1, "a", a:spawn(1))
            runUp(slider, a)
            runUp(dasher, a)
            local sx, dx = slider.x, dasher.x
            Player.step(slider, input({ f = 1, d = 1 }), a, DT)
            Player.step(dasher, input({ d = 1 }), a, DT)
            local early = slider.vx
            for _ = 1, Config.slide.ticks do
                Player.step(slider, input({}), a, DT)
                Player.step(dasher, input({}), a, DT)
            end
            assert(slider.x - sx > dasher.x - dx, "slide " .. (slider.x - sx) .. " dash " .. (dasher.x - dx))
            assert(early > Config.slide.endSpeed * 2, "fast at the start")
        end
    },
    {
        name = "you can shoot while sliding, not while dashing",
        run = function()
            local a = arena()
            local p = Player.new(1, "a", a:spawn(1))
            runUp(p, a)
            Player.step(p, input({ f = 1, d = 1 }), a, DT)
            Player.step(p, input({ b = 1 }), a, DT)
            assert(p.ammo == WeaponConfig.pistol.magazine - 1)
        end
    },
    {
        name = "sliding players are invulnerable only at the start",
        run = function()
            local world = World.new(arena())
            world:add(1, "a")
            local p = world.players[1]
            runUp(p, world.arena)
            Player.step(p, input({ f = 1, d = 1 }), world.arena, DT)
            assert(Player.evading(p))
            for _ = 1, Config.slide.invulnerable do Player.step(p, input({}), world.arena, DT) end
            assert(p.slide > 0 and not Player.evading(p), "vulnerable while slowing down")
        end
    },
    {
        name = "a slide is heard",
        run = function()
            local world = World.new(arena())
            world:add(1, "a")
            world:add(2, "b")
            world.players[2].x = 1500
            local s = 0
            for _ = 1, 41 do
                s = s + 1
                world:queue(1, { { s = s, f = 1, r = 0, a = 0, d = s == 41 and 1 or 0, b = 0, l = 0, t = 0, e = 0, k = 1 } })
                world:step()
            end
            local _, _, noises = world:drain()
            local slid = false
            for _, n in ipairs(noises) do
                if n.kind == "slide" then slid = true end
            end
            assert(not slid, "quiet walking can't slide")
            for _ = 1, Config.dash.cooldown + 10 do
                s = s + 1
                world:queue(1, { { s = s, f = 1, r = 0, a = 0, d = 0, b = 0, l = 0, t = 0, e = 0, k = 0 } })
                world:step()
            end
            world:drain()
            s = s + 1
            world:queue(1, { { s = s, f = 1, r = 0, a = 0, d = 1, b = 0, l = 0, t = 0, e = 0, k = 0 } })
            world:step()
            _, _, noises = world:drain()
            for _, n in ipairs(noises) do
                if n.kind == "slide" then slid = true end
            end
            assert(slid)
        end
    },
    {
        name = "prediction matches the server with slides",
        run = function()
            local world = World.new()
            world:add(1, "a")
            local predicted = Player.new(1, "a", world.arena:spawn(1))
            for s = 1, 400 do
                local c = {
                    s = s, f = 1, r = s % 120 < 60 and 0 or 1, a = Player.packAngle(s * 0.01),
                    d = s % 75 == 0 and 1 or 0, b = s % 9 < 4 and 1 or 0, l = 0, t = 0, e = 0, k = 0
                }
                Player.step(predicted, c, world.arena, DT)
                world:queue(1, { c })
                world:step()
            end
            local server = world.players[1]
            assert(server.x == predicted.x and server.y == predicted.y and server.slide == predicted.slide)
        end
    }
}
