#!/bin/bash

if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 casepath"
	exit
fi

# set paths
CASEDIR=`readlink -f ${1}`
ID=`basename $CASEDIR`
b0b1="${CASEDIR}/b0b1"
B0="${b0b1}/dwi_b0_${ID}.nii.gz"
if [[ ! -f $B0 ]] ; then
	echo "Supplied B0 image not found"
	exit 
fi
atlas_t2="${CASEDIR}/t2/atlas_t2_${ID}.nii.gz"
atlas_mask="${CASEDIR}/t2/atlas_mask_${ID}.nii.gz"
t2_t2="${CASEDIR}/t2/t2_t2_${ID}.nii.gz"
t2_mask="${CASEDIR}/t2/t2_mask_${ID}.nii.gz"
t2_dilmask="${CASEDIR}/t2/t2_mask_${ID}_dilated.nii.gz"
tfm_t2atlas="${CASEDIR}/t2/t2-atlas_${ID}.tfm"

echo $ID
# check for T2 files
if ! [[ -f $atlas_t2 && $atlas_mask && $t2_t2 && $t2_mask && $tfm_t2atlas ]] ; then
	echo "One of the following required files not found:"
	echo ${CASEDIR}/t2/atlas_t2_${ID}.nii.gz
	echo ${CASEDIR}/t2/atlas_mask_${ID}.nii.gz
	echo ${CASEDIR}/t2/t2_t2_${ID}.nii.gz
	echo ${CASEDIR}/t2/t2_mask_${ID}.nii.gz
	echo ${CASEDIR}/t2/t2-atlas_${ID}.tfm
	exit
fi

# Dilate t2 mask
crlBinaryMorphology $t2_mask dilate 1 6 $t2_dilmask

# Function to run Rigid Registration and transform compositions to get dwi->atlas transform
function register {
    b=$1
    metric=$2
    mask=$3
    if [[ $metric == "normcorr" ]] ; then
        mcode="ncc"
    else mcode="mi"
    fi
    # Registers the b0 or b1 recon to the t2 recon in subject space
    # Add in the optional mask argument
    if [[ $mask == "dilate" ]] ; then
        mcode="${mcode}m"
        cmd="crlRigidRegistration --fixedImageMask $t2_dilmask"
    elif [[ $mask == "mask" ]] ; then 
        mcode="${mcode}mu"
        cmd="crlRigidRegistration --fixedImageMask $t2_mask"
    else
        cmd="crlRigidRegistration"
    fi
    tfm_dwit2="${b0b1}/${b}-t2_${ID}_${mcode}.tfm"
    echo "Register DWI to t2: $b $mcode ($mask)"
    cmd="$cmd $t2_t2 ${b0b1}/dwi_${b}_${ID}.nii.gz ${b0b1}/t2_${b}_${ID}_${mcode}.nii.gz $tfm_dwit2 -t 2 -p 2 --metricName $metric"
    $cmd
    tfm_dwiatlas="${b0b1}/${b}-atlas_${ID}_${mcode}.tfm"
    # Combines dwi->t2 and t2->atlas transforms to get a dwi->atlas transform
    echo "Compose transforms: $b $mcode ($mask)"
    crlComposeAffineTransforms $tfm_t2atlas $tfm_dwit2 $tfm_dwiatlas
}

# Registration is very inconsistent so we run it several times with different settings
# We attempt registering both the b0 and b1 recons
# We try two reg metrics, mutual information (mi) and normalized correlation (normcorr)
# We try with 1. no mask, 2. a dilated mask, and 3. an undilated mask
# The last argument is a string that shows which combination of b0b1/metric/mask was used for the registration
register b0 normcorr nomask &
register b0 normcorr dilate &
register b0 normcorr mask   &
register b0 mi       nomask &
register b0 mi       dilate &
register b0 mi       mask   & 
wait
register b1 normcorr nomask &
register b1 normcorr dilate &
register b1 normcorr mask   &
register b1 mi       nomask &
register b1 mi       dilate &
register b1 mi       mask   &
wait

# Check output
REGCOUNT=`find ${CASEDIR}/b0b1/ -type f -iname t2_b?_\*.nii.gz | wc -w`
echo "$REGCOUNT registrations available"
if [[ $REGCOUNT -eq 0 ]] ; then
	echo "No registrations created"
	echo "Verify (moving) b0/b1 images and (target) files in t2 folder"
else
	echo "Note the best registration in b0b1/t2_*"
	echo "It will be needed for the next step"
fi
