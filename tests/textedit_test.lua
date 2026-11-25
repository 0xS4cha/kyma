local TextEdit = require("src.ui.textedit")

local NAME = { limit = 20, pattern = "^[%w%s%-_%.']$" }

--- @param text string
--- @param cursor integer?
--- @return table
local function field(text, cursor)
    local state = TextEdit.new(text)
    if cursor then state.cursor = cursor end
    return state
end

local function press(state, key, mods, options)
    return TextEdit.key(state, key, mods or {}, options or NAME)
end

local function expect(state, text, cursor, label)
    assert(state.text == text, ("%s: text %q, expected %q"):format(label, state.text, text))
    assert(state.cursor == cursor, ("%s: caret at %d, expected %d"):format(label, state.cursor, cursor))
end

return {
    {
        name = "arrows move the caret and typing inserts at it",
        run = function()
            local s = field("helo")
            press(s, "left")
            TextEdit.insert(s, "l", NAME)
            expect(s, "hello", 4, "insert in the middle")
            press(s, "home")
            expect(s, "hello", 0, "home")
            press(s, "left")
            expect(s, "hello", 0, "left stops at the start")
            press(s, "end")
            press(s, "right")
            expect(s, "hello", 5, "right stops at the end")
        end
    },
    {
        name = "backspace and delete work around the caret",
        run = function()
            local s = field("abcd", 2)
            press(s, "backspace")
            expect(s, "acd", 1, "backspace")
            press(s, "delete")
            expect(s, "ad", 1, "delete")
            local handled, changed = press(field("", 0), "backspace")
            assert(handled and not changed, "backspace on an empty field is handled without change")
        end
    },
    {
        name = "ctrl or alt jumps and deletes whole words",
        run = function()
            local s = field("play.example.com:6789")
            press(s, "left", { word = true })
            expect(s, "play.example.com:6789", 17, "word left stops after the colon")
            press(s, "left", { word = true })
            expect(s, "play.example.com:6789", 13, "word left again")
            press(s, "right", { word = true })
            expect(s, "play.example.com:6789", 16, "word right")
            local d = field("hello big world")
            press(d, "backspace", { word = true })
            expect(d, "hello big ", 10, "ctrl backspace deletes the last word")
            press(d, "home")
            press(d, "delete", { word = true })
            expect(d, " big ", 0, "ctrl delete deletes the next word")
        end
    },
    {
        name = "cmd moves and deletes to the line ends",
        run = function()
            local s = field("hello world", 5)
            press(s, "right", { line = true })
            expect(s, "hello world", 11, "cmd right")
            press(s, "left", { line = true })
            expect(s, "hello world", 0, "cmd left")
            local d = field("hello world", 6)
            press(d, "backspace", { line = true })
            expect(d, "world", 0, "cmd backspace")
        end
    },
    {
        name = "shift selects, and typing or deleting replaces the selection",
        run = function()
            local s = field("hello world")
            press(s, "left", { shift = true, word = true })
            assert(TextEdit.selected(s) == "world", "shift ctrl left selects the word, got " .. TextEdit.selected(s))
            TextEdit.insert(s, "there", NAME)
            expect(s, "hello there", 11, "typing replaces the selection")
            press(s, "home", { shift = true })
            assert(TextEdit.selected(s) == "hello there", "shift home selects to the start")
            press(s, "backspace")
            expect(s, "", 0, "backspace deletes the selection")
        end
    },
    {
        name = "an arrow without shift collapses the selection to its side",
        run = function()
            local s = field("abcdef", 2)
            press(s, "right", { shift = true })
            press(s, "right", { shift = true })
            assert(TextEdit.selected(s) == "cd", "selected " .. TextEdit.selected(s))
            press(s, "left")
            expect(s, "abcdef", 2, "left goes to the start of the selection")
            assert(TextEdit.range(s) == nil, "the selection is gone")
            press(s, "right", { shift = true })
            press(s, "right")
            expect(s, "abcdef", 3, "right goes to the end of the selection")
        end
    },
    {
        name = "select all with ctrl or cmd A",
        run = function()
            local s = field("everything", 3)
            press(s, "a", { command = true })
            assert(TextEdit.selected(s) == "everything", "all selected")
            local handled = press(field("x"), "a")
            assert(not handled, "a plain a is left to text input")
        end
    },
    {
        name = "inserted text respects the pattern and the limit",
        run = function()
            local s = field("")
            TextEdit.insert(s, "ab!c\nd", { pattern = "^[%w ]$" })
            expect(s, "abc d", 5, "the pattern drops characters and newlines become spaces")
            local l = field("123456789012345678")
            TextEdit.insert(l, "abcdef", NAME)
            expect(l, "123456789012345678ab", 20, "cut at the limit")
            l.anchor, l.cursor = 0, 20
            TextEdit.insert(l, "new", NAME)
            expect(l, "new", 3, "a full field accepts text over its selection")
        end
    },
    {
        name = "the caret counts characters, not bytes",
        run = function()
            local s = field("café")
            expect(s, "café", 4, "four characters")
            press(s, "backspace")
            expect(s, "caf", 3, "backspace removes the whole é")
            TextEdit.insert(s, "é!", {})
            press(s, "left")
            press(s, "left")
            TextEdit.insert(s, "-", {})
            expect(s, "caf-é!", 4, "insert before the é")
        end
    },
    {
        name = "a value changed from outside keeps the caret in range",
        run = function()
            local s = field("long name")
            TextEdit.sync(s, "ab")
            expect(s, "ab", 2, "caret clamped")
        end
    },
    {
        name = "password fields refuse to copy",
        run = function()
            local s = field("secret")
            TextEdit.selectAll(s)
            local handled, changed = press(s, "x", { command = true }, { secret = true })
            assert(handled and not changed, "cut does nothing in a secret field")
            assert(s.text == "secret", "the password is untouched")
        end
    }
}
