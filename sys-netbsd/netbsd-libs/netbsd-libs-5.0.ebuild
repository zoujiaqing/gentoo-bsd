# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD base system libraries
# Patrice Clement <charlieroot@free.fr>
inherit eutils netbsd

DESCRIPTION="NetBSD 5.0 base system libraries"
HOMEPAGE="http://cvsweb.netbsd.org"
SRC_URI=""
SLOT="0"
LICENCE="BSD"
KEYWORDS="~x86-nbsd"

DEPEND=">=sys-netbsd/netbsd-src-5.0
        >=sys-netbsd/netbsd-cctools-5.0"

src_unpack() {
  cd ${NETBSD_SRC_DIR}/lib
  netbsd_mk_prepatch

  # This patch prevents these libs to be compiled and installed:
  # libbz2, libform, libcurses, libncurses, libmenu, libterm,
  # libz, libmagic, libwrap, libpcap, libcom_err, libedit, libl,
  # BIND related librairies, and all MK related libraries
  # I'll disable later.
  epatch ${FILESDIR}/${P}-Makefile.patch
}

src_compile() {
  # First, we have to compile GNU librairies.
  cd ${NETBSD_SRC_DIR}/gnu/lib
  netbsd_src_compile cleandir
  netbsd_src_compile dependall

  # And then, NetBSD librairies.
  # Here is a workaround.. why do we need it ?
  # Some NetBSD makefiles use ${S} as a variable to set some global paths:
  # as example, ${S} is used here to guess the targeted arch in order
  # to create symlinks to right includes directories.
  # We MUST unset ${S} before calling make as it also used in Portage as a path
  # to temporary build directory: symlinks are created inside this dir,
  # instead of NetBSD sources directory, which is not what we want.
  __S=${S}
  export __S
  unset S
  cd ${NETBSD_SRC_DIR}/lib
  netbsd_src_compile cleandir

  # Here we disable:
  # - cryptographic support
  # - LDAP support
  # - PAM support
  # - Kerberos support
  # Theses libraries are provided by Portage and don't need to be built.
  mymakeopts="${mymakeopts} MKCRYPTO=no MKPAM=no MKLDAP=no MKKERBEROS=no"
  netbsd_src_compile dependall

  S=${__S}
  export S
  unset __S
}

src_install() {
  cd ${D}
  dodir lib
  dodir libdata
  dodir usr/lib/i18n
  dodir usr/lib/security
  dodir usr/libdata
  dodir var/db
  dodir usr/share/misc
  dodir usr/share/info
  netbsd_create_dirs usr/share/nls
  for doc_dir in 1 2 3 5 7 8 9
  do
    dodir usr/share/man/cat${doc_dir}
    dodir usr/share/man/man${doc_dir}
    dodir usr/share/man/html${doc_dir}
  done
  cd ${NETBSD_SRC_DIR}/gnu/lib
  netbsd_src_install install
  cd ${NETBSD_SRC_DIR}/lib
  netbsd_src_install install
  cd ${D}
  find usr/share/man -type f -name "*.html"|xargs dohtml
  rm -rf usr/share/man/html[1-9]
  rm -rf usr/lib/security
}
