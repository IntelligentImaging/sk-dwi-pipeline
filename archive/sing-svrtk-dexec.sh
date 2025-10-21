#!/bin/bash
if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [run script]"
    echo "This script is used after running svrtk-dock-gen.sh to generate 'run-svrtk.sh'"
    echo "Supply a recon directory (usually named 'nii') which has a run-svrtk.sh"
    echo "Creates a detached SVRTK docker image, and then uses it to execute the run script, then deletes the container"
	exit
	fi

# Server directory to be mounted
run=`readlink -f $1`
dir=`dirname $run`
base=`basename $run`

# Validate argument
if [[ ! -f ${run} ]] ; then
    echo error: ${run} not found
    exit 1
fi

cd ${dir}
echo "Running SVRTK container"
singularity exec docker://fetalsvrtk/svrtk /bin/sh $base
echo
echo "Recon done"
cd -
date
