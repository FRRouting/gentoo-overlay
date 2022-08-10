# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools pam systemd

DESCRIPTION="The FRRouting Protocol Suite"
HOMEPAGE="https://frrouting.org/"
LICENSE="GPL-2"
SLOT="0"

KEYWORDS="amd64 ~x86"

SRC_URI="https://github.com/FRRouting/frr/archive/${P}.tar.gz"

IUSE="
	babel +bfd +bgp doc eigrp +fabric fpm +ipv6 +isis +ldp nhrp +ospf ospfapi
	pam pbr +pim realms rip +rpki +rtadv sanitize snmp systemd vrrp"

REQUIRED_USE="
	rpki? ( bgp )
"

COMMON_DEPEND="
	~net-libs/libyang-0.16.104
	dev-lang/python:*
	dev-libs/json-c
	nhrp? ( net-dns/c-ares )
	pam? ( sys-libs/pam )
	rpki? ( >=net-libs/rtrlib-0.6.3[ssh] )
	snmp? ( net-analyzer/net-snmp )
	sys-libs/libcap
	sys-libs/readline
"

BDEPEND="
	${COMMON_DEPEND}
	doc? ( dev-python/sphinx )
	sys-devel/flex
	virtual/yacc
"

DEPEND="
	${COMMON_DEPEND}
"

RDEPEND="
	!!net-misc/quagga
	${DEPEND}
	acct-user/frr
	app-shells/bash
"

# FRR tarballs have weird format.
S="${WORKDIR}/frr-${P}"

src_prepare() {
	default_src_prepare

	eautoreconf
}

src_configure() {
	econf \
		--with-pkg-extra-version="-${PR}-gentoo" \
		--enable-configfile-mask=0640 \
		--enable-logfile-mask=0640 \
		--prefix=/usr \
		--sysconfdir=/etc/frr \
		--libdir=/usr/lib/frr \
		--sbindir=/usr/lib/frr \
		--libexecdir=/usr/lib/frr \
		--localstatedir=/var/run/frr \
		--with-moduledir=/usr/lib/frr/modules \
		--enable-exampledir=/usr/share/doc/${PF}/samples \
		--enable-user=frr \
		--enable-group=frr \
		--enable-vty-group=frrvty \
		--enable-multipath=64 \
		$(use_enable babel babeld) \
		$(use_enable bfd bfdd) \
		$(use_enable bgp bgpd) \
		$(usex bgp $(use_enable rpki)) \
		$(use_enable doc) \
		$(use_enable eigrp eigrpd) \
		$(use_enable fabric fabricd) \
		$(use_enable fpm) \
		$(use_enable isis isisd) \
		$(use_enable ldp ldpd) \
		$(use_enable nhrp nhrpd) \
		$(use_enable ospf ospfd) \
		$(use_enable ospfapi) \
		$(use_enable pbr pbrd) \
		$(use_enable pim pimd) \
		$(use_enable realms) \
		$(use_enable rip ripd) \
		$(usex ipv6 $(use_enable rip ripngd)) \
		$(usex ipv6 $(use_enable ospf ospf6d)) \
		$(use_enable rtadv) \
		$(use_enable sanitize address-sanitizer) \
		$(use_enable snmp) \
		$(use_enable systemd) \
		$(use_enable vrrp vrrpd)
}

src_compile() {
	default_src_compile

	use doc && (cd doc; make html)
}

src_install() {
	default_src_install

	# Install user documentation if asked.
	if use doc ; then
		dodoc -r doc/user/_build/html
	fi

	# Create configuration directory with correct permissions.
	keepdir /etc/frr
	fowners frr:frrvty /etc/frr
	fperms 775 /etc/frr

	# Create logs directory with the correct permissions.
	keepdir /var/log/frr
	fowners frr:frr /var/log/frr
	fperms 775 /var/log/frr

	# Install the default configuration files.
	insinto /etc/frr
	doins tools/etc/frr/vtysh.conf
	doins tools/etc/frr/frr.conf
	doins tools/etc/frr/daemons

	# Fix permissions/owners.
	fowners frr:frrvty /etc/frr/vtysh.conf
	fowners frr:frr /etc/frr/frr.conf
	fowners frr:frr /etc/frr/daemons
	fperms 640 /etc/frr/vtysh.conf
	fperms 640 /etc/frr/frr.conf
	fperms 640 /etc/frr/daemons

	# Install logrotate configuration.
	insinto /etc/logrotate.d
	newins redhat/frr.logrotate frr

	# Install PAM configuration file.
	use pam && newpamd "${FILESDIR}/frr.pam" frr

	# Install init scripts.
	if use systemd ; then
		systemd_dounit tools/frr.service
	else
		newinitd "${FILESDIR}/frr-noprofile-openrc-v1" frr
	fi
}
