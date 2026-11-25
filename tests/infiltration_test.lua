local World = require("src.game.world")
local Arena = require("src.game.arena")
local Maps = require("src.maps.index")
local Config = require("src.config.game")
local Combat = require("src.game.combat")
local Rounds = require("src.game.rounds")
local Room = require("src.server.room")

local rules = Config.modes.infiltration

local function world()
    local w = World.new(Arena.new(Maps.get("embassy")), "infiltration", false)
    for slot = 1, 4 do w:add(slot, "P" .. slot, slot % 2 + 1) end
    w:restart("playing")
    return w
end

local function team(w, role)
    local list = {}
    for slot = 1, 4 do
        local p = w.players[slot]
        if Rounds.role(w, p) == role then list[#list + 1] = p end
    end
    return list
end

local function step(w, ticks)
    for _ = 1, ticks do
        Rounds.update(w)
        Combat.update(w)
    end
end

return {
    {
        name = "infiltration plays on the embassy with attackers outside and defenders inside",
        run = function()
            local room = Room(1, { mode = "infiltration", map = "atrium" })
            assert(room.map == "embassy")
            local w = world()
            for _, p in ipairs(team(w, "attack")) do
                assert(p.y > 1500 and p.weapon == "silencer" and p.gadget == "smoke", "attacker kit and spawn")
            end
            for _, p in ipairs(team(w, "defend")) do
                assert(p.y < 1200 and (p.weapon == "rifle" or p.weapon == "lmg") and not p.gadget, "defender kit and spawn")
            end
            local weapons = 0
            for _, pad in ipairs(w.pads) do if require("src.game.weapons").def(pad.kind) then weapons = weapons + 1 end end
            assert(weapons == 0, "no weapons on the floor")
        end
    },
    {
        name = "the dead stay out until the next round, and losing all attackers ends it",
        run = function()
            local w = world()
            local attackers, defenders = team(w, "attack"), team(w, "defend")
            Combat.kill(w, attackers[1], defenders[1].slot)
            step(w, Config.respawnTicks + 30)
            assert(attackers[1].out and attackers[1].dead > 0, "no respawn")
            Combat.kill(w, attackers[2], defenders[1].slot)
            step(w, 1)
            local defend = 3 - w.round.attackers
            assert(w.teamScore[defend] == 1 and w.round.over > 0, "defenders take the round")
            local before = w.round.attackers
            step(w, rules.roundEndTicks)
            assert(w.round.number == 2 and w.round.attackers ~= before, "sides swap")
            assert(not attackers[1].out and attackers[1].dead == 0 and attackers[1].hp > 0, "everyone is back")
        end
    },
    {
        name = "standing on a terminal hacks it unless a defender contests it",
        run = function()
            local w = world()
            local attacker, defender = team(w, "attack")[1], team(w, "defend")[1]
            local terminal = w.arena.objectives[1]
            attacker.x, attacker.y = terminal.x, terminal.y
            defender.x, defender.y = terminal.x + 30, terminal.y
            step(w, 60)
            assert(w.round.hack[1] == 0, "contested")
            defender.x, defender.y = terminal.x + 600, terminal.y
            step(w, rules.hackTicks)
            assert(w.teamScore[w.round.attackers] == 1 or w.teamScore[3 - w.round.attackers] == 0)
            local heard = false
            for _, noise in ipairs(w.noises) do if noise.kind == "hack" then heard = true end end
            assert(heard, "hacking makes noise")
        end
    },
    {
        name = "defenders win when time runs out, and four rounds win the match",
        run = function()
            local w = world()
            for _ = 1, rules.scoreLimit * 2 do
                local defend = 3 - w.round.attackers
                w.round.timer = 1
                step(w, 1)
                assert(w.teamScore[defend] >= 1)
                if w.over then break end
                step(w, rules.roundEndTicks)
            end
            assert(w.over, "match over")
        end
    },
    {
        name = "attackers walk silently, defenders do not",
        run = function()
            local w = world()
            local attacker, defender = team(w, "attack")[1], team(w, "defend")[1]
            local command = { s = 1, f = 1, r = 0, a = 0, d = 0, b = 0, l = 0, t = 0, e = 0, k = 0, x = 0 }
            for _, p in ipairs({ attacker, defender }) do
                p.vx, p.vy = 200, 0
                for _ = 1, 30 do w:footsteps(p, command) end
            end
            local sources = {}
            for _, noise in ipairs(w.noises) do if noise.kind == "step" then sources[noise.source] = true end end
            assert(not sources[attacker.slot] and sources[defender.slot])
        end
    }
}
