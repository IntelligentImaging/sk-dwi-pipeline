#!/bin/bash

if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [best reg]"
    echo "copies [best reg] to t2_t2_CASEID.nii.gz"
    echo " and clears all other registration attempts"
    echo " WARNING: permanently deletes all un-selected registrations"
	exit
	fi

best="$1"
if [[ ! -f $best ]] ; then
    echo "$best doesn't exist"
    exit 1
fi

base=`basename $best .nii.gz`
dir=`dirname $best`
tmpdir="${dir}/tmp${RANDOM}"
mkdir -v $tmpdir

if [[ ! -d $tmpdir ]] ; then
    echo "couldn't create directory tmp, exiting"
    exit 1
fi

b=`echo $base | sed 's,.*_\(b[0-1]\)_.*,\1,g'` # grab whether it was b0 or b1
met=`echo $base | sed 's,.*_\(.*\),\1,g'` # grab registration metric
mv -v ${best} ${b}-t2_*_${met}.tfm ${b}-atlas_*_${met}.tfm ${tmpdir}/
rm -v ${dir}/t2_b*z ${dir}/b*tfm
mv -v ${tmpdir}/* ${dir}/
rmdir -v ${tmpdir}
