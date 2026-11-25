--- Item pictures for the extraction inventory: Kenney's Generic Items icons where one
--- fits, side views of the weapons drawn in the same flat style, and flat drawings for
--- the rest. The cell background and border take the rarity color.
local Kit = require("src.ui.kit")
local Assets = require("src.modules.extraction.assets")
local Items = require("src.game.extraction.items")
local ItemConfig = require("src.config.items")

local Icons = {}

local lg = love.graphics
local min, pi = math.min, math.pi

local DARK = { 0.24, 0.26, 0.3 }
local STEEL = { 0.42, 0.45, 0.5 }
local LIGHT = { 0.58, 0.61, 0.66 }
local WOOD = { 0.62, 0.4, 0.22 }
local TAN = { 0.74, 0.64, 0.46 }

--- @param inst table
--- @return table
function Icons.rarityColor(inst)
    return Items.rarity(inst).color
end

local function c(color, alpha)
    lg.setColor(color[1], color[2], color[3], alpha)
end

--- Draws a weapon centred in a box, with the gun model the rest of the game uses.
function Icons.weapon(def, cx, cy, w, h, alpha)
    local Character = require("src.modules.session.character")
    local x0, x1, y0, y1 = Character.weaponBounds(def.look)
    if not x0 then return end
    local s = min(w / (x1 - x0), h / math.max(8, y1 - y0))
    lg.push()
    lg.translate(cx - (x0 + x1) / 2 * s, cy - (y0 + y1) / 2 * s)
    lg.scale(s, s)
    Character.drawWeapon(def.look, 0, 0, 0, alpha)
    lg.pop()
end

local MOD_COLORS = {
    bouncing = { 0.3, 0.7, 0.95 }, piercing = { 0.6, 0.62, 0.66 }, incendiary = { 0.95, 0.45, 0.15 }, explosive = { 0.9, 0.25, 0.2 },
    hollow = { 0.85, 0.7, 0.3 }, frost = { 0.55, 0.85, 1 }, vampire = { 0.75, 0.1, 0.25 }, shock = { 0.95, 0.9, 0.3 },
    toxic = { 0.5, 0.8, 0.2 }, tracer = { 1, 0.4, 0.3 }, rubber = { 0.2, 0.22, 0.24 }, split = { 0.7, 0.5, 0.9 },
    ap = { 0.35, 0.38, 0.42 }, magnum = { 0.8, 0.6, 0.25 }, ghost = { 0.85, 0.88, 0.95 }, execution = { 0.55, 0.05, 0.08 }
}

