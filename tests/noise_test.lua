local Arena = require("src.game.arena")
local Player = require("src.game.player")
local World = require("src.game.world")
local Inputs = require("src.net.inputs")
local Config = require("src.config.game")

local function duel(walls, second)
    local world = World.new(Arena.new({
        width = 4000, height = 4000, walls = walls or {},
        spawns = { { x = 1000, y = 1000, angle = 0 }, second or { x = 1500, y = 1000, angle = 0 } }
    }))
    world:add(1, "a")
    world:add(2, "b")
    return world
end

local sequences = {}

local function run(world, ticks, first, second)
    for _ = 1, ticks do
        for slot, fields in pairs({ first or {}, second or {} }) do
            sequences[slot] = (sequences[slot] or 0) + 1
            local c = { s = sequences[slot], f = 0, r = 0, a = Player.packAngle(fields.angle or 0), d = 0, b = 0, l = 0, t = 0, e = 0, k = 0 }
            for k, v in pairs(fields) do
                if k ~= "angle" then c[k] = v end
            end
            world:queue(slot, { c })
        end
        world:step()
    end
end

local function heard(world, listener)
    local _, _, noises = world:drain()
    local list = {}
    for _, noise in ipairs(noises) do
        if world:hears(listener, noise) then list[#list + 1] = noise.kind end
    end
    return list
end

local function count(list, kind)
    local n = 0
    for _, k in ipairs(list) do
        if k == kind then n = n + 1 end
    end
    return n
end

return {
    {
        name = "a shot is heard by an opponent who can't see the shooter",
        run = function()
            sequences = {}
            local world = duel()
            run(world, 1, { b = 1, angle = math.pi })
            local list = heard(world, 2)
            assert(count(list, "shot") == 1, "heard " .. #list)
        end
    },
    {
        name = "noises you can see are not sent as echoes",
        run = function()
            sequences = {}
            local world = duel(nil, { x = 1300, y = 1000, angle = math.pi })
            run(world, 1, { b = 1, angle = math.pi }, { angle = math.pi })
            assert(count(heard(world, 2), "shot") == 0)
        end
    },
    {
        name = "noises fade with distance",
        run = function()
            sequences = {}
            local world = duel(nil, { x = 1000 + Config.noise.shot + 50, y = 1000, angle = 0 })
            run(world, 1, { b = 1, angle = math.pi })
            assert(count(heard(world, 2), "shot") == 0)
        end
    },
    {
        name = "running makes footsteps, walking quietly does not",
        run = function()
            sequences = {}
            local world = duel(nil, { x = 1200, y = 1000, angle = 0 })
            run(world, 120, { f = 1, angle = math.pi / 2 })
            assert(count(heard(world, 2), "step") >= 3, "running is heard")
            run(world, 120, { f = 1, k = 1, angle = -math.pi / 2 })
            assert(count(heard(world, 2), "step") == 0, "quiet walk is silent")
        end
    },
    {
        name = "quiet walk is slower",
        run = function()
            sequences = {}
            local world = duel()
            local p = world.players[1]
            run(world, 60, { f = 1, k = 1, angle = math.pi / 2 })
            local quiet = p.y - 1000
            run(world, 60, { f = 1, angle = math.pi / 2 })
            assert(quiet < (p.y - 1000 - quiet) * 0.6, "quiet " .. quiet)
        end
    },
    {
        name = "dashes and throws are heard",
        run = function()
            sequences = {}
            local world = duel(nil, { x = 1200, y = 1000, angle = 0 })
            run(world, 1, { d = 1, angle = math.pi })
            assert(count(heard(world, 2), "dash") == 1)
            run(world, Config.dash.ticks, { k = 1, angle = math.pi })
            heard(world, 2)
            run(world, 1, { t = 1, angle = math.pi })
            assert(count(heard(world, 2), "throw") == 1)
        end
    },
    {
        name = "the quiet flag is sanitized",
        run = function()
            assert(Inputs.sanitize({ s = 1, a = 0, k = 1 }).k == 1)
            assert(Inputs.sanitize({ s = 1, a = 0, k = 3 }).k == 0)
        end
    }
}
