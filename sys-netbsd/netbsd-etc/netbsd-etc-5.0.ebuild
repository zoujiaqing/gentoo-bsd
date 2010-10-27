# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD base system etc ebuild
# Patrice Clement <charlieroot@free.fr>
inherit netbsd

DESCRIPTION="NetBSD 5.0 base system etc files"
HOMEPAGE="http://cvsweb.netbsd.org"
SRC_URI=""
SLOT="0"
LICENCE="BSD"
KEYWORDS="~x86-nbsd"

DEPEND=">=sys-netbsd/netbsd-src-5.0"

src_compile() {
  cd ${NETBSD_SRC_DIR}/etc
  netbsd_src_compile 
}

src_install() {
  cd ${D}
  for etc_dir in etc etc/atf etc/defaults etc/bluetooth etc/ssh etc/iscsi etc/mtree etc/namedb etc/mail etc/pam.d etc/powerd/scripts etc/rc.d etc/root etc/skel dev var/at var/db var/log var/msgs var/run var/games/hackdir var/games/larn var/cron/tabs var/crash root
  do
    dodir ${etc_dir}
  done
  cd ${NETBSD_SRC_DIR}/etc
  # We don't want Postfix and SSL related etc files.
  mymakeopts="${mymakeopts} MKCRYPTO=no MKPOSTFIX=no"
  netbsd_src_install install-etc-files
}
