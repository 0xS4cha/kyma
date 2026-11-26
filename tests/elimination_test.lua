local Arena = require("src.game.arena")
local World = require("src.game.world")
local Combat = require("src.game.combat")
local Config = require("src.config.game")
local Loadout = require("src.config.loadout")

local function open(mode, elimination)
    return World.new(Arena.new({
        width = 3000, height = 3000, walls = {},
        spawns = {
            { x = 300, y = 300, angle = 0, team = 1 }, { x = 400, y = 300, angle = 0, team = 1 },
            { x = 2700, y = 2700, angle = math.pi, team = 2 }, { x = 2600, y = 2700, angle = math.pi, team = 2 }
        }
    }), mode, false, { el = elimination })
end

local function ticks(world, n)
    for _ = 1, n do world:step() end
end

local function alive(p)
    return p.hp > 0 and p.dead == 0
end

return {
    {
        name = "the elimination rule travels with the match rules",
        run = function()
            assert(Loadout.rules(Loadout.pack(Loadout.rules({ el = true }))).elimination == true)
            assert(Loadout.rules({}).elimination == false)
        end
    },
    {
        name = "elimination only changes duel and teams",
        run = function()
            assert(open("duel", true).rules.elim)
            assert(open("teams", true).rules.elim)
            assert(not open("ffa", true).rules.elim)
            assert(not open("duel", false).rules.elim)
            assert(open("duel", true).rules.scoreLimit == Config.modes.duel.elimination)
            assert(Config.modes.duel.scoreLimit == 10, "the base mode is left alone")
        end
    },
    {
        name = "a teammate stays out until the whole team is down, then the other team scores",
        run = function()
            local world = open("teams", true)
            local a, b = world:add(1, "a", 1), world:add(2, "b", 1)
            local c = world:add(3, "c", 2)
            Combat.kill(world, a, 3)
            ticks(world, Config.respawnTicks + 30)
            assert(a.out and not alive(a), "no respawn while a teammate stands")
            assert(world.teamScore[2] == 0, "a kill is no point")
            Combat.kill(world, b, 3)
            ticks(world, 1)
            assert(world.teamScore[2] == 1, "the wipe gives the point")
            assert(world.teamScore[1] == 0)
            ticks(world, Config.eliminationEndTicks + 1)
            assert(alive(a) and alive(b) and alive(c), "everyone is back for the next round")
            assert(world.elim.number == 2)
        end
    },
    {
        name = "a duel round goes to the one still standing and counts rounds",
        run = function()
            local world = open("duel", true)
            local a, b = world:add(1, "a"), world:add(2, "b")
            Combat.kill(world, b, 1)
            ticks(world, 1)
            assert(world.score[1] == 1 and world.score[2] == 0)
            ticks(world, Config.eliminationEndTicks + 1)
            assert(alive(a) and alive(b))
            assert(world.score[1] == 1, "the kill itself adds nothing")
        end
    },
    {
        name = "dying together gives nobody the round",
        run = function()
            local world = open("duel", true)
            local a, b = world:add(1, "a"), world:add(2, "b")
            Combat.kill(world, a, 2)
            Combat.kill(world, b, 1)
            ticks(world, 1)
            assert(world.score[1] == 0 and world.score[2] == 0)
            assert(world.elim.over > 0, "the next round still comes")
        end
    },
    {
        name = "the match ends at the elimination limit",
        run = function()
            local world = open("duel", true)
            world:add(1, "a")
            local b = world:add(2, "b")
            for _ = 1, Config.modes.duel.elimination do
                Combat.kill(world, b, 1)
                ticks(world, Config.eliminationEndTicks + 2)
                if world.over then break end
            end
            assert(world.over and world.over.winner == 1 and not world.over.team)
        end
    },
    {
        name = "left alone on the map, a player comes back",
        run = function()
            local world = open("duel", true)
            local a = world:add(1, "a")
            world:add(2, "b")
            Combat.kill(world, a, 2)
            assert(a.out)
            world:remove(2)
            ticks(world, 1)
            assert(not a.out, "the respawn timer runs again")
        end
    },
    {
        name = "without the rule, teams respawn as before",
        run = function()
            local world = open("teams", false)
            local a = world:add(1, "a", 1)
            world:add(3, "c", 2)
            Combat.kill(world, a, 3)
            assert(world.teamScore[2] == 1)
            assert(not a.out and world.elim == nil)
        end
    }
}
