/* enable all advanced features */
//#define ADV_FEATURES

parser start {
    return parse_ethernet;
}

#define ETHERTYPE_BF_FABRIC    0x9000
#define ETHERTYPE_BF_SFLOW     0x9001
#define ETHERTYPE_VLAN         0x8100, 0x9100
#define ETHERTYPE_MPLS         0x8847
#define ETHERTYPE_IPV4         0x0800
#define ETHERTYPE_IPV6         0x86dd
#define ETHERTYPE_ARP          0x0806
#define ETHERTYPE_RARP         0x8035
#define ETHERTYPE_NSH          0x894f
#define ETHERTYPE_ETHERNET     0x6558
#define ETHERTYPE_ROCE         0x8915
#define ETHERTYPE_FCOE         0x8906
#define ETHERTYPE_TRILL        0x22f3
#define ETHERTYPE_VNTAG        0x8926
#define ETHERTYPE_LLDP         0x88cc
#define ETHERTYPE_LACP         0x8809

#define IPV4_MULTICAST_MAC 0x01005E
#define IPV6_MULTICAST_MAC 0x3333

/* Tunnel types */
#define INGRESS_TUNNEL_TYPE_NONE               0
#define INGRESS_TUNNEL_TYPE_VXLAN              1
#define INGRESS_TUNNEL_TYPE_GRE                2
#define INGRESS_TUNNEL_TYPE_GENEVE             3 
#define INGRESS_TUNNEL_TYPE_NVGRE              4
#define INGRESS_TUNNEL_TYPE_MPLS_L2VPN         5
#define INGRESS_TUNNEL_TYPE_MPLS_L3VPN         8 

#ifndef ADV_FEATURES
#define PARSE_ETHERTYPE                                    \
        ETHERTYPE_VLAN : parse_vlan;                       \
        ETHERTYPE_MPLS : parse_mpls;                       \
        ETHERTYPE_IPV4 : parse_ipv4;                       \
        ETHERTYPE_IPV6 : parse_ipv6;                       \
        ETHERTYPE_ARP : parse_arp_rarp;                    \
        ETHERTYPE_RARP : parse_arp_rarp;                   \
        ETHERTYPE_ROCE : parse_roce;                       \
        ETHERTYPE_FCOE : parse_fcoe;                       \
        ETHERTYPE_VNTAG : parse_vntag;                     \
        ETHERTYPE_LLDP  : parse_set_prio_high;             \
        ETHERTYPE_LACP  : parse_set_prio_high;             \
        default: ingress
#else
#define PARSE_ETHERTYPE                                    \
        ETHERTYPE_VLAN : parse_vlan;                       \
        ETHERTYPE_MPLS : parse_mpls;                       \
        ETHERTYPE_IPV4 : parse_ipv4;                       \
        ETHERTYPE_IPV6 : parse_ipv6;                       \
        ETHERTYPE_ARP : parse_arp_rarp;                    \
        ETHERTYPE_RARP : parse_arp_rarp;                   \
        ETHERTYPE_NSH : parse_nsh;                         \
        ETHERTYPE_ROCE : parse_roce;                       \
        ETHERTYPE_FCOE : parse_fcoe;                       \
        ETHERTYPE_TRILL : parse_trill;                     \
        ETHERTYPE_VNTAG : parse_vntag;                     \
        ETHERTYPE_LLDP  : parse_set_prio_high;             \
        ETHERTYPE_LACP  : parse_set_prio_high;             \
        ETHERTYPE_BF_SFLOW : parse_bf_internal_sflow;      \
        default: ingress
#endif

header ethernet_t ethernet;

parser parse_ethernet {
    extract(ethernet);
    return select(latest.etherType) {
        0 mask 0xfe00: parse_llc_header;
        0 mask 0xfa00: parse_llc_header;
        ETHERTYPE_BF_FABRIC : parse_fabric_header;
        PARSE_ETHERTYPE;
    }
}

header llc_header_t llc_header;

parser parse_llc_header {
    extract(llc_header);
    return select(llc_header.dsap, llc_header.ssap) {
        0xAAAA : parse_snap_header;
        0xFEFE : parse_set_prio_med;
        default: ingress;
    }
}