local function glyph(def, w, h, a)
    local s = min(w, h)
    local kind = def.kind
    if kind == "ammo" then
        local col = def.color or { 0.7, 0.6, 0.3 }
        for k = -1, 1 do
            c(col, a)
            lg.rectangle("fill", k * s * 0.2 - s * 0.06, -s * 0.18, s * 0.12, s * 0.42, s * 0.03, s * 0.03)
            lg.setColor(0.88, 0.72, 0.36, a)
            lg.polygon("fill", k * s * 0.2 - s * 0.06, -s * 0.18, k * s * 0.2 + s * 0.06, -s * 0.18, k * s * 0.2, -s * 0.34)
        end
    elseif kind == "mod" then
        local slot = def.slot
        if slot == "rounds" then
            local col = MOD_COLORS[def.id] or STEEL
            for k = -1, 1 do
                c(col, a)
                lg.rectangle("fill", k * s * 0.2 - s * 0.07, -s * 0.14, s * 0.14, s * 0.38, 2, 2)
                lg.polygon("fill", k * s * 0.2 - s * 0.07, -s * 0.14, k * s * 0.2 + s * 0.07, -s * 0.14, k * s * 0.2, -s * 0.32)
            end
        elseif slot == "muzzle" or slot == "barrel" then
            c(DARK, a)
            lg.rectangle("fill", -w * 0.4, -s * 0.12, w * 0.8, s * 0.24, s * 0.08, s * 0.08)
            c(STEEL, a)
            for k = -2, 2 do lg.rectangle("fill", k * w * 0.12 - 1, -s * 0.12, 2, s * 0.24) end
        elseif slot == "mag" then
            c(DARK, a)
            if def.id == "drum" then
                lg.circle("fill", 0, 0, s * 0.32)
                c(STEEL, a)
                lg.circle("fill", 0, 0, s * 0.12)
            else
                lg.polygon("fill", -s * 0.14, -h * 0.36, s * 0.12, -h * 0.36, s * 0.2, h * 0.36, -s * 0.06, h * 0.36)
            end
        elseif slot == "optic" then
            c(DARK, a)
            lg.rectangle("fill", -w * 0.36, -s * 0.13, w * 0.72, s * 0.26, s * 0.1, s * 0.1)
            local lens = def.id == "thermal" and { 0.95, 0.45, 0.15 } or (def.id == "laser" and Kit.RED or { 0.45, 0.75, 0.98 })
            c(lens, a)
            lg.circle("fill", w * 0.3, 0, s * 0.12)
        else
            c(DARK, a)
            if def.set and def.set.light then
                lg.rectangle("fill", -s * 0.3, -s * 0.1, s * 0.5, s * 0.2, 3, 3)
                lg.setColor(1, 0.95, 0.6, a)
                lg.polygon("fill", s * 0.2, -s * 0.1, s * 0.42, -s * 0.25, s * 0.42, s * 0.25, s * 0.2, s * 0.1)
            else
                lg.rectangle("fill", -s * 0.28, -s * 0.24, s * 0.56, s * 0.14, 3, 3)
                lg.rectangle("fill", -s * 0.1, -s * 0.12, s * 0.2, s * 0.4, 3, 3)
            end
        end
    elseif kind == "utility" then
        local colors = { frag = { 0.34, 0.42, 0.3 }, sticky = { 0.6, 0.5, 0.2 }, smoke = { 0.62, 0.65, 0.7 }, flash = { 0.8, 0.82, 0.78 },
            fire = { 0.86, 0.4, 0.14 }, cryo = { 0.45, 0.78, 0.95 }, gas = { 0.55, 0.72, 0.25 } }
        if def.throw and colors[def.throw] then
            c(colors[def.throw], a)
            if def.throw == "fire" then
                lg.rectangle("fill", -s * 0.14, -s * 0.12, s * 0.28, s * 0.44, 4, 4)
                lg.rectangle("fill", -s * 0.06, -s * 0.3, s * 0.12, s * 0.2)
                lg.setColor(1, 0.8, 0.3, a)
                lg.circle("fill", 0, -s * 0.34, s * 0.07)
            elseif def.throw == "frag" or def.throw == "sticky" then
                lg.circle("fill", 0, s * 0.06, s * 0.24)
                c(DARK, a)
                lg.rectangle("fill", -s * 0.07, -s * 0.28, s * 0.14, s * 0.14)
                lg.setLineWidth(2)
                lg.circle("line", s * 0.12, -s * 0.24, s * 0.07)
                lg.setLineWidth(1)
            else
                lg.rectangle("fill", -s * 0.16, -s * 0.24, s * 0.32, s * 0.5, s * 0.06, s * 0.06)
                c(DARK, a)
                lg.rectangle("fill", -s * 0.16, -s * 0.06, s * 0.32, s * 0.06)
            end
        elseif def.place then
            c(DARK, a)
            lg.rectangle("fill", -w * 0.38, -s * 0.16, w * 0.76, s * 0.32, 4, 4)
            Kit.color(Kit.RED, a)
            lg.circle("fill", 0, 0, s * 0.07)
        else
            c(STEEL, a)
            lg.rectangle("fill", -w * 0.36, -s * 0.24, w * 0.72, s * 0.48, 4, 4)
            c(DARK, a)
            lg.rectangle("fill", -w * 0.3, -s * 0.16, w * 0.6, s * 0.32, 3, 3)
        end
    elseif kind == "armor" then
        local col = def.immune == "burn" and { 0.75, 0.62, 0.3 } or (def.immune == "poison" and { 0.3, 0.34, 0.3 } or { 0.36, 0.42, 0.34 })
        if def.slot == "helmet" then
            c(col, a)
            lg.arc("fill", 0, s * 0.14, s * 0.36, pi, 2 * pi)
            lg.rectangle("fill", -s * 0.4, s * 0.1, s * 0.8, s * 0.08, 3, 3)
            if def.id == "visor" or def.id == "nightcap" then
                c(DARK, a)
                lg.rectangle("fill", -s * 0.24, -s * 0.02, s * 0.48, s * 0.12, 3, 3)
            end
            if def.id == "nightcap" then
                lg.setColor(0.4, 0.95, 0.5, a)
                lg.circle("fill", s * 0.1, -s * 0.16, s * 0.06)
                lg.circle("fill", -s * 0.1, -s * 0.16, s * 0.06)
            end
            if def.id == "gasmask" then
                c(DARK, a)
                lg.circle("fill", 0, s * 0.2, s * 0.12)
            end
        else
            c(col, a)
            lg.polygon("fill", -w * 0.34, -h * 0.36, -w * 0.14, -h * 0.4, 0, -h * 0.3, w * 0.14, -h * 0.4, w * 0.34, -h * 0.36, w * 0.32, h * 0.4, -w * 0.32, h * 0.4)
            c({ col[1] * 0.75, col[2] * 0.75, col[3] * 0.75 }, a)
            for k = -1, 1 do lg.rectangle("fill", k * w * 0.2 - w * 0.08, h * 0.08, w * 0.16, h * 0.2, 3, 3) end
        end
    elseif kind == "material" then
        local special = {
            steel = function() c(LIGHT, a) lg.rectangle("fill", -w * 0.38, -s * 0.2, w * 0.76, s * 0.4, 3, 3) end,
            alloy = function() lg.setColor(0.75, 0.85, 0.95, a) lg.polygon("fill", -s * 0.3, s * 0.12, -s * 0.18, -s * 0.12, s * 0.3, -s * 0.12, s * 0.18, s * 0.12) end,
            string = function() c(TAN, a) lg.circle("fill", 0, 0, s * 0.26) c(WOOD, a) lg.circle("fill", 0, 0, s * 0.1) end,
            cloth = function() lg.setColor(0.8, 0.76, 0.7, a) lg.polygon("fill", -s * 0.3, -s * 0.22, s * 0.3, -s * 0.28, s * 0.26, s * 0.24, -s * 0.28, s * 0.2) end,
            fuelcan = function() lg.setColor(0.8, 0.18, 0.14, a) lg.rectangle("fill", -s * 0.22, -s * 0.24, s * 0.44, s * 0.5, 4, 4) end,
            fang = function() lg.setColor(0.95, 0.92, 0.85, a) lg.polygon("fill", -s * 0.12, -s * 0.3, s * 0.12, -s * 0.3, 0, s * 0.32) end,
            core = function()
                lg.setColor(0.4, 0.95, 0.8, 0.35 * a)
                lg.circle("fill", 0, 0, s * 0.34)
                lg.setColor(0.4, 0.95, 0.8, a)
                lg.circle("fill", 0, 0, s * 0.18)
            end
        }
        if special[def.id] then
            special[def.id]()
        else
            c(STEEL, a)
            lg.circle("fill", 0, 0, s * 0.24)
        end
    elseif kind == "backpack" then
        lg.setColor(0.46, 0.38, 0.28, a)
        lg.rectangle("fill", -w * 0.32, -h * 0.34, w * 0.64, h * 0.72, 8, 8)
    else
        lg.setColor(0.9, 0.74, 0.3, a)
        lg.polygon("fill", 0, -s * 0.3, s * 0.26, 0, 0, s * 0.3, -s * 0.26, 0)
    end
