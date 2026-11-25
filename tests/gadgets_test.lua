local World = require("src.game.world")
local Arena = require("src.game.arena")
local Gadgets = require("src.game.gadgets")
local GadgetConfig = require("src.config.gadgets")
local Vision = require("src.game.vision")
local Config = require("src.config.game")
local Inputs = require("src.net.inputs")
local Loadout = require("src.config.loadout")

local function open()
    return Arena.new({ id = "open", name = "Open", width = 3000, height = 2000, walls = {}, spawns = { { x = 100, y = 100, angle = 0 }, { x = 2900, y = 1900, angle = 0 } } })
end

local function duel()
    local world = World.new(open(), "duel", false)
    local a, b = world:add(1, "A"), world:add(2, "B")
    a.x, a.y, a.angle = 1000, 1000, 0
    b.x, b.y, b.angle = 1300, 1000, math.pi
    return world, a, b
end

local function run(world, ticks)
    for _ = 1, ticks do Gadgets.update(world) end
end

local function throw(world, p, kind)
    Gadgets.give(p, kind)
    return Gadgets.use(world, p)
end

return {
    {
        name = "a gadget is used once per life and goes off after its fuse",
        run = function()
            local world, a = duel()
            assert(throw(world, a, "smoke"))
            assert(a.gadgets == 0 and not Gadgets.use(world, a), "one charge")
            run(world, GadgetConfig.fuse - 1)
            assert(#world.gadgets == 1 and #world.smokes == 0)
            run(world, 1)
            assert(#world.gadgets == 0 and #world.smokes == 1)
        end
    },
    {
        name = "smoke blocks sight, then clears",
        run = function()
            local world, a, b = duel()
            assert(Vision.sees(world.arena, a, b.x, b.y, Config.player.radius))
            world.smokes[1] = { x = 1150, y = 1000, r = 0, ticks = GadgetConfig.smoke.ticks }
            run(world, GadgetConfig.smoke.grow + 1)
            assert(not Vision.sees(world.arena, a, b.x, b.y, Config.player.radius), "hidden by the smoke")
            assert(not world:sees(1, 2))
            run(world, GadgetConfig.smoke.ticks)
            assert(#world.smokes == 0 and Vision.sees(world.arena, a, b.x, b.y, Config.player.radius))
        end
    },
    {
        name = "a flashbang blinds those who face it, less those who look away",
        run = function()
            local world, a, b = duel()
            b.angle = 0
            Gadgets.flash(world, 1150, 1000)
            assert(a.blind > b.blind and b.blind > 0, a.blind .. " " .. b.blind)
            assert(not world:sees(1, 2), "a blind player sees no one")
            run(world, a.blind)
            assert(a.blind == 0 and world:sees(1, 2))
        end
    },
    {
        name = "walls protect from a flashbang",
        run = function()
            local arena = open()
            arena.walls = { { x = 1100, y = 900, w = 40, h = 200 } }
            local world = World.new(arena, "duel", false)
            local a = world:add(1, "A")
            a.x, a.y, a.angle = 1000, 1000, 0
            Gadgets.flash(world, 1200, 1000)
            assert((a.blind or 0) == 0)
        end
    },
    {
        name = "a decoy fakes gunfire with tracers and noise",
        run = function()
            local world, a = duel()
            a.weapon = "rifle"
            local gadget = throw(world, a, "decoy")
            run(world, GadgetConfig.fuse + GadgetConfig.decoy.interval * 3)
            local shots, noises = 0, 0
            for _, shot in ipairs(world.shots) do
                if shot.o == nil and shot.g then shots = shots + 1 end
            end
            for _, noise in ipairs(world.noises) do
                if noise.kind == "shot" then noises = noises + 1 end
            end
            assert(gadget and shots >= 3 and noises >= 3, shots .. " " .. noises)
            run(world, GadgetConfig.decoy.ticks)
            assert(#world.decoys == 0)
        end
    },
    {
        name = "your loadout gadget comes with your kit and the input carries it",
        run = function()
            local world = World.new(open(), "duel", false, { s = 2 })
            local p = world:add(1, "A", nil, { w = 2, m = 1, g = 3 })
            assert(p.gadget == Loadout.gadgets[3] and p.gadgets == 1)
            local view = world:snapshot(1)
            assert(GadgetConfig.unpack(view.players[1].gk) == p.gadget and view.players[1].gn == 1)
            assert(Inputs.sanitize({ s = 1, a = 0, x = 1 }).x == 1)
            assert(Loadout.sanitize({ g = 9 }).g == 1)
        end
    }
}
