# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD GNU binutils
# Patrice Clement <charlieroot@free.fr>
inherit netbsd

DESCRIPTION="NetBSD 5.0 GNU binutils"
HOMEPAGE="http://cvsweb.netbsd.org"
SRC_URI=""
SLOT="0"
LICENCE="BSD"
KEYWORDS="~x86-nbsd"

DEPEND=">=sys-netbsd/netbsd-src-5.0
        >=sys-netbsd/netbsd-cctools-5.0
        >=sys-netbsd/netbsd-gcc-5.0
        >=sys-netbsd/netbsd-includes-5.0
        >=sys-netbsd/netbsd-libs-5.0"

src_compile() {
  cd ${NETBSD_SRC_DIR}/gnu/lib/libbfd
  netbsd_src_compile cleandir
  netbsd_src_compile dependall
  cd ${NETBSD_SRC_DIR}/gnu/lib/libiberty
  netbsd_src_compile cleandir
  netbsd_src_compile dependall
  cd ${NETBSD_SRC_DIR}/gnu/lib/libopcodes
  netbsd_src_compile cleandir
  netbsd_src_compile dependall
  cd ${NETBSD_SRC_DIR}/gnu/usr.bin/binutils 
  netbsd_src_compile cleandir
  netbsd_src_compile dependall
}

src_install() {
  cd ${D}
  dodir usr/bin
  dodir usr/share/info
  dodir usr/share/man/cat1
  dodir usr/share/man/man1
  dodir usr/share/man/html1
  dodir usr/libdata/ldscripts
  cd ${NETBSD_SRC_DIR}/gnu/usr.bin/binutils
  netbsd_src_install install
  cd ${D}
  find usr/share/man -type f -name "*.html"|xargs dohtml
  rm -rf usr/share/man/html[0-9]
}
