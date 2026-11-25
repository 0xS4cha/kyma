local GM = require("src.core.index")
local Kit = require("src.ui.kit")
local TextEdit = require("src.ui.textedit")
local Settings = require("src.modules.menu.settings")
local Background = require("src.modules.menu.background")

GM.Menu = {}

GM.Modules:Register("Menu", 60)

local SWITCH_IN = 0.5
local SWITCH_OUT = 0.2
local WIPE = 0.45

local Screens = {
    root = require("src.modules.menu.screens.root"),
    play = require("src.modules.menu.screens.play"),
    multiplayer = require("src.modules.menu.screens.multiplayer"),
    tournament = require("src.modules.menu.screens.tournament"),
    settings = require("src.modules.menu.screens.settings"),
    minimap = require("src.modules.menu.screens.minimap"),
    stats = require("src.modules.menu.screens.stats"),
    howto = require("src.modules.menu.screens.howto"),
    profile = require("src.modules.menu.screens.profile"),
    keybinds = require("src.modules.menu.screens.keybinds"),
    loadout = require("src.modules.menu.screens.loadout"),
    rules = require("src.modules.menu.screens.rules"),
    pause = require("src.modules.menu.screens.pause")
}

function GM.Menu:Initialize()
    self.settings = Settings.load()
    local flags = GM.Flags or {}
    if flags.theme then
        self.settings.theme = flags.theme == "dark" and 2 or 1
    end
    Settings.apply(self.settings, not flags.frames)
    self.background = Background()
    self.screen = "root"
    self.previous = nil
    self.direction = 1
    self.switchTime = -10
    self.openTime = love.timer.getTime()
    self.focus = nil
    self.editing = nil
    self.paused = false
    self.wipe = nil
    self.mouseX, self.mouseY = nil, nil
    self.scrolls = {}
end

--- @return boolean
function GM.Menu:active()
    return GM.State == "menu" or self.paused
end

--- @param screen string?
function GM.Menu:Open(screen)
    GM.State = "menu"
    self.paused = false
    self.openTime = love.timer.getTime()
    if self.settings.background then
        self.background:start()
    end
    self:switch(Screens[screen or ""] and screen or "root", 1)
    self.previous = nil
end

function GM.Menu:Pause()
    if self.paused or GM.State ~= "game" then return end
    self.paused = true
    GM.Session:capture(false)
    GM.Session:hold(true)
    self:switch("pause", 1)
    self.previous = nil
end

function GM.Menu:Resume()
    if not self.paused then return end
    self.paused = false
    self.focus, self.editing = nil, nil
    GM.Session:hold(false)
    if GM.Session.world then
        GM.Session:capture(true)
    end
end

--- @param name string
--- @param direction number?
function GM.Menu:switch(name, direction)
    if not Screens[name] then return end
    self.previous = self.screen ~= name and self.screen or nil
    self.screen = name
    self.direction = direction or 1
    self.switchTime = love.timer.getTime()
    self.focus = nil
    self.editing = nil
    if Screens[name].enter then
        Screens[name].enter(self)
    end
end

function GM.Menu:back()
    local screen = Screens[self.screen]
    if screen.back then screen.back(self) end
end

--- @param p number
--- @param k number
--- @return number
function GM.Menu:stagger(p, k)
    return Kit.easeOutCubic(Kit.clamp(p * 1.6 - (k - 1) * 0.08, 0, 1))
end

--- @param key string
--- @param value any
function GM.Menu:setOption(key, value)
    self.settings[key] = value
    Settings.save(self.settings)
    Settings.apply(self.settings, key == "fullscreen" or key == "vsync")
    if key == "background" then
        if value and GM.State == "menu" then
            self.background:start()
        elseif not value then
            self.background:stop()
        end
    elseif key == "zoom" and GM.Session.active then
        GM.Session.camera.scale = require("src.config.game").camera.scale
    elseif (key == "kitWeapon" or key == "kitMods" or key == "kitGadget") and GM.Session.active then
        GM.Multiplayer:Send("kit", { kit = Settings.kit(self.settings) })
    end
