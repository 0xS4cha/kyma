--- Images of the extraction mode, from Kenney's CC0 packs (assets/kenney): ground
--- tiles, characters, monsters and item icons. Loaded on first use and cached.
local Assets = {}

local lg = love.graphics
local cache = {}

local ROOT = "assets/kenney/"

--- @param path string
--- @param wrap boolean? repeat when drawn bigger than the image (ground textures)
--- @return love.Image?
local function image(path, wrap)
    if cache[path] == nil then
        local ok, img = pcall(lg.newImage, ROOT .. path, { mipmaps = true })
        if ok then
            img:setFilter("linear", "linear")
            img:setMipmapFilter("linear")
            if wrap then img:setWrap("repeat", "repeat") end
            cache[path] = img
        else
            cache[path] = false
        end
    end
    return cache[path] or nil
end

Assets.image = image

--- @param id number tile number of the Top-down Shooter pack
--- @param wrap boolean?
--- @return love.Image?
function Assets.tile(id, wrap)
    return image(string.format("tiles/tile_%02d.png", id), wrap)
end

-- Ground textures per biome and floor kind.
Assets.GROUND = {
    forest = 1, field = 5, lake = 2, town = 7, industrial = 9, military = 5, citadel = 10,
    road = 86, wood = 43, planks = 97, concrete = 8, tiles = 13, water = 19
}

local quads = {}

--- Fills a rectangle with a repeating texture.
--- @param id number tile
--- @param scale number texture scale (world units per texture pixel)
function Assets.fill(id, x, y, w, h, scale)
    local img = Assets.tile(id, true)
    if not img then return false end
    scale = scale or 1
    local quad = quads[id]
    if not quad then
        quad = lg.newQuad(0, 0, 1, 1, img:getWidth(), img:getHeight())
        quads[id] = quad
    end
    quad:setViewport(x / scale, y / scale, w / scale, h / scale, img:getWidth(), img:getHeight())
    lg.draw(img, quad, x, y, 0, scale, scale)
    return true
end

--- Draws a tile stretched over a rectangle.
function Assets.stretch(id, x, y, w, h, angle)
    local img = Assets.tile(id)
    if not img then return false end
    if angle and angle ~= 0 then
        lg.draw(img, x + w / 2, y + h / 2, angle, h / img:getWidth(), w / img:getHeight(), img:getWidth() / 2, img:getHeight() / 2)
    else
        lg.draw(img, x, y, 0, w / img:getWidth(), h / img:getHeight())
    end
    return true
end

--- Draws a sprite centred on a point, fitting a size.
function Assets.centered(img, x, y, size, angle)
    if not img then return false end
    local s = size / math.max(img:getWidth(), img:getHeight())
    lg.draw(img, x, y, angle or 0, s, s, img:getWidth() / 2, img:getHeight() / 2)
    return true
end

Assets.CHARACTERS = { "survivor1", "soldier1", "manBlue", "manBrown", "womanGreen", "hitman1", "manOld" }

local POSE = { pistol = "gun", silencer = "silencer", rifle = "machine", lmg = "machine", sniper = "machine", shotgun = "machine" }

--- @param set string character set (survivor1, zoimbie1, robot1...)
--- @param look string? weapon model in hand
--- @param reloading boolean?
--- @return love.Image?
function Assets.character(set, look, reloading)
    local pose = reloading and "reload" or (look and POSE[look]) or "hold"
    return image("characters/" .. set .. "_" .. pose .. ".png")
end

--- The character set of a player slot (the local player can pick by slot too).
--- @param slot number
--- @return string
function Assets.setOf(slot)
    return Assets.CHARACTERS[(slot - 1) % #Assets.CHARACTERS + 1]
end

--- Draws a top-down character facing `angle`, the body `size` units wide.
function Assets.drawCharacter(set, look, x, y, angle, size, reloading, tint, alpha)
    local img = Assets.character(set, look, reloading)
    if not img then return false end
    local s = size / img:getHeight()
    lg.setColor(0, 0, 0, 0.18 * (alpha or 1))
    lg.ellipse("fill", x + 3, y + 4, size * 0.42, size * 0.42)
    if tint then
        lg.setColor(tint[1], tint[2], tint[3], alpha or 1)
    else
        lg.setColor(1, 1, 1, alpha or 1)
    end
    lg.draw(img, x, y, angle, s, s, 16, img:getHeight() / 2)
    return true
end

-- Item icons from the Generic Items pack, by item id.
Assets.ITEMS = {
    bandage = 100, medkit = 102, trauma = 141, stim = 93, adrenaline = 94, painkillers = 89, antidote = 104,
    energy = 126, food = 113, scanner = 62, decoy = 63, beacon = 91,
    sling = 144, daypack = 146, rucksack = 146, raid = 146, hauler = 142,
    scrap = 4, screws = 19, springs = 9, tape = 12, glue = 13, powder = 112, chemicals = 107, wires = 109,
    circuit = 75, lens = 85, polymer = 133, battery = 73, wood = 23,
    phone = 64, drive = 78, gpu = 77, documents = 37, painting = 31, relic = 162, crown = 152,
    chain = 159, watch = 161, lighter = 160, statue = 115
}

-- Tints so items sharing a picture still look different.
Assets.TINTS = {
    rucksack = { 0.75, 0.6, 0.4 }, raid = { 0.55, 0.6, 0.45 }, adrenaline = { 1, 0.8, 0.8 }
}

--- @param id string item definition id
--- @return love.Image?
function Assets.item(id)
    local n = Assets.ITEMS[id]
    if not n then return nil end
    return image(string.format("items/item_%03d.png", n))
end

return Assets
