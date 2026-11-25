--- The hub between raids: your gear, the stash, the trader and the workbench where
--- blueprints become items. Every action is a request to the server, which answers
--- with the new state of the profile.
local Kit = require("src.ui.kit")
local Icons = require("src.modules.extraction.icons")
local UI = require("src.modules.extraction.inventory")
local Items = require("src.game.extraction.items")
local Inventory = require("src.game.extraction.inventory")
local ItemConfig = require("src.config.items")
local Config = require("src.config.extraction")

local Hub = {}

local lg = love.graphics
local floor, min, max = math.floor, math.min, math.max

local TABS = { "Trader", "Workbench", "Record" }
local SHOP_FILTERS = {
    { "All" }, { "Weapons", "weapon" }, { "Ammo", "ammo" }, { "Gear", "armor", "backpack" }, { "Utilities", "utility" },
    { "Mods", "mod" }, { "Materials", "material" }, { "Plans", "blueprint" }
}
local CRAFT_FILTERS = { { "All" }, { "Weapons", "weapon" }, { "Mods", "mod" }, { "Utilities", "utility" }, { "Gear", "armor", "backpack" }, { "Ammo", "ammo" } }

--- @param amount number
--- @return string
function Hub.money(amount)
    local s = tostring(floor(amount))
    local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
    return out .. " cr"
end