end

function GM.Menu:saveSettings()
    Settings.save(self.settings)
end

--- @param label string
--- @param action function
function GM.Menu:Launch(label, action)
    if self.wipe then return end
    self.wipe = { phase = "cover", start = love.timer.getTime(), label = label, action = action }
    if GM.Audio then GM.Audio:Play("whoosh") end
end

--- @param options table
function GM.Menu:Play(options)
    options.name = self.settings.name
    self:Launch(options.label or "Entering the arena", function()
        self.background:stop()
        self.paused = false
        GM.Session:Start(options)
    end)
end

function GM.Menu:LeaveGame()
    self:Launch("Back to the menu", function()
        GM.Session:Stop()
        self:Open("root")
    end)
end

function GM.Menu:updateWipe()
    local wipe = self.wipe
    local t = (love.timer.getTime() - wipe.start) / WIPE
    if t < 1 then return end
    if wipe.phase == "cover" then
        if not wipe.done then
            wipe.done = true
            wipe.action()
            wipe.heldAt = love.timer.getTime()
            return
        end
        if love.timer.getTime() - wipe.heldAt > 0.25 then
            self.wipe = { phase = "reveal", start = love.timer.getTime(), label = wipe.label }
        end
    else
        self.wipe = nil
    end
end

function GM.Menu:drawWipe()
    local wipe = self.wipe
    local lg = love.graphics
    local W, H = lg.getDimensions()
    local t = Kit.clamp((love.timer.getTime() - wipe.start) / WIPE, 0, 1)
    local e = wipe.phase == "cover" and Kit.easeOutCubic(t) or 1 - Kit.easeOutCubic(t)
    local slant = H * 0.35
    local edge = -slant + (W + slant * 2) * e
    if wipe.phase == "reveal" then
        edge = W + slant - (W + slant * 2) * (1 - e)
    end
    lg.push("all")
    lg.origin()
    local paper = Kit.PAPER
    if wipe.phase == "cover" then
        lg.setColor(paper[1], paper[2], paper[3], 1)
        lg.polygon("fill", -10, -10, edge + slant, -10, edge, H + 10, -10, H + 10)
        Kit.color(Kit.RED, 1)
        lg.polygon("fill", edge + slant, -10, edge + slant + 14, -10, edge + 14, H + 10, edge, H + 10)
    else
        local left = W + 10 - (W + slant * 2 + 20) * (1 - e)
        lg.setColor(paper[1], paper[2], paper[3], 1)
        lg.polygon("fill", left + slant, -10, W + 10, -10, W + 10, H + 10, left, H + 10)
        Kit.color(Kit.RED, 1)
        lg.polygon("fill", left + slant - 14, -10, left + slant, -10, left, H + 10, left - 14, H + 10)
    end
    if wipe.phase == "cover" and t >= 1 then
        local text = wipe.label or ""
        Kit.text(text, 26, 0, H / 2 - 30, Kit.INK, 1, "center", W)
        local start = love.timer.getTime() * 5
        lg.setLineWidth(3)
        Kit.color(Kit.RED, 1)
        lg.arc("line", "open", W / 2, H / 2 + 30, 10, start, start + math.pi * 1.3, 24)
    end
    lg.pop()
end

--- @param name string?
--- @return table { value, target }
function GM.Menu:scrollState(name)
    name = name or self.screen
    local state = self.scrolls[name]
    if not state then
        state = { value = 0, target = 0 }
        self.scrolls[name] = state
    end
    return state
end

--- The part of the screen a scrollable screen scrolls its content in, nil
--- for a screen that doesn't scroll.
--- @param name string?
--- @return table? { top, bottom, bar }
function GM.Menu:viewport(name)
    local screen = Screens[name or self.screen]
    return screen and screen.viewport and screen.viewport(self) or nil
end

