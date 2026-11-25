--- Item pictures for the extraction inventory, drawn with shapes so every item of
--- the catalog has one: the weapon models of the game, and glyphs for the rest.
--- The cell background takes the rarity color.
local Kit = require("src.ui.kit")
local Character = require("src.modules.session.character")
local Items = require("src.game.extraction.items")
local ItemConfig = require("src.config.items")

local Icons = {}

local lg = love.graphics

--- @param inst table
--- @return table color of the item's rarity
function Icons.rarityColor(inst)
    return Items.rarity(inst).color
end

local function glyph(def, w, h, alpha)
    local s = math.min(w, h)
    local kind = def.kind
    if kind == "ammo" then
        local c = def.color or { 0.7, 0.6, 0.3 }
        for k = -1, 1 do
            lg.setColor(c[1], c[2], c[3], alpha)
            lg.rectangle("fill", k * s * 0.2 - s * 0.06, -s * 0.22, s * 0.12, s * 0.4, s * 0.05, s * 0.05)
            lg.setColor(0.85, 0.7, 0.35, alpha)
            lg.rectangle("fill", k * s * 0.2 - s * 0.06, -s * 0.3, s * 0.12, s * 0.12, s * 0.06, s * 0.06)
        end
    elseif kind == "mod" then
        lg.setColor(0.32, 0.34, 0.38, alpha)
        local slot = def.slot
        if slot == "muzzle" or slot == "barrel" then
            lg.rectangle("fill", -w * 0.4, -s * 0.1, w * 0.8, s * 0.2, 3, 3)
        elseif slot == "mag" then
            lg.polygon("fill", -s * 0.15, -h * 0.35, s * 0.15, -h * 0.35, s * 0.2, h * 0.35, -s * 0.1, h * 0.35)
        elseif slot == "optic" then
            lg.rectangle("fill", -w * 0.35, -s * 0.12, w * 0.7, s * 0.24, 4, 4)
            lg.setColor(0.4, 0.7, 0.95, alpha)
            lg.circle("fill", w * 0.3, 0, s * 0.12)
        elseif slot == "under" then
            lg.rectangle("fill", -s * 0.25, -s * 0.12, s * 0.5, s * 0.24, 3, 3)
            lg.rectangle("fill", -s * 0.08, 0, s * 0.16, s * 0.3, 3, 3)
        else
            for k = -1, 1 do
                lg.setColor(0.8, 0.5, 0.2, alpha)
                lg.circle("fill", k * s * 0.18, 0, s * 0.09)
            end
        end
    elseif kind == "utility" then
        if def.heal or def.regen or def.cure or def.fortify or def.rush or def.haste then
            lg.setColor(0.95, 0.95, 0.95, alpha)
            lg.rectangle("fill", -s * 0.3, -s * 0.24, s * 0.6, s * 0.48, 4, 4)
            Kit.color(Kit.RED, alpha)
            lg.rectangle("fill", -s * 0.06, -s * 0.18, s * 0.12, s * 0.36)
            lg.rectangle("fill", -s * 0.18, -s * 0.06, s * 0.36, s * 0.12)
        elseif def.repair then
            lg.setColor(0.4, 0.42, 0.46, alpha)
            lg.rectangle("fill", -w * 0.38, -s * 0.25, w * 0.76, s * 0.5, 4, 4)
        elseif def.place or def.scan or def.beacon then
            lg.setColor(0.3, 0.32, 0.3, alpha)
            lg.rectangle("fill", -s * 0.22, -h * 0.3, s * 0.44, h * 0.6, 4, 4)
            Kit.color(def.beacon and Kit.AMBER or Kit.RED, alpha)
            lg.circle("fill", 0, -h * 0.15, s * 0.08)
        else
            local colors = { frag = { 0.34, 0.4, 0.3 }, sticky = { 0.5, 0.42, 0.2 }, smoke = { 0.7, 0.72, 0.74 }, flash = { 0.86, 0.86, 0.8 },
                fire = { 0.86, 0.4, 0.14 }, cryo = { 0.5, 0.8, 0.95 }, gas = { 0.55, 0.7, 0.25 }, decoy = { 0.6, 0.5, 0.7 } }
            local c = colors[def.throw] or { 0.4, 0.4, 0.4 }
            lg.setColor(c[1], c[2], c[3], alpha)
            lg.circle("fill", 0, s * 0.04, s * 0.26)
            lg.setColor(0.25, 0.25, 0.25, alpha)
            lg.rectangle("fill", -s * 0.07, -s * 0.32, s * 0.14, s * 0.12)
        end
    elseif kind == "armor" then
        lg.setColor(0.36, 0.4, 0.34, alpha)
        if def.slot == "helmet" then
            lg.arc("fill", 0, s * 0.12, s * 0.34, math.pi, 2 * math.pi)
            lg.rectangle("fill", -s * 0.38, s * 0.1, s * 0.76, s * 0.08)
        else
            lg.polygon("fill", -w * 0.32, -h * 0.36, -w * 0.12, -h * 0.4, 0, -h * 0.3, w * 0.12, -h * 0.4, w * 0.32, -h * 0.36, w * 0.3, h * 0.4, -w * 0.3, h * 0.4)
        end
    elseif kind == "backpack" then
        lg.setColor(0.46, 0.38, 0.28, alpha)
        lg.rectangle("fill", -w * 0.32, -h * 0.34, w * 0.64, h * 0.72, 8, 8)
        lg.setColor(0.36, 0.3, 0.22, alpha)
        lg.rectangle("fill", -w * 0.24, h * 0.02, w * 0.48, h * 0.26, 5, 5)
    elseif kind == "material" then
        lg.setColor(0.52, 0.5, 0.46, alpha)
        local points = {}
        for k = 0, 5 do
            local a = k / 6 * 2 * math.pi
            points[#points + 1] = math.cos(a) * s * 0.28
            points[#points + 1] = math.sin(a) * s * 0.28
        end
        lg.polygon("fill", points)
        lg.setColor(0.3, 0.3, 0.3, alpha)
        lg.circle("fill", 0, 0, s * 0.1)
    elseif kind == "blueprint" then
        lg.setColor(0.2, 0.38, 0.7, alpha)
        lg.rectangle("fill", -w * 0.38, -h * 0.36, w * 0.76, h * 0.72, 3, 3)
        lg.setColor(1, 1, 1, 0.35 * alpha)
        for k = -2, 2 do
            lg.line(-w * 0.38, k * h * 0.14, w * 0.38, k * h * 0.14)
            lg.line(k * w * 0.15, -h * 0.36, k * w * 0.15, h * 0.36)
        end
    else
        lg.setColor(0.9, 0.74, 0.3, alpha)
        lg.polygon("fill", 0, -s * 0.3, s * 0.26, 0, 0, s * 0.3, -s * 0.26, 0)
    end
end

--- Draws an item filling a rectangle (already rotated when o == 1).
--- @param inst table
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param alpha number?
function Icons.draw(inst, x, y, w, h, alpha)
    alpha = alpha or 1
    local def = Items.def(inst)
    if not def then return end
    local c = Icons.rarityColor(inst)
    local flat = def.kind == "ammo" or def.kind == "material" or def.kind == "valuable"
    lg.setColor(c[1], c[2], c[3], (flat and 0.14 or 0.26) * alpha)
    lg.rectangle("fill", x + 1, y + 1, w - 2, h - 2, 5, 5)
    lg.setColor(c[1], c[2], c[3], (flat and 0.35 or 0.9) * alpha)
    lg.setLineWidth(flat and 1 or 2)
    lg.rectangle("line", x + 1.5, y + 1.5, w - 3, h - 3, 5, 5)
    lg.setLineWidth(1)
    lg.push()
    lg.translate(x + w / 2, y + h / 2)
    local rotated = inst.o == 1
    local iw, ih = w, h
    if rotated then
        lg.rotate(math.pi / 2)
        iw, ih = h, w
    end
    if def.kind == "weapon" then
        local scale = math.min(iw / 46, ih / 12) * 0.95
        lg.scale(scale, scale)
        Character.drawWeapon(def.look, 0, 0, 0, alpha)
    else
        glyph(def, iw, ih, alpha)
    end
    lg.pop()
    local size = h >= 60 and w >= 60 and 12 or 10
    local label = def.kind == "blueprint" and ("Plan " .. (ItemConfig.all[def.target] and ItemConfig.all[def.target].name or "")) or def.name
    lg.push("all")
    lg.intersectScissor(x, y, w, h)
    Kit.text(label, size, x + 4, y + 2, Kit.INK, 0.85 * alpha)
    lg.pop()
    if (inst.n or 1) > 1 or def.charges then
        Kit.text(tostring(inst.n or 1), 12, (x) + (w - 5), y + h - 17, Kit.INK, alpha, "right")
    end
    if def.kind == "weapon" then
        local count = 0
        for _ in pairs(inst.m or {}) do count = count + 1 end
        for k = 1, Items.rarity(inst).slots do
            lg.setColor(c[1], c[2], c[3], (k <= count and 0.95 or 0.3) * alpha)
            lg.circle("fill", x + 7 + (k - 1) * 8, y + h - 8, 2.6)
        end
    elseif def.kind == "armor" and inst.u then
        local max = Items.armorStats(inst).durability
        Kit.bar(x + 4, y + h - 7, w - 8, 3, inst.u / max, Kit.GREEN, alpha)
    end
end

return Icons