local function button(state, id, x, y, w, h, label, run, options)
    local mx, my = love.mouse.getPosition()
    options = options or {}
    options.hot = mx >= x and mx < x + w and my >= y and my < y + h
    Kit.button("hub:" .. id, x, y, w, h, label, options)
    state.buttons[#state.buttons + 1] = { x = x, y = y, w = w, h = h, run = run, disabled = options.disabled }
end

local function matches(def, filter)
    if #filter == 1 then return true end
    for k = 2, #filter do
        if def.kind == filter[k] then return true end
    end
    return false
end

--- @param ext table
function Hub.new(ext)
    local state = { tab = 1, buttons = {}, shopFilter = 1, craftFilter = 1, shopScroll = 0, craftScroll = 0, craftRarity = {} }
    state.ui = UI.new(function(op) ext:send("xhub", op) end)
    state.ui.extraMenu = function(inst, ref)
        local list = {}
        local def = Items.def(inst)
        list[#list + 1] = { "Sell for " .. Hub.money(Items.value(inst, Config.sellRate)), function() ext:send("xhub", { o = "sell", i = inst.i }) end }
        if def.kind == "blueprint" then
            list[#list + 1] = { "Learn this plan", function() ext:send("xhub", { o = "learn", i = inst.i }) end }
        end
        return list
    end
    state.ui.quickMove = function(inst, ref)
        local data = ext.hub
        local places = Hub.places(data)
        local to = (ref == "st") and { "pk", "bp" } or { "st" }
        if ref == "detach" then to = { "st", "bp", "pk" } end
        local def = Items.def(inst)
        if ref == "st" then
            if def.kind == "weapon" then to = { "primary", "secondary", "bp", "pk" } end
            if def.kind == "armor" then to = { def.slot, "bp" } end
            if def.kind == "backpack" then to = { "backpack" } end
        end
        for _, target in ipairs(to) do
            local place = places[target]
            if place and place.kind == "grid" then
                local x, y, o = Inventory.free(place, inst)
                if x then
                    ext:send("xhub", { o = "move", i = inst.i, to = target, x = x, y = y, r = o })
                    return
                end
            elseif place and place.kind == "slot" and not place.get() and place.accept(inst) then
                ext:send("xhub", { o = "move", i = inst.i, to = target })
                return
            end
        end
        ext:toast("No room")
    end
    return state
end

--- @param data table hub view
--- @return table
function Hub.places(data)
    return Inventory.places(data.g, { st = { kind = "grid", w = Config.stash.w, h = Config.stash.h, list = data.stash } })
end

local function stats(data, x, y, w)
    Kit.text("Your record on this server", 13, x, y - 30, Kit.INK, 0.55)
    local s = data.stats or {}
    local lines = {
        { "Raids", s.raids }, { "Extracted", s.extracts }, { "Deaths", s.deaths }, { "Players killed", s.kills },
        { "Monsters killed", s.monsters }, { "Crafted", s.crafted }, { "Earned", Hub.money(s.earned or 0) }
    }
    for k, line in ipairs(lines) do
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], k % 2 == 0 and 0.03 or 0)
        lg.rectangle("fill", x - 8, y + (k - 1) * 34 - 6, w + 16, 32, 6, 6)
        Kit.text(line[1], 15, x, y + (k - 1) * 34, Kit.INK, 0.65)
        Kit.text(tostring(line[2] or 0), 16, (x) + (w), y + (k - 1) * 34, Kit.INK, 0.95, "right")
    end
end

local function trader(state, ext, x, y, w, h)
    local data = ext.hub
    local names = {}
    for k, f in ipairs(SHOP_FILTERS) do names[k] = f[1] end
    Kit.segments("hub:shopFilter", x, y, w, 34, names, state.shopFilter, 1)
    local cell = w / #SHOP_FILTERS
    for k = 1, #SHOP_FILTERS do
        state.buttons[#state.buttons + 1] = { x = x + (k - 1) * cell, y = y, w = cell, h = 34, run = function() state.shopFilter, state.shopScroll = k, 0 end }
    end
    local list = {}
    for _, entry in ipairs(ItemConfig.shop) do
        if matches(ItemConfig.all[entry.id], SHOP_FILTERS[state.shopFilter]) then list[#list + 1] = entry end
    end
    local rowH = 56
    local top = y + 50
    local visible = floor((h - 140) / rowH)
    state.shopScroll = max(0, min(state.shopScroll, #list - visible))
    state.shopRegion = { x = x, y = top, w = w, h = visible * rowH }
    for k = 1, min(visible, #list - state.shopScroll) do
        local entry = list[k + state.shopScroll]
        local def = ItemConfig.all[entry.id]
        local ry = top + (k - 1) * rowH
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.04)
        lg.rectangle("fill", x, ry, w, rowH - 6, 8, 8)
        local inst = { i = -k, d = entry.id, r = 1, n = def.kind == "ammo" and def.stack or nil }
        Icons.draw(inst, x + 6, ry + 4, 72, rowH - 14)
        Kit.text(def.name .. (def.kind == "ammo" and (" x" .. def.stack) or ""), 15, x + 90, ry + 8, Kit.INK, 0.9)
        Kit.text(def.class or def.text or (def.kind == "blueprint" and "Learn to craft " .. ItemConfig.all[def.target].name) or def.kind, 11, x + 90, ry + 28, Kit.INK, 0.5, "left", w - 330)
        local mx, my = love.mouse.getPosition()
        if mx >= x and mx < x + 80 and my >= ry and my < ry + rowH then state.tooltip = inst end
        for r = 1, entry.rarity or 1 do
            local price = Items.price(entry.id, r)
            local rarity = ItemConfig.rarities[ItemConfig.rarities.order[r]]
            local bx = x + w - r * 118
            button(state, "buy" .. entry.id .. r, bx, ry + 6, 112, rowH - 18, Hub.money(price), function()
                ext:send("xhub", { o = "buy", d = entry.id, r = r })
            end, { size = 13, arrow = false, sublabel = rarity.name, disabled = data.money < price })
        end
    end
    state.ui:zone("sell", x, y + h - 80, w, 70, "Drop here to sell")
    if not state.ui.drag then
        Kit.text("Drag items here or right click them to sell (" .. floor(Config.sellRate * 100) .. "% of their value).", 12, x, y + h - 50, Kit.INK, 0.5, "center", w)
    end
end

local function workbench(state, ext, x, y, w, h)
    local data = ext.hub
    local names = {}
    for k, f in ipairs(CRAFT_FILTERS) do names[k] = f[1] end
    Kit.segments("hub:craftFilter", x, y, w, 34, names, state.craftFilter, 1)
    local cell = w / #CRAFT_FILTERS
    for k = 1, #CRAFT_FILTERS do
        state.buttons[#state.buttons + 1] = { x = x + (k - 1) * cell, y = y, w = cell, h = 34, run = function() state.craftFilter, state.craftScroll = k, 0 end }
    end
    local list = {}
    for _, id in ipairs(ItemConfig.craftOrder) do
        if (data.known[id] or 0) > 0 and matches(ItemConfig.all[id], CRAFT_FILTERS[state.craftFilter]) then list[#list + 1] = id end
    end
    local counts = {}
    for _, inst in ipairs(data.stash) do counts[inst.d] = (counts[inst.d] or 0) + (inst.n or 1) end
    local listW = floor(w * 0.45)
    local rowH = 36
    local top = y + 50
    local visible = floor((h - 60) / rowH)
    state.craftScroll = max(0, min(state.craftScroll, #list - visible))
    state.craftRegion = { x = x, y = top, w = listW, h = visible * rowH }
    if not state.selected or not data.known[state.selected] then state.selected = list[1] end
    for k = 1, min(visible, #list - state.craftScroll) do
        local id = list[k + state.craftScroll]
        local def = ItemConfig.all[id]
        local ry = top + (k - 1) * rowH
        local known = data.known[id]
        local rarity = ItemConfig.rarities[ItemConfig.rarities.order[known]]
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], state.selected == id and 0.1 or 0.03)
        lg.rectangle("fill", x, ry, listW, rowH - 4, 6, 6)
        Kit.color(rarity.color, 1)
        lg.rectangle("fill", x, ry + 6, 4, rowH - 16, 2, 2)
        Kit.text(def.name, 14, x + 14, ry + 8, Kit.INK, 0.9, "left", listW - 100)
        if def.kind ~= "ammo" then Kit.text(rarity.name, 11, (x) + (listW - 10), ry + 11, rarity.color, 1, "right") end
        state.buttons[#state.buttons + 1] = { x = x, y = ry, w = listW, h = rowH - 4, run = function() state.selected = id end }
    end
    if #list == 0 then Kit.text("No plan for this kind yet. Find plans in the world or buy them.", 13, x, top + 10, Kit.INK, 0.5, "left", listW) end
    local id = state.selected
    if not id then return end
    local def = ItemConfig.all[id]
    local dx, dw = x + listW + 20, w - listW - 20
    local known = data.known[id]
    local r = min(state.craftRarity[id] or known, known)
    if def.kind == "ammo" then r = 1 end
    local inst = { i = -1, d = id, r = r, n = def.kind == "ammo" and ItemConfig.yield(id) or nil }
    if def.kind == "armor" then inst.u = Items.armorStats(inst).durability end
    local size = 56
    Icons.draw(inst, dx, top, min(dw, def.w * size), def.h * size)
    local ty = top + def.h * size + 14
    local lines = UI.describe(inst)
    for k = 1, min(#lines, 6) do
        local line = lines[k]
        Kit.text(line[1], line[3] or 13, dx, ty, line[2] or Kit.INK, line[2] and 1 or 0.75, "left", dw)
        ty = ty + (line[3] or 13) + 8
    end
    if def.kind ~= "ammo" then
        Kit.text("Rarity (your plan goes up to " .. ItemConfig.rarities[ItemConfig.rarities.order[known]].name:lower() .. ")", 12, dx, ty + 4, Kit.INK, 0.55)
        ty = ty + 24
        for k = 1, known do
            local rarity = ItemConfig.rarities[ItemConfig.rarities.order[k]]
            local bx = dx + (k - 1) * 46
            Kit.color(rarity.color, k == r and 1 or 0.35)
            lg.rectangle("fill", bx, ty, 40, 24, 6, 6)
            state.buttons[#state.buttons + 1] = { x = bx, y = ty, w = 40, h = 24, run = function() state.craftRarity[id] = k end }
        end
        ty = ty + 36
    end
    Kit.text("Materials (from your stash)", 12, dx, ty, Kit.INK, 0.55)
    ty = ty + 20
    local ready = true
    for _, part in ipairs(Items.recipe(id, r)) do
        local have = counts[part.id] or 0
        local ok = have >= part.n
        if not ok then ready = false end
        Kit.text(ItemConfig.all[part.id].name, 13, dx, ty, Kit.INK, 0.8)
        Kit.text(have .. " / " .. part.n, 13, (dx) + (dw), ty, ok and Kit.GREEN or Kit.RED, 1, "right")
        ty = ty + 20
    end
    button(state, "craft", dx, ty + 12, dw, 48, "Craft", function()
        ext:send("xhub", { o = "craft", d = id, r = r })
    end, { primary = ready, size = 18, disabled = not ready })
end

--- @param ext table
function Hub.draw(ext)
    local state, data = ext.hubState, ext.hub
    local W, H = lg.getDimensions()
    lg.clear(Kit.PAPER)
    state.buttons = {}
    state.tooltip = nil
    local places = Hub.places(data)
    state.ui:begin(places)
    local M = 20
    -- Header
    Kit.card(M, M, W - M * 2, 76, 0.97, 16)
    Kit.color(Kit.RED, 1)
    lg.rectangle("fill", M + 18, M + 18, 6, 40, 3, 3)
    Kit.text("The Wilds", 28, M + 36, M + 12, Kit.INK, 1)
    Kit.text(string.format("Official server  ·  %d / %d in the world", data.players or 0, data.max or 64), 13, M + 37, M + 48, Kit.INK, 0.55)
    local money = Hub.money(data.money)
    local mw = Kit.font(22):getWidth(money) + 34
    local mx = W - M - 18 - 200 - 12 - 200 - 16 - mw
    Kit.color(Kit.AMBER, 0.16)
    lg.rectangle("fill", mx, M + 18, mw, 40, 20, 20)
    Kit.text(money, 22, mx + 17, M + 24, Kit.AMBER, 1)
    button(state, "deploy", W - M - 18 - 200, M + 12, 200, 52, "Deploy", function() ext:send("xhub", { o = "deploy" }) end, { primary = true, size = 21, hint = "Enter" })
    local kit = data.kit or 0
    button(state, "kit", W - M - 18 - 200 - 12 - 200, M + 12, 200, 52, kit > 0 and string.format("Free kit  %d:%02d", floor(kit / 60), kit % 60) or "Free kit",
        function() ext:send("xhub", { o = "kit" }) end, { size = 15, disabled = kit > 0, sublabel = "P9, ammo, bandages" })

    local top = M + 76 + 16
    local bottom = H - M
    local cell = max(28, min(42, floor((bottom - top - 330) / 9), floor(W / 46)))
    -- Loadout
    local lw = cell * 7 + 16 + 32
    local value = 0
    for _, inst in ipairs(Inventory.all(data.g)) do value = value + Items.value(inst, Config.sellRate) end
    UI.panel("Loadout", M, top, lw, bottom - top, Hub.money(value))
    state.ui:loadout(data.g, places, M + 16, top + 44, cell, "survivor1")
    -- Stash
    local sw = Config.stash.w * cell + 40
    local sx = W - M - sw
    UI.panel("Stash", sx, top, sw, bottom - top, "wheel to scroll")
    local rows = floor((bottom - top - 64) / cell)
    state.ui:grid("st", places.st, sx + 16, top + 44, cell, nil, rows)
    -- Tabs
    local cx = M + lw + 16
    local cw = sx - 16 - cx
    UI.panel(nil, cx, top, cw, bottom - top)
    local tw = min(cw - 32, 420)
    Kit.segments("hub:tab", cx + 16, top + 14, tw, 36, TABS, state.tab, 1)
    for k = 1, #TABS do
        state.buttons[#state.buttons + 1] = { x = cx + 16 + (k - 1) * tw / #TABS, y = top + 14, w = tw / #TABS, h = 36, run = function() state.tab = k end }
    end
    local contentY = top + 66
    local contentH = bottom - contentY - 16
    if state.tab == 1 then
        trader(state, ext, cx + 16, contentY, cw - 32, contentH)
    elseif state.tab == 2 then
        workbench(state, ext, cx + 16, contentY, cw - 32, contentH)
    else
        stats(data, cx + 24, contentY + 40, min(cw - 48, 420))
        Kit.text("Tips", 13, cx + 24, contentY + 300, Kit.INK, 0.55)
        local tips = {
            "Shift click moves an item between your loadout and the stash.",
            "R rotates an item while you drag it.",
            "Drop an attachment on a weapon to fit it; a utility on a quick slot to bind it.",
            "Right click a plan in the stash to learn it, any item to sell it."
        }
        for k, tip in ipairs(tips) do Kit.text("·  " .. tip, 13, cx + 24, contentY + 300 + k * 22, Kit.INK, 0.7) end
    end
    state.ui:finish()
    state.ui:overlay()
    if state.tooltip and not state.ui.drag then
        local mx2, my2 = love.mouse.getPosition()
        UI.tooltip(state.tooltip, mx2 + 18, my2 + 12)
    end
    ext:drawToasts()
end

--- @return boolean
function Hub.mousepressed(ext, x, y, button)
    local state = ext.hubState
    if state.ui.menu or state.ui.drag then return state.ui:mousepressed(x, y, button) end
    if button == 1 then
        for k = #state.buttons, 1, -1 do
            local b = state.buttons[k]
            if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
                if not b.disabled then
                    b.run()
                    if GM and GM.Audio then GM.Audio:Play("click") end
                end
                return true
            end
        end
    end
    return state.ui:mousepressed(x, y, button)
end

function Hub.mousereleased(ext, x, y, button)
    return ext.hubState.ui:mousereleased(x, y, button)
end

function Hub.wheelmoved(ext, y)
    local state = ext.hubState
    local mx, my = love.mouse.getPosition()
    local function over(r) return r and mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h end
    if state.tab == 1 and over(state.shopRegion) then
        state.shopScroll = state.shopScroll - y
        return
    end
    if state.tab == 2 and over(state.craftRegion) then
        state.craftScroll = state.craftScroll - y
        return
    end
    state.ui:wheelmoved(y)
end

function Hub.keypressed(ext, key)
    local state = ext.hubState
    if state.ui:keypressed(key) then return true end
    if key == "return" or key == "kpenter" then
        ext:send("xhub", { o = "deploy" })
        return true
    end
    if key == "tab" then
        state.tab = state.tab % #TABS + 1
        return true
    end
    return false
end

return Hub
