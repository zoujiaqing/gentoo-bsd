#!/bin/bash
export TARGETVER="${TARGETVER:-9.1}"
export MKSRC="${MKSRC:-NONE}"
export WORKDATE="${WORKDATE:-local}"
export WORKARCH="`uname -m`"
OLDVER="${OLDVER:-9.0}"
OVERLAY_SNAPSHOT="http://git.overlays.gentoo.org/gitweb/?p=proj/gentoo-bsd.git;a=snapshot;h=HEAD;sf=tgz"

prepare(){
	if [ -n "${STABLE}" ] ; then
		local MAJORVER=`echo ${TARGETVER} | awk -F \. '{ print $1 }'`
	fi
	if [ -n "${MAJORVER}" ] ; then
		local CHOSTVER="${MAJORVER}.0"
	else
		local CHOSTVER="${TARGETVER}"
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

	if [ ! -e "/var/tmp/catalyst/builds/default/stage3-${TARGETSUBARCH}-freebsd-${OLDVER}.tar.bz2" ] ; then
		echo "Downloading aballier's ${TARGETSUBARCH} stage3 file..."
		wget -q -P /var/tmp/catalyst/builds/default http://dev.gentoo.org/~aballier/fbsd${OLDVER}/${TARGETARCH}/stage3-${TARGETSUBARCH}-freebsd-${OLDVER}.tar.bz2
		if [ $? -ne 0 ] ; then
			exit 1
		fi
	fi

	cd ${WORKDIR}
	if [ -d "${HOME}/portage.bsd-overlay" ] ; then
		echo "Copy from ${HOME}/portage.bsd-overlay to ${WORKDIR}/"
		cp -a "${HOME}/portage.bsd-overlay" ${WORKDIR}/
	else
		echo "Downloading gentoo-bsd overlay snapshot..."
		wget -q -O bsd-overlay.tar.gz "${OVERLAY_SNAPSHOT}"
		if [ $? -ne 0 ] ; then
			exit 1
		fi

		if [ -e "${WORKDIR}/portage.bsd-overlay" ] ; then
			rm -rf ${WORKDIR}/portage.bsd-overlay
		fi

		tar xzf bsd-overlay.tar.gz
		mv gentoo-bsd-* ${WORKDIR}/portage.bsd-overlay
	fi

	# <app-text/build-docbook-catalog-1.19, Bug 412201
	# =app-arch/libarchive-3.0.3, Bug 421191
	echo "emerging catalyst..."
	PORTDIR_OVERLAY=${WORKDIR}/portage.bsd-overlay ACCEPT_KEYWORDS=~x86-fbsd emerge -uq app-cdr/cdrtools '<app-text/build-docbook-catalog-1.19' dev-util/catalyst::gentoo-bsd =app-arch/libarchive-3.0.3 || exit 1
	grep "^export MAKEOPTS" /etc/catalyst/catalystrc > /dev/null 2>&1
	if [ $? -ne 0 ] ; then
		echo "export MAKEOPTS=\"-j`sysctl hw.ncpu | awk '{ print $2 + 1 }'`"\" >> /etc/catalyst/catalystrc
	fi

	if [ ! -e /usr/portage/profiles/releases/freebsd-${TARGETVER} ] ; then
		echo "prepare new ${TARGETVER} profiles"
		cp -a ${WORKDIR}/portage.bsd-overlay/profiles/default/bsd/fbsd/amd64/${TARGETVER} /usr/portage/profiles/default/bsd/fbsd/amd64/
		cp -a ${WORKDIR}/portage.bsd-overlay/profiles/default/bsd/fbsd/x86/${TARGETVER} /usr/portage/profiles/default/bsd/fbsd/x86/
		cp -a ${WORKDIR}/portage.bsd-overlay/profiles/releases/freebsd-${TARGETVER} /usr/portage/profiles/releases/
	fi

	if [ "${MKSRC}" != "NONE" ] ; then
		if [ "${MKSRC}" = "release" ] ; then
			MY_MKSRC=""
		else
			MY_MKSRC="_${MKSRC}"
		fi
		if [ ! -e /usr/portage/distfiles/freebsd-lib-${TARGETVER}${MY_MKSRC}.tar.bz2 ] ; then
			echo "create src tarball"
			mkdir ${WORKDIR}/${TARGETVER}${MY_MKSRC}_src
			cd ${WORKDIR}/${TARGETVER}${MY_MKSRC}_src
			${WORKDIR}/portage.bsd-overlay/scripts/extract-9.0.sh ${TARGETVER}${MY_MKSRC}
			mkdir -p /usr/portage/distfiles
			mv *${TARGETVER}${MY_MKSRC}*bz2 /usr/portage/distfiles/
		fi

		ls -1 /usr/portage/sys-freebsd/freebsd-lib/freebsd-lib-${TARGETVER}*.ebuild > /dev/null 2>&1
		if [ $? -eq 0 ] ; then
			create_manifest /usr/portage/sys-freebsd
			export WORKDATE="local"
		fi
		create_manifest ${WORKDIR}/portage.bsd-overlay/sys-freebsd
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
	else
		export WORKDATE="`date +%Y%m%d`"
	fi

	#fixes bug 447808
	grep "python_targets_python2_7" /usr/portage/profiles/default/bsd/fbsd/make.defaults > /dev/null 2>&1
	if [ $? -ne 0 ] ; then
		gsed -i 's:BOOTSTRAP_USE="\(.*\)":BOOTSTRAP_USE="\1 python_targets_python2_7":g' /usr/portage/profiles/default/bsd/fbsd/make.defaults
	fi

	if [ -n "${STABLE}" ] ; then
		echo "create stages, mixed stable ${TARGETARCH} and minimal ${TARGETARCH}-fbsd flag on"
		mkdir -p ${WORKDIR}/portage.bsd-overlay/scripts/mkstages/etc/portage/profile
		cp -a ${WORKDIR}/portage.bsd-overlay/scripts/mkstages/minimal-fbsd-list ${WORKDIR}/portage.bsd-overlay/scripts/mkstages/etc/portage/package.keywords
		echo "ACCEPT_KEYWORDS=\"-${TARGETARCH}-fbsd -~${TARGETARCH}-fbsd ${TARGETARCH}\"" >> ${WORKDIR}/portage.bsd-overlay/scripts/mkstages/etc/portage/profile/make.defaults
		echo "CHOST=\"${CATALYST_CHOST}\"" >> ${WORKDIR}/portage.bsd-overlay/scripts/mkstages/etc/portage/profile/make.defaults
		echo "FEATURES=\"preserve-libs\"" >> ${WORKDIR}/portage.bsd-overlay/scripts/mkstages/etc/portage/profile/make.defaults
		echo "sys-apps/portage python2" >> ${WORKDIR}/portage.bsd-overlay/scripts/mkstages/etc/portage/package.use

		#fixes bug 443810
		grep "app-editors/nano" /usr/portage/profiles/default/bsd/fbsd/packages > /dev/null 2>&1
		if [ $? -ne 0 ] ; then
			echo "*app-editors/nano" >> ${WORKDIR}/portage.bsd-overlay/scripts/mkstages/etc/portage/profile/packages
		fi
		#fixes bug 447810
		mkdir -p ${WORKDIR}/portage.bsd-overlay/scripts/mkstages/etc/portage/patches/app-shells/bash
		wget -q -O ${WORKDIR}/portage.bsd-overlay/scripts/mkstages/etc/portage/patches/app-shells/bash/bash-4.2-redir-fbsd.patch "https://447810.bugs.gentoo.org/attachment.cgi?id=333210"
	fi
}