--- How far the content of a screen can scroll: the lowest element that
--- scrolls, plus some room, below the bottom of its viewport.
--- @param name string?
--- @param raw table[]? the elements as built, before scrolling
--- @return number
function GM.Menu:scrollMax(name, raw)
    name = name or self.screen
    local view = self:viewport(name)
    if not view then return 0 end
    raw = raw or Screens[name].build(self)
    local bottom = view.top
    for _, element in ipairs(raw) do
        if not element.fixed then bottom = math.max(bottom, element.y + element.h) end
    end
    if view.content then bottom = math.max(bottom, view.content) end
    return math.max(0, bottom + (view.padding or 24) - view.bottom)
end

--- @param name string?
--- @return number how far the content of the screen is scrolled now
function GM.Menu:scrollOffset(name)
    return self.scrolls[name or self.screen] and self.scrolls[name or self.screen].value or 0
end

--- @param amount number
function GM.Menu:scrollBy(amount)
    local state = self:scrollState()
    state.target = Kit.clamp(state.target + amount, 0, self:scrollMax())
end

--- Scrolls just enough to show an element of the current screen.
--- @param id string?
function GM.Menu:reveal(id)
    local view = self:viewport()
    if not view or not id then return end
    local raw = Screens[self.screen].build(self)
    local element
    for _, e in ipairs(raw) do
        if e.id == id then element = e end
    end
    if not element or element.fixed then return end
    local state = self:scrollState()
    local top, bottom = element.y - 12, element.y + element.h + 12
    if top - state.target < view.top then
        state.target = top - view.top
    elseif bottom - state.target > view.bottom then
        state.target = bottom - view.bottom
    end
    local max = self:scrollMax(nil, raw)
    -- close to an end, go all the way so the card edge isn't cut off
    if state.target < 48 then state.target = 0 end
    if state.target > max - 48 then state.target = max end
    state.target = Kit.clamp(state.target, 0, max)
end

--- Elements of the current screen where they are on screen: moved by the
--- scroll, and marked hidden where the viewport cuts them off.
--- @return table[]
function GM.Menu:elements()
    local list = Screens[self.screen].build(self)
    local view = self:viewport()
    if not view then return list end
    local offset = self:scrollOffset()
    for _, element in ipairs(list) do
        if not element.fixed then
            element.y = element.y - offset
            element.view = view
        end
    end
    return list
end

local function find(elements, id)
    for _, element in ipairs(elements) do
        if element.id == id then return element end
    end
end

local function inside(element, x, y)
    local view = element.view
    if view and (y < view.top or y > view.bottom) then return false end
    return x >= element.x and x <= element.x + element.w and y >= element.y and y <= element.y + element.h
end

--- Draws the scrolling part of the screen being drawn: clipped to its
--- viewport, moved by the scroll, with a scroll bar when it doesn't fit.
--- @param draw function
function GM.Menu:scrolled(draw)
    local view = self:viewport(self.drawing)
    if not view then
        draw()
        return
    end
    local lg = love.graphics
    local offset = self:scrollOffset(self.drawing)
    lg.push("all")
    local _, top = lg.transformPoint(0, view.top)
    local _, bottom = lg.transformPoint(0, view.bottom)
    lg.intersectScissor(0, math.floor(top), lg.getWidth(), math.max(1, math.ceil(bottom - top)))
    lg.translate(0, -math.floor(offset + 0.5))
    draw()
    lg.pop()
    local max = self:scrollMax(self.drawing)
    if max <= 0 or not view.bar then return end
    local track = view.bottom - view.top - 16
    local size = math.max(36, track * (view.bottom - view.top) / (view.bottom - view.top + max))
    local y = view.top + 8 + (track - size) * Kit.clamp(offset / max, 0, 1)
    local hot = Kit.ease("scrollbar:" .. tostring(self.drawing), love.timer.getTime() - (self.scrolledAt or -10) < 1, 6)
    lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.06)
    lg.rectangle("fill", view.bar, view.top + 8, 4, track, 2, 2)
    lg.setColor(Kit.INK[1], Kit.INK[2], Kit.INK[3], 0.22 + 0.25 * hot)
    lg.rectangle("fill", view.bar, y, 4, size, 2, 2)
end

