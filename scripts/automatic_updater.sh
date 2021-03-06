#/bin/bash
set -eu
REMOVEPERL=${REMOVEPERL:-0}

if [[ $# -ne 2 ]] ; then
	echo "need 2 argument"
	echo "arg 1: TARGETVER"
	echo "arg 2: TARGETMODE, Please set kernel, freebsd_userland, world."
	exit 1
else
	TARGETVER=$1
	TARGETMODE=$2
fi

set_profile(){
	emerge --info | head -n 1 | grep clang && :
	if [[ $? -eq 0 ]] ; then
		eselect profile set $(eselect profile list | grep "${TARGETVER}" | grep clang | awk '{print $1}' | sed 's:\[::g' | sed 's:\]::g' | tail -n 1)
	else
		eselect profile set $(eselect profile list | grep "${TARGETVER}" | grep -v clang | awk '{print $1}' | sed 's:\[::g' | sed 's:\]::g' | tail -n 1)
	fi
}

move_makeconf(){
	[[ ! -e /etc/portage ]] && mkdir -p /etc/portage
	if [[ -e /etc/make.conf ]] && [[ ! -e /etc/portage/make.conf ]] ; then
		mv /etc/make.conf /etc/portage/make.conf
	fi
	gsed -i '/LDFLAGS=/d' /etc/portage/make.conf
}

update_portage(){
	local dl_portage_ver="2.2.20.1"
	cd /tmp
	wget http://dev.gentoo.org/~dolsen/releases/portage/portage-${dl_portage_ver}.tar.bz2
	tar xjf portage-${dl_portage_ver}.tar.bz2
	PYTHON_TARGETS="python2_7" "portage-${dl_portage_ver}"/bin/emerge --nodeps dev-lang/python-exec
	eselect python set 1
	"portage-${dl_portage_ver}"/bin/emerge sys-apps/portage --exclude sys-freebsd/*
	emerge dev-lang/python-exec --exclude sys-freebsd/*
	emerge app-admin/eselect --exclude sys-freebsd/*
	eselect python set 1
}

update_minimal(){
	emerge --nodeps sys-freebsd/freebsd-mk-defs
	emerge -u '<sys-apps/findutils-4.6' --exclude sys-freebsd/*
	emerge sys-devel/libtool --exclude sys-freebsd/*

	# https://bugs.gentoo.org/564168
	USE="-*" emerge --nodeps sys-devel/gettext --exclude sys-freebsd/*
	emerge sys-devel/gettext --exclude sys-freebsd/*

	emerge -u sys-devel/flex sys-devel/patch sys-devel/m4 net-libs/libpcap sys-devel/gettext app-arch/libarchive sys-libs/zlib dev-util/dialog --exclude sys-freebsd/*
	emerge sys-devel/libtool --exclude sys-freebsd/*
	if [[ -e /usr/lib/libc++.so ]] ; then
		if [[ $(uname -p) == "amd64" ]] && [[ ! -e /usr/lib32/librt.so ]] ; then
			[[ ! -e /etc/portage/profile ]] && mkdir -p /etc/portage/profile
			echo "sys-libs/libcxx abi_x86_32" >> /etc/portage/profile/package.use.mask
			echo "sys-libs/libcxxrt abi_x86_32" >> /etc/portage/profile/package.use.mask
			emerge -uN sys-libs/libcxx sys-libs/libcxxrt --exclude sys-freebsd/*
			[[ -e /etc/portage/profile/package.use.mask ]] && gsed -i '/sys-libs\/libcxx abi_x86_32/d' /etc/portage/profile/package.use.mask
			[[ -e /etc/portage/profile/package.use.mask ]] && gsed -i '/sys-libs\/libcxxrt abi_x86_32/d' /etc/portage/profile/package.use.mask
		fi
	fi
}

update_toolchain(){
	if [[ $(uname -p) == "amd64" ]] ; then
		gsed -i "s:CHOST=.*:CHOST=\"x86_64-gentoo-freebsd${TARGETVER}\":g" /etc/portage/make.conf
	else
		gsed -i "s:CHOST=.*:CHOST=\"i686-gentoo-freebsd${TARGETVER}\":g" /etc/portage/make.conf
	fi
	emerge -u sys-devel/binutils --exclude sys-freebsd/*
	emerge -u sys-devel/gcc-config --exclude sys-freebsd/*
	emerge -u '<sys-devel/gcc-5.0' --exclude sys-freebsd/*
	gcc-config $(gcc-config -l | grep "${TARGETVER}" | awk '{print $1}' | sed 's:\[::g' | sed 's:\]::g' | tail -n 1)
#	emerge -C \<$(emerge -pq --nodeps sys-devel/gcc --exclude sys-freebsd/* | grep ebuild | awk '{print $4}') && :
	env-update
	source /etc/profile
	emerge sys-devel/libtool --exclude sys-freebsd/*
	emerge sys-devel/binutils --exclude sys-freebsd/*
	if type -P clang > /dev/null ; then
		emerge -u '<sys-devel/clang-3.7' --exclude sys-freebsd/*
	fi
}

update_kernel(){
	emerge -C freebsd-sources sys-freebsd/virtio-kmod sys-fs/fuse4bsd && :
	emerge --nodeps freebsd-sources
}

update_freebsd_userland(){
	if [[ $(uname -p) == "amd64" ]] && [[ ! -e /libexec/ld-elf32.so.1 ]] ; then
		[[ ! -e /etc/portage/profile ]] && mkdir -p /etc/portage/profile
		echo "sys-freebsd/freebsd-libexec abi_x86_32" >> /etc/portage/profile/package.use.mask
	fi

	emerge -C dev-libs/libelf dev-libs/libexecinfo dev-libs/libiconv sys-process/fuser-bsd && :
	CC=gcc CXX=g++ CXXFLAGS="-O2 -pipe" emerge --nodeps sys-freebsd/freebsd-libexec
	CC=gcc CXX=g++ CXXFLAGS="-O2 -pipe" USE=build MAKEOPTS=-j1 emerge --nodeps sys-freebsd/freebsd-lib
	CC=gcc CXX=g++ CXXFLAGS="-O2 -pipe" USE=build emerge --nodeps sys-freebsd/freebsd-share
	[[ -e /etc/portage/profile/package.use.mask ]] && gsed -i '/sys-freebsd\/freebsd-libexec abi_x86_32/d' /etc/portage/profile/package.use.mask

	CC=gcc CXX=g++ CXXFLAGS="-O2 -pipe" emerge freebsd-bin freebsd-lib freebsd-libexec freebsd-mk-defs freebsd-pam-modules freebsd-sbin freebsd-share freebsd-ubin freebsd-usbin
	if [[ -e /usr/lib/libc++.so ]] ; then
		emerge sys-libs/libcxx sys-libs/libcxxrt --exclude sys-freebsd/*
		emerge -u sys-devel/llvm sys-devel/clang
	fi
	emerge boot0 freebsd-bin freebsd-lib freebsd-libexec freebsd-mk-defs freebsd-pam-modules freebsd-sbin freebsd-share freebsd-ubin freebsd-usbin
}

post_freebsd_userland(){
	emerge sys-devel/libtool app-admin/eselect
	emerge sys-apps/portage
}

remove_perl(){
	emerge -C dev-lang/perl
	emerge -C dev-perl/* perl-core/* virtual/perl*
	emerge dev-lang/perl
	emerge dev-perl/Text-Unidecode dev-perl/Unicode-EastAsianWidth dev-perl/XML-Parser dev-perl/libintl-perl
}

emerge_world(){
	emerge sys-devel/libtool
	emerge -C dev-lang/python:3.2 && :
	emerge dev-libs/libxml2
	emerge dev-libs/libxslt app-arch/libarchive dev-libs/glib
	emerge -u sys-devel/gcc
	emerge -C \<$(emerge -pq --nodeps sys-devel/gcc --exclude sys-freebsd/* | grep ebuild | awk '{print $4}') && :
	gcc-config $(gcc-config -l | grep "${TARGETVER}" | awk '{print $1}' | sed 's:\[::g' | sed 's:\]::g' | tail -n 1)
	source /etc/profile
	emerge -e @world
}

cleanup(){
	emerge sys-devel/libtool app-admin/eselect
	emerge @preserved-rebuild
}

case "$TARGETMODE" in
	"kernel" )
		set_profile
		move_makeconf
		update_portage
		update_minimal
		update_toolchain
		update_kernel
	;;
	"kernelonly" ) update_kernel ;;
	"freebsd_userland" )
		update_freebsd_userland
		post_freebsd_userland
	;;
	"world" )
		[[ ${REMOVEPERL} -ne 0 ]] && remove_perl
		emerge_world
		cleanup
	;;
	* )
		echo "Please set kernel, freebsd_userland, world."
		exit 1
	;;
esac

