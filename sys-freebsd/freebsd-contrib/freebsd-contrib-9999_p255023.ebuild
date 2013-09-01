# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit bsdmk freebsd flag-o-matic multilib

DESCRIPTION="Contributed sources for FreeBSD."
if [[ ${PV} != *9999* ]]; then
	KEYWORDS="~amd64-fbsd ~sparc-fbsd ~x86-fbsd"
	SRC_URI="mirror://gentoo/${GNU}.tar.bz2
		mirror://gentoo/${P}.tar.bz2"
fi
LICENSE="BSD GPL-2+ libodialog"
SLOT="0"
IUSE=""

RDEPEND=""
DEPEND="=sys-freebsd/freebsd-sources-${RV}*
	=sys-freebsd/freebsd-mk-defs-${RV}*
	=sys-freebsd/freebsd-ubin-${RV}*"

S="${WORKDIR}/gnu"

src_compile() {
	cd "${S}/usr.bin/patch"
	freebsd_src_compile
}

src_install() {
	use profile || mymakeopts="${mymakeopts} NO_PROFILE= "
	mymakeopts="${mymakeopts} NO_MANCOMPRESS= NO_INFOCOMPRESS= "

	cd "${S}/usr.bin/patch"
	mkinstall BINDIR="/usr/bin/" || die "patch install failed"
}
