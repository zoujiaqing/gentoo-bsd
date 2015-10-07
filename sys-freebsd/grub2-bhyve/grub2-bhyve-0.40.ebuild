# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI="5"

inherit autotools-utils

if [[ ${PV} == *9999* ]]; then
	inherit git-2
	KEYWORDS=""
	EGIT_REPO_URI="git://github.com/grehan-freebsd/grub2-bhyve.git"
else
	KEYWORDS="~amd64-fbsd"
	SRC_URI="https://github.com/grehan-freebsd/grub2-bhyve/archive/v${PV}.tar.gz -> ${P}.tar.gz"
fi

DESCRIPTION="Grub-emu loader for bhyve"
HOMEPAGE="https://github.com/grehan-freebsd/grub2-bhyve"

LICENSE="GPL-3"
SLOT="0"
IUSE="zfs"

RDEPEND="
	>=sys-freebsd/freebsd-usbin-10.0
	>=sys-libs/ncurses-5.2-r5
	zfs? ( >=sys-freebsd/freebsd-cddl-10.0 )
"
DEPEND="${RDEPEND}
	sys-devel/bison
	sys-devel/flex
	sys-apps/help2man
"

src_configure() {
	local myeconfargs=(
		--disable-werror
		--disable-nls
		--with-platform=emu
		--enable-grub-mount=no
		--enable-grub-mkfont=no
		--enable-grub-emu-sdl=no
		$(use_enable zfs libzfs)
	)
	autotools-utils_src_configure
}

src_install() {
	newbin "${BUILD_DIR}"/grub-core/grub-emu grub-bhyve
}
