#!/bin/bash

if [[ $# -lt 3 || $# -gt 4 ]]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [casepath/b0b1/dwi_b0_SUBJID.nii.gz] [SERVER] [BEST ALIGNMENT SUFFIX] [opt: dilate x]"
	echo "SUFFIX =	b0mi b0mim b0mimu b0ncc b0nccm b0nccmu"
	echo "		b1mi b1mim b1mimu b1ncc b1nccm b1nccmu"
	echo "Default dilation is 4"
	echo "Servers: auster, zephyr, boreas, dingo, bayes, eurus, io, lasker"
	exit
	fi

if [[ ! -f $1 ]] ; then
	echo "Couldn't find $1 - exiting"
	exit
	fi

B0=`readlink -f ${1}`
SERVER="$2"
REG="$3"
let DIL="4"
if [[ ! -z $4 ]] ; then
	DIL="$4"
	fi
CASEDIR="${B0%/b0b1*}"
CASEID=`basename $CASEDIR`
SCRIPTS="${CASEDIR}/scripts"

# select available python3 version
if python3.5 -V | grep -q "Python 3.5" ; then
    echo Python3.5
    py="python3.5"
elif python3.6 -V | grep -q -e "Python3.6" -e "Python 3.6" ; then
    echo Python3.6
    py="python3.6"
else
    echo "Python 3.5 or 3.6 not found"
    echo "Exiting"
    exit
fi

cmd="$py ${SCRIPTS}/doSVRandTensorComputev4.py ${B0} ${SERVER} ${REG} -dilateMask=${DIL}"
echo "$cmd" > ${SCRIPTS}/run-doSVRandTensorCompute.py.sh
$cmd
if [[ ! -f ${CASEDIR}/dti/atlas_tensor_${CASEID}_${REG}-CWLLS1.nii.gz ]] ; then
	echo "Something went wrong- tensor not generated"
else
	echo "Done. Check tensor output in dti/"
	echo "Refine t2/atlas_mask* overlaid with b0b1/atlas_b0* and b0b1/atlas_b1*"
	echo "Save refined mask as: t2/atlas_mask_CASEIDScanNum_1pt2_refine.nii.gz"
fi
