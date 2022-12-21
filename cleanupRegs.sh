#!/bin/bash

if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [best reg]"
    echo "copies [best reg] to a tmp dir"
    echo " and clears all other registration attempts"
    echo " WARNING: permanently deletes all un-selected registrations"
	exit
	fi

best=`readlink -f $1`
if [[ ! -f $best ]] ; then
    echo "$best doesn't exist"
    exit 1
fi

base=`basename $best .nii.gz`
dir=`dirname $best`
casedir=`dirname $dir`
id=`basename $casedir`

b=`echo $base | sed 's,.*_\(b[0-1]\)_.*,\1,g'` # grab whether it was b0 or b1
met=`echo $base | sed 's,.*_\(.*\),\1,g'` # grab registration metric
toT2="${b}-t2_${id}_${met}.tfm"
toAtlas="${b}-atlas_${id}_${met}.tfm"
if [[ ! -f $toT2 || ! -f $toAtlas ]] ; then
    echo "Couldn't locate to-T2 or to-Atlas transform, check inputs"
    exit
fi

tmpdir="${dir}/tmp${RANDOM}"
mkdir -v $tmpdir
if [[ ! -d $tmpdir ]] ; then
    echo "couldn't create directory tmp, exiting"
    exit 1
fi

mv -v ${best} ${b}-t2_*_${met}.tfm ${b}-atlas_*_${met}.tfm ${tmpdir}/
rm -v ${dir}/t2_b*z ${dir}/b*-t2*tfm ${dir}/b*-atlas*tfm
mv -v ${tmpdir}/* ${dir}/
rmdir -v ${tmpdir}
