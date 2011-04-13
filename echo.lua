--[[
Decoder for the echobroker protocol.
]]

module(..., package.seeall)

require"net"

local n = net.init()

function decode(inip)
    n:clear()
    n:decode_ip(inip)

    local _, tcp = pcall(n.get_tcp, n)
    local _, ip = pcall(n.get_ipv4, n)

    if not tcp or not ip then
        -- not of requested protocol
        exptrack.debug("ignore protocol", n:dump())
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


