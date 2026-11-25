--- The grid inventory screen, shared by the hub and the raid. Drawn in immediate
--- mode: each frame registers the regions it drew (grids, equipment slots, quick
--- slots, drop zones) and the mouse acts on the last frame's regions.
--- Drag an item to move it (R rotates while dragging), drop a mod on a weapon to
--- attach it, a utility on a quick slot to bind it, right click for more.
local Kit = require("src.ui.kit")
local Icons = require("src.modules.extraction.icons")
local Items = require("src.game.extraction.items")
local Inventory = require("src.game.extraction.inventory")
local ItemConfig = require("src.config.items")
local Config = require("src.config.extraction")
local Keys = require("src.input.keybinds")

local UI = {}
UI.__index = UI

local lg = love.graphics
local floor, max, min = math.floor, math.max, math.min

local SLOT_LABEL = { primary = "Primary", secondary = "Secondary", helmet = "Helmet", vest = "Vest", backpack = "Backpack" }

--- @param send function(op) sends an inventory request
--- @return table
function UI.new(send)
    return setmetatable({ send = send, regions = {}, next = {}, drag = nil, menu = nil, scroll = {} }, UI)
end

--- Starts a frame of drawing.
--- @param places table places of the local copy (Inventory.places)
function UI:begin(places)
    self.places = places
    self.next = {}
end

function UI:finish()
    self.regions = self.next
end

local function inside(r, x, y)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

