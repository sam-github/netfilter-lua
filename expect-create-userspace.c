/* Copyright (C) 2011 Wurldtech Security Technologies All rights reserved. */
/* Note - This code links to libnetfilter_conntrack, which is GPL. */

#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>

#include <libnetfilter_conntrack/libnetfilter_conntrack.h>
#include <libnetfilter_conntrack/libnetfilter_conntrack_tcp.h>

static int verbose;

void ctprint(struct nf_conntrack* ct, const char* msg)
{
    if(verbose) {
        char buf[1024];
        nfct_snprintf(buf, sizeof(buf), ct, 0, 0, 0);
        printf("ct=%s -- %s\n", buf, msg);
    }
}

void expprint(struct nf_expect *exp)
{
    if(verbose) {
        char buf[1024];
        nfexp_snprintf(buf, sizeof(buf), exp, 0, 0, 0);
        printf("exp=%s\n", buf);
    }
}

void usage(void)
{
    fprintf(stderr,
            "usage: expect-create-userspace [-v ] -s srcip -d dstip -f srcport -t dstport -e expectport -T timeout [-P]\n"
           );
    exit(1);
}

int main(int argc, char* argv[])
{
    const char* src = 0;
    const char* dst = 0;
    int sport = 0;
    int dport = 0;
    int expectport = 0;
    int timeout = 0;
    int flags = 0;
    int opt;

    while((opt = getopt(argc, argv, "s:d:f:t:e:T:Pv")) != -1) {
        switch(opt) {
            case 's': src = optarg; break;
            case 'd': dst = optarg; break;
            case 'f': sport = atoi(optarg); break;
            case 't': dport = atoi(optarg); break;
            case 'e': expectport = atoi(optarg); break;
            case 'T': timeout = atoi(optarg); break;
            case 'P': flags = NF_CT_EXPECT_PERMANENT; break;
            case 'v': verbose = 1; break;
            default:
                usage();
                break;
        }
    }

    if(verbose) {
        printf("%s %s:%d - %s:%d expect %d timeout %d flags %#x\n",
                argv[0], src, sport, dst, dport, expectport, timeout, flags);
    }

    if(!(src && dst && sport && dport && expectport && timeout)) {
        fprintf(stderr, "not all mandatory args were specified\n");
        usage();
    }

    struct nf_conntrack* master = nfct_new();

    if (!master) {
        perror("nfct_new");
        exit(EXIT_FAILURE);
    }

    nfct_set_attr_u8(master, ATTR_L3PROTO, AF_INET);
    nfct_set_attr_u32(master, ATTR_IPV4_SRC, inet_addr(src));
    nfct_set_attr_u32(master, ATTR_IPV4_DST, inet_addr(dst));

    nfct_set_attr_u8(master, ATTR_L4PROTO, IPPROTO_TCP);
    nfct_set_attr_u16(master, ATTR_PORT_SRC, htons(sport));
    nfct_set_attr_u16(master, ATTR_PORT_DST, htons(dport));

    ctprint(master, "master");

    struct nf_conntrack* expected = nfct_new();

    if (!expected) {
        perror("nfct_new");
        exit(EXIT_FAILURE);
    }

    nfct_set_attr_u8(expected, ATTR_L3PROTO, AF_INET);
    nfct_set_attr_u32(expected, ATTR_IPV4_SRC, inet_addr(src));
    nfct_set_attr_u32(expected, ATTR_IPV4_DST, inet_addr(dst));

    nfct_set_attr_u8(expected, ATTR_L4PROTO, IPPROTO_TCP);
    nfct_set_attr_u16(expected, ATTR_PORT_SRC, 0);
    nfct_set_attr_u16(expected, ATTR_PORT_DST, htons(expectport));

    ctprint(expected, "expected");

    struct nf_conntrack* mask = nfct_new();

    if (!mask) {
        perror("nfct_new");
        exit(EXIT_FAILURE);
    }

    nfct_set_attr_u8(mask, ATTR_L3PROTO, AF_INET);
    nfct_set_attr_u32(mask, ATTR_IPV4_SRC, 0xffffffff);
    nfct_set_attr_u32(mask, ATTR_IPV4_DST, 0xffffffff);

    nfct_set_attr_u8(mask, ATTR_L4PROTO, IPPROTO_TCP);
    nfct_set_attr_u16(mask, ATTR_PORT_SRC, 0x0000);
    nfct_set_attr_u16(mask, ATTR_PORT_DST, 0xffff);

    ctprint(mask, "mask");

    struct nf_expect* exp = nfexp_new();

    if (!exp) {
        perror("nfexp_new");
        exit(EXIT_FAILURE);
    }

    nfexp_set_attr(exp, ATTR_EXP_MASTER, master);
    nfexp_set_attr(exp, ATTR_EXP_EXPECTED, expected);
    nfexp_set_attr(exp, ATTR_EXP_MASK, mask);
    nfexp_set_attr_u32(exp, ATTR_EXP_TIMEOUT, timeout);
    nfexp_set_attr_u32(exp, ATTR_EXP_FLAGS,   flags);

    nfct_destroy(master);
    nfct_destroy(expected);
    nfct_destroy(mask);

    expprint(exp);

    struct nfct_handle* h = nfct_open(EXPECT, 0);

    if (!h) {
        perror("nfct_open");
        exit(EXIT_FAILURE);
    }

    if (nfexp_query(h, NFCT_Q_CREATE, exp) < 0) {
        /* We don't consider recreation of an existing expectation to be an error. */
        if(errno != EEXIST) {
            perror("nfexp_query");
            exit(EXIT_FAILURE);
        }
    }

    nfct_close(h);

    return 0;
}

