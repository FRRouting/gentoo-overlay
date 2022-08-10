# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

if [[ ${PV} != 9999 ]]; then
	SRC_URI="https://github.com/CESNET/${PN}/archive/v${PV}-r3.tar.gz -> ${PF}.tar.gz"
	KEYWORDS="amd64 x86"
else
	inherit git-r3
	SRC_URI=""
	EGIT_REPO_URI="https://github.com/CESNET/libyang.git"
	KEYWORDS=""
fi

DESCRIPTION="YANG data modeling language library"
HOMEPAGE="https://github.com/CESNET/libyang"

LICENSE="BSD"
SLOT="0"

# Fix source directory naming: GitHub likes to append the revision to
# the source directory as well.
S="${WORKDIR}/${PN}-${PVR}"

src_configure() {
	local mycmakeargs=(
		-DENABLE_LYD_PRIV=ON
		-DCMAKE_BUILD_TYPE=Release
		-DENABLE_CACHE=OFF
	)
	cmake_src_configure
}

src_compile() {
	cmake_src_compile
}
