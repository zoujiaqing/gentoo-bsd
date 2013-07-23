# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $
#
# Diego Pettenò <flameeyes@gentoo.org>

inherit versionator eutils flag-o-matic bsdmk

MY_PV=${PV/_p*}
PLEVEL=${PV##*_p}

LICENSE="BSD"
HOMEPAGE="http://www.freebsd.org/"

# Define global package names
LIB="freebsd-lib-${PV}"
BIN="freebsd-bin-${PV}"
CONTRIB="freebsd-contrib-${PV}"
SHARE="freebsd-share-${PV}"
UBIN="freebsd-ubin-${PV}"
USBIN="freebsd-usbin-${PV}"
CRYPTO="freebsd-crypto-${PV}"
LIBEXEC="freebsd-libexec-${PV}"
SBIN="freebsd-sbin-${PV}"
GNU="freebsd-gnu-${PV}"
ETC="freebsd-etc-${PV}"
SYS="freebsd-sys-${PV}"
INCLUDE="freebsd-include-${PV}"
RESCUE="freebsd-rescue-${PV}"
CDDL="freebsd-cddl-${PV}"

# Release version (5.3, 5.4, 6.0, etc)
# Drop patch level from RV using ${MY_PV}.
RV="$(get_version_component_range 1-2 ${MY_PV})"

if [[ ${PV} == *9999* ]]; then
	inherit subversion

	# Set SVN revision using patch level.
	[[ ${PV} == *_p* ]] && ESVN_REVISION="${PLEVEL}"

	# freebsd-mk-defs is always run svn checkout/update.
	# Other packages use sources that it checked out.
	[[ ${PN} == "freebsd-mk-defs" ]] || ESVN_OFFLINE="1"

	case ${MY_PV%.9999} in
		*.*.*)	BRANCH="release";;
		*.*)	BRANCH="releng"	;;
		9999)	BRANCH="head"	;;
		*)	BRANCH="stable"	;;
	esac
	[[ ${BRANCH} == head ]] || SVN_SUB_URI="${BRANCH}/${MY_PV%.9999}"
	[[ ${BRANCH} == head ]] && SVN_SUB_URI="${BRANCH}"
	ESVN_REPO_URI="svn://svn.freebsd.org/base/${SVN_SUB_URI}"
	ESVN_PROJECT="freebsd-${BRANCH}"
fi

if [[ ${PN} != "freebsd-share" ]] && [[ ${PN} != freebsd-sources ]]; then
	IUSE="profile"
fi

#unalias -a
alias install-info='/usr/bin/bsdinstall-info'

EXPORT_FUNCTIONS src_compile src_install src_unpack

# doperiodic <kind> <file> ...
doperiodic() {
	local kind=$1
	shift

	( # dont want to pollute calling env
		insinto /etc/periodic/${kind}
		insopts -m 0755
		doins "$@"
	)
}

freebsd_get_bmake() {
	local bmake
	bmake=$(get_bmake)
	[[ ${CBUILD} == *-freebsd* ]] || bmake="${bmake} -m /usr/share/mk/freebsd"

	echo "${bmake}"
}

