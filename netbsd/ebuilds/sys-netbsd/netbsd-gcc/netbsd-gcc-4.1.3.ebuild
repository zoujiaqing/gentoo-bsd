# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD GNU Compiler Collection 4.1.3 ebuild
# Patrice Clement <clement.patrice@gmail.com>
inherit netbsd

DESCRIPTION="The GNU Compiler Collection for NetBSD 5.0. Default supported languages frontend: C, C++, Objective-C."
HOMEPAGE="http://gcc.gnu.org"
SRC_URI=""
SLOT="0"
LICENCE="GPL"
KEYWORDS="~x86-nbsd"

DEPEND=">=sys-netbsd/netbsd-src-5.0
        >=sys-netbsd/netbsd-cctools-5.0"

src_compile() {
  cd ${NETBSD_SRC_DIR}/tools/compat
  netbsd_src_compile cleandir
  netbsd_src_compile dependall

  # This file is needed by gcc during compilation.
  cp ${NETBSD_SRC_DIR}/gnu/lib/libgcc4/libgcov/arch/`uname -m`/gcov-iov.h ${NETBSD_SRC_DIR}/gnu/dist/gcc4/gcc
  cd ${NETBSD_SRC_DIR}/gnu/usr.bin/gcc4
  netbsd_src_compile cleandir
  netbsd_src_compile dependall
}

src_install() {
  cd ${D}
  dodir usr/bin
  dodir usr/libexec
  dodir usr/share/man/man1
  dodir usr/share/man/cat1
  dodir usr/share/man/html1
  dodir usr/share/info
  cd ${NETBSD_SRC_DIR}/gnu/usr.bin/gcc4
  netbsd_src_install install
  cd ${D}
  find usr/share/man -type f -name "*.html"|xargs dohtml
  rm -rf usr/share/man/html[1-9]
}
