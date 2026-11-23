local Arena = require("src.game.arena")
local Player = require("src.game.player")
local World = require("src.game.world")
local Weapons = require("src.game.weapons")
local Config = require("src.config.game")
local NetConfig = require("src.net.config")

local DT = 1 / NetConfig.tickRate

local function duel(second)
    local world = World.new(Arena.new({
        width = 6000, height = 6000, walls = {},
        spawns = { { x = 1000, y = 1000, angle = 0 }, second or { x = 1400, y = 1000, angle = math.pi } }
    }))
    world:add(1, "a")
    world:add(2, "b")
    return world, world.players[1], world.players[2]
end

local s = 0
local function step(world, fields)
    s = s + 1
    local c = { s = s, f = 0, r = 0, a = Player.packAngle(fields and fields.angle or 0), d = 0, b = 0, l = 0, t = 0, e = 0, k = 0 }
    for k, v in pairs(fields or {}) do
        if k ~= "angle" then c[k] = v end
    end
    world:queue(1, { c })
    world:step()
end

return {
    {
        name = "the sniper kills in one shot",
        run = function()
            local world, a, b = duel()
            Weapons.give(a, "sniper")
            step(world, { b = 1 })
            assert(b.hp == 0 and b.dead > 0)
        end
    },
    {
        name = "the silencer makes no noise and hides its shots from those who can't see the shooter",
        run = function()
            local world, a = duel({ x = 1400, y = 1000, angle = 0 })
            Weapons.give(a, "silencer")
            step(world, { b = 1, angle = math.pi / 2 })
            local _, shots, noises = world:drain()
            assert(#noises == 0, "no shot noise")
            assert(#shots == 1 and shots[1].q == 1)
            assert(not world:shows(2, shots[1]), "hidden from a player who can't see the shooter")
            assert(world:shows(1, shots[1]), "the shooter sees their own tracer")
        end
    },
    {
        name = "loud weapons still make noise and show their shots",
        run = function()
            local world, a = duel({ x = 1400, y = 1000, angle = 0 })
            step(world, { b = 1, angle = math.pi / 2 })
            local _, shots, noises = world:drain()
            assert(#noises >= 1 and world:shows(2, shots[1]))
        end
    },
    {
        name = "the lmg slows its carrier and prevents sliding",
        run = function()
            local arena = Arena.new({ width = 6000, height = 6000, walls = {}, spawns = { { x = 1000, y = 3000, angle = 0 } } })
            local light, heavy = Player.new(1, "a", arena:spawn(1)), Player.new(1, "a", arena:spawn(1))
            Weapons.give(heavy, "lmg")
            local input = { f = 1, r = 0, a = 0, d = 0, b = 0, l = 0, t = 0, e = 0, k = 0 }
            for _ = 1, 60 do
                Player.step(light, input, arena, DT)
                Player.step(heavy, input, arena, DT)
            end
            assert(heavy.vx < light.vx * 0.8, "heavy " .. heavy.vx .. " light " .. light.vx)
            input.d = 1
            Player.step(heavy, input, arena, DT)
            assert(heavy.slide == 0 and heavy.dash > 0, "dashes instead of sliding")
        end
    },
    {
        name = "a hidden sniper's aim is sent to the opponent, other weapons' are not",
        run = function()
            local world, a = duel({ x = 1400, y = 1000, angle = 0 })
            Weapons.give(a, "sniper")
            step(world, { angle = math.pi / 2 })
            local aims = world:snapshot(2).aims
            assert(#aims == 1 and aims[1].i == 1)
            Weapons.give(a, "rifle")
            assert(#world:snapshot(2).aims == 0)
        end
    },
    {
        name = "new weapons have loot pads",
        run = function()
            local world = World.new()
            world:step()
            local kinds = {}
            for _, item in ipairs(world.items) do kinds[item.kind] = (kinds[item.kind] or 0) + 1 end
            assert(kinds.sniper == 2 and kinds.silencer == 2 and kinds.lmg == 2)
        end
    },
    {
        name = "every weapon kind survives the network packing",
        run = function()
            for _, kind in ipairs(Weapons.order) do
                assert(Weapons.unpack(Weapons.pack(kind)) == kind)
            end
        end
    }
}
