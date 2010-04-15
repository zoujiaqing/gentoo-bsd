# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD usr/bin base system
# Patrice Clement <charlieroot@free.fr>
inherit eutils netbsd

DESCRIPTION="NetBSD 5.0 usr/bin base system"
HOMEPAGE="http://cvsweb.netbsd.org"
SRC_URI=""
SLOT="0"
LICENCE="BSD"
KEYWORDS="~x86-nbsd"

DEPEND=">=sys-netbsd/netbsd-src-5.0
        >=sys-netbsd/netbsd-cctools-5.0
        >=sys-netbsd/netbsd-libs-5.0"

src_unpack() {
  cd ${NETBSD_SRC_DIR}/usr.bin
  netbsd_mk_prepatch

  # This patch prevents, in order, these binaries to be compiled and installed:
  # cmp, bzip2, bzip2recover, crontab, gzip, file, less, lex, sdiff, tset, tput, clear.
  epatch ${FILESDIR}/${P}-Makefile.patch

  cd ${NETBSD_SRC_DIR}/gnu/usr.bin
  netbsd_mk_prepatch

  # This patch prevents, in order, these GNU binaries to be compiled and installed:
  # bc, dc, diffutils (diff, diff3, sdiff), gettext, grep, groff, rcs, texinfo.
  epatch ${FILESDIR}/${P}-Makefile-gnu.patch
}

src_compile() {
  # Clean objects.
  cd ${NETBSD_SRC_DIR}/usr.bin
  netbsd_src_compile cleandir

  # If objects in aout and elf32 aren't compiled before compiling ldd,
  # the whole process will result in an error.
  cd ${NETBSD_SRC_DIR}/usr.bin/ldd/aout
  netbsd_src_compile all
  cd ${NETBSD_SRC_DIR}/usr.bin/ldd/elf32
  netbsd_src_compile all

  # Some binaries are linked with these libraries.
  # They have to be compiled before compilation and linking process.
  cd ${NETBSD_SRC_DIR}/lib/libtelnet
  netbsd_src_compile cleandir
  netbsd_src_compile all
  cd ${NETBSD_SRC_DIR}/lib/libvers
  netbsd_src_compile cleandir
  netbsd_src_compile all

  cd ${NETBSD_SRC_DIR}/usr.bin

  # Don't need CVS, Kerberos, cryptographic, PAM and YP binaries.
  mymakeopts="${mymakeopts} MKCVS=no MKKERBEROS=no MKCRYPTO=no MKYP=no MKPAM=no USE_YP=no"

  # ubin compilation starts here.
  netbsd_src_compile dependall
}

src_install() {
  cd ${D}
  for doc_dir in 1 5 7 8
  do
    dodir usr/share/man/cat${doc_dir}
    dodir usr/share/man/man${doc_dir}
    dodir usr/share/man/html${doc_dir}
  done
  netbsd_create_dirs usr/share/doc/usd
  netbsd_create_dirs usr/share/doc/psd
  dodir usr/bin
  dodir usr/sbin
  dodir usr/libexec
  dodir usr/share/atf
  dodir usr/share/misc
  dodir usr/share/info
  dodir usr/share/tmac
  dodir usr/libdata/lint
  dodir usr/lib/pkgconfig
  dodir usr/share/calendar
  dodir usr/share/nvi/catalog
  dodir usr/share/dict/special
  cd ${NETBSD_SRC_DIR}/usr.bin
  netbsd_src_install install
  cd ${D}
  netbsd_clean_dirs .
  find usr/share/man -type f -name "*.html"|xargs dohtml
  rm -rf usr/share/man/html[1-9]
}
