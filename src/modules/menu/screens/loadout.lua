local Kit = require("src.ui.kit")
local Common = require("src.modules.menu.screens.common")
local Loadout = require("src.config.loadout")
local WeaponConfig = require("src.config.weapons")
local Weapons = require("src.game.weapons")
local Character = require("src.modules.session.character")
local Settings = require("src.modules.menu.settings")

local Screen = {}

local COLS, TILE_H, MOD_H = 4, 84, 44
local ROWS = math.ceil(#WeaponConfig.order / COLS)
-- Mods sit in two columns, name over description.
local MOD_COLS = 2
local MOD_ROWS = math.ceil(#Loadout.mods / MOD_COLS)

local STATS = {
    { label = "Damage", value = function(p, def) return Weapons.stat(p, "damage") * def.pellets end, max = 100, text = function(v) return tostring(v) end },
    { label = "Fire rate", value = function(p) return 60 / Weapons.stat(p, "fireTicks") end, max = 12, text = function(v) return string.format("%.1f / s", v) end },
    { label = "Accuracy", value = function(p) return 1 - math.min(1, Weapons.stat(p, "spread") / 0.25) end, max = 1, text = function(v) return math.floor(v * 100 + 0.5) .. "%" end },
    { label = "Range", value = function(p) return Weapons.stat(p, "range") end, max = 3000, text = function(v) return tostring(v) end },
    { label = "Magazine", value = function(p) return Weapons.stat(p, "magazine") end, max = 60, text = function(v, p) return v .. " + " .. Weapons.stat(p, "reserve") end },
    { label = "Reload", value = function(p) return Weapons.stat(p, "reloadTicks") / 60 end, max = 3.5, invert = true, text = function(v) return string.format("%.1f s", v) end }
}

local function title(name)
    if #name <= 3 then return name end
    return name:sub(1, 1) .. name:sub(2):lower()
end

local function keys(menu)
    if menu.loadoutTarget == "preset" then return "presetWeapon", "presetMods", "presetGadget" end
    return "kitWeapon", "kitMods", "kitGadget"
end

local function layout()
    local W, H = love.graphics.getDimensions()
    local M = Common.margin()
    local panelW = math.min(560, math.floor((W - M * 2) * 0.5))
    return { M = M, x = M, y = 130, w = panelW, H = H, preview = { x = M + panelW + 24, y = 130, w = W - M * 2 - panelW - 24, h = H - 130 - M } }
end

function Screen.build(menu)
    local l = layout()
    local back = menu.loadoutTarget == "preset" and "rules" or (menu.paused and "pause" or "root")
    local list = { Common.backElement(menu, function() menu:switch(back, -1) end) }
    local weaponKey, modKey, gadgetKey = keys(menu)
    local tileW = math.floor((l.w - 44 - (COLS - 1) * 10) / COLS)
    for k, kind in ipairs(WeaponConfig.order) do
        local col, row = (k - 1) % COLS, math.floor((k - 1) / COLS)
        list[#list + 1] = {
            id = "weapon:" .. kind, kind = kind, value = k,
            x = l.x + 22 + col * (tileW + 10), y = l.y + 50 + row * (TILE_H + 10), w = tileW, h = TILE_H,
            press = function() menu:setOption(weaponKey, k) end
        }
    end
    local my = l.y + 50 + ROWS * (TILE_H + 10) + 44
    local modW = math.floor((l.w - 44 - 8 * (MOD_COLS - 1)) / MOD_COLS)
    for k, mod in ipairs(Loadout.mods) do
        local col, row = (k - 1) % MOD_COLS, math.floor((k - 1) / MOD_COLS)
        list[#list + 1] = {
            id = "mod:" .. mod.id, mod = mod, value = k,
            x = l.x + 22 + col * (modW + 8), y = my + row * (MOD_H + 6), w = modW, h = MOD_H,
            press = function()
                local values = menu.settings
                menu:setOption(modKey, Settings.withMod(values[modKey], values[weaponKey], k))
            end
        }
    end
    local gy = my + MOD_ROWS * (MOD_H + 6) + 34
    local count = #Loadout.gadgets
    local gw = l.w - 44
    list[#list + 1] = {
        id = "gadget", x = l.x + 22, y = gy, w = gw, h = 38,
        press = function(_, mx)
            if mx then
                menu:setOption(gadgetKey, Kit.clamp(math.floor((mx - l.x - 22) / (gw / count)) + 1, 1, count))
            else
                menu:setOption(gadgetKey, menu.settings[gadgetKey] % count + 1)
            end
        end,
        left = function() menu:setOption(gadgetKey, math.max(1, menu.settings[gadgetKey] - 1)) end,
        right = function() menu:setOption(gadgetKey, math.min(count, menu.settings[gadgetKey] + 1)) end
    }
    return list
end

local function drawWeapon(kind, x, y, scale, alpha, mod)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(scale)
    Character.drawWeapon(kind, 0, 0, 0, alpha, mod)
    love.graphics.pop()
end

--- @return string?
function Screen.matchNote()
    local GM = require("src.core.index")
    local world = GM.Session and GM.Session.active and GM.Session.world
    if not world or world.spectator then return nil end
    if world.rules.ladder or world.rules.rounds or world.options.spawn ~= "own" then
        return "This match doesn't use your own loadout. It is saved for the next one that does."
    end
    return "Changes apply the next time you respawn."
end

function Screen.draw(menu, elements, p)
    local l = layout()
    local preset = menu.loadoutTarget == "preset"
    local note = not preset and menu.paused and Screen.matchNote() or nil
    Common.header(menu, elements, p, preset and "Set loadout" or "Loadout",
        note or (preset and "What every player starts with in your games." or "What you start with when a game lets you bring your own."))
    local weaponKey, modKey, gadgetKey = keys(menu)
    local s = menu.settings
    local current = Settings.modAt(s[modKey], s[weaponKey])
    local e = menu:stagger(p, 2)
    local panelH = 50 + ROWS * (TILE_H + 10) + 44 + MOD_ROWS * (MOD_H + 6) + 12 + 80
    Kit.card(l.x, l.y + (1 - e) * 20, l.w, panelH, e, 18)
    Kit.text("Weapon", 12, l.x + 22, l.y + 22, Kit.INK, 0.5 * e)
    Kit.text("Mod", 12, l.x + 22, l.y + 50 + ROWS * (TILE_H + 10) + 18, Kit.INK, 0.5 * e)
    local lg = love.graphics
    for k, element in ipairs(elements) do
        local a = menu:stagger(p, 2 + k * 0.2)
        if element.kind then
            local selected = s[weaponKey] == element.value
            local hot = Kit.ease("lw:" .. element.id, menu.focus == element.id)
            local pick = Kit.ease("lwsel:" .. element.id, selected)
            lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], (0.04 + 0.04 * hot) * a)
            lg.rectangle("fill", element.x, element.y, element.w, element.h, 12, 12)
            drawWeapon(element.kind, element.x + element.w / 2, element.y + 30, 2.5, a, Character.modId(Settings.modAt(s[modKey], element.value)))
            local def = WeaponConfig[element.kind]
            Kit.text(title(def.name), 14, element.x, element.y + element.h - 26, Kit.INK, (0.6 + 0.4 * pick) * a, "center", element.w)
            if pick > 0.01 then
                Kit.color(Kit.RED, pick * a)
                lg.setLineWidth(2.5)
                lg.rectangle("line", element.x + 1, element.y + 1, element.w - 2, element.h - 2, 12, 12)
                lg.setLineWidth(1)
            end
        elseif element.id == "gadget" then
            Kit.text("Gadget", 12, element.x, element.y - 20, Kit.INK, 0.5 * a)
            Kit.segments("gadget", element.x, element.y, element.w, element.h, Loadout.gadgetLabels, s[gadgetKey], a)
        elseif element.mod then
            local selected = current == element.value
            local hot = Kit.ease("lm:" .. element.id, menu.focus == element.id)
            local pick = Kit.ease("lmsel:" .. element.id, selected)
            lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], (0.03 + 0.04 * hot + 0.03 * pick) * a)
            lg.rectangle("fill", element.x, element.y, element.w, element.h, 10, 10)
            if pick > 0.01 then
                Kit.color(Kit.RED, pick * a)
                lg.rectangle("fill", element.x, element.y + 10, 3, element.h - 20, 1.5, 1.5)
            end
            Kit.text(element.mod.name, 14, element.x + 14, element.y + 6, Kit.INK, a)
            Kit.text(element.mod.text, 12, element.x + 14, element.y + 25, Kit.INK, 0.5 * a)
        end
    end

    local pv = l.preview
    local pe = menu:stagger(p, 3)
    local py = pv.y + (1 - pe) * 20
    local ph = math.min(pv.h, panelH)
    Kit.card(pv.x, py, pv.w, ph, pe, 18)
    local kind = WeaponConfig.order[s[weaponKey]]
    local def = WeaponConfig[kind]
    local mod = Loadout.mods[current]
    local player = { weapon = kind, mod = current > 1 and current or nil, modWeapon = kind }
    local base = { weapon = kind }
    drawWeapon(kind, pv.x + pv.w / 2, py + 92, 6.5, pe, Character.modId(current))
    Kit.text(title(def.name) .. (mod.id ~= "none" and ("  +  " .. mod.name) or ""), 22, pv.x + 26, py + 170, Kit.INK, pe)
    Kit.text(def.tag or "", 13, pv.x + 26, py + 202, def.exposed and Kit.RED or Kit.INK, 0.55 * pe)
    local gadget = require("src.config.gadgets")[Loadout.gadgets[s[gadgetKey]]]
    local gtext = gadget and (gadget.name .. ": " .. gadget.text:lower()) or "No gadget"
    Kit.text(gtext, 13, pv.x + 26, py + ph - 34, Kit.INK, 0.6 * pe)
    local sy = py + 236
    local barX, barW = pv.x + 130, pv.w - 130 - 120
    for _, stat in ipairs(STATS) do
        local value = stat.value(player, def)
        local plain = stat.value(base, def)
        local fill = Kit.clamp(value / stat.max, 0, 1)
        local ghost = Kit.clamp(plain / stat.max, 0, 1)
        if stat.invert then fill, ghost = 1 - fill, 1 - ghost end
        local better = (stat.invert and value < plain) or (not stat.invert and value > plain)
        local worse = math.abs(value - plain) > 1e-6 and not better
        -- green when the mod improves the stat, red when it makes it worse
        local tint = better and Kit.GREEN or (worse and Kit.RED or Kit.INK)
        Kit.text(stat.label, 13, pv.x + 26, sy, worse and Kit.RED or Kit.INK, worse and 0.9 * pe or 0.6 * pe)
        Kit.bar(barX, sy + 6, barW, 6, Kit.ease("stat:" .. stat.label, fill), tint, pe)
        if better or worse then
            lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.5 * pe)
            lg.rectangle("fill", barX + barW * ghost - 1, sy + 3, 2, 12)
        end
        Kit.text(stat.text(type(value) == "number" and value % 1 ~= 0 and value or math.floor(value), player), 13, pv.x + pv.w - 26, sy, tint, 0.8 * pe, "right")
        sy = sy + 30
    end
end

function Screen.back(menu)
    menu:switch(menu.loadoutTarget == "preset" and "rules" or (menu.paused and "pause" or "root"), -1)
end

return Screen