--- @param ref string
--- @param place table grid place
--- @param x number
--- @param y number
--- @param cell number
--- @param title string?
--- @param visibleRows number? rows shown (scrolls past it)
function UI:grid(ref, place, x, y, cell, title, visibleRows)
    local rows = min(place.h, visibleRows or place.h)
    local scroll = min(self.scroll[ref] or 0, place.h - rows)
    self.scroll[ref] = max(0, scroll)
    scroll = self.scroll[ref]
    local w, h = place.w * cell, rows * cell
    if title then Kit.text(title, 13, x, y - 20, Kit.INK, 0.6) end
    lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.05)
    lg.rectangle("fill", x, y, w, h, 6, 6)
    lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.09)
    for cx = 1, place.w - 1 do lg.line(x + cx * cell, y, x + cx * cell, y + h) end
    for cy = 1, rows - 1 do lg.line(x, y + cy * cell, x + w, y + cy * cell) end
    lg.setScissor(x, y, w, h)
    for _, inst in ipairs(place.list) do
        if not (self.drag and self.drag.inst.i == inst.i) then
            local iw, ih = Items.size(inst)
            local ix, iy = x + inst.x * cell, y + (inst.y - scroll) * cell
            if iy + ih * cell > y and iy < y + h then
                Icons.draw(inst, ix + 1, iy + 1, iw * cell - 2, ih * cell - 2)
            end
        end
    end
    lg.setScissor()
    if rows < place.h then
        local bar = h * rows / place.h
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.25)
        lg.rectangle("fill", x + w + 4, y + (h - bar) * scroll / (place.h - rows), 4, bar, 2, 2)
    end
    self.next[#self.next + 1] = { kind = "grid", ref = ref, place = place, x = x, y = y, w = w, h = h, cell = cell, scroll = scroll }
    if self.drag then self:preview(ref, place, x, y, cell, scroll, w, h) end
    return w, h
end

--- Where the dragged item would land, green if it fits.
function UI:preview(ref, place, x, y, cell, scroll, w, h)
    local mx, my = love.mouse.getPosition()
    if not inside({ x = x, y = y, w = w, h = h }, mx, my) then return end
    local drag = self.drag
    local def = Items.def(drag.inst)
    local iw, ih = def.w, def.h
    if drag.rot == 1 then iw, ih = ih, iw end
    local cx = floor((mx - x) / cell - iw / 2 + 0.5)
    local cy = floor((my - y) / cell - ih / 2 + 0.5) + scroll
    local ignore
    for _, inst in ipairs(place.list) do
        if inst.i == drag.inst.i then ignore = inst end
    end
    local ok = Inventory.fits(place.list, place.w, place.h, iw, ih, cx, cy, ignore)
    local target = self:itemAt(place, cx + floor(iw / 2), cy + floor(ih / 2))
    if target and target.d == drag.inst.d and def.stack > 1 then ok = true end
    Kit.color(ok and Kit.GREEN or Kit.RED, 0.28)
    lg.rectangle("fill", x + cx * cell, y + (cy - scroll) * cell, iw * cell, ih * cell, 5, 5)
end

--- @param place table
--- @param cx number
--- @param cy number
--- @return table?
function UI:itemAt(place, cx, cy)
    for _, inst in ipairs(place.list) do
        local iw, ih = Items.size(inst)
        if cx >= inst.x and cx < inst.x + iw and cy >= inst.y and cy < inst.y + ih then return inst end
    end
end

--- An equipment slot.
function UI:slot(ref, inst, x, y, w, h, label)
    local hot = self.drag and Items.def(self.drag.inst) and self.places[ref] and self.places[ref].accept(self.drag.inst)
    lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], hot and 0.12 or 0.05)
    lg.rectangle("fill", x, y, w, h, 8, 8)
    if hot then
        Kit.color(Kit.GREEN, 0.7)
        lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 8, 8)
    end
    if inst and not (self.drag and self.drag.inst.i == inst.i) then
        local def = Items.def(inst)
        local iw, ih = def.w, def.h
        local scale = min(w / iw, h / ih)
        local dw, dh = iw * scale, ih * scale
        Icons.draw(inst, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh)
    else
        Kit.text(label or SLOT_LABEL[ref] or ref, 12, x, y + h / 2 - 8, Kit.INK, 0.35, "center", w)
    end
    self.next[#self.next + 1] = { kind = "slot", ref = ref, inst = inst, x = x, y = y, w = w, h = h }
end

--- A titled card behind a group of panels.
function UI.panel(title, x, y, w, h, subtitle)
    Kit.card(x, y, w, h, 0.97, 14)
    if title then
        Kit.text(title, 15, x + 16, y + 12, Kit.INK, 0.95)
        if subtitle then Kit.text(subtitle, 12, (x + w - 16), y + 14, Kit.INK, 0.5, "right") end
    end
end

--- The whole loadout: equipment around a portrait, quick slots, pockets and bag.
--- @return number width, number height
function UI:loadout(gear, places, x, y, cell)
    local C = cell
    local pad = 8
    self:slot("helmet", gear.helmet, x, y, C * 2, C * 2)
    self:slot("backpack", gear.backpack, x, y + C * 2 + pad, C * 2, C * 2)
    local px, pw, ph = x + C * 2 + pad, C * 3, C * 4 + pad
    lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.05)
    lg.rectangle("fill", px, y, pw, ph, 10, 10)
    local look = gear.primary and ItemConfig.all[gear.primary.d] and ItemConfig.all[gear.primary.d].look or nil
    lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.06)
    lg.circle("fill", px + pw / 2, y + ph / 2, pw * 0.42)
    local Character = require("src.modules.session.character")
    local Renderer = require("src.modules.session.renderer")
    lg.push()
    lg.translate(px + pw / 2, y + ph / 2)
    lg.scale(C / 14, C / 14)
    Character.draw({ slot = 0, x = 0, y = 0, angle = -math.pi / 2, vx = 0, vy = 0, weapon = look }, Renderer.selfPalette())
    lg.pop()
    self:slot("vest", gear.vest, px + pw + pad, y, C * 2, C * 3)
    local wy = y + ph + pad + 4
    local ww = C * 7 + pad * 2
    self:slot("primary", gear.primary, x, wy, ww, C * 2, "Primary  ·  " .. Keys.label("weapon1"))
    self:slot("secondary", gear.secondary, x, wy + C * 2 + pad, ww, C * 2, "Secondary  ·  " .. Keys.label("weapon2"))
    local qy = wy + C * 4 + pad * 2 + 22
    Kit.text("Quick slots", 12, x, qy - 18, Kit.INK, 0.55)
    self:quick(gear, x, qy, C)
    local py = qy + C + 30
    self:grid("pk", places.pk, x, py, C, "Pockets")
    local height = py + C - y
    if places.bp then
        local by = py + C + 30
        self:grid("bp", places.bp, x, by, C, Items.name(gear.backpack))
        height = by + places.bp.h * C - y
    end
    return ww, height