freebsd_do_patches() {
	if [[ ${#PATCHES[@]} -gt 1 ]] ; then
		for x in "${PATCHES[@]}"; do
			epatch "${x}"
		done
	else
		for x in ${PATCHES} ; do
			epatch "${x}"
		done
	fi
	epatch_user
}

freebsd_rename_libraries() {
	ebegin "Renaming libraries"
	# We don't use libtermcap, we use libncurses
	find "${S}" -name Makefile -print0 | xargs -0 \
		sed -i -e 's:-ltermcap:-lncurses:g; s:{LIBTERMCAP}:{LIBNCURSES}:g'
	# flex provides libfl, not libl
	find "${S}" -name Makefile -print0 | xargs -0 \
		sed -i -e 's:-ll$:-lfl:g; s:-ll :-lfl :g; s:{LIBL}:{LIBFL}:g'
	# ncurses provides libncursesw not libcursesw
	find "${S}" -name Makefile -print0 | xargs -0 \
		sed -i -e 's:-lcursesw:-lncursesw:g'
	# we use expat instead of bsdxml
	find "${S}" -name Makefile -print0 | xargs -0 \
		sed -i -e 's:-lbsdxml:-lexpat:g'

	eend $?
}

freebsd_src_unpack() {
	if [[ ${PV} == *9999* ]]; then
		S="${WORKDIR}" subversion_src_unpack
	else
		unpack ${A}
	fi
	cd "${S}"

	dummy_mk ${REMOVE_SUBDIRS}

	freebsd_do_patches
	freebsd_rename_libraries
}

freebsd_src_compile() {
	use profile && filter-flags "-fomit-frame-pointer"
	use profile || mymakeopts="${mymakeopts} NO_PROFILE= "

	mymakeopts="${mymakeopts} NO_MANCOMPRESS= NO_INFOCOMPRESS= NO_FSCHG="

	# Make sure to use FreeBSD definitions while crosscompiling
	[[ -z "${BMAKE}" ]] && BMAKE="$(freebsd_get_bmake)"

	# Support for upgrade from a previous version.
	# If install command does not support -l option, this is necessary.
	if [[ ${RV} > 9.1 ]] && [[ ${PV} != *9999* ]] && has_version '<sys-freebsd/freebsd-ubin-9.2_beta1' ; then
		export INSTALL_LINK="ln -f"
		export INSTALL_SYMLINK="ln -fs"
	fi

	# Create objdir if MAKEOBJDIRPREFIX is defined, so that we can make out of
	# tree builds easily.
	if [[ -n "${MAKEOBJDIRPREFIX}" ]] ; then
		mkmake obj || die
	fi

	bsdmk_src_compile
}

# Helper function to make a multilib build with FreeBSD Makefiles.
# Usage: 
# MULTIBUILD_VARIANTS=( $(get_all_abis) )
# multibuild_foreach_variant freebsd_multilib_multibuild_wrapper my_function
#
# Important note: To use this function you _have_ to:
# - inherit multilib.eclass and multibuild.eclass
# - set MULTILIB_VARIANTS
# - have a multilib useflag in IUSE

freebsd_multilib_multibuild_wrapper() {
	# Get the ABI from multibuild.eclass
	# This assumes MULTILIB_VARIANTS contains only valid ABIs.
	local ABI=${MULTIBUILD_VARIANT}

	# First, save the variables: CFLAGS, CXXFLAGS, LDFLAGS, LDADD and mymakeopts.
	for i in CFLAGS CXXFLAGS LDFLAGS LDADD mymakeopts ; do
		export ${i}_SAVE="${!i}"
	done

	# Setup the variables specific to this ABI.
	multilib_toolchain_setup "${ABI}"

	local target="$(tc-arch-kernel ${CHOST})"
	mymakeopts="${mymakeopts} TARGET=${target} MACHINE=${target} MACHINE_ARCH=${target} SHLIBDIR=/usr/$(get_libdir) LIBDIR=/usr/$(get_libdir)"
	if use multilib && [ "${ABI}" != "${DEFAULT_ABI}" ] ; then
		mymakeopts="${mymakeopts} COMPAT_32BIT="
	fi

	einfo "Building for ABI=${ABI} and TARGET=${target}"

	export MAKEOBJDIRPREFIX="${BUILD_DIR}"
	if [ ! -d "${MAKEOBJDIRPREFIX}" ] ; then
		mkdir "${MAKEOBJDIRPREFIX}" || die "Could not create ${MAKEOBJDIRPREFIX}."
	fi
	
	CTARGET="${CHOST}" "$@"
	
	# Restore the variables now.
	for i in CFLAGS CXXFLAGS LDFLAGS LDADD mymakeopts ; do
		ii="${i}_SAVE"
		export ${i}="${!ii}"
	done
}

freebsd_src_install() {
	use profile || mymakeopts="${mymakeopts} NO_PROFILE= "

	mymakeopts="${mymakeopts} NO_MANCOMPRESS= NO_INFOCOMPRESS= NO_FSCHG="

	[[ -z "${BMAKE}" ]] && BMAKE="$(freebsd_get_bmake)"

	bsdmk_src_install
}
