local GameConfig = require("src.config.game")

local CONFIG = {
    version = 1,
    address = "*",
    port = 6789,
    localAddress = "127.0.0.1",
    localPorts = { 6790, 6809 },
    lanPorts = { 6789, 6799 },
    discoveryPort = 6788,
    discoveryInterval = 1,
    discoveryExpire = 4,
    maxPeers = 64,
    channels = 2,
    reliable = 0,
    unreliable = 1,
    tickRate = GameConfig.tickRate,
    snapshotTicks = GameConfig.snapshotTicks,
    timeout = 5000,
    roomPlayers = 2,
    inputRedundancy = 4,
    inputCredit = 4,
    inputQueue = 12
}

return CONFIG
