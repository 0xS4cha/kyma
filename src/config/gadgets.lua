local GADGETS = {
    order = { "smoke", "flash", "decoy" },
    speed = 560,
    friction = 0.9,
    radius = 5,
    fuse = 48,
    charges = 1,
    smoke = { name = "Smoke", text = "A cloud that blocks sight for 8 s", radius = 120, grow = 24, ticks = 480 },
    flash = { name = "Flashbang", text = "Blinds everyone who sees it go off", radius = 430, blind = 180, glance = 0.35 },
    decoy = { name = "Decoy", text = "Fakes your gunfire for 4 s", ticks = 240, interval = 18, range = 600 }
}

--- @param kind string?
--- @return number
function GADGETS.pack(kind)
    for k, id in ipairs(GADGETS.order) do
        if id == kind then return k end
    end
    return 0
end

--- @param value number?
--- @return string?
function GADGETS.unpack(value)
    return value and GADGETS.order[value] or nil
end

return GADGETS
