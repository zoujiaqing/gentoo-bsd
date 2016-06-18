#!/bin/bash -eu
# Automatic bug fix script
# sys-apps/portage: bug 493126, 574626
# sys-libs/db: bug 578506
# sys-devel/llvm

PORTDIR="${PORTDIR:-/usr/portage}"
TMPDIR="${TMPDIR:-/tmp/autofix}"

if [[ ! -e "${TMPDIR}" ]] ; then
	mkdir -p "${TMPDIR}"
fi

latest_ebuild(){
	local pkg="$1"

	echo $(emerge -qp --color=n ${pkg} 2>/dev/null | grep ${pkg} | gsed "s:.*${pkg}:${pkg}:g" | awk '{print $1}'  | awk -F/ '{print $2}').ebuild
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

fix_db(){
	echo "sys-libs/db cxx" >> "${PORTDIR}/profiles/arch/amd64-fbsd/clang/package.use.mask"
}

fix_llvm_ninja(){
	# Traceback (most recent call last):
	#   File "configure.py", line 435, in <module>
	#     if has_re2c():
	#   File "configure.py", line 432, in has_re2c
	#     return int(proc.communicate()[0], 10) >= 1103
	# ValueError: invalid literal for int() with base 10: ''
	#  * ERROR: dev-util/ninja-1.6.0::gentoo failed (compile phase):

	local pkg="sys-devel/llvm"
	local ebuild="$(latest_ebuild ${pkg})"

	gsed -i 's/CMAKE_MAKEFILE_GENERATOR:=ninja/CMAKE_MAKEFILE_GENERATOR:=emake/g' "${PORTDIR}"/${pkg}/*.ebuild
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
}

for func in mk_patches fix_portage fix_db fix_llvm_ninja
do
	echo "${func}"
	${func}
done