header snap_header_t snap_header;

parser parse_snap_header {
    extract(snap_header);
    return select(latest.type_) {
        PARSE_ETHERTYPE;
    }
}

header roce_header_t roce;

parser parse_roce {
    extract(roce);
    return ingress;
}

header fcoe_header_t fcoe;

parser parse_fcoe {
    extract(fcoe);
    return ingress;
}

#define VLAN_DEPTH 2
header vlan_tag_t vlan_tag_[VLAN_DEPTH];
header vlan_tag_3b_t vlan_tag_3b[VLAN_DEPTH];
header vlan_tag_5b_t vlan_tag_5b[VLAN_DEPTH];

parser parse_vlan {
    extract(vlan_tag_[next]);
    return select(latest.etherType) {
        PARSE_ETHERTYPE;
    }
}

#define MPLS_DEPTH 3
/* all the tags but the last one */
header mpls_t mpls[MPLS_DEPTH];

/* TODO: this will be optimized when pushed to the chip ? */
parser parse_mpls {
    extract(mpls[next]);
    return select(latest.bos) {
        0 : parse_mpls;
        1 : parse_mpls_bos;
        default: ingress;
    }
}

parser parse_mpls_bos {
    //TODO: last keyword is not supported in compiler yet.
    // replace mpls[0] to mpls[last]
    return select(current(0, 4)) {
        0x4 : parse_mpls_inner_ipv4;
        0x6 : parse_mpls_inner_ipv6;
        default: parse_eompls;
    }
}

parser parse_mpls_inner_ipv4 {
    set_metadata(tunnel_metadata.ingress_tunnel_type,
                 INGRESS_TUNNEL_TYPE_MPLS_L3VPN);
    return parse_inner_ipv4;
}

parser parse_mpls_inner_ipv6 {
    set_metadata(tunnel_metadata.ingress_tunnel_type,
                 INGRESS_TUNNEL_TYPE_MPLS_L3VPN);
    return parse_inner_ipv6;
}

parser parse_vpls {
    return ingress;
}

parser parse_pw {
    return ingress;
}

#define IP_PROTOCOLS_ICMP              1
#define IP_PROTOCOLS_IGMP              2
#define IP_PROTOCOLS_IPV4              4
#define IP_PROTOCOLS_TCP               6
#define IP_PROTOCOLS_UDP               17
#define IP_PROTOCOLS_IPV6              41
#define IP_PROTOCOLS_GRE               47
#define IP_PROTOCOLS_IPSEC_ESP         50
#define IP_PROTOCOLS_IPSEC_AH          51
#define IP_PROTOCOLS_ICMPV6            58
#define IP_PROTOCOLS_EIGRP             88
#define IP_PROTOCOLS_OSPF              89
#define IP_PROTOCOLS_PIM               103
#define IP_PROTOCOLS_VRRP              112

#define IP_PROTOCOLS_IPHL_ICMP         0x501
#define IP_PROTOCOLS_IPHL_IPV4         0x504
#define IP_PROTOCOLS_IPHL_TCP          0x506
#define IP_PROTOCOLS_IPHL_UDP          0x511
#define IP_PROTOCOLS_IPHL_IPV6         0x529
#define IP_PROTOCOLS_IPHL_GRE          0x52f

header ipv4_t ipv4;

field_list ipv4_checksum_list {
        ipv4.version;
        ipv4.ihl;
        ipv4.diffserv;
        ipv4.totalLen;
        ipv4.identification;
        ipv4.flags;
        ipv4.fragOffset;
        ipv4.ttl;
        ipv4.protocol;
        ipv4.srcAddr;
        ipv4.dstAddr;
}

field_list_calculation ipv4_checksum {
    input {
        ipv4_checksum_list;
    }
    algorithm : csum16;
    output_width : 16;
}

calculated_field ipv4.hdrChecksum  {
    verify ipv4_checksum if (ipv4.ihl == 5);
    update ipv4_checksum if (ipv4.ihl == 5);
}

