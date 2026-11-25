local Keybinds = {}

local FILE = "kyma_keybinds.txt"

Keybinds.actions = {
    { id = "forward", label = "Move forward", keys = { "w", "up" } },
    { id = "back", label = "Move back", keys = { "s", "down" } },
    { id = "left", label = "Strafe left", keys = { "a" } },
    { id = "right", label = "Strafe right", keys = { "d" } },
    { id = "turnLeft", label = "Turn left", keys = { "left" } },
    { id = "turnRight", label = "Turn right", keys = { "right" } },
    { id = "dash", label = "Dash / slide", keys = { "space", "lshift" } },
    { id = "quiet", label = "Walk quietly", keys = { "c", "lctrl" } },
    { id = "reload", label = "Reload", keys = { "r" } },
    { id = "throw", label = "Throw weapon", keys = { "g" } },
    { id = "gadget", label = "Use gadget", keys = { "q" } },
    { id = "pickup", label = "Pick up / open", keys = { "e" } },
    { id = "ready", label = "Ready up", keys = { "f" } },
    { id = "scoreboard", label = "Scoreboard", keys = { "tab" } },
    { id = "ping", label = "Ping (or middle click)", keys = { "v" } },
    { id = "chat", label = "Chat", keys = { "return" } },
    { id = "help", label = "Controls panel", keys = { "h" } },
    { id = "inventory", label = "Inventory (extraction)", keys = { "tab" } },
    { id = "map", label = "Map (extraction)", keys = { "m" } },
    { id = "weapon1", label = "Primary weapon", keys = { "1" } },
    { id = "weapon2", label = "Secondary weapon", keys = { "2" } },
    { id = "quick1", label = "Quick slot 1", keys = { "3" } },
    { id = "quick2", label = "Quick slot 2", keys = { "4" } },
    { id = "quick3", label = "Quick slot 3", keys = { "5" } },
    { id = "quick4", label = "Quick slot 4", keys = { "6" } }
}

Keybinds.byId = {}
for _, action in ipairs(Keybinds.actions) do Keybinds.byId[action.id] = action end

Keybinds.reserved = { escape = true }

local NAMES = {
    space = "Space", ["return"] = "Enter", kpenter = "Enter", tab = "Tab", backspace = "Backspace",
    lshift = "L Shift", rshift = "R Shift", lctrl = "Ctrl", rctrl = "R Ctrl", lalt = "Alt", ralt = "Alt Gr",
    lgui = "Cmd", rgui = "Cmd", up = "Up", down = "Down", left = "Left", right = "Right", capslock = "Caps"
}

local binds

local function defaults()
    local out = {}
    for _, action in ipairs(Keybinds.actions) do
        out[action.id] = { action.keys[1], action.keys[2] }
    end
    return out
end

function Keybinds.reset()
    binds = defaults()
    Keybinds.save()
end

--- @param text string?
function Keybinds.parse(text)
    binds = defaults()
    for line in (text or ""):gmatch("[^\r\n]+") do
        local id, first, second = line:match("^(%w+)=([^,]*),?(.*)$")
        if id and binds[id] then
            local function valid(key) return key ~= "" and not Keybinds.reserved[key] and key or nil end
            binds[id] = { valid(first), valid(second) }
        end
    end
end

function Keybinds.load()
    local text = love.filesystem and love.filesystem.getInfo(FILE) and love.filesystem.read(FILE) or nil
    Keybinds.parse(text)
end

--- @return string
function Keybinds.serialize()
    local lines = {}
    for _, action in ipairs(Keybinds.actions) do
        local keys = binds[action.id]
        lines[#lines + 1] = action.id .. "=" .. (keys[1] or "") .. "," .. (keys[2] or "")
    end
    return table.concat(lines, "\n") .. "\n"
end

function Keybinds.save()
    if love.filesystem then love.filesystem.write(FILE, Keybinds.serialize()) end
end

local function ensure()
    if not binds then Keybinds.load() end
end

--- @param id string
--- @return table
function Keybinds.keys(id)
    ensure()
    return binds[id] or {}
end

--- @param id string
--- @param slot number
--- @param scancode string?
--- @return string? moved action that lost the key
function Keybinds.set(id, slot, scancode)
    ensure()
    if scancode and Keybinds.reserved[scancode] then return nil end
    local moved
    if scancode then
        for other, keys in pairs(binds) do
            for k = 1, 2 do
                if keys[k] == scancode and not (other == id and k == slot) then
                    keys[k] = nil
                    moved = other
                end
            end
        end
    end
    binds[id][slot] = scancode
    Keybinds.save()
    return moved
end

--- @param id string
--- @param scancode string
--- @return boolean
function Keybinds.is(id, scancode)
    local keys = Keybinds.keys(id)
    return scancode ~= nil and (keys[1] == scancode or keys[2] == scancode)
end

--- @param id string
--- @return boolean
function Keybinds.down(id)
    local keys = Keybinds.keys(id)
    for k = 1, 2 do
        if keys[k] and love.keyboard.isScancodeDown(keys[k]) then return true end
    end
    return false
end

--- @param scancode string?
--- @return string
function Keybinds.name(scancode)
    if not scancode then return "-" end
    if NAMES[scancode] then return NAMES[scancode] end
    local key = love.keyboard and love.keyboard.getKeyFromScancode and love.keyboard.getKeyFromScancode(scancode) or scancode
    if NAMES[key] then return NAMES[key] end
    return #key == 1 and key:upper() or (key:sub(1, 1):upper() .. key:sub(2))
end

--- @param id string
--- @return string
function Keybinds.label(id)
    local keys = Keybinds.keys(id)
    return Keybinds.name(keys[1] or keys[2])
end

return Keybinds
