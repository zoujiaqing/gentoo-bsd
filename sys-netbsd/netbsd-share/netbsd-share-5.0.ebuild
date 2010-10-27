# Copyright 1999-2009 Gentoo FounDation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD share base system
# Patrice Clement <charlieroot@free.fr>
inherit eutils netbsd

DESCRIPTION="NetBSD 5.0 share base system"
HOMEPAGE="http://cvsweb.netbsd.org"
SRC_URI=""
SLOT="0"
LICENCE="BSD"
KEYWORDS="~x86-nbsd"

DEPEND=">=sys-netbsd/netbsd-src-5.0
        >=sys-netbsd/netbsd-cctools-5.0"

src_unpack() {
  cd ${NETBSD_SRC_DIR}/share
  netbsd_mk_prepatch

  # This patch prevents man and termcap directories to be installed.
  epatch "${FILESDIR}/${P}-Makefile.patch"
}

src_compile() {
  cd ${NETBSD_SRC_DIR}/share
  netbsd_src_compile cleandir
  netbsd_src_compile dependall
}

src_install() {
  cd ${D}
  # Strange behaviour ? Same as with netbsd-libs. This time, we can't unset
  # FILESDIR (read-only variable). Just create the dir and remove it later.
  dodir ./${FILESDIR}
  netbsd_create_dirs usr/share
  cd ${NETBSD_SRC_DIR}/share
  netbsd_src_install install
  cd ${D}
  netbsd_clean_dirs ./
  # Here!
  find ./${FILESDIR} -type f -exec mv {} usr/share/doc/smm \;
  rm -rf ./${FILESDIR}
  find usr/share/man -type f -name '*.html'|xargs dohtml
  rm -rf usr/share/man/html[1-9]
}
