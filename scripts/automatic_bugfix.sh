#!/bin/bash -eu
# Automatic bug fix script
# sys-apps/portage: bug 493126, 574626
# app-shells/bash: bug 574426
# sys-devel/gettext: bug 564168
# sys-apps/findutils: bug 577714

PORTDIR="${PORTDIR:-/usr/portage}"
TMPDIR="${TMPDIR:-/tmp/autofix}"

if [[ ! -e "${TMPDIR}" ]] ; then
	mkdir -p "${TMPDIR}"
fi

latest_ebuild(){
	local pkg="$1"

	echo "$(emerge -qp ${pkg} 2>/dev/null | awk '{print $4}' | grep ${pkg} | awk -F/ '{print $2}').ebuild"
}

fix_portage() {
	# Fix bug 493126 and 574626
	local pkg="sys-apps/portage"
	local ebuild="$(latest_ebuild ${pkg})"

	cp "${TMPDIR}/bug493126.patch" "${PORTDIR}/${pkg}"/files/
	cp "${TMPDIR}/bug574626.patch" "${PORTDIR}/${pkg}"/files/

	patch -p1 "${PORTDIR}/${pkg}/${ebuild}" < "${TMPDIR}/portage_ebuild.patch"
	ebuild "${PORTDIR}/${pkg}/${ebuild}" manifest
}

fix_bash() {
	# Fix bug 574426
	local pkg="app-shells/bash"
	local ebuild="$(latest_ebuild ${pkg})"

	patch -p1 "${PORTDIR}/${pkg}/${ebuild}" < "${TMPDIR}/bug574426.patch"
	ebuild "${PORTDIR}/${pkg}/${ebuild}" manifest
}

fix_gettext() {
	# Fix bug 564168
	local pkg="sys-devel/gettext"
	local ebuild="$(latest_ebuild ${pkg})"

	patch -p1 "${PORTDIR}/${pkg}/${ebuild}" < "${TMPDIR}/bug564168.patch"
	ebuild "${PORTDIR}/${pkg}/${ebuild}" manifest

	echo "dev-libs/libintl-0.19.7" >> ${PORTDIR}/profiles/default/bsd/fbsd/package.provided
}

fix_findutils() {
	# Fix bug 577714
	local pkg="sys-apps/findutils"
	local ebuild="$(latest_ebuild ${pkg})"

	gsed -i '/<sys\/sysmacros.h>/d' "${PORTDIR}/${pkg}/${ebuild}"
	ebuild "${PORTDIR}/${pkg}/${ebuild}" manifest
}

