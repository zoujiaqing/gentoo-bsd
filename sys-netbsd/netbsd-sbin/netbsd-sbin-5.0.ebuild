# Copyright 1999-2009 Gentoo FounDation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD sbin base system
# Patrice Clement <charlieroot@free.fr>
inherit eutils netbsd

DESCRIPTION="NetBSD 5.0 sbin base system"
HOMEPAGE="http://cvsweb.netbsd.org"
SRC_URI=""
SLOT="0"
LICENCE="BSD"
KEYWORDS="~x86-nbsd"

DEPEND=">=sys-netbsd/netbsd-src-5.0
        >=sys-netbsd/netbsd-cctools-5.0"

src_unpack() {
  cd ${NETBSD_SRC_DIR}/sbin
  netbsd_mk_prepatch

  # This patch avoid rcorder to be compiled and installed.
  epatch "${FILESDIR}/${P}-Makefile.patch"
}

src_compile() {
  cd ${NETBSD_SRC_DIR}/sbin
  netbsd_src_compile cleandir
  netbsd_src_compile dependall
}

src_install() {
  cd ${D}
  for doc_dir in 5 8
  do
    dodir usr/share/man/cat${doc_dir}
    dodir usr/share/man/man${doc_dir}
    dodir usr/share/man/html${doc_dir}
  done
  dodir sbin
  dodir usr/sbin
  dodir usr/share/doc/smm/03.fsck_ffs
  dodir usr/share/examples/mount_portal
  dodir usr/share/examples/smbfs
  cd ${NETBSD_SRC_DIR}/sbin
  netbsd_src_install install
  cd ${D}
  find usr/share/man -type f -name "*.html"|xargs dohtml
  rm -rf usr/share/man/html[1-9]
}
