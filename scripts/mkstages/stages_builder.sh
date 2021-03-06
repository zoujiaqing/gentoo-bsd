#!/bin/bash
export TARGETVER="${TARGETVER:-9.1}"
export MKSRC="${MKSRC:-NONE}"
export WORKDATE="${WORKDATE:-local}"
export WORKARCH="${WORKARCH:-$(uname -m)}"
export FORCESTAGE3="${FORCESTAGE3:-}"
export EXTRAOVERLAY="${EXTRAOVERLAY:-}"
OLDVER="${OLDVER:-9.0}"
OVERLAY_SNAPSHOT="https://gitweb.gentoo.org/proj/gentoo-bsd.git/snapshot/gentoo-bsd-master.tar.gz"

prepare(){
	local MAJORVER=`echo ${TARGETVER} | awk -F \. '{ print $1 }'`
	if [ -n "${STABLE}" ] ; then
		export CHOSTVER="${MAJORVER}.0"
	else
		export CHOSTVER="${TARGETVER}"
	fi

	if [ "$1" = "x86" ] || [ "${WORKARCH}" = "i386" ] ; then
		export CATALYST_CHOST="i686-gentoo-freebsd${CHOSTVER}"
		export TARGETARCH="x86"
		export TARGETSUBARCH="i686"
	else
		export CATALYST_CHOST="x86_64-gentoo-freebsd${CHOSTVER}"
		export TARGETARCH="amd64"
		export TARGETSUBARCH="amd64"
	fi

	export WORKDIR="/tmp/mk_stages_${TARGETARCH}_${TARGETVER}"
	[[ -n ${CLANG} ]] && WORKDIR="${WORKDIR}_clang"

	if [ -e ${WORKDIR} ] ; then
		echo "WORKDIR ${WORKDIR} is already exists."
		echo "Please remove manually it."
		echo ""
		echo "chflags -R noschg ${WORKDIR} && rm -rf ${WORKDIR}"
		exit 1
	else
		mkdir -p ${WORKDIR}
	fi

	if [ ! -e "/var/tmp/catalyst/builds/default" ] ; then
		mkdir -p /var/tmp/catalyst/builds/default
	fi

	if [ -z "${FORCESTAGE3}" ] ; then
		if [ -z "${CLANG}" ] ; then
			local oldstage3fn="stage3-${TARGETSUBARCH}-freebsd-${OLDVER}"
			local oldstage3url="http://dev.gentoo.org/~aballier/fbsd${OLDVER}/${TARGETARCH}/${oldstage3fn}.tar.bz2"
		else
			local oldstage3fn="stage3-${TARGETSUBARCH}-clangfbsd-${OLDVER}"
			local oldstage3url="http://dev.gentoo.org/~aballier/fbsd${OLDVER}/${TARGETARCH}/clang/${oldstage3fn}.tar.bz2"
		fi

		if [ ! -e "/var/tmp/catalyst/builds/default/${oldstage3fn}.tar.bz2" ] ; then
			echo "Downloading aballier's ${TARGETSUBARCH} stage3 file..."
			wget -q -P /var/tmp/catalyst/builds/default "${oldstage3url}"
			[[ $? -ne 0 ]] && exit 1
		fi
		export FORCESTAGE3="${oldstage3fn}"
	fi

	cd ${WORKDIR}
	if [ -d "${HOME}/gentoo-bsd" ] ; then
		echo "Copy from ${HOME}/gentoo-bsd to ${WORKDIR}/"
		cp -a "${HOME}/gentoo-bsd" ${WORKDIR}/
	else
		echo "Clone gentoo-bsd overlay snapshot..."
		wget -q -O "${WORKDIR}"/gentoo-bsd.tar.gz "${OVERLAY_SNAPSHOT}"
		[[ $? -ne 0 ]] && exit 1
		mkdir -p ${WORKDIR}/gentoo-bsd
		tar xzf "${WORKDIR}"/gentoo-bsd.tar.gz --strip-components=1 -C "${WORKDIR}/gentoo-bsd"
	fi
	if [ -n "${EXTRAOVERLAY}" ] ; then
		if [[ "${EXTRAOVERLAY}" =~ ^http ]]; then
			echo "Downloading extra overlay."
			wget -q -O ${WORKDIR}/extraoverlay.tar.bz2 "${EXTRAOVERLAY}"
			[[ $? -ne 0 ]] && exit 1
			echo "Copy from ${WORKDIR}/extraoverlay to ${WORKDIR}/gentoo-bsd"
			mkdir ${WORKDIR}/extraoverlay
			tar xjf ${WORKDIR}/extraoverlay.tar.bz2 --strip-components=1 -C ${WORKDIR}/extraoverlay
			cp -a ${WORKDIR}/extraoverlay/* ${WORKDIR}/gentoo-bsd/
		else
			echo "Copy from ${EXTRAOVERLAY} to ${WORKDIR}/gentoo-bsd"
			cp -a ${EXTRAOVERLAY}/* ${WORKDIR}/gentoo-bsd/
		fi
	fi

	if [[ ! -e /usr/bin/catalyst ]] ; then
		echo "emerging catalyst..."
		PORTDIR_OVERLAY=${WORKDIR}/gentoo-bsd ACCEPT_KEYWORDS=~x86-fbsd emerge -uq app-cdr/cdrtools app-text/build-docbook-catalog || exit 1
		PORTDIR_OVERLAY=${WORKDIR}/gentoo-bsd ACCEPT_KEYWORDS=~x86-fbsd emerge -q dev-util/catalyst::gentoo-bsd || exit 1
	fi

	if [ ! -e /usr/portage/profiles/releases/freebsd-${TARGETVER} ] ; then
		echo "prepare new ${TARGETVER} profiles"
		cp -a ${WORKDIR}/gentoo-bsd/profiles/arch/amd64-fbsd/clang /usr/portage/profiles/arch/amd64-fbsd/
		cp -a ${WORKDIR}/gentoo-bsd/profiles/default/bsd/fbsd/amd64/${TARGETVER} /usr/portage/profiles/default/bsd/fbsd/amd64/
		cp -a ${WORKDIR}/gentoo-bsd/profiles/default/bsd/fbsd/x86/${TARGETVER} /usr/portage/profiles/default/bsd/fbsd/x86/
		cp -a ${WORKDIR}/gentoo-bsd/profiles/releases/freebsd-${TARGETVER} /usr/portage/profiles/releases/

		cat <<- _EOF_ >> /usr/portage/profiles/profiles.desc
			amd64-fbsd default/bsd/fbsd/amd64/${TARGETVER} dev
			amd64-fbsd default/bsd/fbsd/amd64/${TARGETVER}/clang dev
			x86-fbsd default/bsd/fbsd/x86/${TARGETVER} dev
		_EOF_
	fi

	if [ "${WORKDATE}" = "remote" ] ; then
		wget -q -O ${WORKDIR}/snapshot_list.html http://distfiles.gentoo.org/snapshots/
		export WORKDATE=`grep -e 'portage-[0-9]\+.*bz2' ${WORKDIR}/snapshot_list.html | tail -n 1 | gsed 's:.*portage-\([0-9]\+\).*:\1:g'`
		mkdir -p /var/tmp/catalyst/snapshots
		if [ ! -e "/var/tmp/catalyst/snapshots/portage-${WORKDATE}.tar.bz2" ] ; then
			wget -q -P /var/tmp/catalyst/snapshots "http://distfiles.gentoo.org/snapshots/portage-${WORKDATE}.tar.bz2"
			if [ $? -ne 0 ] ; then
				export WORKDATE="`date +%Y%m%d`"
			fi
		fi
	elif [ "${WORKDATE}" = "resume" ] ; then
		ls -1 /var/tmp/catalyst/snapshots/*bz2 > /dev/null 2>&1
		if [ $? -eq 0 ] ; then
			export WORKDATE="`ls -1 /var/tmp/catalyst/snapshots/*bz2 | tail -n 1 | gsed 's:.*portage-\([0-9]\+\).*:\1:g'`"
		else
			export WORKDATE="`date +%Y%m%d`"
		fi
	elif [ "${WORKDATE}" = "local" ] ; then
		export WORKDATE="`date +%Y%m%d`"
	else
		export WORKDATE="${WORKDATE}"
	fi

	if [ -n "${STABLE}" ] ; then
		echo "create stages, mixed stable ${TARGETARCH} and minimal ${TARGETARCH}-fbsd flag on"
		mkdir -p ${WORKDIR}/gentoo-bsd/scripts/mkstages/etc/portage/profile
		mkdir -p ${WORKDIR}/gentoo-bsd/scripts/mkstages/etc/portage/package.keywords
		cp -a ${WORKDIR}/gentoo-bsd/scripts/mkstages/minimal-fbsd-list ${WORKDIR}/gentoo-bsd/scripts/mkstages/etc/portage/package.keywords/
		echo "ACCEPT_KEYWORDS=\"-${TARGETARCH}-fbsd -~${TARGETARCH}-fbsd ${TARGETARCH}\"" >> ${WORKDIR}/gentoo-bsd/scripts/mkstages/etc/portage/profile/make.defaults
		echo "CHOST=\"${CATALYST_CHOST}\"" >> ${WORKDIR}/gentoo-bsd/scripts/mkstages/etc/portage/profile/make.defaults
		echo 'CHOST_amd64_fbsd="${CHOST}"' >> ${WORKDIR}/gentoo-bsd/scripts/mkstages/etc/portage/profile/make.defaults
		echo "CHOST_x86_fbsd=\"i686-gentoo-freebsd${CHOSTVER}\"" >> ${WORKDIR}/gentoo-bsd/scripts/mkstages/etc/portage/profile/make.defaults
		echo "FEATURES=\"preserve-libs\"" >> ${WORKDIR}/gentoo-bsd/scripts/mkstages/etc/portage/profile/make.defaults
	fi
}

check_ecompressdir() {
	# dirty solution
	# /dev is still mounted; performing auto-bind-umount...
	local PID=`ps auxw | grep ebuild-helpers/ecompressdir | grep -v grep | awk '{ print $2 }' | xargs`
	if [ -n "${PID}" ] ; then
		echo "kill ecompressdir"
		kill -9 ${PID}
		rm -rf "/var/tmp/catalyst/tmp/default/$1" || exit 1
		return 1
	else
		return 0
	fi
}

run_catalyst() {
	local C_TARGET="$1"
	local C_SOURCE="$2"
	local C_APPEND_VERSION="$3"
	local C_APPEND_OPT=""

	if [ ! -e /var/tmp/catalyst/builds/default/${C_TARGET}-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_APPEND_VERSION}.tar.bz2 ] ; then
		local specfile="${WORKDIR}/${C_TARGET}.spec"
		[[ -e "${specfile}" ]] && rm "${specfile}"

		if [ "${C_TARGET}" != "stage3" ] ; then
			echo "chost: ${CATALYST_CHOST}" >> "${specfile}"
		fi
		if [ -n "${STABLE}" ] ; then
			echo "portage_confdir: ${WORKDIR}/gentoo-bsd/scripts/mkstages/etc/portage" >> "${specfile}"
		else
			if [ -e ${WORKDIR}/gentoo-bsd/etc/portage ] ; then
				echo "portage_confdir: ${WORKDIR}/gentoo-bsd/etc/portage" >> "${specfile}"
			fi
		fi
		if [ -n "${CLANG}" ] ; then
			C_APPEND_PROFILE="/clang"
			echo 'cxxflags: -stdlib=libc++ ${CFLAGS}' >> "${specfile}"
		fi

		cat <<- _EOF_ >> "${specfile}"
			target: ${C_TARGET}
			version_stamp: fbsd-${TARGETVER}-${WORKDATE}${C_APPEND_VERSION}
			profile: default/bsd/fbsd/${TARGETARCH}/${TARGETVER}${C_APPEND_PROFILE}
			snapshot: ${WORKDATE}
			source_subpath: default/${C_SOURCE}
			subarch: ${TARGETSUBARCH}
			rel_type: default
		_EOF_

		if [ ! -n "${NOOVERLAY}" ] ; then
			echo "portage_overlay: ${WORKDIR}/gentoo-bsd" >> "${specfile}"
		fi

		catalyst -f "${specfile}"

		if [ $? -ne 0 ] ; then
			check_ecompressdir "${C_TARGET}-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_APPEND_VERSION}/usr/local/portage"
			if [ $? -ne 0 ] ; then
				catalyst -f "${specfile}" ${C_APPEND_OPT}
			fi
		fi

		if [ ! -e /var/tmp/catalyst/builds/default/${C_TARGET}-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_APPEND_VERSION}.tar.bz2 ] ; then
			exit 1
		fi
	else
		echo "${C_TARGET}-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_APPEND_VERSION}.tar.bz2 is exist."
		echo "skip the creation of ${C_TARGET}-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_APPEND_VERSION}"
	fi
}

mk_stages() {
	[[ -n "${CLANG}" ]] && local C_CLANG_APPEND_VERSION="-cl"
	local C_TMP_APPEND_VERSION="${C_CLANG_APPEND_VERSION}t"
	local SOURCE_STAGE3="stage3-${TARGETSUBARCH}-freebsd-${OLDVER}"
	[[ -n ${FORCESTAGE3} ]] && SOURCE_STAGE3="${FORCESTAGE3}"

	run_catalyst stage1 ${SOURCE_STAGE3} ${C_TMP_APPEND_VERSION}
	run_catalyst stage2 stage1-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_TMP_APPEND_VERSION} ${C_TMP_APPEND_VERSION}
	run_catalyst stage3 stage2-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_TMP_APPEND_VERSION} ${C_TMP_APPEND_VERSION}

	run_catalyst stage1 stage3-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_TMP_APPEND_VERSION} ${C_CLANG_APPEND_VERSION}
	run_catalyst stage2 stage1-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_CLANG_APPEND_VERSION} ${C_CLANG_APPEND_VERSION}
	run_catalyst stage3 stage2-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_CLANG_APPEND_VERSION} ${C_CLANG_APPEND_VERSION}
}

if [ -e /etc/catalyst/catalystrc ] ; then
	source /etc/catalyst/catalystrc
fi

prepare $1

if [ ! -e "/var/tmp/catalyst/snapshots/portage-${WORKDATE}.tar.bz2" ] ; then
	catalyst -C target=snapshot version_stamp=${WORKDATE} || exit 1
fi

if [ -e /var/tmp/catalyst/snapshot_cache/${WORKDATE}/portage/eclass/toolchain.eclass ] ; then
	gsed -i 's:SLOT="${GCC_CONFIG_VER}":SLOT="${GCC_BRANCH_VER}":g' /var/tmp/catalyst/snapshot_cache/${WORKDATE}/portage/eclass/toolchain.eclass
fi

mk_stages


