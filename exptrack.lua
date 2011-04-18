#!/usr/bin/env lua5.1
--[[
A userspace connection tracker for an example RPC-like echo service.
Assumes iptables rules have been setup appropriately.
See ECHO.txt for usage.
]]

-- FIXME remove assert
local assert = assert
local tonumber = tonumber
local tostring = tostring
local nfct = require"nfct"
local nfq = require"nfq"


module(...)

-- You can set these to make things print for debug purposes.
function debug() end
function verbose() end

--[[-
-- qhandle = exptrack.open(decodefn, queuenum)

Opens a netfilter queuenum and sets it up to catch packets.

The queue must previously have been setup using iptables rules. The default queue is 0.
]]

function open(decode, queuenum)
    queuenum = assert(tonumber(queuenum or 0))

    local qhandle = assert(nfq.open())

    nfq.unbind_pf(qhandle, "inet")
    nfq.bind_pf(qhandle, "inet")

    local queue = assert(nfq.create_queue(qhandle, queuenum))

    assert(nfq.set_mode(queue, "packet"))

    return qhandle
end

--[[-
-- exptrack.catch(qhandle, decode)

The decode function will be passed an IPv4 packet to analyze. It can create
expectations by calling exptrack.expect().
]]
function catch(qhandle, decode)
    return nfq.catch(qhandle, function (nfqdata)
        debug("CB nfq")

        local inip = assert(nfq.get_payload(nfqdata))

        decode(inip)

        return "accept"
    end)
end

-- nfct helpers

function ctprint(ct, name, ...)
    verbose("ct="..nfct.tostring(ct).." -- "..name, ...)
end

function expprint(exp, name, ...)
    verbose("exp="..nfct.exp_tostring(exp).." -- "..name, ...)
end

function check(...)
    if (...) then
        return ...
    end
    local _, emsg, eno = ...
    local emsg = "["..tostring(eno).."] "..tostring(emsg)
    return assert(_, emsg)
end

function tuple(name, src, dst, sport, dport)
    local ct = assert(nfct.new())

    nfct.set_attr_pf(ct, "l3proto",  "inet")
    nfct.set_attr_ipv4(ct, "ipv4-src", src)
    nfct.set_attr_ipv4(ct, "ipv4-dst", dst)

    nfct.set_attr_ipproto(ct, "l4proto",  "tcp")

    if sport then
        nfct.set_attr_port(ct, "port-src", sport)
    end

    nfct.set_attr_port(ct, "port-dst", dport)

    ctprint(ct, name)

    return ct
end


--[[-
-- exptrack.expect(src, dst, sport, dport, expectport, timeout, flags)

- src, dst are addresses of master connection, and will be used for expected
- sport, dport are ports of master connection
- expectport is destination port of expected connection
- timeout is how long the expectation will wait for a matching connection, in seconds
- flags defaults to nil, but can be "permanent"

FIXME assumes TCP! Would need a protocol argument to work with UDP.
]]
function expect(src, dst, sport, dport, expectport, timeout, flags)
    -- identify the master to which this expectation is related
    local master = tuple("master", src, dst, sport, dport)
    local expected = tuple("expected", src, dst, nil, expectport)
    local mask = tuple("mask", 0xffffffff, 0xffffffff, nil, expectport)
    local timeout = timeout or 10
    local exp = assert(nfct.exp_new(master, expected, mask, timeout, flags))

    nfct.destroy(master)
    nfct.destroy(expected)
    nfct.destroy(mask)

    expprint(exp, "expectation")

    local h = assert(nfct.open("expect"))

    -- FIXME this can fail if conntrack hasn't tracked the master... but is
    -- that possible? we just got data from nfq, the connection must exist
    local _, emsg, eno = nfct.exp_query(h, "create", exp)

    if eno == 17 then
        -- expectation already exists... normal?
    else
        check(_, emsg, eno)
    end

    nfct.exp_destroy(exp)

    nfct.close(h)
end

