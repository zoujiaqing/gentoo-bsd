# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-freebsd/freebsd-sources/freebsd-sources-9.1_rc3.ebuild,v 1.2 2012/11/24 11:30:56 aballier Exp $

inherit bsdmk freebsd flag-o-matic

DESCRIPTION="FreeBSD kernel sources"
SLOT="${PVR}"
KEYWORDS="~amd64-fbsd ~sparc-fbsd ~x86-fbsd"

IUSE="symlink"

SRC_URI="mirror://gentoo/${SYS}.tar.bz2"

RDEPEND=">=sys-freebsd/freebsd-mk-defs-8.0"
DEPEND=""

RESTRICT="strip binchecks"

S="${WORKDIR}/sys"

MY_PVR="${PVR}"

[[ ${MY_PVR} == "${RV}" ]] && MY_PVR="${MY_PVR}-r0"

PATCHES=( "${FILESDIR}/${PN}-9.0-disable-optimization.patch"
	"${FILESDIR}/${PN}-9.1-gentoo.patch"
	"${FILESDIR}/${PN}-6.0-flex-2.5.31.patch"
	"${FILESDIR}/${PN}-6.1-ntfs.patch"
	"${FILESDIR}/${PN}-7.1-types.h-fix.patch"
	"${FILESDIR}/${PN}-8.0-subnet-route-pr40133.patch"
	"${FILESDIR}/${PN}-7.1-includes.patch"
	"${FILESDIR}/${PN}-9.0-sysctluint.patch"
	"${FILESDIR}/${PN}-9.1-MFC-r239588.patch"
	"${FILESDIR}/${PN}-cve-2012-4576.patch"
	"${FILESDIR}/${PN}-7.0-tmpfs_whiteout_stub.patch" )

src_unpack() {
	freebsd_src_unpack

	# This replaces the gentoover patch, it doesn't need reapply every time.
	sed -i -e 's:^REVISION=.*:REVISION="'${PVR}'":' \
		-e 's:^BRANCH=.*:BRANCH="Gentoo":' \
		-e 's:^VERSION=.*:VERSION="${TYPE} ${BRANCH} ${REVISION}":' \
		"${S}/conf/newvers.sh"

	# __FreeBSD_cc_version comes from FreeBSD's gcc.
	# on 9.0-RELEASE it's 900001.
	sed -e "s:-D_KERNEL:-D_KERNEL -D__FreeBSD_cc_version=900001:g" \
		-i "${S}/conf/kern.pre.mk" \
		-i "${S}/conf/kmod.mk" || die "Couldn't set __FreeBSD_cc_version"

	# Remove -Werror
	sed -e "s:-Werror:-Wno-error:g" \
		-i "${S}/conf/kern.pre.mk" \
		-i "${S}/conf/kmod.mk" || die
}

src_compile() {
	einfo "Nothing to compile.."
}

src_install() {
	insinto "/usr/src/sys-${MY_PVR}"
	doins -r "${S}/"*
}

pkg_postinst() {
	if [[ ! -L "${ROOT}/usr/src/sys" ]]; then
		einfo "/usr/src/sys symlink doesn't exist; creating symlink to sys-${MY_PVR}..."
		ln -sf "sys-${MY_PVR}" "${ROOT}/usr/src/sys" || \
			eerror "Couldn't create ${ROOT}/usr/src/sys symlink."
		# just in case...
		[[ -L ""${ROOT}/usr/src/sys-${RV}"" ]] && rm "${ROOT}/usr/src/sys-${RV}"
		ln -sf "sys-${MY_PVR}" "${ROOT}/usr/src/sys-${RV}" || \
			eerror "Couldn't create ${ROOT}/usr/src/sys-${RV} symlink."
	elif use symlink; then
		einfo "Updating /usr/src/sys symlink to sys-${MY_PVR}..."
		rm "${ROOT}/usr/src/sys" "${ROOT}/usr/src/sys-${RV}" || \
			eerror "Couldn't remove previous symlinks, please fix manually."
		ln -sf "sys-${MY_PVR}" "${ROOT}/usr/src/sys" || \
			eerror "Couldn't create ${ROOT}/usr/src/sys symlink."
		ln -sf "sys-${MY_PVR}" "${ROOT}/usr/src/sys-${RV}" || \
			eerror "Couldn't create ${ROOT}/usr/src/sys-${RV} symlink."
	fi

	if use sparc-fbsd ; then
		ewarn "WARNING: kldload currently causes kernel panics"
		ewarn "on sparc64. This is probably a gcc-4.1 issue, but"
		ewarn "we need gcc-4.1 to compile the kernel correctly :/"
		ewarn "Please compile all modules you need into the kernel"
	fi
}