parser parse_ipv4 {
    extract(ipv4);
    return select(latest.fragOffset, latest.ihl, latest.protocol) {
        IP_PROTOCOLS_IPHL_ICMP : parse_icmp;
        IP_PROTOCOLS_IPHL_TCP : parse_tcp;
        IP_PROTOCOLS_IPHL_UDP : parse_udp;
        IP_PROTOCOLS_IPHL_GRE : parse_gre;
        IP_PROTOCOLS_IPHL_IPV4 : parse_inner_ipv4;
        IP_PROTOCOLS_IPHL_IPV6 : parse_inner_ipv6;
        IP_PROTOCOLS_IGMP : parse_set_prio_med;
        IP_PROTOCOLS_EIGRP : parse_set_prio_med;
        IP_PROTOCOLS_OSPF : parse_set_prio_med;
        IP_PROTOCOLS_PIM : parse_set_prio_med;
        IP_PROTOCOLS_VRRP : parse_set_prio_med;
        default: ingress;
    }
}

header ipv6_t ipv6;

parser parse_ipv6 {
    extract(ipv6);
#if !defined(IPV6_DISABLE)
    set_metadata(ipv6_metadata.lkp_ipv6_sa, latest.srcAddr);
    set_metadata(ipv6_metadata.lkp_ipv6_da, latest.dstAddr);
#endif /* !defined(IPV6_DISABLE) */
    return select(latest.nextHdr) {
        IP_PROTOCOLS_ICMPV6 : parse_icmp;
        IP_PROTOCOLS_TCP : parse_tcp;
        IP_PROTOCOLS_UDP : parse_udp;
        IP_PROTOCOLS_GRE : parse_gre;
        IP_PROTOCOLS_IPV4 : parse_inner_ipv4;
        IP_PROTOCOLS_IPV6 : parse_inner_ipv6;

        IP_PROTOCOLS_EIGRP : parse_set_prio_med;
        IP_PROTOCOLS_OSPF : parse_set_prio_med;
        IP_PROTOCOLS_PIM : parse_set_prio_med;
        IP_PROTOCOLS_VRRP : parse_set_prio_med;

        default: ingress;
    }
}

header icmp_t icmp;

parser parse_icmp {
    extract(icmp);
    set_metadata(l3_metadata.lkp_icmp_type, latest.type_);
    set_metadata(l3_metadata.lkp_icmp_code, latest.code);
    return select(latest.type_) {
        /* MLD and ND, 130-136 */
        0x82 mask 0xfe : parse_set_prio_med;
        0x84 mask 0xfc : parse_set_prio_med;
        0x88 : parse_set_prio_med;
        default: ingress;
    }
}

#define TCP_PORT_BGP                   179
#define TCP_PORT_MSDP                  639

header tcp_t tcp;

parser parse_tcp {
    extract(tcp);
    set_metadata(l3_metadata.lkp_l4_sport, latest.srcPort);
    set_metadata(l3_metadata.lkp_l4_dport, latest.dstPort);
    return select(latest.dstPort) {
        TCP_PORT_BGP : parse_set_prio_med;
        TCP_PORT_MSDP : parse_set_prio_med;
        default: ingress;
    }
}

#define UDP_PORT_BOOTPS                67
#define UDP_PORT_BOOTPC                68
#define UDP_PORT_RIP                   520
#define UDP_PORT_RIPNG                 521
#define UDP_PORT_DHCPV6_CLIENT         546
#define UDP_PORT_DHCPV6_SERVER         547
#define UDP_PORT_HSRP                  1985
#define UDP_PORT_BFD                   3785
#define UDP_PORT_LISP                  4341
#define UDP_PORT_VXLAN                 4789
#define UDP_PORT_ROCE_V2               4791
#define UDP_PORT_GENV                  6081
#define UDP_PORT_SFLOW                 6343

header udp_t udp;

header roce_v2_header_t roce_v2;

parser parse_roce_v2 {
    extract(roce_v2);
    return ingress;
}

