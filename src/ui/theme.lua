local Theme = {}

Theme.order = { "light", "dark" }
Theme.labels = { "Light", "Dark" }

Theme.palettes = {
    light = {
        ink = { 0.1, 0.11, 0.13 },
        card = { 1, 1, 1 },
        paper = { 0.93, 0.95, 0.97 },
        surface = { 1, 1, 1 },
        shadow = { 0.05, 0.07, 0.1 },
        ghost = { 1, 0.8, 0.75 },
        background = { 0.93, 0.95, 0.97 },
        floor = { 0.8, 0.82, 0.85 },
        grid = { 0.66, 0.69, 0.74, 0.3 },
        wallTop = { 0.98, 0.985, 0.99 },
        wallSide = { 0.82, 0.86, 0.9 },
        doorTop = { 0.84, 0.86, 0.9 },
        doorSide = { 0.66, 0.7, 0.76 },
        glassTop = { 0.78, 0.9, 0.98, 0.45 },
        glassSide = { 0.62, 0.8, 0.95, 0.3 },
        coverTop = { 0.93, 0.94, 0.96 },
        coverSide = { 0.7, 0.74, 0.8 },
        wallShadow = { 0.35, 0.4, 0.48, 0.14 },
        pitRim = { 0.36, 0.4, 0.46 },
        pitDeep = { 0.2, 0.23, 0.28 },
        pitEdge = { 1, 1, 1, 0.5 },
        fog = { 0.4, 0.44, 0.5, 0.5 },
        pad = { 0.13, 0.14, 0.16, 0.12 },
        halo = { 1, 1, 1 },
        minimapFloor = { 0.82, 0.84, 0.87 },
        tracerSelf = { 0.15, 0.15, 0.17 },
        smoke = { 0.45, 0.48, 0.53 },
        cloud = { 0.9, 0.91, 0.93 },
        impactRim = { 0.18, 0.2, 0.24 },
        impactHole = { 0.05, 0.06, 0.08 },
        lift = { 0 }
    },
    dark = {
        ink = { 0.9, 0.91, 0.93 },
        card = { 0.13, 0.135, 0.155 },
        paper = { 0.055, 0.06, 0.075 },
        surface = { 0.21, 0.22, 0.25 },
        shadow = { 0, 0, 0 },
        ghost = { 0.55, 0.24, 0.22 },
        background = { 0.05, 0.055, 0.07 },
        floor = { 0.15, 0.16, 0.185 },
        grid = { 0.3, 0.32, 0.37, 0.35 },
        wallTop = { 0.31, 0.32, 0.36 },
        wallSide = { 0.2, 0.21, 0.24 },
        doorTop = { 0.25, 0.26, 0.3 },
        doorSide = { 0.15, 0.16, 0.19 },
        glassTop = { 0.4, 0.6, 0.8, 0.35 },
        glassSide = { 0.28, 0.46, 0.66, 0.28 },
        coverTop = { 0.27, 0.28, 0.32 },
        coverSide = { 0.17, 0.18, 0.21 },
        wallShadow = { 0, 0, 0, 0.35 },
        pitRim = { 0.08, 0.085, 0.1 },
        pitDeep = { 0.02, 0.02, 0.03 },
        pitEdge = { 0.45, 0.47, 0.52, 0.5 },
        fog = { 0, 0, 0.02, 0.6 },
        pad = { 0.9, 0.92, 0.95, 0.14 },
        halo = { 0.6, 0.63, 0.7 },
        minimapFloor = { 0.2, 0.21, 0.24 },
        tracerSelf = { 0.88, 0.89, 0.92 },
        smoke = { 0.55, 0.58, 0.63 },
        cloud = { 0.4, 0.42, 0.46 },
        impactRim = { 0.07, 0.075, 0.09 },
        impactHole = { 0, 0, 0 },
        lift = { 0.4 }
    }
}

Theme.colors = {}
for key, value in pairs(Theme.palettes.light) do
    Theme.colors[key] = { unpack(value) }
end

Theme.current = "light"
Theme.version = 0

--- @param name string?
function Theme.apply(name)
    if not Theme.palettes[name or ""] then name = "light" end
    for key, value in pairs(Theme.palettes[name]) do
        local target = Theme.colors[key]
        for k = 1, math.max(#target, #value) do target[k] = value[k] end
    end
    if Theme.current ~= name then Theme.version = Theme.version + 1 end
    Theme.current = name
end

--- @return boolean
function Theme.dark()
    return Theme.current == "dark"
end

--- @param color table
--- @return table
function Theme.lifted(color)
    local k = Theme.colors.lift[1]
    if k <= 0 then return color end
    return { color[1] + (1 - color[1]) * k, color[2] + (1 - color[2]) * k, color[3] + (1 - color[3]) * k, color[4] }
end

return Theme
