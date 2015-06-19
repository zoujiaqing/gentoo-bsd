# Copyright 1999-2009 Gentoo FounDation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD usr/sbin base system
# Patrice Clement <charlieroot@free.fr>
inherit eutils netbsd

DESCRIPTION="NetBSD 5.0 usr/sbin base system"
HOMEPAGE="http://cvsweb.netbsd.org"
SRC_URI=""
SLOT="0"
LICENCE="BSD"
KEYWORDS="~x86-nbsd"

DEPEND=">=sys-netbsd/netbsd-src-5.0
        >=sys-netbsd/netbsd-cctools-5.0"

src_unpack() {
  # Same as with netbsd-bin ebuild.
  cd ${NETBSD_SRC_DIR}/usr.sbin
  netbsd_mk_prepatch

  # This patch prevents, in order, these binaries to be compiled and installed:
  # bind, dhcpcd, dhclient, ntp, lpr (and related commands), tcpdump, tcpdchk, tcpdmatch
  # inetd (which is xinetd on Gentoo), cron, syslogd, wpa (and related commands).
  epatch ${FILESDIR}/${P}-Makefile.patch
}

src_compile() {
  cd ${NETBSD_SRC_DIR}/lib/libvers
  netbsd_src_compile all
  cd ${NETBSD_SRC_DIR}/usr.sbin
  netbsd_src_compile cleandir

  # Don't need Kerberos, cryptographic and YP binaries.
  mymakeopts="${mymakeopts} MKKERBEROS=no MKCRYPTO=no MKYP=no"
  netbsd_src_compile dependall
}

src_install() {
  cd ${D}
  for doc_dir in 1 4 5 8
  do
    dodir usr/share/man/cat${doc_dir}/amiga
    dodir usr/share/man/man${doc_dir}/amiga
    dodir usr/share/man/html${doc_dir}/amiga
    dodir usr/share/man/cat${doc_dir}/hp300
    dodir usr/share/man/man${doc_dir}/hp300
    dodir usr/share/man/html${doc_dir}/hp300
    dodir usr/share/man/cat${doc_dir}/sparc
    dodir usr/share/man/man${doc_dir}/sparc
    dodir usr/share/man/html${doc_dir}/sparc
    dodir usr/share/man/cat${doc_dir}/i386
    dodir usr/share/man/man${doc_dir}/i386  
    dodir usr/share/man/html${doc_dir}/i386
    dodir usr/share/man/cat${doc_dir}/x68k  
    dodir usr/share/man/man${doc_dir}/x68k  
    dodir usr/share/man/html${doc_dir}/x68k
  done
  dodir dev
  dodir sbin
  dodir var/yp
  dodir usr/bin
  dodir usr/sbin
  dodir usr/libexec/lpr
  dodir usr/share/info
  dodir usr/share/dhcpd
  dodir usr/share/examples/ipf
  dodir usr/share/examples/pf
  dodir usr/share/examples/rtadvd
  dodir usr/share/examples/dhcp
  dodir usr/share/doc/smm/12.timed
  dodir usr/share/doc/smm/11.timedop
  cd ${NETBSD_SRC_DIR}/usr.sbin
  netbsd_src_install install
}