parser parse_udp {
    extract(udp);
    set_metadata(l3_metadata.lkp_l4_sport, latest.srcPort);
    set_metadata(l3_metadata.lkp_l4_dport, latest.dstPort);
    return select(latest.dstPort) {
        UDP_PORT_VXLAN : parse_vxlan;
        UDP_PORT_GENV: parse_geneve;
        UDP_PORT_ROCE_V2: parse_roce_v2;
#ifdef ADV_FEATURES
        UDP_PORT_LISP : parse_lisp;
        UDP_PORT_BFD : parse_bfd;
        UDP_PORT_SFLOW : parse_sflow;
#endif
        UDP_PORT_BOOTPS : parse_set_prio_med;
        UDP_PORT_BOOTPC : parse_set_prio_med;
        UDP_PORT_DHCPV6_CLIENT : parse_set_prio_med;
        UDP_PORT_DHCPV6_SERVER : parse_set_prio_med;
        UDP_PORT_RIP : parse_set_prio_med;
        UDP_PORT_RIPNG : parse_set_prio_med;
        UDP_PORT_HSRP : parse_set_prio_med;
        default: ingress;
    }
}

header sctp_t sctp;

parser parse_sctp {
    extract(sctp);
    return ingress;
}

#define GRE_PROTOCOLS_NVGRE            0x20006558
#define GRE_PROTOCOLS_ERSPAN_V1        0x88BE
#define GRE_PROTOCOLS_ERSPAN_V2        0x22EB

header gre_t gre;

parser parse_gre {
    extract(gre);
    return select(latest.C, latest.R, latest.K, latest.S, latest.s,
                  latest.recurse, latest.flags, latest.ver, latest.proto) {
        GRE_PROTOCOLS_NVGRE : parse_nvgre;
        ETHERTYPE_IPV4 : parse_gre_ipv4;
        ETHERTYPE_IPV6 : parse_gre_ipv6;
        GRE_PROTOCOLS_ERSPAN_V1 : parse_erspan_v1;
        GRE_PROTOCOLS_ERSPAN_V2 : parse_erspan_v2;
#ifdef ADV_FEATURES
        ETHERTYPE_NSH : parse_nsh;
#endif
        default: ingress;
    }
}

parser parse_gre_ipv4 {
    set_metadata(tunnel_metadata.ingress_tunnel_type, INGRESS_TUNNEL_TYPE_GRE);
    return parse_inner_ipv4;
}

parser parse_gre_ipv6 {
    set_metadata(tunnel_metadata.ingress_tunnel_type, INGRESS_TUNNEL_TYPE_GRE);
    return parse_inner_ipv6;
}

header nvgre_t nvgre;
header ethernet_t inner_ethernet;

header ipv4_t inner_ipv4;
header ipv6_t inner_ipv6;

field_list inner_ipv4_checksum_list {
        inner_ipv4.version;
        inner_ipv4.ihl;
        inner_ipv4.diffserv;
        inner_ipv4.totalLen;
        inner_ipv4.identification;
        inner_ipv4.flags;
        inner_ipv4.fragOffset;
        inner_ipv4.ttl;
        inner_ipv4.protocol;
        inner_ipv4.srcAddr;
        inner_ipv4.dstAddr;
}

field_list_calculation inner_ipv4_checksum {
    input {
        inner_ipv4_checksum_list;
    }
    algorithm : csum16;
    output_width : 16;
}

calculated_field inner_ipv4.hdrChecksum {
    verify inner_ipv4_checksum if (inner_ipv4.ihl == 5);
    update inner_ipv4_checksum if (inner_ipv4.ihl == 5);
}

header udp_t outer_udp;

parser parse_nvgre {
    extract(nvgre);
    set_metadata(tunnel_metadata.ingress_tunnel_type,
                 INGRESS_TUNNEL_TYPE_NVGRE);
    set_metadata(tunnel_metadata.tunnel_vni, latest.tni);
    return parse_inner_ethernet;
}

header erspan_header_v1_t erspan_v1_header;

parser parse_erspan_v1 {
    extract(erspan_v1_header);
    return ingress;
}

header erspan_header_v2_t erspan_v2_header;