end

--- Draws the picture of an item definition centred in a box.
function Icons.picture(def, cx, cy, w, h, alpha, rotated)
    alpha = alpha or 1
    lg.push()
    lg.translate(cx, cy)
    local iw, ih = w, h
    if rotated then
        lg.rotate(pi / 2)
        iw, ih = h, w
    end
    if def.kind == "weapon" then
        Icons.weapon(def, 0, 0, iw * 0.92, ih * 0.86, alpha)
    elseif def.kind == "blueprint" then
        lg.setColor(0.18, 0.36, 0.68, alpha)
        lg.rectangle("fill", -iw * 0.42, -ih * 0.4, iw * 0.84, ih * 0.8, 3, 3)
        lg.setColor(1, 1, 1, 0.2 * alpha)
        for k = -3, 3 do
            lg.line(-iw * 0.42, k * ih * 0.1, iw * 0.42, k * ih * 0.1)
            lg.line(k * iw * 0.12, -ih * 0.4, k * iw * 0.12, ih * 0.4)
        end
        local target = ItemConfig.all[def.target]
        if target then Icons.picture(target, 0, 0, iw * 0.7, ih * 0.6, alpha * 0.85) end
    else
        local img = Assets.item(def.id)
        if img then
            local tint = Assets.TINTS[def.id]
            if tint then lg.setColor(tint[1], tint[2], tint[3], alpha) else lg.setColor(1, 1, 1, alpha) end
            local s = min(iw * 0.82 / img:getWidth(), ih * 0.82 / img:getHeight())
            lg.draw(img, 0, 0, 0, s, s, img:getWidth() / 2, img:getHeight() / 2)
        else
            glyph(def, iw, ih, alpha)
        end
    end
    lg.pop()
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
    local col = Icons.rarityColor(inst)
    local flat = def.kind == "ammo" or def.kind == "material" or def.kind == "valuable"
    lg.setColor(col[1], col[2], col[3], (flat and 0.1 or 0.2) * alpha)
    lg.rectangle("fill", x + 1, y + 1, w - 2, h - 2, 4, 4)
    lg.setColor(col[1], col[2], col[3], (flat and 0.06 or 0.14) * alpha)
    lg.rectangle("fill", x + 1, y + h * 0.55, w - 2, h * 0.45 - 1, 4, 4)
    lg.setColor(col[1], col[2], col[3], (flat and 0.3 or 0.85) * alpha)
    lg.setLineWidth(flat and 1 or 1.5)
    lg.rectangle("line", x + 1.5, y + 1.5, w - 3, h - 3, 4, 4)
    lg.setLineWidth(1)
    if not flat then
        lg.setColor(col[1], col[2], col[3], alpha)
        lg.rectangle("fill", x + 3, y + h - 5, w - 6, 2, 1, 1)
    end
    Icons.picture(def, x + w / 2, y + h / 2 + 2, w, h - 8, alpha, inst.o == 1)
    if w >= 70 then
        lg.push("all")
        lg.intersectScissor(x, y, w, h)
        Kit.text(def.kind == "blueprint" and "Plan" or def.name, 10, x + 4, y + 2, Kit.INK, 0.7 * alpha)
        lg.pop()
    end
    if (inst.n or 1) > 1 or def.charges then
        local text = tostring(inst.n or 1)
        local tw = Kit.font(11):getWidth(text) + 6
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.75 * alpha)
        lg.rectangle("fill", x + w - tw - 3, y + h - 17, tw, 14, 4, 4)
        Kit.text(text, 11, x + w - tw, y + h - 17, Kit.PAPER, alpha)
    end
    if def.kind == "weapon" then
        local count = 0
        for _ in pairs(inst.m or {}) do count = count + 1 end
        for k = 1, Items.rarity(inst).slots do
            lg.setColor(col[1], col[2], col[3], (k <= count and 1 or 0.3) * alpha)
            lg.circle("fill", x + 8 + (k - 1) * 8, y + h - 11, 2.6)
        end
    elseif def.kind == "armor" and inst.u then
        local maxU = Items.armorStats(inst).durability
        Kit.bar(x + 5, y + h - 11, w - 10, 3, inst.u / maxU, Kit.GREEN, alpha)
    end
end

return Icons
