.PHONY: default build test

-include local.mak

default: build

BINDING=nfq.so nfct.so

CC = gcc
LDFLAGS = -fPIC -fno-common -shared
LUA = lua5.1
CLUA=$(shell pkg-config --cflags ${LUA})
LLUA=$(shell pkg-config --libs ${LUA})

build: $(BINDING)

prefix=/usr

SODIR = $(DESTDIR)$(prefix)/lib/lua/5.1/

.PHONY: install
install: $(BINDING)
	mkdir -p $(SODIR)
	install -t $(SODIR) $(BINDING)

CWARNS = -Wall \
  -pedantic \
  -Wcast-align \
  -Wnested-externs \
  -Wpointer-arith \
  -Wshadow \
  -Wwrite-strings

COPT=-O2 -DNDEBUG -g
CFLAGS=$(CWARNS) $(CDEFS) $(CLUA) $(LDFLAGS)
LDLIBS=$(LLUA)

CC.SO := $(CC) $(COPT) $(CFLAGS)

%.so: %.c
	$(CC.SO) -o $@ $^ $(LDLIBS)

nfq.so: nfq.c nflua.h
nfq.so: LDLIBS+=-lnetfilter_queue

nfct.so: nfct.c nflua.h
nfct.so: LDLIBS+=-lnetfilter_conntrack

options:
	./luaopts PF /usr/include/bits/socket.h > _pf.c
	./luaopts IPPROTO /usr/include/netinet/in.h > _ipproto.c
	-./luaopts ATTR /usr/include/libnetfilter_conntrack/libnetfilter_conntrack.h > _attr.c
	-./luaopts NFCT_Q /usr/include/libnetfilter_conntrack/libnetfilter_conntrack.h > _nfct_q.c

TNET=$(wildcard test-*.lua)
TOUT=$(TNET:.lua=.test)

echo:
	echo $(TOUT)

test: $(TOUT)

%.test: %.lua net.so
	lua $<
	touch $@

%.test: %-test %.so
	lua $<
	touch $@

%.test: %-test net.so
	lua $<
	touch $@

