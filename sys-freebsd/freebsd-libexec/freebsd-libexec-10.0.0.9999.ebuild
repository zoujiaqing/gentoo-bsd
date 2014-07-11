# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

inherit bsdmk freebsd pam multilib multibuild multilib-build

DESCRIPTION="FreeBSD libexec things"
SLOT="0"

if [[ ${PV} != *9999* ]]; then
	KEYWORDS="~amd64-fbsd ~sparc-fbsd ~x86-fbsd"
	SRC_URI="mirror://gentoo/${LIBEXEC}.tar.xz
		mirror://gentoo/${UBIN}.tar.xz
		mirror://gentoo/${BIN}.tar.xz
		mirror://gentoo/${CONTRIB}.tar.xz
		mirror://gentoo/${LIB}.tar.xz
		mirror://gentoo/${ETC}.tar.xz
		mirror://gentoo/${USBIN}.tar.xz"
fi

RDEPEND="=sys-freebsd/freebsd-lib-${RV}*
	>=sys-freebsd/freebsd-lib-9.1-r11[${MULTILIB_USEDEP}]
	pam? ( virtual/pam )"
DEPEND="${RDEPEND}
	=sys-freebsd/freebsd-mk-defs-${RV}*
	=sys-freebsd/freebsd-sources-${RV}*"
RDEPEND="${RDEPEND}
	xinetd? ( sys-apps/xinetd )"

S="${WORKDIR}/libexec"

# Remove sendmail, tcp_wrapper and other useless stuff
REMOVE_SUBDIRS="smrsh mail.local tcpd telnetd rshd rlogind lukemftpd ftpd"

IUSE="pam ssl kerberos ipv6 nis xinetd"

PATCHES=( "${FILESDIR}/${PN}-9.2-no_ld32.patch"
	"${FILESDIR}/${PN}-10.0-atf-check.patch" )

pkg_setup() {
	use ipv6 || mymakeopts="${mymakeopts} WITHOUT_INET6= WITHOUT_INET6_SUPPORT= "
	use kerberos || mymakeopts="${mymakeopts} WITHOUT_KERBEROS_SUPPORT= "
	use nis || mymakeopts="${mymakeopts} WITHOUT_NIS= "
	use pam || mymakeopts="${mymakeopts} WITHOUT_PAM_SUPPORT= "
	use ssl || mymakeopts="${mymakeopts} WITHOUT_OPENSSL= "

	mymakeopts="${mymakeopts} WITHOUT_SENDMAIL= WITHOUT_PF= WITHOUT_RCMDS= "
}

src_prepare() {
	if [[ ! -e "${WORKDIR}/include" ]]; then
		ln -s /usr/include "${WORKDIR}/include" || die "Symlinking /usr/include.."
	fi
}

setup_multilib_vars() {
	if ! multilib_is_native_abi ; then
		cd "${WORKDIR}/libexec/rtld-elf" || die
		export mymakeopts="${mymakeopts} PROG=ld-elf32.so.1"
	else
		cd "${S}"
	fi
	"$@"
}

src_compile() {
	local MULTIBUILD_VARIANTS=( $(multilib_get_enabled_abis) )
	multibuild_foreach_variant freebsd_multilib_multibuild_wrapper setup_multilib_vars freebsd_src_compile
}

src_install() {
	local MULTIBUILD_VARIANTS=( $(multilib_get_enabled_abis) )
	multibuild_foreach_variant freebsd_multilib_multibuild_wrapper setup_multilib_vars freebsd_src_install

	insinto /etc
	doins "${WORKDIR}/etc/gettytab"
	newinitd "${FILESDIR}/bootpd.initd" bootpd
	newconfd "${FILESDIR}/bootpd.confd" bootpd

	if use xinetd; then
		for rpcd in rstatd rusersd walld rquotad sprayd; do
			insinto /etc/xinetd.d
			newins "${FILESDIR}/${rpcd}.xinetd" ${rpcd}
		done
	fi
}