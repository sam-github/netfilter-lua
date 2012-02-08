.PHONY: default build test

-include local.mak

default: build

SO=nfq.so nfct.so
BIN=conntracker nfct-expect-create-userspace expect-create-userspace
LIB=exptrack.lua

LUA=lua5.1

build: build-core build-conntracker

build-core: $(SO)

build-conntracker: $(BIN) $(LIB)

prefix=/usr/local

SODIR = $(DESTDIR)$(prefix)/lib/lua/5.1/
LIBDIR = $(DESTDIR)$(prefix)/share/lua/5.1/
BINDIR = $(DESTDIR)$(prefix)/bin/

.PHONY: install install-core install-conntracker
install: install-core install-conntracker

install-core: $(SO)
	mkdir -p $(SODIR) && install -t $(SODIR) $(SO)

install-conntracker: $(BIN) $(LIB)
	mkdir -p $(BINDIR) && install -t $(BINDIR) $(BIN)
	mkdir -p $(LIBDIR) && install -t $(LIBDIR) $(LIB)

CLUA=$(shell pkg-config --cflags ${LUA})
LLUA=$(shell pkg-config --libs ${LUA})

FLAGS.SO=-fPIC -fno-common -shared

CWARNS = -Wall \
  -std=c99 \
  -pedantic \
  -Wcast-align \
  -Wnested-externs \
  -Wpointer-arith \
  -Wshadow \
  -Wwrite-strings

COPT=-O2 -DNDEBUG -g
CFLAGS=$(CWARNS) $(CDEFS) $(LDFLAGS)


CC.SO := $(CC) $(COPT) $(CFLAGS)

%.so: %.c
	$(CC.SO) $(FLAGS.SO) $(CLUA) -o $@ $^ $(LDLIBS) $(LLUA)

nfq.so: nfq.c nflua.h
nfq.so: LDLIBS+=-lnetfilter_queue

nfct.so: nfct.c nflua.h
nfct.so: LDLIBS+=-lnetfilter_conntrack

expect-create-userspace: CFLAGS+=-std=c99
expect-create-userspace: LDLIBS+=-lnetfilter_conntrack
expect-create-userspace: expect-create-userspace.c

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

doc: README.txt

README.txt: README.txt.in nfq.c nfct.c
	cp README.txt.in $@
	luadoc nfq.c nfct.c >> $@