parser parse_erspan_v2 {
    extract(erspan_v2_header);
    return ingress;
}

#define ARP_PROTOTYPES_ARP_RARP_IPV4 0x0800

header arp_rarp_t arp_rarp;

parser parse_arp_rarp {
    extract(arp_rarp);
    return select(latest.protoType) {
        ARP_PROTOTYPES_ARP_RARP_IPV4 : parse_arp_rarp_ipv4;
        default: ingress;
    }
}

header arp_rarp_ipv4_t arp_rarp_ipv4;

parser parse_arp_rarp_ipv4 {
    extract(arp_rarp_ipv4);
    return parse_set_prio_med;
}

header eompls_t eompls;

parser parse_eompls {
    //extract(eompls);
    set_metadata(tunnel_metadata.ingress_tunnel_type,
                 INGRESS_TUNNEL_TYPE_MPLS_L2VPN);
    return parse_inner_ethernet;
}

header vxlan_t vxlan;

parser parse_vxlan {
    extract(vxlan);
    set_metadata(tunnel_metadata.ingress_tunnel_type,
                 INGRESS_TUNNEL_TYPE_VXLAN);
    set_metadata(tunnel_metadata.tunnel_vni, latest.vni);
    return parse_inner_ethernet;
}

header genv_t genv;

parser parse_geneve {
    extract(genv);
    set_metadata(tunnel_metadata.tunnel_vni, latest.vni);
    set_metadata(tunnel_metadata.ingress_tunnel_type,
                 INGRESS_TUNNEL_TYPE_GENEVE);
    return select(genv.ver, genv.optLen, genv.protoType) {
        ETHERTYPE_ETHERNET : parse_inner_ethernet;
        ETHERTYPE_IPV4 : parse_inner_ipv4;
        ETHERTYPE_IPV6 : parse_inner_ipv6;
        default : ingress;
    }
}

header nsh_t nsh;
header nsh_context_t nsh_context;

parser parse_nsh {
    extract(nsh);
    extract(nsh_context);
    return select(nsh.protoType) {
        ETHERTYPE_IPV4 : parse_inner_ipv4;
        ETHERTYPE_IPV6 : parse_inner_ipv6;
        ETHERTYPE_ETHERNET : parse_inner_ethernet;
        default : ingress;
    }
}

header lisp_t lisp;

parser parse_lisp {
    extract(lisp);
    return select(current(0, 4)) {
        0x4 : parse_inner_ipv4;
        0x6 : parse_inner_ipv6;
        default : ingress;
    }
}

parser parse_inner_ipv4 {
    extract(inner_ipv4);
    return select(latest.fragOffset, latest.ihl, latest.protocol) {
        IP_PROTOCOLS_IPHL_ICMP : parse_inner_icmp;
        IP_PROTOCOLS_IPHL_TCP : parse_inner_tcp;
        IP_PROTOCOLS_IPHL_UDP : parse_inner_udp;
        default: ingress;
    }
}

header icmp_t inner_icmp;

parser parse_inner_icmp {
    extract(inner_icmp);
    set_metadata(l3_metadata.lkp_inner_icmp_type, latest.type_);
    set_metadata(l3_metadata.lkp_inner_icmp_code, latest.code);
    return ingress;
}

header tcp_t inner_tcp;

parser parse_inner_tcp {
    extract(inner_tcp);
    set_metadata(l3_metadata.lkp_inner_l4_sport, latest.srcPort);
    set_metadata(l3_metadata.lkp_inner_l4_dport, latest.dstPort);
    return ingress;
}

header udp_t inner_udp;

parser parse_inner_udp {
    extract(inner_udp);
    set_metadata(l3_metadata.lkp_inner_l4_sport, latest.srcPort);
    set_metadata(l3_metadata.lkp_inner_l4_dport, latest.dstPort);
    return ingress;    
}

header sctp_t inner_sctp;

parser parse_inner_sctp {
    extract(inner_sctp);
    return ingress;
}

