module(..., package.seeall)

--
-- C functions exported through FFI
--

local ffi = require("ffi")

-- Structs
ffi.cdef[[

enum gk_flow_state { GK_REQUEST, GK_GRANTED, GK_DECLINED, GK_BPF };

enum protocols {
	ICMP = 1,
	TCP = 6,
	UDP = 17,
	ICMPV6 = 58,
	IPV4 = 0x0800,
	IPV6 = 0x86DD,
};

enum icmp_types {
	ICMP_ECHO_REQUEST_TYPE = 8,
};

enum icmp_codes {
	ICMP_ECHO_REQUEST_CODE = 0,
};

enum icmpv6_types {
	ICMPV6_ECHO_REQUEST_TYPE = 128,
};

enum icmpv6_codes {
	ICMPV6_ECHO_REQUEST_CODE = 0,
};

struct rte_ipv4_hdr {
	uint8_t  version_ihl;
	uint8_t  type_of_service;
	uint16_t total_length;
	uint16_t packet_id;
	uint16_t fragment_offset;
	uint8_t  time_to_live;
	uint8_t  next_proto_id;
	uint16_t hdr_checksum;
	uint32_t src_addr;
	uint32_t dst_addr;
} __attribute__((__packed__));

struct rte_ipv6_hdr {
	uint32_t vtc_flow;
	uint16_t payload_len;
	uint8_t  proto; 
	uint8_t  hop_limits;
	uint8_t  src_addr[16];
	uint8_t  dst_addr[16];
} __attribute__((__packed__));

struct rte_tcp_hdr {
	uint16_t src_port;
	uint16_t dst_port;
	uint32_t sent_seq;
	uint32_t recv_ack;
	uint8_t  data_off;
	uint8_t  tcp_flags;
	uint16_t rx_win;
	uint16_t cksum;
	uint16_t tcp_urp;
} __attribute__((__packed__));

struct rte_udp_hdr {
	uint16_t src_port;
	uint16_t dst_port;
	uint16_t dgram_len;
	uint16_t dgram_cksum;
} __attribute__((__packed__));

struct rte_icmp_hdr {
	uint8_t  icmp_type;
	uint8_t  icmp_code;
	uint16_t icmp_cksum;
	uint16_t icmp_ident;
	uint16_t icmp_seq_nb;
} __attribute__((__packed__));

struct icmpv6_hdr {
	uint8_t  icmpv6_type;
	uint8_t  icmpv6_code;
	uint16_t icmpv6_cksum;
} __attribute__((__packed__));

struct gt_packet_headers {
	uint16_t outer_ethertype;
	uint16_t inner_ip_ver;
	uint8_t l4_proto;
	uint8_t priority;
	uint8_t outer_ecn;
	uint8_t upper_len;

	void *l2_hdr;
	void *outer_l3_hdr;
	void *inner_l3_hdr;
	void *l4_hdr;
	/* This struct has hidden fields. */
};

struct ip_flow {
	uint16_t proto;

	union {
		struct {
			uint32_t src;
			uint32_t dst;
		} v4;

		struct {
			uint8_t src[16];
			uint8_t dst[16];
		} v6;
	} f;
};

struct ggu_granted {
	uint32_t tx_rate_kb_sec;
	uint32_t cap_expire_sec;
	uint32_t next_renewal_ms;
	uint32_t renewal_step_ms;
} __attribute__ ((packed));

struct ggu_declined {
	uint32_t expire_sec;
} __attribute__ ((packed));

struct gk_bpf_cookie {
	uint64_t mem[8];
};

struct ggu_bpf {
	uint32_t expire_sec;
	uint8_t  program_index;
	uint8_t  reserved;
	uint16_t cookie_len;
	struct gk_bpf_cookie cookie;
} __attribute__ ((packed));

struct ggu_policy {
	uint8_t state;
	struct ip_flow flow;
	union {
		struct ggu_granted granted;
		struct ggu_declined declined;
		struct ggu_bpf bpf;
	} params;
};

struct granted_params {
	uint32_t tx_rate_kb_sec;
	uint32_t next_renewal_ms;
	uint32_t renewal_step_ms;
};

struct in_addr {
	uint32_t s_addr;
};

struct in6_addr {
	unsigned char s6_addr[16];
};

struct rte_lpm {
	/* This struct has hidden fields. */
};

struct rte_lpm6 {
	/* This struct has hidden fields. */
};

]]

c = ffi.C

function decision_granted_nobpf(policy, tx_rate_kb_sec, cap_expire_sec,
	next_renewal_ms, renewal_step_ms)
	policy.state = c.GK_GRANTED
	policy.params.granted.tx_rate_kb_sec = tx_rate_kb_sec
	policy.params.granted.cap_expire_sec = cap_expire_sec
	policy.params.granted.next_renewal_ms = next_renewal_ms
	policy.params.granted.renewal_step_ms = renewal_step_ms
	return true
end

function decision_declined_nobpf(policy, expire_sec)
	policy.state = c.GK_DECLINED
	policy.params.declined.expire_sec = expire_sec
	return false
end

function decision_granted(policy, tx_rate_kb_sec, cap_expire_sec,
	next_renewal_ms, renewal_step_ms)
	policy.state = c.GK_BPF
	policy.params.bpf.expire_sec = cap_expire_sec
	policy.params.bpf.program_index = 0
	policy.params.bpf.reserved = 0
	policy.params.bpf.cookie_len = ffi.sizeof("struct granted_params")

	local params = ffi.cast("struct granted_params *",
		policy.params.bpf.cookie)
	params.tx_rate_kb_sec = tx_rate_kb_sec
	params.next_renewal_ms = next_renewal_ms
	params.renewal_step_ms = renewal_step_ms

	return true
end

function decision_declined(policy, expire_sec)
	policy.state = c.GK_BPF
	policy.params.bpf.expire_sec = expire_sec
	policy.params.bpf.program_index = 1
	policy.params.bpf.reserved = 0
	policy.params.bpf.cookie_len = 0
	return false
end