function GM.Menu:WheelMoved(_, y)
    if not self:active() or self.wipe or not self:viewport() or y == 0 then return end
    self:scrollBy(-y * 70)
    self.scrolledAt = love.timer.getTime()
end

function GM.Menu:drawVeil()
    local lg = love.graphics
    local W, H = lg.getDimensions()
    local paper = Kit.PAPER
    if self.paused then
        lg.setColor(paper[1], paper[2], paper[3], 0.75)
        lg.rectangle("fill", 0, 0, W, H)
        return
    end
    local strength = self.screen == "root" and 0.9 or 0.96
    local reach = self.screen == "root" and 0.62 or 1
    local mesh = lg.newMesh({
        { 0, 0, 0, 0, paper[1], paper[2], paper[3], strength },
        { W * reach, 0, 0, 0, paper[1], paper[2], paper[3], self.screen == "root" and 0 or 0.82 },
        { W * reach, H, 0, 0, paper[1], paper[2], paper[3], self.screen == "root" and 0 or 0.82 },
        { 0, H, 0, 0, paper[1], paper[2], paper[3], strength }
    }, "fan", "stream")
    lg.setColor(1, 1, 1, 1)
    lg.draw(mesh)
    if reach < 1 then return end
    lg.setColor(paper[1], paper[2], paper[3], 0.82)
    lg.rectangle("fill", W * reach, 0, W - W * reach, H)
end

function GM.Menu:drawScreen(name, p, direction)
    local lg = love.graphics
    lg.push()
    lg.translate(math.floor((1 - Kit.easeOutCubic(p)) * 40 * direction), 0)
    self.drawing = name
    Screens[name].draw(self, Screens[name].build(self), p)
    self.drawing = nil
    lg.pop()
end

function GM.Menu:Draw()
    if self:active() then
        local lg = love.graphics
        lg.push("all")
        if not self.paused then
            if self.settings.background then
                self.background:draw()
            else
                lg.clear(Kit.PAPER)
            end
        end
        self:drawVeil()
        local now = love.timer.getTime()
        local delay = 0
        if self.previous then
            local out = 1 - Kit.clamp((now - self.switchTime) / SWITCH_OUT, 0, 1)
            if out > 0 then
                self:drawScreen(self.previous, out, -self.direction)
            end
            delay = SWITCH_OUT * 0.5
        end
        local p = Kit.clamp((now - self.switchTime - delay) / SWITCH_IN, 0, 1)
        self:drawScreen(self.screen, p, self.direction)
        lg.pop()
    end
    if self.wipe then
        self:drawWipe()
    end
end

function GM.Menu:Think(dt)
    self.consumed = nil
    if self.wipe then
        self:updateWipe()
    end
    local browsing = GM.State == "menu" and self.screen == "multiplayer"
    GM.Multiplayer:Browse(browsing and self.settings.browseSource == 3)
    GM.Multiplayer:BrowseServer(browsing and Screens.multiplayer.browsing(self) or nil)
    if not self.editing then self.edit = nil end
    local typing = self:active() and self.editing ~= nil
    if typing ~= (self.typing == true) then
        self.typing = typing
        love.keyboard.setKeyRepeat(typing)
    end
    if not self:active() then return end
    if self:viewport() then
        local state = self:scrollState()
        state.target = Kit.clamp(state.target, 0, self:scrollMax())
        state.value = Kit.approach(state.value, state.target, 16, dt)
        if math.abs(state.value - state.target) < 0.5 then state.value = state.target end
    end
    local now = love.timer.getTime()
    if self.previous and now - self.switchTime > SWITCH_OUT then
        self.previous = nil
    end
    if GM.State == "menu" and self.settings.background then
        self.background:update(dt)
    end
    local screen = Screens[self.screen]
    if screen.update then
        screen.update(self, dt)
    end
    local mx, my = love.mouse.getPosition()
    if mx ~= self.mouseX or my ~= self.mouseY then
        self.mouseX, self.mouseY = mx, my
        local hovered
        for _, element in ipairs(self:elements()) do
            if element.press and inside(element, mx, my) then
                hovered = element.id
            end
        end
        if hovered and hovered ~= self.focus and GM.Audio then GM.Audio:Play("hover") end
        if hovered then self.focus = hovered end
    end
