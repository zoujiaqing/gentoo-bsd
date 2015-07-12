#!/bin/bash
set -eu

TARGETVER="${TARGETVER:-10.1}"
TARGETARCH="${TARGETARCH:-amd64}"
OLDSTAGE3="${OLDSTAGE3:-http://distfiles.gentoo.org/experimental/bsd/freebsd/stages/amd64-fbsd-9.1/stage3-amd64-freebsd-9.1.tar.bz2}"
WORKDIR="/${TARGETVER}-forcestage3/${TARGETARCH}"
PORTDIR="${PORTDIR:-/usr/portage}"
TMPFS=${TMPFS:-0}
CLANG=${CLANG:-0}
[[ ${CLANG} -ne 0 ]] && WORKDIR="${WORKDIR}_clang"

prepare(){
	local distdir="$(emerge --info | grep DISTDIR | sed s:DISTDIR=::g | sed 's:"::g')"
	if [[ ! -d "${WORKDIR}" ]]; then
		mkdir -p "${WORKDIR}"
	fi

	if [[ "${OLDSTAGE3}" =~ ^http ]]; then
		if [[ ! -e /tmp/$(basename ${OLDSTAGE3}) ]]; then
			wget -P /tmp "${OLDSTAGE3}"
		fi
	else
		cp "${OLDSTAGE3}" /tmp
	fi

	tar xjpf /tmp/$(basename ${OLDSTAGE3}) -C "${WORKDIR}"

	mkdir -p "${WORKDIR}"/usr/portage/distfiles
	mkdir -p "${WORKDIR}"/var/tmp/portage

	mount -t devfs devfs "${WORKDIR}"/dev
	mount -t nullfs "${PORTDIR}" "${WORKDIR}"/usr/portage
	if [[ ! "${distdir}" =~ ${PORTDIR}.* ]]; then
		echo "mount DISTDIR"
		mount -t nullfs "${WORKDIR}"/usr/portage/distfiles
	fi
	if [[ "${TMPFS}" -ne 0 ]] ; then
		echo "mount TMPFS"
		mount -t tmpfs tmpfs "${WORKDIR}"/var/tmp/portage
	fi
	wget -P "${WORKDIR}" https://gitweb.gentoo.org/proj/gentoo-bsd.git/plain/scripts/automatic_updater.sh
	cp /etc/resolv.conf "${WORKDIR}"/etc
}

chroot_update(){
	if [[ -e "${WORKDIR}"/etc/make.conf ]]; then
		local makeconf="${WORKDIR}"/etc/make.conf
	else
		local makeconf="${WORKDIR}"/etc/portage/make.conf
	fi

	echo "MAKEOPTS=\"-j$(sysctl hw.ncpu | awk '{ print $2 + 1 }')"\" >> "${makeconf}"
	echo 'USE="${USE} -fortran -build-kernel"' >> "${makeconf}"

	export EMERGE_DEFAULT_OPTS="-q"
	chroot "${WORKDIR}" bash /automatic_updater.sh ${TARGETVER} kernel
	chroot "${WORKDIR}" bash /automatic_updater.sh ${TARGETVER} freebsd_userland
	REMOVEPERL=1 chroot "${WORKDIR}" bash /automatic_updater.sh ${TARGETVER} world
	unset EMERGE_DEFAULT_OPTS
}

check_ecompressdir() {
	# dirty solution
	# /dev is still mounted; performing auto-bind-umount...
	local PID=$(ps auxw | grep ebuild-helpers/ecompressdir | grep -v grep | awk '{ print $2 }' | xargs)
	if [[ -n "${PID}" ]] ; then
		echo "kill ecompressdir"
		kill -9 ${PID} && :
		return 0
	else
		return 0
	fi
}

cleanup(){
	check_ecompressdir
	umount "${WORKDIR}"/usr/portage/distfiles
	umount "${WORKDIR}"/usr/portage
	if [[ "${TMPFS}" -ne 0 ]] ; then
		umount "${WORKDIR}"/var/tmp/portage
	fi
	umount "${WORKDIR}"/dev
}

create_stage3(){
	local tarfile

	cd "${WORKDIR}"
	if [[ ! -e /var/tmp/catalyst/builds/default ]] ; then
		mkdir -p /var/tmp/catalyst/builds/default
	fi
	if [[ ${CLANG} -ne 0 ]]; then
		tarfile="stage3-${TARGETARCH}-fbsd-${TAGETVER}-forcestage3-cl"
	else
		tarfile="stage3-${TARGETARCH}-fbsd-${TAGETVER}-forcestage3"
	fi

	tar cjpf /var/tmp/catalyst/builds/default/"${tarfile}".tar.bz2 .

	echo "Complete !"
	echo "Set FORCESTAGE3=${tarfile}"
}

prepare
chroot_update
cleanup
create_stage3

