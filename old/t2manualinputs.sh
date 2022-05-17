#!/bin/bash

if [ $# -ne 5 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [mask_r3D.nii] [register.nii.gz] [nxb_to_atlas.mat] [CASEID] [fetus_xx.nii]"
    echo "Must be in the T2 RECON NII directory"
	exit
	fi
MASK=$1
REG=$2
TFM=$3
CASEID=$4
STACK=$5

if [[ ! -f $MASK || ! -f $REG || ! -f $TFM || ! -f $STACK ]] ; then
	echo "Invalid input(s) - check files"
	exit
	fi

if [[ -f run-createT2Atlas.sh ]] ; then rm -v run-createT2Atlas.sh ; fi 
cp /home/ch191070/scripts/fetalDTI/createAtlasT2andMaskFilev4.sh -v .
cmd="sh ./createAtlasT2andMaskFilev4.sh $MASK $REG $TFM $CASEID $STACK"

echo $cmd >> run-createT2Atlas.sh
$cmd
echo "Outputs:"
echo atlas_t2_${CASEID}.nii.gz
echo atlas_mask_${CASEID}.nii.gz
echo t2_t2_${CASEID}.nii.gz
echo t2_mask_${CASEID}.nii.gz
echo t2-atlas_${CASEID}.tfm
