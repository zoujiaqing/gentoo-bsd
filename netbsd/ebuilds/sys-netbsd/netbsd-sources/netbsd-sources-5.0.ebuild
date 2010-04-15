# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD GENERIC kernel ebuild
# Patrice Clement <clement.patrice@gmail.com>
inherit eutils netbsd

DESCRIPTION="NetBSD 5.0 kernel ebuild (GENERIC)"
HOMEPAGE="http://cvsweb.netbsd.org"
SRC_URI=""
SLOT="0"
LICENCE="BSD"
KEYWORDS="~x86-nbsd"

DEPEND=">=sys-netbsd/netbsd-src-5.0
        >=sys-netbsd/netbsd-cctools-5.0"

src_unpack() {
  # Move to kernel configuration files directory
  cd ${NETBSD_SRC_DIR}/sys/arch/i386/conf

  # Backup original GENERIC kernel configuration file
  if [ ! -e GENERIC_ORIG ]; then
    cp GENERIC GENERIC_ORIG
  else
    cp GENERIC_ORIG GENERIC
  fi

  # This patch:
  # - changes march & mtune GCC compilation flags to prescott
  # - enable ACPI verbosity
  # - enable kernel built-in pf device (no need to load it through LKM)
  epatch ${FILESDIR}/${P}-GENERIC.patch

  # Generate kernel directory data structure
  einfo "Generating kernel directory data structure..."
  ${NETBSD_TOOLDIR}/bin/nbconfig GENERIC
  einfo "OK!"

  # Move to GENERIC kernel data directory
  cd ${NETBSD_SRC_DIR}/sys/arch/i386/compile/GENERIC

  # Clean directory
  einfo "Cleaning GENERIC kernel directory..."
  netbsd_src_compile clean
  einfo "OK!"

  # Create kernel dependencies
  einfo "Creating kernel dependencies..."
  netbsd_src_compile depend
  einfo "OK!"
}

src_compile() {
  # Compile kernel
  einfo "Starting kernel compilation..."
  cd ${NETBSD_SRC_DIR}/sys/arch/i386/compile/GENERIC
  netbsd_src_compile all
  einfo "Kernel compilation finished."
}

pkg_preinst() {
  # Create a backup of existing kernel, which should be named "netbsd" by default.
  if [ -e ${ROOT}/netbsd ]; then
    einfo "Create a backup of existing kernel..."
    mv ${ROOT}/netbsd ${ROOT}/netbsd.old
    einfo "OK!"
  fi
}

src_install() {
  # Kernel will be installed in ${NETBSD_ROOT} directory, called "netbsd", with 755 rights.
  cd ${NETBSD_SRC_DIR}/sys/arch/i386/compile/GENERIC
  insinto ${NETBSD_ROOT}
  insopts -m0755
  einfo 'Installing new compiled kernel...'
  doins netbsd
  einfo 'OK!'
}
