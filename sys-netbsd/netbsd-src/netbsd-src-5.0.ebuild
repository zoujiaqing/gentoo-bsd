# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD CVS sources ebuild
# Patrice Clement <charlieroot@free.fr>
inherit netbsd

DESCRIPTION="NetBSD 5.0 CVS sources"
HOMEPAGE="http://cvsweb.netbsd.org"
SRC_URI=""
SLOT="0"
LICENCE="BSD"
KEYWORDS="~x86-nbsd"

src_unpack() {
  # Simply fetch sources
  netbsd_src_unpack
}
