local Arena = require("src.game.arena")
local Player = require("src.game.player")
local World = require("src.game.world")
local Weapons = require("src.game.weapons")
local Config = require("src.config.game")
local WeaponConfig = require("src.config.weapons")
local NetConfig = require("src.net.config")

local DT = 1 / NetConfig.tickRate

local function duel(distance, mode, teams)
    local world = World.new(Arena.new({
        width = 3000, height = 3000, walls = {},
        spawns = { { x = 1000, y = 1000, angle = 0 }, { x = 1000 + (distance or 40), y = 1000, angle = math.pi } }
    }), mode)
    world:add(1, "a", teams and 1 or nil)
    world:add(2, "b", teams and (teams == "same" and 1 or 2) or nil)
    Weapons.give(world.players[1], nil)
    return world, world.players[1], world.players[2]
end

local s = 0
local function strike(world, fields)
    s = s + 1
    local c = { s = s, f = 0, r = 0, a = 0, d = 0, b = 1, l = 0, t = 0, e = 0, k = 0, v = world.tick }
    for k, v in pairs(fields or {}) do c[k] = v end
    world:queue(1, { c })
    world:step()
    s = s + 1
    world:queue(1, { { s = s, f = 0, r = 0, a = c.a, d = 0, b = 0, l = 0, t = 0, e = 0, k = 0 } })
    world:step()
end

return {
    {
        name = "an unarmed strike hurts, stuns and knocks the weapon out",
        run = function()
            local world, a, b = duel(40)
            Weapons.give(b, "rifle")
            strike(world)
            assert(b.hp == Config.health - WeaponConfig.melee.damage, "hp " .. b.hp)
            assert(b.stun > 0 and b.weapon ~= "rifle", "stunned and disarmed")
            local dropped = false
            for _, item in ipairs(world.items) do
                if item.kind == "rifle" then dropped = true end
            end
            assert(dropped, "the weapon lies on the floor")
        end
    },
    {
        name = "strikes miss out of reach or behind",
        run = function()
            local world, _, b = duel(120)
            strike(world)
            assert(b.hp == Config.health, "too far")
            world = select(1, duel(40))
            strike(world, { a = Player.packAngle(math.pi) })
            assert(world.players[2].hp == Config.health, "facing away")
        end
    },
    {
        name = "strikes wait for their cooldown and need a new click",
        run = function()
            local world, a, b = duel(40, "gungame") -- le gun game laisse les poings (pas d'arme de secours)
            strike(world)
            local hp = b.hp
            strike(world)
            assert(b.hp == hp, "no second strike during the cooldown")
            for _ = 1, WeaponConfig.melee.cooldown do strike(world, { b = 0 }) end
            strike(world)
            assert(b.hp < hp, "strikes again after the cooldown")
        end
    },
    {
        name = "teammates can't be struck",
        run = function()
            local world, _, b = duel(40, "teams", "same")
            strike(world)
            assert(b.hp == Config.health and b.weapon)
        end
    },
    {
        name = "stunned players move slowly and can't shoot or dash",
        run = function()
            local a = Arena.new({ width = 3000, height = 3000, walls = {}, spawns = {} })
            local p, q = Player.new(1, "a", { x = 1000, y = 1000, angle = 0 }), Player.new(2, "b", { x = 1000, y = 2000, angle = 0 })
            p.stun = 20
            for _ = 1, 10 do
                Player.step(p, { f = 1, r = 0, a = 0, d = 1, b = 1, l = 0, t = 0, e = 0, k = 0 }, a, DT)
                Player.step(q, { f = 1, r = 0, a = 0, d = 0, b = 0, l = 0, t = 0, e = 0, k = 0 }, a, DT)
            end
            assert(p.dash == 0 and p.ammo == WeaponConfig.pistol.magazine, "no dash and no shot")
            assert(p.x - 1000 < (q.x - 1000) * 0.5, "slowed down")
        end
    },
    {
        name = "prediction matches the server while striking",
        run = function()
            local world = World.new(nil, "gungame")
            world:add(1, "a")
            Weapons.give(world.players[1], nil)
            local predicted = Player.new(1, "a", { x = 0, y = 0, angle = 0 })
            Player.copy(world.players[1], predicted)
            for seq = 1, 200 do
                local c = { s = seq, f = 1, r = seq % 30 < 15 and 1 or 0, a = Player.packAngle(seq * 0.02), d = 0, b = seq % 7 < 2 and 1 or 0, l = 0, t = 0, e = 0, k = 0 }
                Player.step(predicted, c, world.arena, DT)
                world:queue(1, { c })
                world:step()
            end
            local server = world.players[1]
            assert(server.x == predicted.x and server.meleeCooldown == predicted.meleeCooldown)
        end
    },
    {
        name = "an unarmed bot strikes an enemy in reach",
        run = function()
            local Bot = require("src.game.bot")
            local world = World.new(Arena.new({ width = 3000, height = 3000, walls = {}, spawns = { { x = 1000, y = 1000, angle = 0 }, { x = 1050, y = 1000, angle = math.pi } } }), "gungame")
            world:add(1, "bot")
            world:add(2, "target")
            Weapons.give(world.players[1], nil)
            local bot = Bot.new(1, "hard", 2)
            for _ = 1, 120 do
                world:queue(1, { bot:command(world) })
                world:step()
            end
            assert(world.players[2].hp < Config.health, "the bot struck")
        end
    }
}
