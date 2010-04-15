# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD base system include headers
# Patrice Clement <clement.patrice@gmail.com>
inherit netbsd bsdmk

DESCRIPTION="Base system include files (/usr/include) for NetBSD 5.0"
HOMEPAGE="http://cvsweb.netbsd.org"
SRC_URI=""
SLOT="0"
LICENCE="BSD"
KEYWORDS="~x86-nbsd"

DEPEND=">=sys-netbsd/netbsd-src-5.0
        >=sys-netbsd/netbsd-cctools-5.0"

src_compile() {
  cd ${NETBSD_SRC_DIR}/include
  netbsd_src_compile dependall
}

src_install() {
  cd ${D}
  dodir usr/include
  for inc_dir in arpa protocols rpcsvc ssp rpc prop atf-c atf-c++ readline rump objc g++ g++/backward g++/ext g++/bits g++/debug g++/tr1 
  do
    dodir usr/include/${inc_dir}
  done
  dodir usr/share/tmac
  cd ${NETBSD_SRC_DIR}
  # Don't need SSL, PAM and LDAP related include headers.
  mymakeopts="${mymakeopts} MKCRYPTO=no MKKERBEROS=no MKPAM=no MKLDAP=no"
  netbsd_src_install includes
}
