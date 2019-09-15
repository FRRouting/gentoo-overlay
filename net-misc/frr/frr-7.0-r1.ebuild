# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit autotools eutils flag-o-matic multilib pam readme.gentoo-r1 systemd tmpfiles user vcs-snapshot

if [[ ${PV} != 9999 ]]; then
	SRC_URI="https://github.com/FRRouting/frr/archive/${P}.tar.gz"
	KEYWORDS="amd64 x86"
else
	inherit git-r3
	SRC_URI=""
	EGIT_REPO_URI="https://github.com/FRRouting/frr.git"
	KEYWORDS=""
fi

DESCRIPTION="Free Range Routing Protocol Suite, fork of Quagga"
HOMEPAGE="https://frrouting.org/"

LICENSE="GPL-2"
SLOT="0"

IUSE="caps doc elibc_glibc ipv6 +readline +bgp +rip +ospf +ldp +nhrp +eigrp +babel watchfrr +isis +pim +pbr +fabric +snmp systemd fpm rpki multipath pam protobuf shell-access"
REQUIRED_USE="
	rpki? ( bgp )
"

COMMON_DEPEND="
	!!net-misc/quagga
	dev-libs/json-c:0=
	caps? ( sys-libs/libcap )
	nhrp? ( net-dns/c-ares:0= )
	protobuf? ( dev-libs/protobuf-c:0= )
	readline? (
		sys-libs/readline:0=
		pam? ( sys-libs/pam )
	)
	snmp? ( net-analyzer/net-snmp )
	!elibc_glibc? ( dev-libs/libpcre )
	rpki? ( >=net-libs/rtrlib-0.6.3[ssh] )
	>=net-libs/libyang-0.16-r3"
DEPEND="${COMMON_DEPEND}
	dev-perl/XML-LibXML
	sys-apps/gawk
	sys-devel/libtool:2"
RDEPEND="${COMMON_DEPEND}
	sys-apps/iproute2"

PATCHES=(
	"${FILESDIR}/${PN}-2.0-ipctl-forwarding.patch"
)

DISABLE_AUTOFORMATTING=1
DOC_CONTENTS="Sample configuration files can be found in /usr/share/doc/${PF}/samples
You have to create config files in /etc/frr before
starting one of the daemons.

You can pass additional options to the daemon by setting the EXTRA_OPTS
variable in their respective file in /etc/conf.d"

pkg_setup() {
	enewgroup quagga
	enewuser quagga -1 -1 /var/empty quagga
}

src_prepare() {
	eapply "${PATCHES[@]}"
	eapply_user
	eautoreconf
}

src_configure() {
	append-flags -fno-strict-aliasing

	# do not build PDF docs
	export ac_cv_prog_PDFLATEX=no
	export ac_cv_prog_LATEXMK=no

	econf \
		--enable-exampledir=/usr/share/doc/${PF}/samples \
		--enable-user=quagga \
		--enable-group=quagga \
		--enable-vty-group=quagga \
		--with-pkg-extra-version="-gentoo" \
		--sysconfdir=/etc/frr \
		--localstatedir=/run/frr \
		--disable-static \
		--enable-address-sanitizer \
		--enable-irdp \
		$(use_enable caps capabilities) \
		$(use_enable !elibc_glibc pcreposix) \
		$(use_enable doc) \
		$(use_enable bgp bgpd) \
		$(use_enable rip ripd) \
		$(use_enable ospf ospfd) \
		$(use_enable ospf ospfapi) \
		$(use_enable ospf ospfclient) \
		$(usex ipv6 $(use_enable ospf ospf6d)) \
		$(usex ipv6 $(use_enable rip ripngd)) \
		$(use_enable ldp ldpd) \
		$(use_enable nhrp nhrpd) \
		$(use_enable eigrp eigrpd) \
		$(use_enable babel babeld) \
		$(use_enable watchfrr) \
		$(use_enable isis isisd) \
		$(use_enable pim pimd) \
		$(use_enable pbr pbrd) \
		$(use_enable fabric fabricd) \
		$(use_enable snmp) \
		$(use_enable systemd) \
		$(use_enable fpm) \
		$(usex bgp $(use_enable rpki)) \
		$(usex multipath $(use_enable multipath) '' '=64' '') \
		$(use_enable readline vtysh) \
		$(use_with pam libpam) \
		$(use_enable protobuf) \
		$(use_enable shell-access)
}

src_install() {
	default
	prune_libtool_files
	readme.gentoo_create_doc

	keepdir /etc/frr
	fowners root:quagga /etc/frr
	fperms 0770 /etc/frr

	# Install systemd-related stuff, bug #553136
	dotmpfiles "${FILESDIR}/systemd/frr.conf"
	use systemd && systemd_dounit "${FILESDIR}/systemd/zebra.service"

	# install zebra as a file, symlink the rest
	use systemd || newinitd "${FILESDIR}"/frr.init zebra

	for service in zebra staticd \
			$(usex bgp bgpd "") \
			$(usex rip ripd "") \
			$(usex ospf ospfd "") \
			$(usex ldp ldpd "") \
			$(usex nhrp nhrpd "") \
			$(usex eigrp eigrpd "") \
			$(usex babel babeld "") \
			$(usex isis isisd "") \
			$(usex pim pimd "") \
			$(usex pbr pbrd "") \
			$(usex fabric fabricd "") \
			$(usex ipv6 $(usex ospf ospf6d "") "") \
			$(usex ipv6 $(usex rip ripngd "") "") \
	; do
		use systemd || dosym zebra /etc/init.d/${service}
		use systemd && systemd_dounit "${FILESDIR}/systemd/${service}.service"
	done

	use readline && use pam && newpamd "${FILESDIR}/frr.pam" frr

	insinto /etc/logrotate.d
	newins redhat/frr.logrotate frr
}

pkg_postinst() {
	# Path for PIDs before first reboot should be created here, bug #558194
	tmpfiles_process frr.conf

	readme.gentoo_print_elog
}
