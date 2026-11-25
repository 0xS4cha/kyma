--- Item icons of the extraction inventory, from Kenney's CC0 Generic Items pack
--- (assets/kenney/items). Loaded on first use and cached. Items without a picture
--- here are drawn by src/modules/extraction/icons.lua.
local Assets = {}

local cache = {}

-- Icon number in the Generic Items pack, by item id.
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
    local path = string.format("assets/kenney/items/item_%03d.png", n)
    if cache[path] == nil then
        local ok, img = pcall(love.graphics.newImage, path, { mipmaps = true })
        if ok then
            img:setFilter("linear", "linear")
            img:setMipmapFilter("linear")
        end
        cache[path] = ok and img or false
    end
    return cache[path] or nil
end

return Assets
