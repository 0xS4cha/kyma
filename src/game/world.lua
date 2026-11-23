local Arena = require("src.game.arena")
local Player = require("src.game.player")
local NetConfig = require("src.net.config")

local World = {}
World.__index = World

--- @param arena table?
--- @return table
function World.new(arena)
    return setmetatable({
        arena = arena or Arena.new(),
        tick = 0,
        dt = 1 / NetConfig.tickRate,
        players = {},
        inputs = {}
    }, World)
end

--- @param slot number
--- @param name string
--- @return table
function World:add(slot, name)
    local player = Player.new(slot, name, self.arena:spawn(slot))
    self.players[slot] = player
    self.inputs[slot] = { queue = {}, last = 0, acked = 0, credit = 0 }
    return player
end

--- @param slot number
function World:remove(slot)
    self.players[slot] = nil
    self.inputs[slot] = nil
end

--- @param slot number
--- @param commands table[]
function World:queue(slot, commands)
    local state = self.inputs[slot]
    if not state then return end
    for _, command in ipairs(commands) do
        if command.s > state.last then
            state.last = command.s
            state.queue[#state.queue + 1] = command
        end
    end
    while #state.queue > NetConfig.inputQueue do
        local dropped = table.remove(state.queue, 1)
        state.acked = dropped.s
    end
end

function World:step()
    self.tick = self.tick + 1
    for slot, player in pairs(self.players) do
        local state = self.inputs[slot]
        state.credit = math.min(state.credit + 1, NetConfig.inputCredit)
        while state.credit >= 1 and #state.queue > 0 do
            local command = table.remove(state.queue, 1)
            Player.step(player, command, self.arena, self.dt)
            state.acked = command.s
            state.credit = state.credit - 1
        end
    end
end

--- @param slot number
--- @return number
function World:ack(slot)
    local state = self.inputs[slot]
    return state and state.acked or 0
end

--- @return table[]
function World:snapshot()
    local list = {}
    for slot, p in pairs(self.players) do
        list[#list + 1] = {
            i = slot, x = p.x, y = p.y, a = Player.packAngle(p.angle), u = p.vx, v = p.vy,
            e = p.dash, w = p.cooldown, m = p.dashX, n = p.dashY
        }
    end
    table.sort(list, function(a, b) return a.i < b.i end)
    return list
end

return World