end

--- Height of what UI:loadout draws.
--- @return number
function UI.loadoutHeight(places, C)
    local pad = 8
    local height = C * 4 + pad + 4 + pad + C * 4 + pad * 2 + 22 + C + 30 + C
    if places.bp then height = height + 30 + places.bp.h * C end
    return height
end

--- The quick slots bar.
function UI:quick(gear, x, y, size)
    for k = 1, Config.quickSlots do
        local bx = x + (k - 1) * (size + 6)
        lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.06)
        lg.rectangle("fill", bx, y, size, size, 8, 8)
        local uid = gear.quick[k]
        local loc = uid and uid ~= 0 and Inventory.locate(self.places, uid)
        if loc then
            Icons.draw(loc.inst, bx, y, size, size)
        end
        Kit.keycap(Keys.label("quick" .. k), bx + 3, y + size - 20, 0.8, 11)
        self.next[#self.next + 1] = { kind = "quick", k = k, x = bx, y = y, w = size, h = size, inst = loc and loc.inst }
    end
end

--- A zone that accepts drops (recycle, ground...).
function UI:zone(kind, x, y, w, h, label)
    local mx, my = love.mouse.getPosition()
    local hot = self.drag and inside({ x = x, y = y, w = w, h = h }, mx, my)
    if self.drag then
        Kit.color(kind == "recycle" and Kit.GREEN or Kit.RED, hot and 0.3 or 0.1)
        lg.rectangle("fill", x, y, w, h, 10, 10)
        if label then Kit.text(label, 16, x, y + h / 2 - 10, Kit.INK, 0.8, "center", w) end
    end
    self.next[#self.next + 1] = { kind = kind, x = x, y = y, w = w, h = h }
end

--- @return table? region, table? inst under the mouse
function UI:hit(mx, my)
    for k = #self.regions, 1, -1 do
        local r = self.regions[k]
        if inside(r, mx, my) then
            if r.kind == "grid" then
                local cx, cy = floor((mx - r.x) / r.cell), floor((my - r.y) / r.cell) + r.scroll
                return r, self:itemAt(r.place, cx, cy), cx, cy
            end
            return r, r.inst
        end
    end
end

--- Where the dragged item lands in a grid region, from the mouse.
local function landing(r, drag, mx, my)
    local def = Items.def(drag.inst)
    local iw, ih = def.w, def.h
    if drag.rot == 1 then iw, ih = ih, iw end
    return floor((mx - r.x) / r.cell - iw / 2 + 0.5), floor((my - r.y) / r.cell - ih / 2 + 0.5) + r.scroll
end

--- @return boolean consumed
function UI:mousepressed(mx, my, button)
    if self.menu then
        local menu = self.menu
        self.menu = nil
        for k, entry in ipairs(menu.entries) do
            local ey = menu.y + 6 + (k - 1) * 28
            if mx >= menu.x and mx < menu.x + menu.w and my >= ey and my < ey + 28 then
                entry.run()
                return true
            end
        end
        return true
    end
    local r, inst = self:hit(mx, my)
    if not r then return false end
    if button == 1 and inst and r.kind ~= "quick" then
        if love.keyboard.isDown("lshift", "rshift") and self.quickMove then
            self.quickMove(inst, r.ref)
            return true
        end
        self.drag = { inst = inst, from = r.ref, rot = inst.o == 1 and 1 or 0 }
        return true
    elseif button == 2 and inst then
        if r.kind == "quick" then
            self.send({ o = "quick", k = r.k, i = 0 })
            return true
        end
        self:openMenu(inst, r.ref, mx, my)
        return true
    end
    return r ~= nil
end

function UI:mousereleased(mx, my, button)
    local drag = self.drag
    if button ~= 1 or not drag then return false end
    self.drag = nil
    local r, target = self:hit(mx, my)
    local inst = drag.inst
    local def = Items.def(inst)
    if not r then
        if self.onOutside then self.onOutside(inst) end
        return true
    end
    if r.kind == "grid" then
        if target and target.i ~= inst.i and def.kind == "mod" and Items.def(target).kind == "weapon" then
            self.send({ o = "attach", i = inst.i, w = target.i })
            return true
        end
        local cx, cy = landing(r, drag, mx, my)
        if target and target.i ~= inst.i and target.d == inst.d and def.stack > 1 then cx, cy = target.x, target.y end
        self.send({ o = "move", i = inst.i, to = r.ref, x = cx, y = cy, r = drag.rot })
    elseif r.kind == "slot" then
        if def.kind == "mod" and r.inst and Items.def(r.inst).kind == "weapon" then
            self.send({ o = "attach", i = inst.i, w = r.inst.i })
        else
            self.send({ o = "move", i = inst.i, to = r.ref })
        end
    elseif r.kind == "quick" then
        if def.kind == "utility" then self.send({ o = "quick", k = r.k, i = inst.i }) end
    elseif r.kind == "recycle" then
        self.send({ o = "recycle", i = inst.i })
    elseif r.kind == "ground" then
        self.send({ o = "drop", i = inst.i })
    end
    return true
end

function UI:keypressed(key, scancode)
    if self.drag and (key == "r" or (scancode and Keys.is("reload", scancode))) then
        local def = Items.def(self.drag.inst)
        if def.w ~= def.h then self.drag.rot = 1 - self.drag.rot end
        return true
    end
    if key == "escape" and (self.drag or self.menu) then
        self.drag, self.menu = nil, nil
        return true
    end
    return false
end

function UI:wheelmoved(y)
    local mx, my = love.mouse.getPosition()
    for _, r in ipairs(self.regions) do
        if r.kind == "grid" and inside(r, mx, my) then
            self.scroll[r.ref] = max(0, (self.scroll[r.ref] or 0) - y * 2)
            return true
        end
    end
    return false
end

--- Right click menu entries for an item.
function UI:openMenu(inst, ref, mx, my)
    local def = Items.def(inst)
    local entries = {}
    local function add(label, run) entries[#entries + 1] = { label = label, run = run } end
    if def.kind == "utility" then
        for k = 1, Config.quickSlots do
            add("Bind to " .. Keys.label("quick" .. k), function() self.send({ o = "quick", k = k, i = inst.i }) end)
        end
    end
    local equip = def.kind == "weapon" and { "primary", "secondary" } or (def.kind == "armor" and { def.slot }) or (def.kind == "backpack" and { "backpack" }) or {}
    for _, slot in ipairs(equip) do
        if ref ~= slot then add("Equip as " .. SLOT_LABEL[slot]:lower(), function() self.send({ o = "move", i = inst.i, to = slot }) end) end
    end
    if def.kind == "weapon" then
        for _, slot in ipairs(ItemConfig.slots.order) do
            local attached = inst.m and inst.m[slot]
            if attached then
                add("Detach " .. Items.name(attached), function()
                    if self.quickMove then self.quickMove(attached, "detach") end
                end)
            end
        end
    end
    for _, extra in ipairs(self.extraMenu and self.extraMenu(inst, ref) or {}) do add(extra[1], extra[2]) end
    if #entries == 0 then return end
    local w = 210
    local W, H = lg.getDimensions()
    self.menu = { x = min(mx, W - w - 8), y = min(my, H - #entries * 28 - 16), w = w, entries = entries }
end

local function fmt(v)
    if v >= 100 then return tostring(floor(v + 0.5)) end
    return string.format("%.1f", v)
end

--- The lines of a tooltip.
--- @param inst table
--- @return table[] { text, color?, size? }
function UI.describe(inst)
    local def = Items.def(inst)
    local rarity = Items.rarity(inst)
    local lines = { { def.name, rarity.color, 18 } }
    local flat = def.kind == "ammo" or def.kind == "material" or def.kind == "valuable"
    local kind = def.class or (def.kind == "mod" and ItemConfig.slots[def.slot] .. " attachment") or def.kind:sub(1, 1):upper() .. def.kind:sub(2)
    lines[#lines + 1] = { (flat and "" or rarity.name .. " ") .. kind .. "   " .. def.w .. "x" .. def.h, Kit.INK, 12 }
    if def.kind == "weapon" then
        local s = Items.weaponStats(inst)
        lines[#lines + 1] = { string.format("Damage %s%s   Fire rate %d/min", fmt(s.damage), s.pellets > 1 and (" x" .. s.pellets) or "", floor(3600 / s.fireTicks)) }
        lines[#lines + 1] = { string.format("Magazine %d   Reload %.1f s   Range %d", s.magazine, s.reloadTicks / 60, floor(s.range)) }
        lines[#lines + 1] = { string.format("Spread %.3f   %s rounds   %d/%d attachments", s.spread, ItemConfig.calibers[s.ammo].name:lower(), (function()
            local n = 0
            for _ in pairs(inst.m or {}) do n = n + 1 end
            return n
        end)(), rarity.slots) }
        local traits = {}
        if s.silent then traits[#traits + 1] = "silent" end
        if s.hidden then traits[#traits + 1] = "no tracers" end
        if s.bounce then traits[#traits + 1] = "ricochet x" .. s.bounce end
        if s.pierce then traits[#traits + 1] = "pierce " .. s.pierce end
        if s.blast then traits[#traits + 1] = "explosive" end
        if s.burn then traits[#traits + 1] = "fire" end
        if s.poison then traits[#traits + 1] = "poison" end
        if s.chill then traits[#traits + 1] = "frost" end
        if s.chain then traits[#traits + 1] = "chain " .. floor(s.chain) .. "%" end
        if s.leech then traits[#traits + 1] = "leech " .. floor(s.leech * 100) .. "%" end
        if s.light then traits[#traits + 1] = "light" end
        if s.thermal then traits[#traits + 1] = "thermal" end
        if s.mark then traits[#traits + 1] = "marks" end
        if s.knock then traits[#traits + 1] = "knockback" end
        if s.execute then traits[#traits + 1] = "execution" end
        if s.exposed then traits[#traits + 1] = "laser visible" end
        if #traits > 0 then lines[#lines + 1] = { table.concat(traits, ", "), Kit.RED } end
        for _, slot in ipairs(ItemConfig.slots.order) do
            local attached = inst.m and inst.m[slot]
            if attached then lines[#lines + 1] = { "+ " .. Items.name(attached), Items.rarity(attached).color } end
        end
        lines[#lines + 1] = { "Slots: " .. table.concat((function()
            local names = {}
            for _, slot in ipairs(def.slots) do names[#names + 1] = ItemConfig.slots[slot]:lower() end
            return names
        end)(), ", "), Kit.INK, 12 }
    elseif def.kind == "mod" then
        lines[#lines + 1] = { def.text }
        lines[#lines + 1] = { "Strength x" .. string.format("%.2f", Items.strength(inst)) .. " (rarity)", Kit.INK, 12 }
    elseif def.kind == "utility" then
        lines[#lines + 1] = { def.text }
        if def.heal then lines[#lines + 1] = { "Heals " .. floor(def.heal * rarity.power + 0.5), Kit.GREEN } end
    elseif def.kind == "armor" then
        local s = Items.armorStats(inst)
        lines[#lines + 1] = { string.format("Absorbs %d%%   Durability %d/%d", floor(s.reduce * 100 * (def.slot == "helmet" and 0.6 or 1)), floor(inst.u or s.durability), s.durability) }
        if def.immune then lines[#lines + 1] = { "Immune to " .. def.immune, Kit.GREEN } end
        if def.sight then lines[#lines + 1] = { "See farther in the dark", Kit.GREEN } end
        if s.haste and s.haste < 1 then lines[#lines + 1] = { string.format("Slows you %d%%", floor((1 - s.haste) * 100 + 0.5)), Kit.RED } end
    elseif def.kind == "backpack" then
        lines[#lines + 1] = { "Holds " .. def.grid[1] .. "x" .. def.grid[2] .. " (" .. #(inst.c or {}) .. " items inside)" }
    elseif def.kind == "blueprint" then
        local target = ItemConfig.all[def.target]
        lines[#lines + 1] = { "Learn at the workbench to craft " .. target.name .. " up to " .. rarity.name:lower() }
        local parts = {}
        for _, part in ipairs(Items.recipe(def.target, inst.r)) do parts[#parts + 1] = part.n .. " " .. ItemConfig.all[part.id].name:lower() end
        lines[#lines + 1] = { table.concat(parts, ", "), Kit.INK, 12 }
    elseif def.kind == "material" then
        lines[#lines + 1] = { "Crafting material" }
    end
    local parts = Items.salvage(inst)
    if parts then
        local names = {}
        for _, part in ipairs(parts) do names[#names + 1] = part.n .. " " .. ItemConfig.all[part.id].name:lower() end
        lines[#lines + 1] = { "Recycles into " .. table.concat(names, ", "), Kit.GREEN, 12 }
    end
    return lines
end

--- Draws the dragged item, the tooltip and the context menu: call last.
function UI:overlay()
    local mx, my = love.mouse.getPosition()
    if self.drag then
        local def = Items.def(self.drag.inst)
        local cell = 44
        for _, r in ipairs(self.regions) do
            if r.cell then cell = r.cell break end
        end
        local iw, ih = def.w, def.h
        if self.drag.rot == 1 then iw, ih = ih, iw end
        local ghost = setmetatable({ o = self.drag.rot == 1 and 1 or nil }, { __index = self.drag.inst })
        Icons.draw(ghost, mx - iw * cell / 2, my - ih * cell / 2, iw * cell, ih * cell, 0.85)
        return
    end
    if self.menu then
        local menu = self.menu
        Kit.card(menu.x, menu.y, menu.w, #menu.entries * 28 + 12, 1, 10)
        for k, entry in ipairs(menu.entries) do
            local ey = menu.y + 6 + (k - 1) * 28
            if mx >= menu.x and mx < menu.x + menu.w and my >= ey and my < ey + 28 then
                Kit.color(Kit.RED, 0.12)
                lg.rectangle("fill", menu.x + 4, ey, menu.w - 8, 28, 6, 6)
            end
            Kit.text(entry.label, 14, menu.x + 14, ey + 6, Kit.INK, 0.9)
        end
        return
    end
    local _, inst = self:hit(mx, my)
    if inst then UI.tooltip(inst, mx + 18, my + 12) end
end

--- @param inst table
function UI.tooltip(inst, x, y)
    local lines = UI.describe(inst)
    local w = 200
    local h = 16
    for _, line in ipairs(lines) do
        h = h + (line[3] or 14) + 8
        w = max(w, Kit.font(line[3] or 14):getWidth(line[1]) + 36)
    end
    local W, H = lg.getDimensions()
    x, y = min(x, W - w - 8), min(y, H - h - 8)
    Kit.card(x, y, w, h, 0.97, 10)
    local c = Items.rarity(inst).color
    lg.setColor(c[1], c[2], c[3], 1)
    lg.rectangle("fill", x, y + 10, 4, h - 20, 2, 2)
    local cy = y + 10
    for _, line in ipairs(lines) do
        Kit.text(line[1], line[3] or 14, x + 16, cy, line[2] or Kit.INK, line[2] and 1 or 0.75, "left", w - 28)
        cy = cy + (line[3] or 14) + 8
    end
end

return UI
