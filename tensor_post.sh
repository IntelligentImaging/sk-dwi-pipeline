#!/bin/bash

if [[ $# -ne 1 ]]; then	
	echo "Incorrect argument supplied!"
    echo "usage: sh $0 [CASE DIR]"
	echo "produces AD, FA, CFA, MD, RD from tensor"
    echo "Uses dti/*CWLLS.nii.gz and t2/atlas_mask*_1pt2_refine.nii.gz"
    echo
	exit
	fi

if [[ ! -d $1 ]] ; then
    echo err: $1 is not a directory
    exit 1
fi
DIR=`readlink -f $1`

echo "Searching for tensor and mask"
TENSOR=`find ${DIR}/dti -maxdepth 1 -type f -name atlas_tensor\*CWLLS1.nii.gz`
TBASE=`basename $TENSOR`
TTBASE="${TBASE%%.*}"
MASK=`find ${DIR}/t2 -maxdepth 1 -type f -name atlas_mask\*1pt2_refine.nii.gz` 
if [[ ! -f $TENSOR ]] ; then
    echo "err: tensor not found (check CASEDIR/dti)"
    exit 1
elif [[ ! -f $MASK ]] ; then
    echo "err: mask not found (check CASEDIR/t2)"
    exit 1
fi
echo "Tensor and mask found"

FULLPATH=`readlink -f $TENSOR`
CASEDIR="${FULLPATH%/dti*}"
TENSORDIR="${CASEDIR}/dti"
OUT="${TENSORDIR}/masked"
mkdir -pv ${OUT}
SCRIPTS="${CASEDIR}/scripts"
mkdir -pv $SCRIPTS
RUN="${SCRIPTS}/run-tensor_post.sh"
if [[ -f $RUN ]] ; then rm -v $RUN ; fi

# pick one of the tensor executable outputs
base=`basename $MASK`
IDtmp="${base#*mask_}"
ID="${IDtmp%%_1pt2*}"
for LOOK in CWLLS1 WLLS1 LLS ; do
	if echo ${FULLPATH} | grep -iq $LOOK ; then
	METRIC="$LOOK"
	break
	fi
done
MTENSOR="${OUT}/m-atlas_tensor_${ID}-${METRIC}.nii.gz"

# Crop
echo "Crop tensor"
cmd="crlMaskImage2 -i $TENSOR -m $MASK -o $MTENSOR"
echo $cmd >> $RUN
$cmd

# Diffusion metrics
AD="${OUT}/atlas_AD_${ID}-${METRIC}.nii.gz"
FA="${OUT}/atlas_FA_${ID}-${METRIC}.nii.gz"
MD="${OUT}/atlas_MD_${ID}-${METRIC}.nii.gz"
RD="${OUT}/atlas_RD_${ID}-${METRIC}.nii.gz"
CFA="${OUT}/atlas_CFA_${ID}-${METRIC}.nii.gz"

# Command for diffusion metrics
cmd="crlTensorScalarParameter $MTENSOR"
cmd="$cmd -a $AD"
cmd="$cmd -f $FA"
cmd="$cmd -m $MD"
cmd="$cmd -r $RD"
echo $cmd >> $RUN
echo "Generate scalar parameters"
$cmd

echo "Generate color FA"
cmd="TVtool -in ${TENSOR} -out ${CFA} -rgb"
echo $cmd >> $RUN
$cmd

if [[ ! -f $MTENSOR ]] ; then
	echo "Masked tensor NOT created"
else
	echo "Masked tensor: $MTENSOR"
fi
if [[ ! -f ${AD} || ! -f ${FA} || ! -f ${MD} || ! -f ${RD} || ! -f ${CFA} ]] ; then
	echo "Error: Output diffusion parameter(s) missing from ${OUT}"
else
	echo "Diffusion parameters located in ${OUT}"
fi
