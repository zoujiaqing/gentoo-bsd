#!/bin/bash
export TARGETVER="${TARGETVER:-9.1}"
export MKSRC="${MKSRC:-rc1}"
export WORKDATE="`date +%Y%m%d`"
export ARCH="`uname -m`"
OLDVER="${OLDVER:-9.0}"
OVERLAY_SNAPSHOT="http://git.overlays.gentoo.org/gitweb/?p=proj/gentoo-bsd.git;a=snapshot;h=HEAD;sf=tgz"

prepare(){
	if [ "$1" = "x86" ] || [ "${ARCH}" = "i386" ] ; then
		export CATALYST_CHOST="i686-gentoo-freebsd${TARGETVER}"
		export TARGETARCH="x86"
		export TARGETSUBARCH="i686"
	else
		export CATALYST_CHOST="x86_64-gentoo-freebsd${TARGETVER}"
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

	echo "emerging catalyst..."
	PORTDIR_OVERLAY=${WORKDIR}/portage.bsd-overlay ACCEPT_KEYWORDS=~x86-fbsd emerge -uq =app-cdr/cdrtools-3.00 '<app-text/build-docbook-catalog-1.19' =dev-util/catalyst-2.0.10.1 =app-arch/libarchive-3.0.3 || exit 1
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

	if [ -n "${MKSRC}" ] ; then
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
			mv *${TARGETVER}${MY_MKSRC}*bz2 /usr/portage/distfiles/
		fi

		cd ${WORKDIR}/portage.bsd-overlay/sys-freebsd
		echo "re-create Manifest"
		for dir in `ls -1 | grep freebsd-` boot0;
		do
			cd ${dir}
			gsed -i "/${TARGETVER}/d" Manifest
			ls -1 *.ebuild > /dev/null 2>&1

			if [ $? -eq 0 ] ; then
				EBUILDFILE=`ls -1 *.ebuild | head -n 1`
				echo ${EBUILDFILE}
				ebuild ${EBUILDFILE} digest
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
	echo 'PORTDIR_OVERLAY="/usr/local/portage.bsd-overlay"' >> ${WORKDIR}/stage3tmp/etc/make.conf

	if [ -e /etc/resolv.conf ]; then
		cp /etc/resolv.conf ${WORKDIR}/stage3tmp/etc/
	else
		echo "nameserver 8.8.8.8" > ${WORKDIR}/stage3tmp/etc/resolv.conf
	fi
	chroot ${WORKDIR}/stage3tmp /tmp/chroot_prepare_upgrade.sh
	umount ${WORKDIR}/stage3tmp/usr/portage/distfiles || exit 1
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

mk_stages_tmp() {
	if [ "${OLDVER}" != "${TARGETVER}" ] ; then
		local SOURCE_STAGE3="stage3tmp-${TARGETSUBARCH}-freebsd-${TARGETVER}"
	else
		local SOURCE_STAGE3="stage3-${TARGETSUBARCH}-freebsd-${OLDVER}"
	fi

	catalyst -C target=stage1 version_stamp=fbsd-${TARGETVER}-${WORKDATE}t profile=default/bsd/fbsd/${TARGETARCH}/${TARGETVER} snapshot=${WORKDATE} source_subpath=default/${SOURCE_STAGE3} subarch=${TARGETSUBARCH} rel_type=default portage_overlay=${WORKDIR}/portage.bsd-overlay chost=${CATALYST_CHOST}

	local PID=`ps auxw | grep portage/bin/ebuild-helpers/ecompressdir | grep -v grep | awk '{ print $2 }' | xargs`
	kill -9 ${PID}
	rm -rf /var/tmp/catalyst/tmp/default/stage1-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}t/usr/local/portage || exit 1

	catalyst -C target=stage1 version_stamp=fbsd-${TARGETVER}-${WORKDATE}t profile=default/bsd/fbsd/${TARGETARCH}/${TARGETVER} snapshot=${WORKDATE} source_subpath=default/${SOURCE_STAGE3} subarch=${TARGETSUBARCH} rel_type=default portage_overlay=${WORKDIR}/portage.bsd-overlay chost=${CATALYST_CHOST} || exit 1

	### Added when the library was upgraded
	ln -s libmpfr.so.5 /var/tmp/catalyst/tmp/default/stage1-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}t/tmp/stage1root/usr/lib/libmpfr.so.4 || exit 1


	catalyst -C target=stage2 version_stamp=fbsd-${TARGETVER}-${WORKDATE}t profile=default/bsd/fbsd/${TARGETARCH}/${TARGETVER} snapshot=${WORKDATE} source_subpath=default/stage1-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}t subarch=${TARGETSUBARCH} rel_type=default portage_overlay=${WORKDIR}/portage.bsd-overlay chost=${CATALYST_CHOST} || exit 1
	catalyst -C target=stage3 version_stamp=fbsd-${TARGETVER}-${WORKDATE}t profile=default/bsd/fbsd/${TARGETARCH}/${TARGETVER} snapshot=${WORKDATE} source_subpath=default/stage2-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}t subarch=${TARGETSUBARCH} rel_type=default portage_overlay=${WORKDIR}/portage.bsd-overlay chost=${CATALYST_CHOST} || exit 1
}

