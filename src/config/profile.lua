local PROFILE = {
    bodies = {
        { name = "Charcoal", color = { 0.24, 0.25, 0.28 } },
        { name = "Graphite", color = { 0.4, 0.42, 0.46 } },
        { name = "Olive", color = { 0.36, 0.4, 0.24 } },
        { name = "Plum", color = { 0.42, 0.26, 0.42 } },
        { name = "Teal", color = { 0.14, 0.4, 0.42 } },
        { name = "Sand", color = { 0.6, 0.53, 0.4 } }
    },
    accents = {
        { name = "White", color = { 1, 1, 1 } },
        { name = "Gold", color = { 0.98, 0.78, 0.25 } },
        { name = "Mint", color = { 0.4, 0.9, 0.7 } },
        { name = "Pink", color = { 0.98, 0.55, 0.72 } },
        { name = "Cyan", color = { 0.35, 0.8, 0.98 } },
        { name = "Orange", color = { 0.98, 0.55, 0.2 } },
        { name = "Lime", color = { 0.7, 0.92, 0.3 } },
        { name = "Violet", color = { 0.65, 0.5, 0.98 } }
    },
    heads = { "Hex", "Round", "Crest", "Visor" }
}

--- @param look any
--- @return table
function PROFILE.sanitize(look)
    look = type(look) == "table" and look or {}
    local head = tonumber(look.h)
    local accent = tonumber(look.a)
    local function pick(v, count)
        if not v or v ~= math.floor(v) or v < 1 or v > count then return 1 end
        return v
    end
    return { h = pick(head, #PROFILE.heads), a = pick(accent, #PROFILE.accents) }
end

return PROFILE
