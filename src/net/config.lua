local GameConfig = require("src.config.game")

local CONFIG = {
    version = 2,
    address = "*",
    port = 6789,
    official = "localhost:6789",
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
    chatLength = 120,
    chatBurst = 5,
    chatWindow = 5,
    chatHistory = 30,
    inputRedundancy = 4,
    inputCredit = 4,
    inputQueue = 12,
    matchmaking = {
        sizes = { duel = 2, ffa = 4, teams = 4, gungame = 4, infiltration = 4 },
        fillAfter = 25,
        window = 100,
        widen = 15,
        statusInterval = 1
    }
}

return CONFIG
