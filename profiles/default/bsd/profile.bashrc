if [[ ${EBUILD_PHASE} == compile ]] ; then
	if grep -q "Assume that mode_t is passed compatibly" ${S} -r --include openat.c; then
		eerror "The source code contains a faulty openat.c unit from gnulib."
		eerror "Please report this on Gentoo Bugzilla in Gentoo/Alt product for component FreeBSD."
		eerror "http://bugs.gentoo.org/enter_bug.cgi?product=Gentoo%2FAlt&component=FreeBSD&op_sys=FreeBSD"
		die "Broken openat.c gnulib unit."
	fi
        if grep -q "test .*==" "${S}" -r --include configure; then
                eerror "Found a non POSIX test construction in a configure script"
                eerror "The configure checks of this package may not function properly"
                eerror "Please report this on Gentoo Bugzilla in Gentoo/Alt product for component FreeBSD."
                eerror "http://bugs.gentoo.org/enter_bug.cgi?product=Gentoo%2FAlt&component=FreeBSD&op_sys=FreeBSD"
        fi
fi

# Hack to avoid every package that uses libiconv/gettext
# install a charset.alias that will collide with libiconv's one
# See bugs 169678, 195148 and 256129.
# Also the discussion on
# http://archives.gentoo.org/gentoo-dev/msg_8cb1805411f37b4eb168a3e680e531f3.xml
bsd-post_src_install() {
        local f
        if [[ ${PN} != "libiconv" && -n $(ls "${D}"/usr/lib*/charset.alias 2>/dev/null) ]]; then
                einfo "automatically removing charset.alias"
                rm -f "${D}"/usr/lib*/charset.alias
        fi
}

# These are because of
# http://archives.gentoo.org/gentoo-dev/msg_529a0806ed2cf841a467940a57e2d588.xml
# The profile-* ones are meant to be used in etc/portage/profile.bashrc by user
# until there is the registration mechanism.
profile-post_src_install() { bsd-post_src_install ; }
        post_src_install() { bsd-post_src_install ; }

# Another hack to fix old versions of install-sh (automake) where a non-gnu
# mkdir is not considered thread-safe (make install errors with -j > 1)

bsd-post_src_unpack() {
	# Do nothing if we don't have patch installed:
	if [[ -z $(type -P gpatch) ]]; then
		return 0
	fi
	local EPDIR="${ECLASSDIR}/ELT-patches/install-sh"
	local EPATCHES="${EPDIR}/1.5.6 ${EPDIR}/1.5.4 ${EPDIR}/1.5"
	local ret=0
	for file in $(find . -name "install-sh" -print); do
		if [[ -n $(egrep "scriptversion=2005|scriptversion=2004" ${file}) ]]; then
			einfo "Automatically patching parallel-make unfriendly install-sh."
			# Stolen from libtool.eclass
			for mypatch in ${EPATCHES}; do
				if gpatch -p0 --dry-run "${file}" "${mypatch}" &> "${T}/patch_install-sh.log"; then
					gpatch -p0 -g0 --no-backup-if-mismatch "${file}" "${mypatch}" \
						&> "${T}/patch_install-sh.log"
					ret=$?
					break
				else
					ret=1
				fi
			done
			if [[ ret -eq 0 ]]; then
				einfo "Patch applied successfully on \"${file}\"."
			else
				ewarn "Unable to apply install-sh patch. "
				ewarn "If you experience errors during install phase, try with MAKEOPTS=\"-j1\""
			fi
		fi
	done
}

if [[ -n $EAPI ]] ; then
	case "$EAPI" in
		0|1)
			profile-post_src_unpack() { bsd-post_src_unpack ; }
			post_src_unpack() { bsd-post_src_unpack ; }
			;;
		*)
			profile_post_src_prepare() { bsd-post_src_unpack ; }
			post_src_prepare() { bsd-post_src_unpack ; }
			;;
	esac
fi
