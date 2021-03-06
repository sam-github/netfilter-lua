--[[
Decoder for the echobroker protocol.
]]

module(..., package.seeall)

require"net"

arg.filter = "(dst port 9999 and dst host 127.0.0.1) or (src port 9999 and src host 127.0.0.1)"

local n = net.init()

function decode(inip)
    n:clear()
    n:decode_ip(inip)

    local tcpok, tcp = pcall(n.get_tcp, n)
    local ipok, ip = pcall(n.get_ipv4, n)

    if not tcpok or not ipok then
        -- not of requested protocol
        exptrack.debug("ignore protocol<")
        exptrack.debug(n:dump())
        exptrack.debug(">")
        return "accept"
    end

    -- Original connection was client->server, and this packet is
    -- server->client, so reverse src and dst
    local src, dst, sport, dport = ip.dst, ip.src, tcp.dst, tcp.src
    local indata = tcp.payload

    if indata then
        exptrack.debug("data", indata)
        local expectport = tonumber(indata)
        if expectport ~= nil then
            exptrack.verbose("Q", "master", src, dst, sport, dport)
            exptrack.verbose("Q", "expect", src, dst, "*", expectport)
            exptrack.expect(src, dst, sport, dport, expectport, 10, "permanent")
        end 
    else
        exptrack.debug("Q", "flags", string.format("%#x", tcp.flags), "(non-data)")
    end
end


