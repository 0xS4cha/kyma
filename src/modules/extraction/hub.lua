--- The hub between raids: your gear, the stash and the workbench where
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

local TABS = { "Workbench", "Record" }
local KIND_NAMES = { weapon = "Weapon", mod = "Attachment", utility = "Utility", armor = "Armor", backpack = "Backpack", ammo = "Ammunition" }
local RARITY_LETTERS = { "C", "U", "R", "E", "L", "M" }
local CRAFT_FILTERS = { { "All" }, { "Weapons", "weapon" }, { "Mods", "mod" }, { "Utilities", "utility" }, { "Gear", "armor", "backpack" }, { "Ammo", "ammo" } }

--- "3 screws, 1 circuit board" for a list of materials.
--- @param parts table[]
--- @return string
function Hub.parts(parts)
    local out = {}
    for _, part in ipairs(parts) do out[#out + 1] = part.n .. " " .. ItemConfig.all[part.id].name:lower() end
    return table.concat(out, ", ")
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
    local state = { tab = 1, buttons = {}, craftFilter = 1, craftScroll = 0, craftRarity = {} }
    state.ui = UI.new(function(op) ext:send("xhub", op) end)
    state.ui.extraMenu = function(inst, ref)
        local list = {}
        local def = Items.def(inst)
        local parts = Items.salvage(inst)
        if parts then
            list[#list + 1] = { "Recycle into " .. Hub.parts(parts), function() ext:send("xhub", { o = "recycle", i = inst.i }) end }
        end
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

--- The share of raids you came back from, nil before the first one.
local function survival(s)
    local raids = s.raids or 0
    if raids == 0 then return nil end
    return floor((s.extracts or 0) / raids * 100 + 0.5)
end

local function stats(data, x, y, w)
    Kit.text("Your record on this server", 13, x, y - 30, Kit.INK, 0.55)
    local s = data.stats or {}
    local rate = survival(s)
    local tiles = {
        { rate and (rate .. "%") or "-", "Survival rate", rate and (rate >= 50 and Kit.GREEN or Kit.RED) or Kit.INK },
        { s.raids, "Raids" }, { s.extracts, "Extracted", Kit.GREEN }, { s.deaths, "Deaths", Kit.RED },
        { s.kills, "Players killed" }, { s.monsters, "Monsters killed" }, { s.crafted, "Crafted" }, { s.recycled, "Recycled" }
    }
    local cols = 4
    local gap = 10
    local tw = (w - gap * (cols - 1)) / cols
    for k, tile in ipairs(tiles) do
        local tx = x + ((k - 1) % cols) * (tw + gap)
        local ty = y + floor((k - 1) / cols) * (96 + gap)
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.04)
        lg.rectangle("fill", tx, ty, tw, 96, 12, 12)
        Kit.text(tostring(tile[1] or 0), 30, tx, ty + 18, tile[3] or Kit.INK, 1, "center", tw)
        Kit.text(tile[2], 12, tx, ty + 62, Kit.INK, 0.5, "center", tw)
    end
    return 2 * (96 + gap)
end

local function workbench(state, ext, x, y, w, h)
    local data = ext.hub
    local zoneH = 64
    state.ui:zone("recycle", x, y + h - zoneH, w, zoneH, "Drop here to recycle into materials")
    if not state.ui.drag then
        local zy = y + h - zoneH
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.03)
        lg.rectangle("fill", x, zy, w, zoneH, 10, 10)
        -- a dashed edge: a place to drop things on
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.25)
        local dash = 10
        for dx = x + 12, x + w - 12 - dash, dash * 2 do
            lg.rectangle("fill", dx, zy, dash, 1.5)
            lg.rectangle("fill", dx, zy + zoneH - 1.5, dash, 1.5)
        end
        for dy = zy + 12, zy + zoneH - 12 - dash, dash * 2 do
            lg.rectangle("fill", x, dy, 1.5, dash)
            lg.rectangle("fill", x + w - 1.5, dy, 1.5, dash)
        end
        Kit.text("RECYCLE", 12, x, zy + 14, Kit.RED, 0.9, "center", w)
        Kit.text("Drag an item here, or right click it: you get part of its recipe back, at its rarity.", 12, x, zy + 34, Kit.INK, 0.55, "center", w)
    end
    h = h - zoneH - 12
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
    local rowH = 46
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
        local selected = state.selected == id
        local mx, my = love.mouse.getPosition()
        local hover = mx >= x and mx < x + listW and my >= ry and my < ry + rowH - 4
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], selected and 0.1 or (hover and 0.06 or 0.03))
        lg.rectangle("fill", x, ry, listW, rowH - 4, 8, 8)
        if selected then
            Kit.color(Kit.RED, 1)
            lg.rectangle("fill", x, ry + 8, 3, rowH - 20, 1.5, 1.5)
        end
        local shown = { i = -1, d = id, r = def.kind == "ammo" and 1 or known }
        local iw = def.kind == "weapon" and 56 or 34
        Icons.draw(shown, x + 10, ry + 4, iw, rowH - 12, 1)
        Kit.text(def.name, 14, x + 20 + iw, ry + 5, Kit.INK, 0.9, "left", listW - iw - 110)
        Kit.text(KIND_NAMES[def.kind] or "", 11, x + 20 + iw, ry + 23, Kit.INK, 0.45)
        if def.kind ~= "ammo" then Kit.text(rarity.name, 11, (x) + (listW - 12), ry + 15, rarity.color, 1, "right") end
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
    local rarity = Items.rarity(inst)
    local boxH = def.h * size + 24
    lg.setColor(rarity.color[1], rarity.color[2], rarity.color[3], 0.08)
    lg.rectangle("fill", dx, top, dw, boxH, 12, 12)
    local iw = min(dw - 24, def.w * size)
    Icons.draw(inst, dx + (dw - iw) / 2, top + 12, iw, def.h * size)
    local ty = top + boxH + 14
    local lines = UI.describe(inst)
    for k = 1, min(#lines, 6) do
        local line = lines[k]
        Kit.text(line[1], line[3] or 13, dx, ty, line[2] or Kit.INK, line[2] and 1 or 0.75, "left", dw)
        ty = ty + (line[3] or 13) + 8
    end
    if def.kind ~= "ammo" then
        Kit.text("Rarity (your plan goes up to " .. ItemConfig.rarities[ItemConfig.rarities.order[known]].name:lower() .. ")", 12, dx, ty + 4, Kit.INK, 0.55)
        ty = ty + 24
        for k = 1, #ItemConfig.rarities.order do
            local tier = ItemConfig.rarities[ItemConfig.rarities.order[k]]
            local bx = dx + (k - 1) * 46
            local open = k <= known
            Kit.color(tier.color, open and (k == r and 1 or 0.4) or 0.1)
            lg.rectangle("fill", bx, ty, 40, 26, 7, 7)
            if k == r then
                Kit.color(Kit.INK, 0.8)
                lg.setLineWidth(2)
                lg.rectangle("line", bx - 2, ty - 2, 44, 30, 8, 8)
                lg.setLineWidth(1)
            end
            Kit.text(RARITY_LETTERS[k], 12, bx, ty + 5, open and { 1, 1, 1 } or Kit.INK, open and 1 or 0.3, "center", 40)
            if open then
                state.buttons[#state.buttons + 1] = { x = bx, y = ty, w = 40, h = 26, run = function() state.craftRarity[id] = k end }
            end
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
        Icons.draw({ i = -1, d = part.id }, dx, ty, 24, 24, 1)
        Kit.text(ItemConfig.all[part.id].name, 13, dx + 32, ty + 1, Kit.INK, 0.8)
        Kit.text(have .. " / " .. part.n, 13, (dx) + (dw), ty + 1, ok and Kit.GREEN or Kit.RED, 1, "right")
        local track = dw - 32
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.08)
        lg.rectangle("fill", dx + 32, ty + 20, track, 3, 1.5, 1.5)
        Kit.color(ok and Kit.GREEN or Kit.RED, 0.9)
        lg.rectangle("fill", dx + 32, ty + 20, track * min(1, have / part.n), 3, 1.5, 1.5)
        ty = ty + 32
    end
    button(state, "craft", dx, ty + 12, dw, 48, ready and ("Craft " .. def.name:lower()) or "Missing materials", function()
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
    -- the record at a glance
    local s = data.stats or {}
    local rate = survival(s)
    local chips = {
        { tostring(s.raids or 0), "raids" },
        { tostring(s.extracts or 0), "extracted", Kit.GREEN },
        { rate and (rate .. "%") or "-", "survival", rate and (rate >= 50 and Kit.GREEN or Kit.RED) or nil },
        { tostring(s.kills or 0), "kills" }
    }
    local chx = M + 300
    for _, chip in ipairs(chips) do
        local vw = Kit.font(20):getWidth(chip[1])
        local lw2 = Kit.font(11):getWidth(chip[2])
        local cw2 = max(vw, lw2) + 28
        if chx + cw2 > W - M - 460 then break end
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.04)
        lg.rectangle("fill", chx, M + 14, cw2, 48, 10, 10)
        Kit.text(chip[1], 20, chx, M + 17, chip[3] or Kit.INK, 1, "center", cw2)
        Kit.text(chip[2], 11, chx, M + 43, Kit.INK, 0.5, "center", cw2)
        chx = chx + cw2 + 8
    end
    button(state, "deploy", W - M - 18 - 200, M + 12, 200, 52, "Deploy", function() ext:send("xhub", { o = "deploy" }) end, { primary = true, size = 21, hint = "Enter" })
    local kit = data.kit or 0
    button(state, "kit", W - M - 18 - 200 - 12 - 200, M + 12, 200, 52, kit > 0 and string.format("Free kit  %d:%02d", floor(kit / 60), kit % 60) or "Free kit",
        function() ext:send("xhub", { o = "kit" }) end, { size = 15, disabled = kit > 0, sublabel = "P9, ammo, bandages" })

    local top = M + 76 + 16
    local bottom = H - M
    local cell = max(28, min(42, floor((bottom - top - 330) / 9), floor(W / 46)))
    -- Loadout
    local lw = cell * 7 + 16 + 32
    UI.panel("Loadout", M, top, lw, bottom - top, #Inventory.all(data.g) .. " items")
    state.ui:loadout(data.g, places, M + 16, top + 44, cell)
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
        workbench(state, ext, cx + 16, contentY, cw - 32, contentH)
    else
        local used = stats(data, cx + 24, contentY + 40, min(cw - 48, 640))
        local tipsY = contentY + 40 + used + 30
        Kit.text("Tips", 13, cx + 24, tipsY, Kit.INK, 0.55)
        local tips = {
            "Shift click moves an item between your loadout and the stash.",
            "R rotates an item while you drag it.",
            "Drop an attachment on a weapon to fit it; a utility on a quick slot to bind it.",
            "Right click a plan in the stash to learn it, any other item to recycle it."
        }
        for k, tip in ipairs(tips) do Kit.text("·  " .. tip, 13, cx + 24, tipsY + k * 22, Kit.INK, 0.7) end
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
    if state.tab == 1 and over(state.craftRegion) then
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