end

--- The editing state of a text field while it is being edited, following its
--- value; nil for any other field.
--- @param id string
--- @param value string
--- @return table?
function GM.Menu:editState(id, value)
    if self.editing ~= id then return nil end
    if not self.edit or self.edit.id ~= id then
        self.edit = TextEdit.new(value)
        self.edit.id = id
    else
        TextEdit.sync(self.edit, value)
    end
    return self.edit
end

--- @param element table
--- @return table? the edited field's state, kept in step with its value
function GM.Menu:fieldState(element)
    if not element or not element.text or self.editing ~= element.id then return nil end
    return self:editState(element.id, element.text.get())
end

function GM.Menu:MousePressed(x, y, button)
    if not self:active() or self.wipe then return end
    if button == 4 then
        self:back()
        return
    end
    if button ~= 1 then return end
    for _, element in ipairs(self:elements()) do
        if element.press and inside(element, x, y) then
            self.focus = element.id
            self.editing = element.text and element.id or nil
            element.press(self, x, y)
            local state = self:fieldState(element)
            if state then
                local value = element.text.get()
                local shown = element.text.secret and string.rep("*", #value) or value
                local caret = Kit.caretAt("field:" .. element.id, shown, 16, x - element.x - Kit.FIELD_PADDING)
                TextEdit.moveTo(state, caret, love.keyboard.isDown("lshift", "rshift"))
            end
            if GM.Audio then GM.Audio:Play("click") end
            return
        end
    end
    self.editing = nil
end

function GM.Menu:TextInput(text)
    if not self:active() or self.wipe or not self.editing then return end
    local element = find(self:elements(), self.editing)
    local state = self:fieldState(element)
    if state and TextEdit.insert(state, text, element.text) then
        element.text.set(state.text)
        self:saveSettings()
    end
end

function GM.Menu:KeyPressed(key, scancode, isrepeat)
    if self.consumed == key then
        self.consumed = nil
        return
    end
    if not self:active() or self.wipe then return end
    local capture = Screens[self.screen].capture
    if capture and capture(self, key, scancode) then return end
    local elements = self:elements()
    local field = self.editing and find(elements, self.editing)
    local state = self:fieldState(field)
    if state then
        local handled, changed = TextEdit.key(state, key, TextEdit.mods(), field.text)
        if changed then
            field.text.set(state.text)
            self:saveSettings()
        end
        if handled then return end
    end
    if isrepeat then return end
    if key == "escape" then
        if self.editing then
            self.editing = nil
        else
            self:back()
        end
        return
    end
    local screen = Screens[self.screen]
    if screen.keyPressed and screen.keyPressed(self, key) then
        return
    end
    local focused = self.focus and find(elements, self.focus)
    if key == "up" or key == "down" or key == "tab" then
        local nav = {}
        local position
        for _, element in ipairs(elements) do
            if element.press and element.nav ~= false then
                nav[#nav + 1] = element
                if element == focused then position = #nav end
            end
        end
        if #nav == 0 then return end
        local step = key == "up" and -1 or 1
        position = position and (position - 1 + step) % #nav + 1 or 1
        self.focus = nav[position].id
        self.editing = nav[position].text and nav[position].id or nil
        self:reveal(self.focus)
    elseif (key == "left" or key == "right") and focused and focused[key] then
        focused[key](self)
        self:saveSettings()
    elseif (key == "return" or key == "kpenter") and focused and focused.press then
        focused.press(self)
    elseif (key == "pageup" or key == "pagedown") and self:viewport() then
        local view = self:viewport()
        self:scrollBy((key == "pageup" and -1 or 1) * (view.bottom - view.top) * 0.8)
        self.scrolledAt = love.timer.getTime()
    end
end

GM.Menu.Screens = Screens
GM.Menu.find = find

return GM.Menu
