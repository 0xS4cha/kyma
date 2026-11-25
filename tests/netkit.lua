local enet = require("enet")
local Protocol = require("src.net.protocol")
local NetConfig = require("src.net.config")

--- Small fake clients that talk to a real Host over loopback, for server tests.
local NetKit = {}

--- @param port number
--- @param name string
--- @param hello table?
--- @return table
function NetKit.client(port, name, hello)
    local client = { host = enet.host_create(), inbox = {}, name = name, hello = hello or {} }
    client.peer = client.host:connect("127.0.0.1:" .. port, NetConfig.channels)
    return client
end

--- @param client table
--- @param kind string
--- @param data any
function NetKit.send(client, kind, data)
    client.peer:send(Protocol.Encode(kind, data), 0, "reliable")
end

--- @param client table
--- @param kind string
--- @return table?
function NetKit.last(client, kind)
    for k = #client.inbox, 1, -1 do
        if client.inbox[k].kind == kind then return client.inbox[k].data end
    end
end

--- @param client table
--- @param kind string
--- @return number
function NetKit.count(client, kind)
    local n = 0
    for _, message in ipairs(client.inbox) do
        if message.kind == kind then n = n + 1 end
    end
    return n
end

--- Runs the server and the clients for a while. Clients say hello on connect,
--- and send `client.queue` once welcomed when it is set.
--- @param server table
--- @param clients table[]
--- @param seconds number
--- @param step number?
function NetKit.pump(server, clients, seconds, step)
    step = step or 0.004
    local deadline = love.timer.getTime() + seconds
    while love.timer.getTime() < deadline do
        server:Think(step)
        for _, client in ipairs(clients) do
            local event = client.host:service(0)
            while event do
                if event.type == "connect" then
                    local hello = { name = client.name, version = NetConfig.version }
                    for key, value in pairs(client.hello) do hello[key] = value end
                    NetKit.send(client, "hello", hello)
                elseif event.type == "receive" then
                    local kind, data = Protocol.Decode(event.data)
                    client.inbox[#client.inbox + 1] = { kind = kind, data = data }
                    if kind == "welcome" and client.queue then
                        NetKit.send(client, "queue", client.queue)
                    elseif kind == "joined" then
                        client.slot = data.slot
                        client.room = data.room
                    end
                end
                event = client.host:service(0)
            end
        end
        love.timer.sleep(0.002)
    end
end

--- @param clients table[]
function NetKit.close(clients)
    for _, client in ipairs(clients) do
        client.peer:disconnect_now()
        client.host:flush()
    end
end

--- Runs a test body against a started server and always cleans up.
--- @param server table
--- @param clients table[]
--- @param body function
function NetKit.run(server, clients, body)
    local ok, err = xpcall(body, debug.traceback)
    NetKit.close(clients)
    server:Stop()
    assert(ok, err)
end

return NetKit
