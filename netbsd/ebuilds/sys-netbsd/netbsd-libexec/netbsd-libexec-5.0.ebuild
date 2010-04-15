# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD base system libexec ebuild
# Patrice Clement <clement.patrice@gmail.com>
inherit netbsd

DESCRIPTION="NetBSD 5.0 libexec binaries"
HOMEPAGE="http://cvsweb.netbsd.org"
SRC_URI=""
SLOT="0"
LICENCE="BSD"
KEYWORDS="~x86-nbsd"

DEPEND=">=sys-netbsd/netbsd-src-5.0
        >=sys-netbsd/netbsd-cctools-5.0"

src_compile() {
  # ld_elf.so library is linked against libc, we have to compile it before
  cd ${NETBSD_SRC_DIR}/lib/libc
  netbsd_src_compile cleandir
  netbsd_src_compile dependall
  # same for telnetd
  cd ${NETBSD_SRC_DIR}/lib/libtelnet
  netbsd_src_compile cleandir
  netbsd_src_compile dependall
  # and libvers
  cd ${NETBSD_SRC_DIR}/lib/libvers
  netbsd_src_compile cleandir
  netbsd_src_compile dependall
  # now let's built the whole libexec binaries
  cd ${NETBSD_SRC_DIR}/libexec
  netbsd_src_compile cleandir
  netbsd_src_compile dependall
}

src_install() {
  cd ${D}
  for doc_dir in 1 5 8
  do
    dodir usr/share/man/cat${doc_dir}
    dodir usr/share/man/man${doc_dir}
    dodir usr/share/man/html${doc_dir}
  done
  dodir libexec
  dodir usr/libexec/atrun
  cd ${NETBSD_SRC_DIR}/libexec
  netbsd_src_install install
  cd ${D}
  find usr/share/man -type f -name "*.html"|xargs dohtml
  rm -rf usr/share/man/html[1-9]
}
