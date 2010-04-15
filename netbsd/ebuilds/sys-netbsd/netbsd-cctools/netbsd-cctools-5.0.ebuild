# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD cross-compiling tools needed to build, compile and install NetBSD system parts
# Patrice Clement <clement.patrice@gmail.com>
inherit netbsd

DESCRIPTION="Build, compile and install tools to compile NetBSD 5.0 system."
HOMEPAGE="http://cvsweb.netbsd.org"
SRC_URI=""
SLOT="0"
LICENCE="BSD"
KEYWORDS="~x86-nbsd"

DEPEND=">=sys-netbsd/netbsd-src-5.0"

src_compile() {
  # "dummy" make clean
  cd ${NETBSD_SRC_DIR}/tools
  netbsd_src_compile clean
}

src_install() {
  # Let's go inside NetBSD sources directory
  cd ${NETBSD_SRC_DIR}
  # If objects directory doesn't exist, we create it
  if [ ! -d ${NETBSD_SRC_DIR}/objdir ]; then
    dodir ${NETBSD_SRC_DIR}/objdir
  fi
  # We display some information before building tools
  einfo "Cross-compiling tools will be compiled and installed in ${NETBSD_TOOLDIR} ..."
  sleep 5
  ./build.sh -a i386 -m i386 -O ${NETBSD_SRC_DIR}/objdir -T ${NETBSD_TOOLDIR} tools || die "./build.sh tools failed"
  einfo "Build finished."
}
