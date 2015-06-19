# Copyright 1999-2009 Gentoo FounDation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD bin base system
# Patrice Clement <charlieroot@free.fr>
inherit eutils netbsd

DESCRIPTION="NetBSD 5.0 bin base system"
HOMEPAGE="http://cvsweb.netbsd.org"
SRC_URI=""
SLOT="0"
LICENCE="BSD"
KEYWORDS="~x86-nbsd"

DEPEND=">=sys-netbsd/netbsd-src-5.0
        >=sys-netbsd/netbsd-cctools-5.0"

src_unpack() {
  cd ${NETBSD_SRC_DIR}/bin
  netbsd_mk_prepatch

  # This patch will prevent csh and ed to be compiled and installed:
  # these binaries are provided by Portage.
  epatch "${FILESDIR}/${P}-Makefile.patch"
}

src_compile() {
  cd ${NETBSD_SRC_DIR}/bin
  netbsd_src_compile cleandir
  netbsd_src_compile dependall
}

src_install() {
  cd ${D}
  for doc_dir in 1 8
  do
    dodir usr/share/man/cat${doc_dir}
    dodir usr/share/man/man${doc_dir}
    dodir usr/share/man/html${doc_dir}
  done
  dodir bin
  dodir usr/bin
  dodir usr/share/doc/usd/04.csh
  cd ${NETBSD_SRC_DIR}/bin
  netbsd_src_install install
  cd ${D}
  find usr/share/man -type f -name "*.html"|xargs dohtml
  rm -rf usr/share/man/html[1-9]
}