mk_stages(){
	catalyst -C target=stage1 version_stamp=fbsd-${TARGETVER}-${WORKDATE} profile=default/bsd/fbsd/${TARGETARCH}/${TARGETVER} snapshot=${WORKDATE} source_subpath=default/stage3-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}t subarch=${TARGETSUBARCH} rel_type=default portage_overlay=${WORKDIR}/portage.bsd-overlay chost=${CATALYST_CHOST}

	local PID=`ps auxw | grep portage/bin/ebuild-helpers/ecompressdir | grep -v grep | awk '{ print $2 }' | xargs`
	kill -9 ${PID}
	rm -rf /var/tmp/catalyst/tmp/default/stage1-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}/usr/local/portage || exit 1

	catalyst -C target=stage1 version_stamp=fbsd-${TARGETVER}-${WORKDATE} profile=default/bsd/fbsd/${TARGETARCH}/${TARGETVER} snapshot=${WORKDATE} source_subpath=default/stage3-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE}t subarch=${TARGETSUBARCH} rel_type=default portage_overlay=${WORKDIR}/portage.bsd-overlay chost=${CATALYST_CHOST} || exit 1

	catalyst -C target=stage2 version_stamp=fbsd-${TARGETVER}-${WORKDATE} profile=default/bsd/fbsd/${TARGETARCH}/${TARGETVER} snapshot=${WORKDATE} source_subpath=default/stage1-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE} subarch=${TARGETSUBARCH} rel_type=default portage_overlay=${WORKDIR}/portage.bsd-overlay chost=${CATALYST_CHOST} || exit 1
	catalyst -C target=stage3 version_stamp=fbsd-${TARGETVER}-${WORKDATE} profile=default/bsd/fbsd/${TARGETARCH}/${TARGETVER} snapshot=${WORKDATE} source_subpath=default/stage2-${TARGETSUBARCH}-fbsd-${TARGETVER}-${WORKDATE} subarch=${TARGETSUBARCH} rel_type=default portage_overlay=${WORKDIR}/portage.bsd-overlay chost=${CATALYST_CHOST} || exit 1
}

prepare $1

if [ ! -e "/var/tmp/catalyst/snapshots/portage-${WORKDATE}.tar.bz2" ] ; then
	catalyst -C target=snapshot version_stamp=${WORKDATE} || exit 1
fi

if [ ! -e "/var/tmp/catalyst/builds/default/stage3tmp-${TARGETSUBARCH}-freebsd-${TARGETVER}.tar.bz2" ] && [ "${OLDVER}" != "${TARGETVER}" ] ; then
	upgrade_src_stage3
	echo "upgrade done"
fi

mk_stages_tmp
mk_stages

