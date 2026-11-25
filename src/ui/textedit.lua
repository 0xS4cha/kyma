local Text = require("src.core.text")

--- Editing state of a one-line text field: the text, a caret and an optional
--- selection between the caret and an anchor. Positions count characters
--- (not bytes): 0 is before the first one, #chars after the last one.
local TextEdit = {}

--- @param s string
--- @return string[]
local function chars(s)
    local list = Text.chars(s)
    if list then return list end
    list = {}
    for i = 1, #s do list[i] = s:sub(i, i) end
    return list
end

--- @param text string?
--- @return table { text, cursor, anchor, moved }
function TextEdit.new(text)
    text = text or ""
    return { text = text, cursor = #chars(text), anchor = nil, moved = 0 }
end

--- Follows a text changed from outside the field, keeping the caret in range.
--- @param state table
--- @param text string
function TextEdit.sync(state, text)
    if state.text == text then return end
    local length = #chars(text)
    state.text = text
    state.cursor = math.min(state.cursor, length)
    if state.anchor then state.anchor = math.min(state.anchor, length) end
    if state.anchor == state.cursor then state.anchor = nil end
end

--- @param state table
--- @return integer? first, integer? last the selected characters are first + 1 .. last
function TextEdit.range(state)
    local a, b = state.anchor, state.cursor
    if not a or a == b then return nil end
    if a > b then a, b = b, a end
    return a, b
end

--- @param state table
--- @return string
function TextEdit.selected(state)
    local a, b = TextEdit.range(state)
    if not a then return "" end
    return table.concat(chars(state.text), "", a + 1, b)
end

function TextEdit.selectAll(state)
    state.anchor, state.cursor = 0, #chars(state.text)
    if state.cursor == 0 then state.anchor = nil end
end

--- @param state table
--- @param position integer
--- @param extend boolean? keep or start a selection (shift held)
function TextEdit.moveTo(state, position, extend)
    local length = #chars(state.text)
    position = math.max(0, math.min(length, position))
    if extend then
        state.anchor = state.anchor or state.cursor
    else
        state.anchor = nil
    end
    state.cursor = position
    if state.anchor == state.cursor then state.anchor = nil end
    state.moved = love and love.timer and love.timer.getTime() or 0
end

--- @param c string?
--- @return boolean
local function separator(c)
    return c ~= nil and (c:match("^%s$") ~= nil or c:match("^%p$") ~= nil)
end

--- The start of the word before the position, like Ctrl+Left in a text editor.
--- @param list string[]
--- @param i integer
--- @return integer
local function wordLeft(list, i)
    while i > 0 and separator(list[i]) do i = i - 1 end
    while i > 0 and not separator(list[i]) do i = i - 1 end
    return i
end

--- The end of the word after the position, like Ctrl+Right in a text editor.
--- @param list string[]
--- @param i integer
--- @return integer
local function wordRight(list, i)
    while i < #list and separator(list[i + 1]) do i = i + 1 end
    while i < #list and not separator(list[i + 1]) do i = i + 1 end
    return i
end

--- Replaces the characters first + 1 .. last with a string.
--- @param state table
--- @param first integer
--- @param last integer
--- @param str string
local function replace(state, first, last, str)
    local list = chars(state.text)
    state.text = table.concat(list, "", 1, first) .. str .. table.concat(list, "", last + 1, #list)
    state.cursor = first + #chars(str)
    state.anchor = nil
    state.moved = love and love.timer and love.timer.getTime() or 0
end

--- @param state table
--- @return boolean changed
local function deleteSelection(state)
    local a, b = TextEdit.range(state)
    if not a then return false end
    replace(state, a, b, "")
    return true
end

--- Types or pastes text at the caret, over the selection if there is one.
--- Characters that don't match the pattern are dropped, and the text is cut
--- so the field never holds more than limit characters.
--- @param state table
--- @param str string
--- @param options table? { limit, pattern }
--- @return boolean changed
function TextEdit.insert(state, str, options)
    options = options or {}
    local kept = {}
    for _, c in ipairs(chars(str)) do
        if c:match("^%c$") then c = " " end
        if not options.pattern or c:match(options.pattern) then kept[#kept + 1] = c end
    end
    local a, b = TextEdit.range(state)
    a, b = a or state.cursor, b or state.cursor
    if options.limit then
        local room = options.limit - (#chars(state.text) - (b - a))
        for k = #kept, math.max(room, 0) + 1, -1 do kept[k] = nil end
    end
    if #kept == 0 and a == b then return false end
    replace(state, a, b, table.concat(kept))
    return true
end

--- Which modifier keys are held, read from the keyboard.
--- @return table { shift, word, line, command }
function TextEdit.mods()
    local down = love.keyboard.isDown
    local ctrl, alt, gui = down("lctrl", "rctrl"), down("lalt", "ralt"), down("lgui", "rgui")
    return {
        shift = down("lshift", "rshift"),
        word = ctrl or alt,
        line = gui,
        command = ctrl or gui
    }
end

--- Handles a key for the field: moving, selecting, deleting and the clipboard.
--- @param state table
--- @param key string
--- @param mods table? from TextEdit.mods
--- @param options table? { limit, pattern, secret = no copy or cut }
--- @return boolean handled, boolean changed
function TextEdit.key(state, key, mods, options)
    mods = mods or {}
    options = options or {}
    local list = chars(state.text)
    local a = TextEdit.range(state)
    if key == "left" or key == "right" then
        local target
        if mods.line then
            target = key == "left" and 0 or #list
        elseif mods.word then
            target = key == "left" and wordLeft(list, state.cursor) or wordRight(list, state.cursor)
        elseif a and not mods.shift then
            local first, last = TextEdit.range(state)
            target = key == "left" and first or last
        else
            target = state.cursor + (key == "left" and -1 or 1)
        end
        TextEdit.moveTo(state, target, mods.shift)
        return true, false
    elseif key == "home" or key == "end" then
        TextEdit.moveTo(state, key == "home" and 0 or #list, mods.shift)
        return true, false
    elseif key == "backspace" or key == "delete" then
        if deleteSelection(state) then return true, true end
        local from, to = state.cursor, state.cursor
        if key == "backspace" then
            from = mods.line and 0 or mods.word and wordLeft(list, state.cursor) or math.max(0, state.cursor - 1)
        else
            to = mods.line and #list or mods.word and wordRight(list, state.cursor) or math.min(#list, state.cursor + 1)
        end
        if from == to then return true, false end
        replace(state, from, to, "")
        return true, true
    elseif mods.command and key == "a" then
        TextEdit.selectAll(state)
        return true, false
    elseif mods.command and (key == "c" or key == "x") then
        if options.secret or not a then return true, false end
        love.system.setClipboardText(TextEdit.selected(state))
        if key == "x" then return true, deleteSelection(state) end
        return true, false
    elseif mods.command and key == "v" then
        local ok, pasted = pcall(love.system.getClipboardText)
        if not ok or type(pasted) ~= "string" then return true, false end
        return true, TextEdit.insert(state, pasted, options)
    end
    return false, false
end

return TextEdit
