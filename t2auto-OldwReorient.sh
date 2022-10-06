#!/bin/bash

if [[ $# -ne 2 && $# -ne 1 ]]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [CASE T2 nii DIR] [opt: CASE DIFF DIR]"
	echo "runs t2Atlas prep script for DTI processing and copies output to diffusion dir"
	echo "finds inputs automatically"
	exit 1
fi

# Verify script arguments
NII=`readlink -f $1`
if [[ ! $NII == *"nii"*  && -d $NII ]] ; then
    NII=`find $NII -type d -name nii`
fi
echo "Input T2 recon directory: $NII"
if [[ ! -d ${NII} ]] ; then
    echo "T2 nii dir not found, check path"
    echo $1
    exit 1
fi

if [[ -n $2 ]] ; then
    DIFF=`readlink -f $2`
    echo "Diffusion processing directory: $DIFF"
    if [[ ! -d $DIFF ]] ; then
        echo "DTI dir not found, check path"
        echo $DIFF
        exit 1
    fi
    DIFFt2="${DIFF}/t2"
fi

# t2Atlas prep script for processing
T2sh="${FETALDTI}/createAtlasT2andMaskFile_OldwReorient.sh"
T2shlocal="${NII}/`basename $T2sh`"

# Use find to locate T2 files (oriented recon, mask, recon atlas space, transform, and T2 stack used for orientation)
echo "Finding T2 files..."
DIR=`dirname ${NII}`
CASEID=`basename ${DIR}`
# Find oriented T2 recon
rT2=`find ${NII} -maxdepth 1 -iname r3D\*best\*`
if [[ ! -f $rT2 ]] ; then
    echo "error: T2 recon (r3DreconOfetus_best*) not found"
    echo "Check case recon folder"
    exit 1
fi
# Find oriented T2 recon mask
MASK=`find ${NII}/registration -maxdepth 1 -name mask_\*_registration\*`
NMASKS=`echo $MASK | wc -w`
if [[ $NMASKS -gt 1 ]] ; then
    echo "error: More than one mask found"
    echo "Check case recon registration folder"
    exit 1
elif [[ ! -f $MASK ]] ; then
    echo "error: T2 recon mask (mask_ID_registration*) not found"
    echo "Check case recon registration folder"
    exit 1
fi
# Find atlas space T2 recon
REG=`find ${NII}/registration -maxdepth 1 -iname register\*nii\* -o -iname atlas_t2final\*nii\* | head -n1`
if [[ ! -f $REG ]] ; then
    echo "error: Atlas-registrered recon (register*) not found"
    echo "Check case recon registration folder"
    exit 1
fi
# Find transform from T2 recon to atlas
TFM=`find ${NII}/registration -maxdepth 1 -iname \*nx\*txt -o -iname \*nx\*mat -o -iname \*nx\*tfm -o -iname tfm\*nx\*txt -o -iname \*r3D\*mat -o -iname tfm_\*.txt`
NTFMS=`echo $TFM | wc -w`
if [[ $NTFMS -gt 1 ]] ; then
	echo "error: More then one transform found"
	echo "check case recon registration folder"
	exit 1
elif [[ ! -f $TFM ]] ; then
    echo "error: Transform not found"
    echo "check case recon registration folder"
    exit 1
fi
# Find T2 stack reference used for orientation (for making r3DreconOfetus_best*)
STACK=`echo $rT2 | sed 's,r3DreconO,,g' | sed 's,_best,,g'`
if [[ ! -f $STACK ]] ; then
    echo "error: Reference T2 stack (fetus_xx.nii.gz) not found"
    echo "Check case recon folder"
    exit 1
fi

# Process T2 files
echo "=== All files found for CaseID $CASEID ==="
echo "T2 recon: $rT2"
echo "T2 mask: $MASK"
echo "T2 final recon atlas space: $REG"
echo "Transform (T2->Atlas): $TFM"
echo "Reference T2 stack: $STACK"

# "Run" script
SCRIPT="${NII}/run-createT2Atlas.sh"
# Copy process script to case dir and run command
cp $T2sh -v $T2shlocal
cmd="sh $T2shlocal $MASK $REG $TFM $CASEID $STACK"
echo $cmd > $SCRIPT
$cmd
# Check output and copy to diffusion dir
AT="${NII}/atlas_t2_${CASEID}.nii.gz"
ATm="${NII}/atlas_mask_${CASEID}.nii.gz"
TM="${NII}/t2_t2_${CASEID}.nii.gz"
TMm="${NII}/t2_mask_${CASEID}.nii.gz"
outTFM="${NII}/t2-atlas_${CASEID}.tfm" 
outFINAL="${NII}/atlas_t2final_${CASEID}.nii.gz"

if [[ -f ${REG} ]] ; then
    cp ${REG} -v ${outFINAL}
else echo "Final cropped, atlas space T2 recon wasn't found (not necessary for DWI pipeline)"
fi

if [[ -f ${AT} && -f ${ATm} && -f ${TM} && -f ${TMm} && -f ${outTFM} && -f ${REG} ]] ; then
    echo "T2 prep done"
    if [[ -n $2 ]] ; then
        echo "copy to DWI dir"
        cp ${AT} ${ATm} ${TM} ${TMm} ${outTFM} -v ${DIFFt2}/
        cp ${outFINAL} -v ${DIFFt2}
    else echo "DWI dir not supplied"
    fi
else echo "Something went wrong- missing outputs"
fi
echo
