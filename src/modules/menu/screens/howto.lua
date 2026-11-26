local Kit = require("src.ui.kit")
local Common = require("src.modules.menu.screens.common")

local Howto = {}

local Keybinds = require("src.input.keybinds")
local Loadout = require("src.config.loadout")
local Config = require("src.config.game")
local WeaponConfig = require("src.config.weapons")

--- A key shown by the action it does, so rebinding it in the settings updates the card.
local function bind(...) return { bind = { ... } } end

local seconds = function(ticks) return math.floor(ticks / 60 + 0.5) end

local CARDS = {
    {
        title = "Read the room",
        text = "The camera turns with you: where you aim is always up. You see a cone in front of you and a small circle around you. Walls and closed doors block the view, glass does not. Enemies are invisible outside of it."
    },
    {
        title = "Noise gives you away",
        text = "Shots, dashes, running, thrown weapons and scans leave an echo for an opponent who can't see you. Bullet trails and holes in the walls point back to the shooter.",
        keys = { { bind("quiet"), "Walk quietly" }, { bind("ping"), "Ping a spot for your team" } }
    },
    {
        title = "Dash and slide",
        text = "A dash makes bullets go through you, but you can't shoot. Dash while running to slide instead: you can shoot, but you are only untouchable at the start.",
        keys = { { bind("dash"), "Dash or slide" } }
    },
    {
        title = "Weapons",
        grid = {
            { "Pistol", "3 hits, one per click" }, { "Rifle", "Automatic" },
            { "Shotgun", "Deadly up close" }, { "Sniper", "One shot without shield" },
            { "Silencer", "Silent, no echo" }, { "LMG", "60 rounds, slows you" },
            { "SMG", "Very fast, wide spread" }, { "Revolver", "Slow, 3 hits kill" },
            { "DMR", "Precise, long range" }, { "Auto shotgun", "Fast pump" },
            { "Breaker", "Shreds shield plates" }
        }
    },
    {
        title = "Loot and shields",
        text = "Weapons wait on the circles and come back " .. seconds(WeaponConfig.padRespawn) .. " s after being taken. Ammo packs add a magazine, health packs heal " .. WeaponConfig.healAmount
            .. ". Shield plates take " .. Config.shield.plateHp .. " damage each before your health, up to " .. Config.shield.plates
            .. ". A weapon thrown or dropped vanishes after " .. seconds(WeaponConfig.dropLifetime) .. " s.",
        keys = { { bind("pickup"), "Pick up or swap" }, { bind("throw"), "Throw it, " .. WeaponConfig.throw.damage .. " damage" } }
    },
    {
        title = "Loadout and scan",
        text = "In Loadout, pick a weapon, a mod and a gadget: smoke, flashbang, decoy, stim or shock, one per life. Each mod has a cost, shown in red. The scan shows nearby enemies as red dots on your minimap, every "
            .. seconds(Config.scan.cooldown) .. " s, but they hear it.",
        keys = { { bind("gadget"), "Use your gadget" }, { bind("scan"), "Scan for enemies" } }
    },
    {
        title = "Modes",
        rows = {
            { "Duel", "One on one" },
            { "Free for all", "Everyone for themselves" },
            { "Teams", "Two teams" },
            { "Gun game", "Each kill, the next weapon" },
            { "Infiltration", "Hack a terminal or hold it" }
        },
        foot = "Match rules under the maps in Play: floor weapons, heal on kill, shields, starting kit, elimination rounds in Duel and Teams."
    },
    {
        title = "Controls",
        columns = true,
        keys = {
            { bind("forward", "left", "back", "right"), "Move" }, { "Mouse", "Aim" }, { "Click", "Fire" },
            { bind("reload"), "Reload" }, { bind("ready"), "Ready" }, { bind("scoreboard"), "Scores" },
            { bind("chat"), "Chat" }, { bind("help"), "Help" }, { "Esc", "Pause" }
        }
    }
}

local function layout()
    local W, H = love.graphics.getDimensions()
    local M = Common.margin()
    local gap = 18
    local cols = W >= 1200 and 4 or 3
    local rows = math.ceil(#CARDS / cols)
    local w = math.floor((math.min(W - M * 2, 1760) - gap * (cols - 1)) / cols)
    local top = 126
    local h = math.floor((H - top - M - gap * (rows - 1)) / rows)
    return { x = M, y = top, w = w, h = math.min(h, 330), gap = gap, cols = cols }
end

function Howto.build(menu)
    return { Common.backElement(menu, function() menu:switch("root", -1) end) }
end

local function keyName(key)
    if type(key) ~= "table" then return key end
    local names = {}
    for _, id in ipairs(key.bind) do names[#names + 1] = Keybinds.label(id) end
    return table.concat(names, " ")
end

--- @return number height used
local function keys(list, x, y, w, alpha, columns)
    local per = columns and math.ceil(#list / 3) or #list
    local colW = columns and math.floor(w / 3) or w
    for k, pair in ipairs(list) do
        local col, row = columns and math.floor((k - 1) / per) or 0, columns and (k - 1) % per or k - 1
        local kx, ky = x + col * colW, y + row * 32
        local kw = Kit.keycap(keyName(pair[1]), kx, ky, alpha, 12)
        Kit.text(pair[2], 13, kx + (columns and kw + 8 or math.max(kw, 70) + 10), ky + 4, Kit.INK, 0.7 * alpha)
    end
    return per * 32
end

function Howto.draw(menu, elements, p)
    local l = layout()
    Common.header(menu, elements, p, "How to play", "Everything you need for your first match.")
    for k, card in ipairs(CARDS) do
        local e = menu:stagger(p, k + 1)
        local col, row = (k - 1) % l.cols, math.floor((k - 1) / l.cols)
        local x = l.x + col * (l.w + l.gap)
        local y = l.y + row * (l.h + l.gap) + (1 - e) * 24
        Kit.card(x, y, l.w, l.h, e, 18)
        Kit.text(string.format("0%d", k), 12, x + 20, y + 18, Kit.RED, e)
        Kit.text(card.title, 20, x + 20, y + 36, Kit.INK, e)
        local cy = y + 72
        if card.text then
            cy = cy + Common.paragraph(card.text, 13, x + 20, cy, l.w - 40, Kit.INK, 0.65 * e) + 14
        end
        if card.rows then
            for r, pair in ipairs(card.rows) do
                Kit.text(pair[1], 14, x + 20, cy + (r - 1) * 26, Kit.INK, e)
                Kit.text(pair[2], 13, x + 130, cy + (r - 1) * 26 + 1, Kit.INK, 0.6 * e)
            end
            cy = cy + #card.rows * 26 + 8
        end
        if card.grid then
            -- two columns, the name over what it does
            local half = math.floor((l.w - 40) / 2)
            for r, pair in ipairs(card.grid) do
                local gx, gy = x + 20 + ((r - 1) % 2) * half, cy + math.floor((r - 1) / 2) * 38
                Kit.text(pair[1], 14, gx, gy, Kit.INK, e)
                Kit.text(pair[2], 12, gx, gy + 18, Kit.INK, 0.55 * e)
            end
        end
        if card.foot then
            Common.paragraph(card.foot, 12, x + 20, cy, l.w - 40, Kit.INK, 0.5 * e)
        end
        if card.keys then
            keys(card.keys, x + 20, cy, l.w - 40, e, card.columns)
        end
    end
end

function Howto.back(menu)
    menu:switch(menu.paused and "pause" or "root", -1)
end

return Howto
