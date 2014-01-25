#!/bin/bash
# Copyright 1999-2013 Gentoo Foundation; Distributed under the GPL v2
# $Header: $

# Check if clang/clang++ exist before setting them so that we can more easily
# switch to this profile and build stages.
type -P clang > /dev/null && export CC=clang
if type -P clang++ > /dev/null && [ -f /usr/lib/libc++.so ]; then
	export CXX="clang++ -stdlib=libc++"
	# add -stdlib=libc++ to CXXFLAGS, bug 498910.
	[[ ${CXXFLAGS} != *-stdlib=libc++* ]] && export CXXFLAGS="-stdlib=libc++ ${CXXFLAGS}"
fi