create_manifest(){
	local rootdir=$1

	if [ -d ${rootdir} ] ; then
		cd ${rootdir}
		echo "re-create Manifest"
		for dir in `ls -1 | grep freebsd-` boot0;
		do
			cd ${dir}
			ls -1 *${TARGETVER}*.ebuild > /dev/null 2>&1
			if [ $? -eq 0 ] ; then
				gsed -i "/${TARGETVER}/d" Manifest
				ls -1 *${TARGETVER}${MY_MKSRC}*.ebuild > /dev/null 2>&1
				if [[ "${MKSRC}" = "release" || $? -ne 0 ]] ; then
					EBUILDFILE=`ls -1 *${TARGETVER}*.ebuild | tail -n 1`
					echo "copy ${EBUILDFILE} to ${TARGETVER}${MY_MKSRC}.ebuild"
					gsed -i '/cve-2012-4576.patch/d' ${EBUILDFILE}
					cp ${EBUILDFILE} ${dir}-${TARGETVER}${MY_MKSRC}.ebuild
				fi

				ls -1 *.ebuild > /dev/null 2>&1

				if [ $? -eq 0 ] ; then
					EBUILDFILE=`ls -1 *.ebuild | tail -n 1`
					echo ${EBUILDFILE}
					ebuild ${EBUILDFILE} digest
				fi
			fi
			cd ..
		done
	fi
}

