# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Gentoo/NetBSD eclass
# Patrice Clement <clement.patrice@gmail.com>
inherit bsdmk

# @ECLASS: netbsd.eclass
# @MAINTAINER: clement.patrice@gmail.com
# @BLURB: functions and environment variables used to set up dirs, paths, names in ebuilds
# @DESCRIPTION:
# The netbsd eclass contains a suite of functions and environment variables used to setup many
# paths, directory names, and other things in Gentoo/NetBSD. I try to be as much explicit as I
# can. Read comments to understand how does the function work and what it does.

# Source directory.
# I wanted to let end-user the possiblity to set where he wants to push NetBSD sources on his machine. 
# It can now be achieved with a variable which have to be set in make.conf: NETBSD_SRC_DIR.
# ex: NETBSD_SRC_DIR="/usr" or "/docs/netbsd-5.0"
# Default, if not set, is "/usr"
if [ -z ${NETBSD_SRC_DIR} ]; then
  NETBSD_SRC_DIR="/usr"
fi

# CVS directory MUST ALWAYS be "src"
# that's why we set it as readonly.
readonly NETBSD_CVS_DIR="src"

# This is the global path of where sources are pushed on user's machine.
# We'll need it later.
NETBSD_SRC_DIR="${NETBSD_SRC_DIR}/${NETBSD_CVS_DIR}"
export NETBSD_SRC_DIR

# Tools directory.
# Default, if not set, is tooldir.NetBSD-5.0-i386
# Later, we can think about USE flags which would cross-compile
# tools and system in another directory, using ROOT option,
# in order to build the system for a different CPU architecture.
if [ -z ${NETBSD_SRC_TOOLDIR} ]; then
  NETBSD_SRC_TOOLDIR="tooldir-NetBSD-5.0-i386"
  #NETBSD_SRC_TOOLDIR="tooldir-`uname -s`-`uname -r`-`uname -m`
fi
export NETBSD_SRC_TOOLDIR

# In order to have the global path of where are tools on machine,
# and to avoid writing ${NETBSD_SRC_DIR}/${NETBSD_TOOLDIR} each times,
# we create a variable to assemble these two.
NETBSD_TOOLDIR="${NETBSD_SRC_DIR}/${NETBSD_SRC_TOOLDIR}"
export NETBSD_TOOLDIR

# Define mymakeopts environment variable.
# BSDSRCDIR = Real path of NetBSD sources on local machine.
# TOOLDIR = Real path of tools directory.
# USETOOLS=yes = We'll always use cross-compiling tools to build any part of the system.
mymakeopts="BSDSRCDIR=${NETBSD_SRC_DIR} TOOLDIR=${NETBSD_TOOLDIR} USETOOLS=yes"

# @FUNCTION: netbsd_create_dirs
# @USAGE: <pattern>
# @DESCRIPTION:
# This function is used before invoking "make install". A common problem, while invoking "make install",
# is that make doesn't create directories in DESTDIR before installing files.
# I've noticed that NetBSD system directory hierarchy is described in /etc/mtree so we just need
# to use this file to construct the hierarchy of the directory we want to build inside our DESTDIR.
# For example, if I want to create /usr/share directory hierarchy, I just need to use the function
# like this: netbsd_create_dirs usr/share and it will create every directories and sub-directories
# in DESTDIR (which is ${D}).
netbsd_create_dirs() {
  if [ ! ${1} ]; then
    eerror "You must provide an argument to match!"
    eerror "Please read netbsd.eclass for more information."
    die
  else
    grep "${1}" "${NETBSD_SRC_DIR}/etc/mtree/NetBSD.dist" | sed "s/^.\///g" | xargs dodir
  fi
}

# @FUNCTION: netbsd_clean_dirs
# @USAGE: <directory>
# @DESCRIPTION:
# Clean empty directories in target directory. 
# Useful after using netbsd_create_dirs functions (which could create a lot of directories.
netbsd_clean_dirs() {
  if [ ! ${1} ]; then
    eerror "You must provide a directory to search into!"
    eerror "Please read netbsd.eclass for more information."
    die
  else
    DIRS=`find ${1} -type d`
    for i in ${DIRS}
    do
      if [ ! "$(ls -A ${i})" ]; then
        rm -rf ${i}
      fi
    done
  fi
}

# @FUNCTION: netbsd_mk_prepatch
# @USAGE: <>
# @DESCRIPTION:
# Function used to copy original Makefile before applying patches.
netbsd_mk_prepatch() {
  if [ ! -e Makefile.orig ]; then
    cp Makefile Makefile.orig
  else
    cp Makefile.orig Makefile
  fi
}

# @FUNCTION: netbsd_src_compile
# @USAGE: <>
# @DESCRIPTION:
# Function used to compile sources, using bsdmake.
netbsd_src_compile() {
  mymakeopts="${mymakeopts}"

  [[ -z ${BMAKE} ]] && BMAKE="$(get_bmake)"
  ${BMAKE} ${MAKEOPTS} ${EXTRA_EMAKE} ${mymakeopts} "$@" || die "make failed"
}

# @FUNCTION: netbsd_src_install
# @USAGE: <>
# @DESCRIPTION:
# Function used to install sources, using bsdmake.
netbsd_src_install() {
  mymakeopts="${mymakeopts} DESTDIR=${D}"

  [[ -z ${BMAKE} ]] && BMAKE="$(get_bmake)"
  ${BMAKE} ${MAKEOPTS} ${EXTRA_EMAKE} ${mymakeopts} "$@" || die "make install failed"
}

# @FUNCTION: netbsd_src_unpack
# @USAGE: <>
# @DESCRIPTION:
# Function used to fetch sources through CVS
netbsd_src_unpack() {
  # We use CVS eclass
  inherit cvs

  # Set up ${NETBSD_SRC_DIR}
  if [ ! -d ${NETBSD_SRC_DIR} ]; then
      mkdir -p ${NETBSD_SRC_DIR}
  fi

  # For all the ebuilds I've coded, I've worked with NetBSD 5.0-RELEASE, which is the final release for 5.0 branch.
  # ex: NETBSD_CVS_TAG="netbsd-5-0-RELEASE"
  # Default, if not set, is "netbsd-5-0-RELEASE"
  if [ -z ${NETBSD_CVS_TAG} ]; then
      NETBSD_CVS_TAG="netbsd-5-0-RELEASE"
      export NETBSD_CVS_TAG
  fi

  # CVS options
  ECVS_SERVER="anoncvs.NetBSD.org:/cvsroot"
  ECVS_AUTH="pserver"
  ECVS_USER="anoncvs"
  ECVS_PASS="anoncvs"
  # We fetch the whole src directory
  ECVS_MODULE="-r ${NETBSD_CVS_TAG} -P src"
  ECVS_TOP_DIR=""

  # We finally fetch the sources 
  cd ${NETBSD_SRC_DIR}/..
  cvs_src_unpack
}

