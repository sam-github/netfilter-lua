= nfq and nfct - bindings to libnetfilter_queue and libnetfilter_conntrack

To build, see Makefile.

Homepage: <https://github.com/sam-github/netfilter-lua>
Author: <sroberts@wurldtech.com>

Documentation:

See below, extracted from in-source comments.




** nfq - a binding to netfilter's queue subsystem



-- qhandle = nfq.open()

Return an nfqueue qhandle on success, or nil,emsg,errno on failure.


-- nfq.close(qhandle)

Close the qhandle, freeing its resources.

- fd = nfq.fd(qhandle)

Return the underlying fd used by the qhandle, useful for
selecting on.


-- qhandle = nfq.setblocking(qhandle, [blocking])

blocking is true to set blocking, and false to set non-blocking (default is false)

Return is qhandle on success, or nil,emsg,errno on failure.


-- qhandle = nfq.unbind_pf(qhandle, family)

Protocol family is one of "inet", "inet6".

Return is qhandle on success and nil,emsg,errno on failure.


-- qhandle = nfq.bind_pf(qhandle, family)

Protocol family is one of "inet", "inet6".

Note that sample code seems to always unbind before binding, I've no idea why,
and there is no indication of whether its possible to bind to multiple address
families.

Return is qhandle on success and nil,emsg,errno on failure.


-- qhandle = nfq.catch(qhandle, cbfn)


-- verdict = cbfn(qdata)

cbfn - a function called for every queued packet with one argument, qdata. It
returns "accept" or "drop" meaning to do that to the packet. For no return
value, the default is "accept".  If the packet is accepted, the cbfn can
optionally return a second argument, a string that replaces the current packet.

Return qhandle on success and nil,emsg,errno on failure.


-- loop = nfq.loop(cb, copy)

A one shot way to catch on queue zero, the equivalent of:

  h = nfq.open()
  nfq.unbind_pf(h, "inet")
  nfq.bind_pf(h, "inet")
  q = nfq.create_queue(h, 0)
  nfq.set_mode(q, copy, 0xffff)
  ... = nfq.catch(h, cb)
  nfq.destroy_queue(q)
  nfq.close(h)
  return ...

DEPRECATED - don't use it in new code, it will be deleted as soon as
the existing users of it have been updated.



-- queue = nfq.create_queue(qhandle, queuenum)

queuenum is number of the queue to bind to.

Return a queue on success, or nil,emsg,errno on failure.


-- nfq.destroy_queue(queue)

Close the queue, freeing its resources.


-- queue = nfq.set_mode(queue, copy, range)

queue is returned by nfq.create_queue().

copy is one of "none" (a no-op, don't use it), "meta" (copy just packet
metadata), or "packet" (copy the full packet) (default is currently "packet").