upgrade_src_stage3(){
	if [ -e ${WORKDIR}/stage3tmp ] ; then
		chflags -R noschg ${WORKDIR}/stage3tmp
		rm -rf ${WORKDIR}/stage3tmp
	fi
	mkdir ${WORKDIR}/stage3tmp
	tar xjpf /var/tmp/catalyst/builds/default/stage3-${TARGETSUBARCH}-freebsd-${OLDVER}.tar.bz2 -C ${WORKDIR}/stage3tmp
	mount -t devfs devfs ${WORKDIR}/stage3tmp/dev
	mkdir ${WORKDIR}/stage3tmp/usr/portage
	kldload nullfs
	mount -t nullfs /usr/portage ${WORKDIR}/stage3tmp/usr/portage
	mount -t nullfs /usr/portage/distfiles ${WORKDIR}/stage3tmp/usr/portage/distfiles

	cp -a ${WORKDIR}/portage.bsd-overlay/scripts/mkstages/chroot_prepare_upgrade.sh ${WORKDIR}/stage3tmp/tmp
	cp -a ${WORKDIR}/portage.bsd-overlay ${WORKDIR}/stage3tmp/usr/local/
	if [ -e ${WORKDIR}/portage.bsd-overlay/scripts/mkstages/etc/portage ] ; then
		cp -a ${WORKDIR}/portage.bsd-overlay/scripts/mkstages/etc/portage/* ${WORKDIR}/stage3tmp/etc/portage/
	fi
	if [ -e /etc/catalyst/catalystrc ] ; then
		cp -a /etc/catalyst/catalystrc ${WORKDIR}/stage3tmp/tmp
	fi
	echo 'PORTDIR_OVERLAY="/usr/local/portage.bsd-overlay"' >> ${WORKDIR}/stage3tmp/etc/make.conf

	if [ -e /etc/resolv.conf ]; then
		cp /etc/resolv.conf ${WORKDIR}/stage3tmp/etc/
	else
		echo "nameserver 8.8.8.8" > ${WORKDIR}/stage3tmp/etc/resolv.conf
	fi
	chroot ${WORKDIR}/stage3tmp /tmp/chroot_prepare_upgrade.sh
	umount ${WORKDIR}/stage3tmp/usr/portage/distfiles
	umount ${WORKDIR}/stage3tmp/usr/portage || exit 1
	umount ${WORKDIR}/stage3tmp/dev || exit 1
	if [ ! -e ${WORKDIR}/stage3tmp/tmp/prepare_done ] ; then
		exit 1
	fi
	cd ${WORKDIR}/stage3tmp
	tar cjpf /var/tmp/catalyst/builds/default/stage3tmp-${TARGETSUBARCH}-freebsd-${TARGETVER}.tar.bz2 .
	cd ${WORKDIR}
	chflags -R noschg ${WORKDIR}/stage3tmp
	rm -rf ${WORKDIR}/stage3tmp
}

check_ecompressdir() {
	# dirty solution
	# /dev is still mounted; performing auto-bind-umount... 
	local PID=`ps auxw | grep portage/bin/ebuild-helpers/ecompressdir | grep -v grep | awk '{ print $2 }' | xargs`
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
		if [ "${C_TARGET}" != "stage3" ] ; then
			C_APPEND_OPT="${C_APPEND_OPT} chost=${CATALYST_CHOST}"
		fi
		if [ -n "${STABLE}" ] ; then
			C_APPEND_OPT="${C_APPEND_OPT} portage_confdir=${WORKDIR}/portage.bsd-overlay/scripts/mkstages/etc/portage"
		fi

		catalyst -C target=${C_TARGET} version_stamp=fbsd-${TARGETVER}-${WORKDATE}${C_APPEND_VERSION} profile=default/bsd/fbsd/${TARGETARCH}/${TARGETVER} snapshot=${WORKDATE} source_subpath=default/${C_SOURCE} subarch=${TARGETSUBARCH} rel_type=default portage_overlay=${WORKDIR}/portage.bsd-overlay ${C_APPEND_OPT}

		if [ $? -ne 0 ] ; then
			check_ecompressdir "${C_TARGET}-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_APPEND_VERSION}/usr/local/portage"
			if [ $? -ne 0 ] ; then
				catalyst -C target=${C_TARGET} version_stamp=fbsd-${TARGETVER}-${WORKDATE}${C_APPEND_VERSION} profile=default/bsd/fbsd/${TARGETARCH}/${TARGETVER} snapshot=${WORKDATE} source_subpath=default/${C_SOURCE} subarch=${TARGETSUBARCH} rel_type=default portage_overlay=${WORKDIR}/portage.bsd-overlay ${C_APPEND_OPT} || exit 1
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
	local C_TMP_APPEND_VERSION="t"

	if [ "${OLDVER}" != "${TARGETVER}" ] ; then
		local SOURCE_STAGE3="stage3tmp-${TARGETSUBARCH}-freebsd-${TARGETVER}"
	else
		local SOURCE_STAGE3="stage3-${TARGETSUBARCH}-freebsd-${OLDVER}"
	fi

	run_catalyst stage1 ${SOURCE_STAGE3} ${C_TMP_APPEND_VERSION}

	### Added when the library was upgraded
	ln -s libmpfr.so.5 /var/tmp/catalyst/tmp/default/stage1-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_TMP_APPEND_VERSION}/tmp/stage1root/usr/lib/libmpfr.so.4
	ln -s libmpc.so /var/tmp/catalyst/tmp/default/stage1-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_TMP_APPEND_VERSION}/tmp/stage1root/usr/lib/libmpc.so.2
	ln -s libmpc.so /var/tmp/catalyst/tmp/default/stage1-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_TMP_APPEND_VERSION}/tmp/stage1root/usr/lib/libmpc.so.2.0.0

	run_catalyst stage2 stage1-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_TMP_APPEND_VERSION} ${C_TMP_APPEND_VERSION}
	run_catalyst stage3 stage2-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_TMP_APPEND_VERSION} ${C_TMP_APPEND_VERSION}


	run_catalyst stage1 stage3-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}${C_TMP_APPEND_VERSION}
	run_catalyst stage2 stage1-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}
	run_catalyst stage3 stage2-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}

}

if [ -e /etc/catalyst/catalystrc ] ; then
	source /etc/catalyst/catalystrc
fi

prepare $1

if [ ! -e "/var/tmp/catalyst/snapshots/portage-${WORKDATE}.tar.bz2" ] ; then
	catalyst -C target=snapshot version_stamp=${WORKDATE} || exit 1
fi

if [ ! -e "/var/tmp/catalyst/builds/default/stage3tmp-${TARGETSUBARCH}-freebsd-${TARGETVER}.tar.bz2" ] && [ "${OLDVER}" != "${TARGETVER}" ] ; then
	upgrade_src_stage3
	echo "upgrade done"
fi

mk_stages

