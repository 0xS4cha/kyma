local Kit = require("src.ui.kit")
local Common = require("src.modules.menu.screens.common")

local Howto = {}

local CARDS = {
    {
        title = "Read the room",
        text = "The camera turns with you: where you aim is always up. You see a cone in front of you and a small circle around you. Walls and closed doors block the view, glass does not. Enemies are invisible outside of it."
    },
    {
        title = "Noise gives you away",
        text = "Shots, dashes, running and thrown weapons leave an echo for an opponent who can't see you. Bullet trails and holes in the walls point back to the shooter.",
        keys = { { "C", "Walk quietly" } }
    },
    {
        title = "Dash and slide",
        text = "A dash makes bullets go through you, but you can't shoot. Dash while running to slide instead: you can shoot, but you are only untouchable at the start.",
        keys = { { "Space", "Dash or slide" } }
    },
    {
        title = "Weapons",
        rows = {
            { "Pistol", "3 hits, one shot per click" },
            { "Rifle", "Automatic" },
            { "Shotgun", "Deadly up close" },
            { "Sniper", "One shot, its laser shows" },
            { "Silencer", "Silent, no echo" },
            { "LMG", "60 rounds, slows you down" }
        }
    },
    {
        title = "Loot",
        text = "Weapons wait on the circles on the floor and come back 10 s after being taken. Ammo packs add a magazine, health packs heal 50. The fallen drop their weapon and ammo.",
        keys = { { "E", "Swap weapons" }, { "G", "Throw it, 45 damage" } }
    },
    {
        title = "Controls",
        keys = {
            { "W A S D", "Move" }, { "Mouse", "Aim" }, { "Left click", "Fire" },
            { "R", "Reload" }, { "H", "Controls in game" }, { "Esc", "Pause" }
        }
    }
}

local function layout()
    local W, H = love.graphics.getDimensions()
    local M = Common.margin()
    local gap = 18
    local cols = 3
    local w = math.floor((math.min(W - M * 2, 1300) - gap * (cols - 1)) / cols)
    local top = 126
    local h = math.floor((H - top - M - gap) / 2)
    return { x = M, y = top, w = w, h = math.min(h, 300), gap = gap, cols = cols }
end

function Howto.build(menu)
    return { Common.backElement(menu, function() menu:switch("root", -1) end) }
end

local function keys(list, x, y, alpha)
    for k, pair in ipairs(list) do
        local kw = Kit.keycap(pair[1], x, y + (k - 1) * 32, alpha, 12)
        Kit.text(pair[2], 13, x + math.max(kw, 70) + 10, y + (k - 1) * 32 + 4, Kit.INK, 0.7 * alpha)
    end
end

function Howto.draw(menu, elements, p)
    local l = layout()
    Common.header(menu, elements, p, "How to play", "Everything you need for your first duel.")
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
                Kit.text(pair[2], 13, x + 110, cy + (r - 1) * 26 + 1, Kit.INK, 0.6 * e)
            end
        end
        if card.keys then
            keys(card.keys, x + 20, cy, e)
        end
    end
end

function Howto.back(menu)
    menu:switch("root", -1)
end

return Howto