range is the size of the packet to copy, and is optional (it defaults to
0xffff, larger than any ethernet packet can be, and larger than any link
layer packet I'm aware of).

Returns the queue on success and nil,emsg,errno on failure.


-- str = nfq.get_payload(cbctx)

str is the IP payload, it has been stripped of link-layer headers.




** nfct - a binding to netfilter's conntrack subsystem

NOTE I know its confusing that the nfct module has functions that should be
called on different kinds of objects mixed together, but unless I make full
userdata out of one or both of them, thats what it has to be. Don't confuse
them, or you will segfault!

Also, the netfilter libraries use assert() to check for invalid argument
checking, and non-type-safe APIs. The end result is you can absolutely
segfault or abort if you misuse this module.


-- cthandle = nfct.open(subsys, [subscription...])

subsys is "conntrack", "expect", or "both".

subscription is the groups for which notifications are requested, zero or more of
"none", "new", "update", "destroy", or "all" (default is "none").

Returns a conntrack handle on success, or nil,emsg,errno on failure.

There is no garbage collection, nfct.fini() must be called on the handle to
release it's resources.


-- nfct.close(cthandle)

Close the conntrack handle, freeing its resources.


-- fd = nfct.fd(cthandle)

Return the underlying fd used by the conntrack handle, useful for
selecting on.


-- cthandle = nfct.setblocking(cthandle, [blocking])

blocking is true to set blocking, and false to set non-blocking (default is false)

Return is cthandle on success, or nil,emsg,errno on failure.


-- cthandle = nfct.ct_callback_register(cthandle, ctcb, ctmsgtype)


-- cthandle = nfct.exp_callback_register(cthandle, expcb, ctmsgtype)

For each subsystem (conntrack and expect) only one registration can be active
at a time, the latest call replaces any previous ones.

Callbacks can't be registered for a subsystem that wasn't opened.

The callback function will be called as either

  verdict = ctcb(ctmsgtype, ct)
  verdict = expcb(ctmsgtype, exp)

depending on which register is called. Since you can't know the type of the object,
use different callback functions.

ctmsgtype is one of "new", "update", "destroy", "all", or "error" (default is "all").

The callback can return any of "failure", "stop", "continue", or "stolen" (the
default is "continue"):

  "failure" will stop the loop,
  "continue" will continue with the next message, and
  "stolen" is like continue, except the conntrack or expect object will
    not be destroyed (the user must destroy it later with the appropriate
    nfct.destroy() or nfct.exp_destroy or resources will be leaked)

Returns cthandle on success, nil,emsg,errno on failure.


-- cthandle = nfct.catch(cthandle)

Return is the cthandle on success, or nil,emsg,errno on failure.


-- nfct.loop(cthandle, ctmsgtype, ctcb)

Equivalent to

  nfct.ct_callback_register(cthandle, ctcb, ctmsgtype)
  return nfct.catch(cthandle)

Will probably be removed soon.


-- ct = nfct.new()

Create a new conntrack context (NOT a conntrack handle).

No garbage collection on the context is done, it must be destroyed with
nfct.destroy() or resources will be leaked.

Return is the conntrack context on sucess, and nil,emsg,errno on failure (but
it can only fail if malloc fails).


-- nfct.destroy(ct)

Destroy a conntrack context.

Note that only contexts created with nfct.new() should be destroyed - in particular,
the ct passed in a nfct.loop() callback should NOT be destroyed.



-- str = nfct.tostring(ct, ctmsgtype)

ctmsgtype is one of "new", "update", "destroy", or nil (meaning msg type is unknown).

Returns a string representation of a conntrack.


-- ct = nfct.setobjopt(ct, option)

Sets an option on a conntrack context, option is one of:
    "undo-snat",
    "undo-dnat",
    "undo-spat",
    "undo-dpat",
    "setup-original",
    "setup-reply"

Returns ct on success so calls can be chained, and nil,emsg,errno on failure.


-- value = nfct.get_attr_u8(ct, attr)


-- value = nfct.get_attr_u16(ct, attr)


-- value = nfct.get_attr_u32(ct, attr)


-- value = nfct.get_attr_n16(ct, attr)


-- value = nfct.get_attr_n32(ct, attr)


-- value = nfct.get_attr_port(ct, attr)

No error checking is done, values of zero will be returned for
attributes that aren't present, and undefined values will be returned
for attributes that aren't actually of the type requested. Also,
the attribute value may be in network byte order.

ct is a conntrack context (NOT a conntrack handle, do not mix the two).

get_attr_n#() is like the "u" version, but it converts the number from network
to host byte order.

get_attr_port() is an alias for get_attr_n16(), since TCP and UDP ports are n16.

attr is one of the enum nf_conntrack_attr values, where some aliases are
provided for the more commonly used origin attributes:
  orig-ipv4-src                -- ATTR_ORIG_IPV4_SRC, u32 bits
  ipv4-src                     -- ATTR_IPV4_SRC, alias
  orig-ipv4-dst                -- ATTR_ORIG_IPV4_DST, u32 bits
  ipv4-dst                     -- ATTR_IPV4_DST, alias
  repl-ipv4-src                -- ATTR_REPL_IPV4_SRC, u32 bits
  repl-ipv4-dst                -- ATTR_REPL_IPV4_DST, u32 bits
  orig-ipv6-src                -- ATTR_ORIG_IPV6_SRC, u128 bits
  ipv6-src                     -- ATTR_IPV6_SRC, alias
  orig-ipv6-dst                -- ATTR_ORIG_IPV6_DST, u128 bits
  ipv6-dst                     -- ATTR_IPV6_DST, alias
  repl-ipv6-src                -- ATTR_REPL_IPV6_SRC, u128 bits
  repl-ipv6-dst                -- ATTR_REPL_IPV6_DST, u128 bits
  orig-port-src                -- ATTR_ORIG_PORT_SRC, u16 bits
  port-src                     -- ATTR_PORT_SRC, alias
  orig-port-dst                -- ATTR_ORIG_PORT_DST, u16 bits
  port-dst                     -- ATTR_PORT_DST, alias
  repl-port-src                -- ATTR_REPL_PORT_SRC, u16 bits
  repl-port-dst                -- ATTR_REPL_PORT_DST, u16 bits
  icmp-type                    -- ATTR_ICMP_TYPE, u8 bits
  icmp-code                    -- ATTR_ICMP_CODE, u8 bits
  icmp-id                      -- ATTR_ICMP_ID, u16 bits
  orig-l3proto                 -- ATTR_ORIG_L3PROTO, u8 bits
  l3proto                      -- ATTR_L3PROTO, alias
  repl-l3proto                 -- ATTR_REPL_L3PROTO, u8 bits
  orig-l4proto                 -- ATTR_ORIG_L4PROTO, u8 bits
  l4proto                      -- ATTR_L4PROTO, alias
  repl-l4proto                 -- ATTR_REPL_L4PROTO, u8 bits
  tcp-state                    -- ATTR_TCP_STATE, u8 bits
  snat-ipv4                    -- ATTR_SNAT_IPV4, u32 bits
  dnat-ipv4                    -- ATTR_DNAT_IPV4, u32 bits
  snat-port                    -- ATTR_SNAT_PORT, u16 bits
  dnat-port                    -- ATTR_DNAT_PORT, u16 bits
  timeout                      -- ATTR_TIMEOUT, u32 bits
  mark                         -- ATTR_MARK, u32 bits
  orig-counter-packets         -- ATTR_ORIG_COUNTER_PACKETS, u32 bits
  repl-counter-packets         -- ATTR_REPL_COUNTER_PACKETS, u32 bits
  orig-counter-bytes           -- ATTR_ORIG_COUNTER_BYTES, u32 bits
  repl-counter-bytes           -- ATTR_REPL_COUNTER_BYTES, u32 bits
  use                          -- ATTR_USE, u32 bits
  id                           -- ATTR_ID, u32 bits
  status                       -- ATTR_STATUS, u32 bits
  tcp-flags-orig               -- ATTR_TCP_FLAGS_ORIG, u8 bits
  tcp-flags-repl               -- ATTR_TCP_FLAGS_REPL, u8 bits
  tcp-mask-orig                -- ATTR_TCP_MASK_ORIG, u8 bits
  tcp-mask-repl                -- ATTR_TCP_MASK_REPL, u8 bits
  master-ipv4-src              -- ATTR_MASTER_IPV4_SRC, u32 bits
  master-ipv4-dst              -- ATTR_MASTER_IPV4_DST, u32 bits
  master-ipv6-src              -- ATTR_MASTER_IPV6_SRC, u128 bits
  master-ipv6-dst              -- ATTR_MASTER_IPV6_DST, u128 bits
  master-port-src              -- ATTR_MASTER_PORT_SRC, u16 bits
  master-port-dst              -- ATTR_MASTER_PORT_DST, u16 bits
  master-l3proto               -- ATTR_MASTER_L3PROTO, u8 bits
  master-l4proto               -- ATTR_MASTER_L4PROTO, u8 bits
  secmark                      -- ATTR_SECMARK, u32 bits
  orig-nat-seq-correction-pos  -- ATTR_ORIG_NAT_SEQ_CORRECTION_POS, u32 bits
  orig-nat-seq-offset-before   -- ATTR_ORIG_NAT_SEQ_OFFSET_BEFORE, u32 bits
  orig-nat-seq-offset-after    -- ATTR_ORIG_NAT_SEQ_OFFSET_AFTER, u32 bits
  repl-nat-seq-correction-pos  -- ATTR_REPL_NAT_SEQ_CORRECTION_POS, u32 bits
  repl-nat-seq-offset-before   -- ATTR_REPL_NAT_SEQ_OFFSET_BEFORE, u32 bits
  repl-nat-seq-offset-after    -- ATTR_REPL_NAT_SEQ_OFFSET_AFTER, u32 bits
  sctp-state                   -- ATTR_SCTP_STATE, u8 bits
  sctp-vtag-orig               -- ATTR_SCTP_VTAG_ORIG, u32 bits
  sctp-vtag-repl               -- ATTR_SCTP_VTAG_REPL, u32 bits
  helper-name                  -- ATTR_HELPER_NAME, string (30 bytes max)
  dccp-state                   -- ATTR_DCCP_STATE, u8 bits
  dccp-role                    -- ATTR_DCCP_ROLE, u8 bits
  dccp-handshake-seq           -- ATTR_DCCP_HANDSHAKE_SEQ, u64 bits



-- ct = nfct.set_attr_u8(ct, attr, value)


-- ct = nfct.set_attr_u16(ct, attr, value)


-- ct = nfct.set_attr_u32(ct, attr, value)


-- ct = nfct.set_attr_n16(ct, attr, value)


-- ct = nfct.set_attr_n32(ct, attr, value)


-- ct = nfct.set_attr_port(ct, attr, value)

No error checking is done, value will be cast to the necessary type, and who
knows what will happen for values that aren't actually of the correct type for
the attribute. The attribute value may need to be in network byte order.

ct is a conntrack context (NOT a conntrack handle, do not mix the two).

See nfct.get_attr_*() for the supported attr names and types.

Returns the conntrack conntext, so calls can be chained.


-- ct = nfct.set_attr_ipv4(ct, attr, value)

Get an attribute as a string, the internet address in presentation format.

See inet_ntop(3) for more information.

Return is the presentation address, or nil,emsg,errno on failure.


-- ct = nfct.set_attr_ipv4(ct, attr, value)


-- ct = nfct.set_attr_ipv6(ct, attr, value)

Set an attribute as a string, the internet address in presentation format.

See inet_ntop(3) for more information.

Returns the conntrack conntext, so calls can be chained.


-- value = nfct.get_attr_pf(ct, attr)


-- ct = nfct.set_attr_pf(ct, attr, value)

Set or get attributes with address family/protocol values as a string, for
example, the "l3proto".

The address families, such as AF_INET and AF_INET6, are defined in the system
headers to be identical to the equivalent protocol family.

Value is one of:
  unspec    -- PF_UNSPEC, Unspecified.
  local     -- PF_LOCAL, Local to host (pipes and file-domain).
  unix      -- PF_UNIX, POSIX name for PF_LOCAL.
  file      -- PF_FILE, Another non-standard name for PF_LOCAL.
  inet      -- PF_INET, IP protocol family.
  ax25      -- PF_AX25, Amateur Radio AX.25.
  ipx       -- PF_IPX, Novell Internet Protocol.
  appletalk -- PF_APPLETALK, Appletalk DDP.
  netrom    -- PF_NETROM, Amateur radio NetROM.
  bridge    -- PF_BRIDGE, Multiprotocol bridge.
  atmpvc    -- PF_ATMPVC, ATM PVCs.
  x25       -- PF_X25, Reserved for X.25 project.
  inet6     -- PF_INET6, IP version 6.
  rose      -- PF_ROSE, Amateur Radio X.25 PLP.
  decnet    -- PF_DECnet, Reserved for DECnet project.
  netbeui   -- PF_NETBEUI, Reserved for 802.2LLC project.
  security  -- PF_SECURITY, Security callback pseudo AF.
  key       -- PF_KEY, PF_KEY key management API.
  netlink   -- PF_NETLINK
  route     -- PF_ROUTE, Alias to emulate 4.4BSD.
  packet    -- PF_PACKET, Packet family.
  ash       -- PF_ASH, Ash.
  econet    -- PF_ECONET, Acorn Econet.
  atmsvc    -- PF_ATMSVC, ATM SVCs.
  rds       -- PF_RDS, RDS sockets.
  sna       -- PF_SNA, Linux SNA Project
  irda      -- PF_IRDA, IRDA sockets.
  pppox     -- PF_PPPOX, PPPoX sockets.
  wanpipe   -- PF_WANPIPE, Wanpipe API sockets.
  llc       -- PF_LLC, Linux LLC.
  can       -- PF_CAN, Controller Area Network.
  tipc      -- PF_TIPC, TIPC sockets.
  bluetooth -- PF_BLUETOOTH, Bluetooth sockets.
  iucv      -- PF_IUCV, IUCV sockets.
  rxrpc     -- PF_RXRPC, RxRPC sockets.
  isdn      -- PF_ISDN, mISDN sockets.
  phonet    -- PF_PHONET, Phonet sockets.
  ieee802154-- PF_IEEE802154, IEEE 802.15.4 sockets.

Get returns the value as a string if it is known, or a number if it is not.

Set returns the conntrack conntext, so calls can be chained.


-- value = nfct.get_attr_ipproto(ct, attr)


-- ct = nfct.set_attr_ipproto(ct, attr, value)

Set or get attributes with IP protocol values as a string, for example, the
"l4proto" attribute if the "l3proto" is "inet" or "inet6".

Value is one of:

  ip        -- IPPROTO_IP, Dummy protocol for TCP.
  hopopts   -- IPPROTO_HOPOPTS, IPv6 Hop-by-Hop options.
  icmp      -- IPPROTO_ICMP, Internet Control Message Protocol.
  igmp      -- IPPROTO_IGMP, Internet Group Management Protocol.
  ipip      -- IPPROTO_IPIP, IPIP tunnels (older KA9Q tunnels use 94).
  tcp       -- IPPROTO_TCP, Transmission Control Protocol.
  egp       -- IPPROTO_EGP, Exterior Gateway Protocol.
  pup       -- IPPROTO_PUP, PUP protocol.
  udp       -- IPPROTO_UDP, User Datagram Protocol.
  idp       -- IPPROTO_IDP, XNS IDP protocol.
  tp        -- IPPROTO_TP, SO Transport Protocol Class 4.
  dccp      -- IPPROTO_DCCP, Datagram Congestion Control Protocol.
  ipv6      -- IPPROTO_IPV6, IPv6 header.
  routing   -- IPPROTO_ROUTING, IPv6 routing header.
  fragment  -- IPPROTO_FRAGMENT, IPv6 fragmentation header.
  rsvp      -- IPPROTO_RSVP, Reservation Protocol.
  gre       -- IPPROTO_GRE, General Routing Encapsulation.
  esp       -- IPPROTO_ESP, encapsulating security payload.
  ah        -- IPPROTO_AH, authentication header.
  icmpv6    -- IPPROTO_ICMPV6, ICMPv6.
  none      -- IPPROTO_NONE, IPv6 no next header.
  dstopts   -- IPPROTO_DSTOPTS, IPv6 destination options.
  mtp       -- IPPROTO_MTP, Multicast Transport Protocol.
  encap     -- IPPROTO_ENCAP, Encapsulation Header.
  pim       -- IPPROTO_PIM, Protocol Independent Multicast.
  comp      -- IPPROTO_COMP, Compression Header Protocol.
  sctp      -- IPPROTO_SCTP, Stream Control Transmission Protocol.
  udplite   -- IPPROTO_UDPLITE, UDP-Lite protocol.
  raw       -- IPPROTO_RAW, Raw IP packets.

Get returns the value as a string if it is known, or a number if it is not.

Set returns the conntrack conntext, so calls can be chained.


-- exp = nfct.exp_new(ctmaster, ctexpected, ctmask, timeout, flags...)

master, expected, mask are all ct objects, see nfct.new().

timeout is in seconds the expectation will wait for a connection

flags is one or more of "permanent", "inactive", or "userspace", and is optional (default is no flags).

permanent means the expectation remains in place until timeout, even if when connections match (the default
is to clear the connection after an expectaion matches).

userspace appears to be true for all expectations created using this API, I
don't know why its there, and I've no idea what inactive means.



-- str = nfct.exp_tostring(exp, ctmsgtype)

ctmsgtype is one of "new", "update", "destroy", or nil (meaning msg type is unknown).

Returns a string representation of an expectation.


-- cthandle = nfct.exp_query(cthandle, qtype, data)

Currently, only create and destroy is supported.

  create         -- NFCT_Q_CREATE, data must be an exp object
  update         -- NFCT_Q_UPDATE
  destroy        -- NFCT_Q_DESTROY, data must be an exp object
  get            -- NFCT_Q_GET
  flush          -- NFCT_Q_FLUSH
  dump           -- NFCT_Q_DUMP
  dump-reset     -- NFCT_Q_DUMP_RESET
  create-update  -- NFCT_Q_CREATE_UPDATE


-- h = nfct.ntohs(n)


-- n = nfct.htons(h)

Convert a short between network and host byte order.  No error or bounds
checking on the numbers is done.
