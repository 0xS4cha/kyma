--- Constants of the extraction mode: one persistent world per official server.
local EXTRACTION = {
    seed = 7331,
    size = 40000,
    chunk = 2000,
    road = 110,
    cell = 256,
    players = 64,

    -- How far around a player the server streams dynamic things (items, corpses, doors).
    interest = 1400,
    -- Monsters wake up when a player comes this close to their nest, and sleep again
    -- when nobody has been near for `sleepTicks`.
    activation = 2600,
    sleepTicks = 60 * 45,
    monsterCap = 420,
    aiBudget = 6,

    extractRadius = 130,
    extractTicks = 60 * 8,
    lingerTicks = 60 * 30,
    interactRadius = 90,
    pickupRadius = 60,
    corpseTicks = 60 * 60 * 12,
    groundTicks = 60 * 60 * 6,
    containerRefill = 60 * 60 * 15,
    saveEvery = 10,
    spawnClearance = 900,

    stash = { w = 10, h = 24 },
    pockets = { w = 3, h = 1 },
    quickSlots = 4,
    startMoney = 4000,
    kitCooldown = 60 * 10,
    sellRate = 0.55,

    -- Danger goes up from the edges (1) to the centre (4); it picks the monsters, the
    -- loot tables and the rarity rolls of every chunk.
    tiers = 4,

    events = {
        first = 60 * 60 * 2,
        every = 60 * 60 * 4,
        warn = 60 * 30,
        last = 60 * 60 * 5,
        max = 3
    },

    vision = { range = 420, flashlight = 640 },

    use = {
        slow = 0.55
    }
}

return EXTRACTION
