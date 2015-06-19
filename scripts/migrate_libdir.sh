#!/bin/bash
for d in / /usr /usr/local
do
	if [ -L ${d}/lib ] ; then
		ls -l ${d}/lib | grep lib64 > /dev/null 2>&1
		if [ $? -eq 0 ] ; then
			rm ${d}/lib
			if [ -d ${d}/lib64 ] ; then
				LD_LIBRARY_PATH="${d}/lib64" mv ${d}/lib64 ${d}/lib
			else
				mkdir ${d}/lib
			fi
			ln -s lib ${d}/lib64
			echo "Migrated to ${d}/lib from ${d}/lib64"
		else
			echo "Migration fails, lib symlink target is not ${d}/lib64."
			ls -l ${d}/lib
		fi
	fi
done

