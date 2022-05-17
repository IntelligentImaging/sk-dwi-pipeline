#!/bin/bash

if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 CASEDIR"
	exit
	fi
CASEDIR=`readlink -f $1`
if [[ ! -d $CASEDIR ]] ; then
	echo "Directory not found"
	echo "usage: sh $0 CASEDIR"
	exit
	fi
SCRIPTS="${CASEDIR}/scripts"
cmd="python3 ${SCRIPTS}/prepDWI.py ${CASEDIR}"
echo "$cmd" > ${SCRIPTS}/run-prepDWI.py.sh
$cmd
VOLCOUNT=`find ${CASEDIR}/volumes/ -maxdepth 1 -mindepth 1 -type d | wc -l`
echo "Number of converted volumes: ${VOLCOUNT}"
if [[ ${VOLCOUNT} -eq 0 ]] ; then
	echo "Something went wrong- no volumes converted"
	echo "Verify DICOMs in DICOM folder"
else
	echo "Volumes prepared"
	echo "Now create B0 ROI crop and run createB0B1"
fi
