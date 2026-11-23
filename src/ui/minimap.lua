local Kit = require("src.ui.kit")

local Minimap = {}

local ICON = {
    rifle = 1, shotgun = 1, sniper = 1, silencer = 1, lmg = 1, pistol = 1,
    ammo = 2, health = 3
}

local function rects(list, color, alpha, scale, ox, oy)
    local lg = love.graphics
    lg.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
    for _, r in ipairs(list or {}) do
        lg.rectangle("fill", ox + r.x * scale, oy + r.y * scale, math.max(1, r.w * scale), math.max(1, r.h * scale))
    end
end

--- @param def table
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param alpha number?
--- @param options table?
function Minimap.draw(def, x, y, w, h, alpha, options)
    alpha = alpha or 1
    options = options or {}
    local lg = love.graphics
    local scale = math.min(w / def.width, h / def.height)
    local mw, mh = def.width * scale, def.height * scale
    local ox, oy = x + (w - mw) / 2, y + (h - mh) / 2
    lg.setColor(0.82, 0.84, 0.87, alpha)
    lg.rectangle("fill", ox, oy, mw, mh, 4, 4)
    rects(def.pits, { 0.3, 0.33, 0.38 }, alpha, scale, ox, oy)
    rects(def.cover, { 0.6, 0.64, 0.7 }, alpha, scale, ox, oy)
    rects(def.walls, { 0.98, 0.985, 0.99 }, alpha, scale, ox, oy)
    rects(def.glass, { 0.45, 0.68, 0.9 }, alpha, scale, ox, oy)
    rects(def.doors, Kit.RED, alpha, scale, ox, oy)
    if options.spawns ~= false then
        for _, spawn in ipairs(def.spawns) do
            local c = spawn.team == 2 and Kit.RED or Kit.ALLY
            Kit.dot(ox + spawn.x * scale, oy + spawn.y * scale, math.max(2, 3 * scale * 6), c, alpha * 0.85)
        end
    end
    if options.loot ~= false then
        for _, item in ipairs(def.loot) do
            local kind = ICON[item.kind] or 1
            local c = kind == 3 and { 1, 1, 1 } or kind == 2 and { 0.72, 0.6, 0.32 } or Kit.INK
            Kit.dot(ox + item.x * scale, oy + item.y * scale, math.max(1.5, 2.2 * scale * 6), c, alpha)
        end
    end
end

return Minimap
