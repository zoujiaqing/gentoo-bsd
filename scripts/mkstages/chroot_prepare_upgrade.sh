#!/bin/bash

if [ -e /etc/make.conf ] ; then
	echo "MAKEOPTS=\"-j`sysctl hw.ncpu | awk '{ print $2 + 1 }'`"\" >> /etc/make.conf
fi
if [ -e /etc/portage/make.conf ] ; then
	echo "MAKEOPTS=\"-j`sysctl hw.ncpu | awk '{ print $2 + 1 }'`"\" >> /etc/portage/make.conf
fi
if [ -e /tmp/catalystrc ] ; then
	source /tmp/catalystrc
fi
# fixes bug #447810
MAKEOPTS=-j1 emerge -q app-shells/bash || exit

# fixes bug #412319
emerge -q sys-devel/gcc-config || exit
gcc-config 1

# fixes bug #413865
emerge -q app-arch/libarchive || exit

# upgrade sys-freebsd packages
emerge -q sys-apps/portage || exit
emerge -q sys-devel/libtool || exit
# fixes bug 425530
emerge -q app-admin/eselect || exit

rm /etc/make.profile /etc/portage/make.profile
ln -s ../../usr/portage/profiles/default/bsd/fbsd/${TARGETARCH}/${TARGETVER} /etc/portage/make.profile

emerge -1q sys-freebsd/freebsd-mk-defs
USE=build emerge -1q --nodeps sys-freebsd/freebsd-lib
emerge -Cq sys-freebsd/boot0
USE=symlink emerge -1q freebsd-bin freebsd-cddl freebsd-contrib freebsd-lib freebsd-libexec freebsd-mk-defs freebsd-pam-modules freebsd-sbin freebsd-share freebsd-ubin freebsd-usbin || exit

# sys-libs/zlib will request ${CHOST}-gcc.
# different ${CHOST}-gcc fails to install
CHOST=${CATALYST_CHOST} emerge -q sys-devel/gcc || exit

# fixes bug 436560
fixes436560(){
	local rootdir=$1

	if [ -d "${rootdir}lib64" ] && [ -L "${rootdir}lib" ] ; then
		rm "${rootdir}lib"
		LD_LIBRARY_PATH="${rootdir}lib64" mv "${rootdir}lib64" "${rootdir}lib"
		ln -s lib ${rootdir}lib64
	fi
}

fixes436560 /
fixes436560 /usr/
fixes436560 /usr/local/

emerge -q sys-apps/baselayout
emerge -q sys-apps/portage || exit

# libtool has the old CHOST. Need to be updated
CHOST=${CATALYST_CHOST} emerge -q sys-devel/libtool || exit

# fixes bug 425530
emerge -q app-admin/eselect || exit

if [ -e /etc/portage/profile ] ; then
	rm -rf /etc/portage/profile
	rm /etc/portage/package.keywords
	rm /etc/portage/package.use
	rm -rf /etc/portage/patches
fi

rm -rf /usr/local/portage.bsd-overlay
gsed -i '/PORTDIR_OVERLAY=.*/d' /etc/make.conf
gsed -i '/PORTDIR_OVERLAY=.*/d' /etc/portage/make.conf
touch /tmp/prepare_done
