#!/bin/bash

if [[ $# -lt 1 ]]; then
	echo "You must specify the version of the packages to build."
	exit 1
fi

# These are the base packages recognized by original script:
# base bin contrib crypto etc games gnu include krb5 lib libexec release
# rescue sbin secure share sys tools ubin usbin
# Added cddl and compat.

if [[ -z $2 ]]; then
	dists="bin cddl contrib crypto gnu include lib libexec sbin share usr.bin usr.sbin sys etc rescue secure "
else
	dists="$2"
fi

MIRROR=${FTPMIRROR:-ftp.FreeBSD.org}
echo "Using mirror ${MIRROR}"

P=$1
MY_P=${P/_rc/-RC}
MY_P=${MY_P/_beta/-BETA}
MY_P=${MY_P/_alpha/-ALPHA}
MAJORVER=${P%.*}

echo "Getting version ${P} [${MY_P}].."
if [[ ${MY_P} == ${P} ]]; then
	MY_P="${MY_P}-RELEASE"
fi

echo "Downloading files..."
wget -nv -c "ftp://${MIRROR}/pub/FreeBSD/releases/i386/i386/${MY_P}/MANIFEST"
wget -nv -c "ftp://${MIRROR}/pub/FreeBSD/releases/i386/i386/${MY_P}/src.txz"
echo "Done downloading files."

# Create tar.xz 10.0 or later version. In the case of 9.x, create tar.bz2.
if [[ ${MAJORVER} -ge 10 ]]; then
	TAROPT=J
	TAREXT=xz
else
	TAROPT=j
	TAREXT=bz2
fi

echo "Repackaging files..."
tar xf src.txz
for i in $dists; do
	echo "  Repackaging source component: $i"
        pushd usr/src > /dev/null
        tar c${TAROPT}f ../../freebsd-${i/usr./u}-$P.tar.${TAREXT} $i
        popd > /dev/null
done
echo "Done repackaging sources."
exit 0