parser parse_inner_ipv6 {
    extract(inner_ipv6);
    return select(latest.nextHdr) {
        IP_PROTOCOLS_ICMPV6 : parse_inner_icmp;
        IP_PROTOCOLS_TCP : parse_inner_tcp;
        IP_PROTOCOLS_UDP : parse_inner_udp;
        default: ingress;
    }
}

parser parse_inner_ethernet {
    extract(inner_ethernet);
    return select(latest.etherType) {
        ETHERTYPE_IPV4 : parse_inner_ipv4;
        ETHERTYPE_IPV6 : parse_inner_ipv6;
        default: ingress;
    }
}

header trill_t trill;

parser parse_trill {
    extract(trill);
    return parse_inner_ethernet;
}

header vntag_t vntag;

parser parse_vntag {
    extract(vntag);
    return parse_inner_ethernet;
}

header bfd_t bfd;

parser parse_bfd {
    extract(bfd);
    return parse_set_prio_max;
}

header sflow_t sflow;
header sflow_internal_ethernet_t sflow_internal_ethernet;
header sflow_sample_t sflow_sample;
header sflow_record_t sflow_record;

parser parse_sflow {
    extract(sflow);
    return ingress;
}

parser parse_bf_internal_sflow {
    extract(sflow_internal_ethernet);
    extract(sflow_sample);
    extract(sflow_record);
    return ingress;
}

header fabric_header_t                 fabric_header;
header fabric_header_unicast_t         fabric_header_unicast;
header fabric_header_multicast_t       fabric_header_multicast;
header fabric_header_mirror_t          fabric_header_mirror;
header fabric_header_control_t         fabric_header_control;
header fabric_header_cpu_t             fabric_header_cpu;
header fabric_payload_header_t         fabric_payload_header;

parser parse_fabric_header {
    extract(fabric_header);
    return select(latest.packetType) {
        FABRIC_HEADER_TYPE_UNICAST : parse_fabric_header_unicast;
        FABRIC_HEADER_TYPE_MULTICAST : parse_fabric_header_multicast;
        FABRIC_HEADER_TYPE_MIRROR : parse_fabric_header_mirror;
        FABRIC_HEADER_TYPE_CONTROL : parse_fabric_header_control;
        FABRIC_HEADER_TYPE_CPU : parse_fabric_header_cpu;
        default : ingress;
    }
}

parser parse_fabric_header_unicast {
    extract(fabric_header_unicast);
    return parse_fabric_payload_header;
}

parser parse_fabric_header_multicast {
    extract(fabric_header_multicast);
    return parse_fabric_payload_header;
}

parser parse_fabric_header_mirror {
    extract(fabric_header_mirror);
    return parse_fabric_payload_header;
}

parser parse_fabric_header_control {
    extract(fabric_header_control);
    return parse_fabric_payload_header;
}

parser parse_fabric_header_cpu {
    extract(fabric_header_cpu);
    return parse_fabric_payload_header;
}

parser parse_fabric_payload_header {
    extract(fabric_payload_header);
    return select(latest.etherType) {
        0 mask 0xfe00: parse_llc_header;
        0 mask 0xfa00: parse_llc_header;
        PARSE_ETHERTYPE;
    }
}

#define CONTROL_TRAFFIC_PRIO_0         0
#define CONTROL_TRAFFIC_PRIO_1         1
#define CONTROL_TRAFFIC_PRIO_2         2
#define CONTROL_TRAFFIC_PRIO_3         3
#define CONTROL_TRAFFIC_PRIO_4         4
#define CONTROL_TRAFFIC_PRIO_5         5
#define CONTROL_TRAFFIC_PRIO_6         6
#define CONTROL_TRAFFIC_PRIO_7         7

parser parse_set_prio_med {
    set_metadata(intrinsic_metadata.priority, CONTROL_TRAFFIC_PRIO_3);
    return ingress;
}

parser parse_set_prio_high {
    set_metadata(intrinsic_metadata.priority, CONTROL_TRAFFIC_PRIO_5);
    return ingress;
}

parser parse_set_prio_max {
    set_metadata(intrinsic_metadata.priority, CONTROL_TRAFFIC_PRIO_7);
    return ingress;
}
