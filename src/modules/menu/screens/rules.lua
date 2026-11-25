local Kit = require("src.ui.kit")
local Common = require("src.modules.menu.screens.common")
local Loadout = require("src.config.loadout")
local Settings = require("src.modules.menu.settings")
local WeaponConfig = require("src.config.weapons")

local Screen = {}

local ROW = 70

local function layout()
    local W = love.graphics.getWidth()
    local M = Common.margin()
    return { x = M, y = 130, w = math.min(720, W - M * 2) }
end

--- @param values table
--- @param kit table
--- @return string
function Screen.kitName(kit)
    local def = WeaponConfig[WeaponConfig.order[kit.w]]
    local mod = Loadout.mods[kit.m]
    local name = #def.name <= 3 and def.name or (def.name:sub(1, 1) .. def.name:sub(2):lower())
    local gadget = require("src.config.gadgets")[Loadout.gadgets[kit.g or 1]]
    return name .. (gadget and (" + " .. gadget.name:lower()) or "") .. (mod.id ~= "none" and (" + " .. mod.name:lower()) or "")
end

--- @param values table
--- @return string
function Screen.summary(values)
    local spawn = values.spawnWith
    local start = spawn == 1 and "start with a pistol" or spawn == 2 and "start with your loadout"
        or ("everyone starts with " .. Screen.kitName(Settings.kit(values, "preset")):lower())
    return (values.floorWeapons and "Weapons on the floor" or "No weapons on the floor") .. ", " .. start
        .. (values.killHeal and (", +" .. Loadout.killHeal .. " HP per kill") or "")
        .. (values.shields == false and ", no shields" or "")
end

function Screen.enter(menu)
    menu.loadoutTarget = nil
end

function Screen.build(menu)
    local l = layout()
    local list = { Common.backElement(menu, function() menu:switch("play", -1) end) }
    local x, w = l.x + 16, l.w - 32
    local y = l.y + 22
    list[#list + 1] = {
        id = "floorWeapons", x = x, y = y, w = w, h = ROW - 8,
        press = function() menu:setOption("floorWeapons", not menu.settings.floorWeapons) end,
        left = function() menu:setOption("floorWeapons", false) end,
        right = function() menu:setOption("floorWeapons", true) end
    }
    y = y + ROW
    list[#list + 1] = {
        id = "killHeal", x = x, y = y, w = w, h = ROW - 8,
        press = function() menu:setOption("killHeal", not menu.settings.killHeal) end,
        left = function() menu:setOption("killHeal", false) end,
        right = function() menu:setOption("killHeal", true) end
    }
    y = y + ROW
    list[#list + 1] = {
        id = "shields", x = x, y = y, w = w, h = ROW - 8,
        press = function() menu:setOption("shields", not menu.settings.shields) end,
        left = function() menu:setOption("shields", false) end,
        right = function() menu:setOption("shields", true) end
    }
    y = y + ROW
    local count = #Loadout.spawn
    local segX, segW = x + w - 380, 360
    list[#list + 1] = {
        id = "spawnWith", x = x, y = y, w = w, h = ROW - 8,
        press = function(_, mx)
            if mx and mx >= segX then
                menu:setOption("spawnWith", Kit.clamp(math.floor((mx - segX) / (segW / count)) + 1, 1, count))
            elseif not mx then
                menu:setOption("spawnWith", menu.settings.spawnWith % count + 1)
            end
        end,
        left = function() menu:setOption("spawnWith", math.max(1, menu.settings.spawnWith - 1)) end,
        right = function() menu:setOption("spawnWith", math.min(count, menu.settings.spawnWith + 1)) end
    }
    y = y + ROW
    list[#list + 1] = {
        id = "preset", x = x, y = y, w = w, h = ROW - 8,
        press = function()
            if menu.settings.spawnWith ~= 3 then return end
            menu.loadoutTarget = "preset"
            menu:switch("loadout", 1)
        end
    }
    return list
end

function Screen.draw(menu, elements, p)
    local l = layout()
    Common.header(menu, elements, p, "Match rules", "For the games you start: practice and hosted games.")
    local s = menu.settings
    local e = menu:stagger(p, 2)
    Kit.card(l.x, l.y + (1 - e) * 20, l.w, 5 * ROW + 36, e, 18)
    local lg = love.graphics
    local rows = {
        floorWeapons = { "Weapons on the floor", "Weapons wait on their spots and come back after a while" },
        killHeal = { "Heal on kill", "Each kill gives back " .. Loadout.killHeal .. " HP, up to full health" },
        shields = { "Shield plates", "Plates spawn next to the health packs and absorb damage before your health" },
        spawnWith = { "Players start with", "A pistol, their loadout, or one for all" },
        preset = { "Set loadout", s.spawnWith == 3 and Screen.kitName(Settings.kit(s, "preset")) or "Pick Same for all to use it" }
    }
    for k = 2, #elements do
        local element = elements[k]
        local a = menu:stagger(p, k + 1)
        local x, y, w, h = element.x - (1 - a) * 24, element.y, element.w, element.h
        local enabled = element.id ~= "preset" or s.spawnWith == 3
        local hot = Kit.ease("rule:" .. element.id, menu.focus == element.id and enabled)
        if hot > 0.01 then
            lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.045 * hot * a)
            lg.rectangle("fill", x, y, w, h, 10, 10)
            Kit.color(Kit.RED, hot * a)
            lg.rectangle("fill", x, y + 14, 3, h - 28, 1.5, 1.5)
        end
        local text = rows[element.id]
        local fade = enabled and 1 or 0.4
        Kit.text(text[1], 17, x + 18, y + 10, Kit.INK, a * fade)
        Kit.text(text[2], 12, x + 18, y + 35, Kit.INK, 0.5 * a * fade)
        if element.id == "floorWeapons" or element.id == "killHeal" or element.id == "shields" then
            Kit.toggle(element.id, x + w - 66, y + (h - 26) / 2, s[element.id], a)
        elseif element.id == "spawnWith" then
            Kit.segments(element.id, x + w - 380, y + (h - 36) / 2, 360, 36, Loadout.spawnLabels, s.spawnWith, a)
        else
            Kit.color(Kit.INK, (0.3 + 0.5 * hot) * a * fade)
            lg.setLineWidth(2)
            local ax, ay = x + w - 30 + hot * 4, y + h / 2
            lg.line(ax - 4, ay - 6, ax + 2, ay, ax - 4, ay + 6)
            lg.setLineWidth(1)
        end
    end
    local mode = Settings.gameMode(s)
    if mode == "gungame" then
        Kit.text("Gun game ignores the weapon rules: everyone climbs the same weapon ladder.", 13, l.x, l.y + 5 * ROW + 56, Kit.RED, 0.8 * e)
    elseif mode == "infiltration" then
        Kit.text("Infiltration ignores the weapon rules: attackers get a silencer and a smoke, defenders a rifle or an LMG.", 13, l.x, l.y + 5 * ROW + 56, Kit.RED, 0.8 * e)
    end
end

function Screen.back(menu)
    menu:switch("play", -1)
end

return Screen
