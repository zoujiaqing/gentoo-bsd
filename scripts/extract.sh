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
	dists="bin cddl compat contrib crypto gnu include lib libexec sbin share ubin usbin sys etc rescue "
else
	dists="$2"
fi

MIRROR=${FTPMIRROR:-ftp.FreeBSD.org}
echo "Using mirror ${MIRROR}"

P=$1
MY_P=${P/_rc/-RC}
MY_P=${MY_P/_beta/-BETA}
echo "Getting version ${P} [${MY_P}].."
if [[ ${MY_P} == ${P} ]]; then
	MY_P="${MY_P}-RELEASE"
fi

echo "Downloading files..."
wget -nv -c "ftp://${MIRROR}/pub/FreeBSD/releases/i386/${MY_P}/src/CHECKSUM.MD5"

sed -e 's:MD5 (\(.*\)) = \(.*\):\2 \1:' CHECKSUM.MD5 > MD5SUM

for i in $dists; do
	wget -nv -c -t0 "ftp://${MIRROR}/pub/FreeBSD/releases/i386/${MY_P}/src/s$i*"
done
echo "Done downloading files."

echo "Repackaging files..."
for i in $dists; do
	echo "  Repackaging source component: $i"
	cat s${i}.?? | zcat - | bzip2 - > freebsd-${i}-$P.tar.bz2
done
echo "Done repackaging sources."
exit 0