mk_patches() {
	cat > "${TMPDIR}/bug493126.patch" <<-'EOF'
	diff --git a/portage-2.2.7/pym/portage/process.py b/portage-2.2.7/pym/portage/process.py
	index 9ae7a55..cee2440 100644
	--- a/portage-2.2.7/pym/portage/process.py
	+++ b/portage-2.2.7/pym/portage/process.py
	@@ -55,8 +55,8 @@ for _fd_dir in ("/proc/self/fd", "/dev/fd"):
	 		_fd_dir = None
	 
	 # /dev/fd does not work on FreeBSD, see bug #478446
	-if platform.system() in ('FreeBSD',) and _fd_dir == '/dev/fd':
	-	_fd_dir = None
	+#if platform.system() in ('FreeBSD',) and _fd_dir == '/dev/fd':
	+#	_fd_dir = None
	 
	 if _fd_dir is not None:
	 	def get_open_fds():
	EOF

	cat > "${TMPDIR}/bug574626.patch" <<-'EOF'
	diff --git a/portage-2.2.27/bin/phase-helpers.sh b/portage-2.2.27/bin/phase-helpers.sh
	index 80f5946..69dfe4b 100644
	--- a/portage-2.2.27/bin/phase-helpers.sh
	+++ b/portage-2.2.27/bin/phase-helpers.sh
	@@ -987,6 +987,9 @@ if ___eapi_has_eapply; then
	 		_eapply_patch() {
	 			local f=${1}
	 			local prefix=${2}
	+			local prepend=""
	+
	+			type -P gpatch > /dev/null && prepend="g"
	 
	 			started_applying=1
	 			ebegin "${prefix:-Applying }${f##*/}"
	@@ -995,7 +998,7 @@ if ___eapi_has_eapply; then
	 			# -s to silence progress output
	 			# -g0 to guarantee no VCS interaction
	 			# --no-backup-if-mismatch not to pollute the sources
	-			patch -p1 -f -s -g0 --no-backup-if-mismatch \
	+			${prepend}patch -p1 -f -s -g0 --no-backup-if-mismatch \
	 				"${patch_options[@]}" < "${f}"
	 			failed=${?}
	 			if ! eend "${failed}"; then
	EOF

	cat > "${TMPDIR}/portage_ebuild.patch" <<-'EOF'
	diff --git a/portage-2.2.26.ebuild b/portage-2.2.26.ebuild
	index 982053e..62e9785 100644
	--- a/portage-2.2.26.ebuild
	+++ b/portage-2.2.26.ebuild
	@@ -84,6 +84,8 @@ pkg_setup() {
	 
	 python_prepare_all() {
	 	distutils-r1_python_prepare_all
	+	epatch "${FILESDIR}/bug493126.patch"
	+	epatch "${FILESDIR}/bug574626.patch"
	 
	 	if ! use ipc ; then
	 		einfo "Disabling ipc..."
	EOF

	cat > "${TMPDIR}/bug574426.patch" <<-'EOF'
	diff --git a/bash-4.3_p42-r2.ebuild b/bash-4.3_p42-r2.ebuild
	index c914d04..d4edb87 100644
	--- a/bash-4.3_p42-r2.ebuild
	+++ b/bash-4.3_p42-r2.ebuild
	@@ -39,7 +39,7 @@ SRC_URI="mirror://gnu/bash/${MY_P}.tar.gz $(patches)"
	 LICENSE="GPL-3"
	 SLOT="0"
	 KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~m68k ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86 ~amd64-fbsd ~sparc-fbsd ~x86-fbsd"
	-IUSE="afs bashlogger examples mem-scramble +net nls plugins +readline vanilla"
	+IUSE="afs bashlogger examples mem-scramble +net nls plugins +readline vanilla elibc_FreeBSD"
	 
	 DEPEND=">=sys-libs/ncurses-5.2-r2
	 	readline? ( >=sys-libs/readline-${READLINE_VER} )
	@@ -130,6 +130,10 @@ src_configure() {
	 		myconf+=( --with-installed-readline=. )
	 	fi
	 
	+	# Fix cannot make pipe for process substitution: File exists error.
	+	# Bug 574426
	+	use elibc_FreeBSD && append-cflags -DUSE_MKTEMP=1 -DUSE_MKSTEMP=1
	+
	 	if use plugins; then
	 		append-ldflags -Wl,-rpath,/usr/$(get_libdir)/bash
	 	else
	EOF

	cat > "${TMPDIR}/bug564168.patch" <<-'EOF'
	diff --git a/gettext-0.19.7.ebuild b/gettext-0.19.7.ebuild
	index 7677f88..f959f3e 100644
	--- a/gettext-0.19.7.ebuild
	+++ b/gettext-0.19.7.ebuild
	@@ -17,7 +17,7 @@ SRC_URI="mirror://gnu/${PN}/${P}.tar.gz"
	 LICENSE="GPL-3+ cxx? ( LGPL-2.1+ )"
	 SLOT="0"
	 KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~m68k ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86 ~amd64-fbsd ~sparc-fbsd ~x86-fbsd"
	-IUSE="acl -cvs +cxx doc emacs git java ncurses nls openmp static-libs"
	+IUSE="acl -cvs +cxx doc emacs git java ncurses nls openmp static-libs elibc_glibc elibc_musl"
	 
	 # only runtime goes multilib
	 # Note: expat lacks a subslot because it is dynamically loaded at runtime.  We
	@@ -69,8 +69,6 @@ multilib_src_configure() {
	 		# this will _disable_ libunistring (since it is not bundled),
	 		# see bug #326477
	 		--with-included-libunistring
	-		# Never build libintl since it's in dev-libs/libintl now.
	-		--without-included-gettext
	 
	 		$(use_enable acl)
	 		$(use_enable cxx c++)
	@@ -79,11 +77,23 @@ multilib_src_configure() {
	 		$(usex git --without-cvs $(use_with cvs))
	 		$(use_enable java)
	 		$(use_enable ncurses curses)
	-		$(use_enable nls)
	 		$(use_enable openmp)
	 		$(use_enable static-libs static)
	 	)
	 
	+	# Build with --without-included-gettext (on glibc systems)
	+	if use elibc_glibc || use elibc_musl ; then
	+		myconf+=(
	+			--without-included-gettext
	+			$(use_enable nls)
	+		)
	+	else
	+		myconf+=(
	+			--with-included-gettext
	+			--enable-nls
	+		)
	+	fi
	+
	 	local ECONF_SOURCE=${S}
	 	if ! multilib_is_native_abi ; then
	 		# for non-native ABIs, we build runtime only
	EOF
}

for func in mk_patches fix_portage fix_bash fix_gettext fix_findutils
do
	echo "${func}"
	${func}
done

