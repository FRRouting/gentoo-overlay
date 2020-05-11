# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit cmake-utils

DESCRIPTION="YANG data modeling language library"
HOMEPAGE="https://github.com/CESNET/libyang"
SRC_URI="https://github.com/CESNET/${PN}/archive/v${PV}.tar.gz -> ${PF}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE="doc"

DEPEND="dev-libs/libpcre"
RDEPEND="${DEPEND}"
BDEPEND="doc? ( app-doc/doxygen:=[dot] )"

# Fix source directory naming: GitHub likes to append the revision to
# the source directory as well.
S="${WORKDIR}/${PN}-${PVR}"

src_configure() {
	local mycmakeargs=(
		-DENABLE_LYD_PRIV=1
		-DCMAKE_BUILD_TYPE=Release
	)
	cmake-utils_src_configure
}

src_compile() {
	cmake-utils_src_make

	use doc && cmake-utils_src_make doc
}

src_install() {
	cmake-utils_src_install

	use doc && dodoc -r ${S}/doc/*
}
