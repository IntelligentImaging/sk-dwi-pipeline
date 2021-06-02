#!/bin/bash

if [ $# -ne 2 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 casepath/b0b1/dwi_b0_SUBJID.nii.gz casepath/b0b1/b0-t2_SUBJID_Slicer.tfm"
    echo "This script is for running further registration refinements using the Slicer transform as an initialization"
    echo "in cases where manual landmark registration in 3DSlicer was required"
    echo "Slicer transform should be in ITK .tfm format"
	exit
	fi

# set paths
B0=`readlink -f ${1}`
if [[ ! -f $B0 ]] ; then
	echo "Supplied B0 image not found"
	exit 
fi
TFM=`readlink -f ${2}`
if [[ ! -f $TFM ]] ; then
    echo "Slicer transform not found"
    exit
fi
CASEDIR="${B0%/b0b1*}"
ID=`basename $CASEDIR`
SCRIPTS="${CASEDIR}/scripts"
echo $ID
# check for T2 files
if ! [[ -f ${CASEDIR}/t2/atlas_t2_${ID}.nii.gz && ${CASEDIR}/t2/atlas_mask_${ID}.nii.gz && ${CASEDIR}/t2/t2_t2_${ID}.nii.gz && ${CASEDIR}/t2/t2_mask_${ID}.nii.gz && ${CASEDIR}/t2/t2-atlas_${ID}.tfm ]] ; then
	echo "One of the following required files not found:"
	echo ${CASEDIR}/t2/atlas_t2_${ID}.nii.gz
	echo ${CASEDIR}/t2/atlas_mask_${ID}.nii.gz
	echo ${CASEDIR}/t2/t2_t2_${ID}.nii.gz
	echo ${CASEDIR}/t2/t2_mask_${ID}.nii.gz
	echo ${CASEDIR}/t2/t2-atlas_${ID}.tfm
	exit
fi

# select available python3 version
python3.5 -V
if [ $? -eq 0 ] ; then
        echo Python3.5
        py="python3.5"
fi
python3.6 -V
if [ $? -eq 0 ] ; then
        echo Python3.6
        py="python3.6"
fi
if [ $? -ne 0 ] ; then
        echo "Neither Python3.5 nor Python3.6 found"
        echo "Exiting"
        exit
fi

# Registration
cmd="nice $py ${SCRIPTS}/registerB0B1toT2-multicrl.py ${B0}"
echo "$cmd" > ${SCRIPTS}/run-registerB0B1toT2.py.sh
$cmd
REGCOUNT=`find ${CASEDIR}/b0b1/ -type f -iname t2_b?_\*.nii.gz | wc -w`
echo "$REGCOUNT registrations available"
if [[ $REGCOUNT -eq 0 ]] ; then
	echo "No registrations created"
	echo "Verify (moving) b0/b1 images and (target) files in t2 folder"
else
	echo "Note the best registration in b0b1/t2_*"
	echo "It will be needed for the next step"
fi
