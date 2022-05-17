#!/bin/bash

if [ $# -ne 2 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [tensor file] [refined mask]"
	echo "produces AD, FA, CFA, MD, RD from tensor"
	echo "INPUT tensor should be the .nii.gz file - which has been converted to float and cleaned with crlTensorClean"
	exit
	fi

TENSOR="$1"
TBASE=`basename $TENSOR`
TTBASE="${TBASE%%.*}"
MASK="$2"

if [[ ! -f $TENSOR || ! -f $MASK ]] ; then
	echo "Invalid inputs - check files"
	exit
	fi

FULLPATH=`readlink -f $TENSOR`
CASEDIR="${FULLPATH%/dti*}"
TENSORDIR="${CASEDIR}/dti"
OUT="${TENSORDIR}/masked"
mkdir -pv ${OUT}
SCRIPTS="${CASEDIR}/scripts"
mkdir -pv $SCRIPTS
if [[ -f $SCRIPTS/run-updateTensorOutput.sh ]] ; then rm -v $SCRIPTS/run-updateTensorOutput.sh ; fi

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

# crop tensor
cmd="crlMaskImage2 -i $TENSOR -m $MASK -o $MTENSOR"
echo $cmd >> $SCRIPTS/run-updateTensorOutput.sh
$cmd

# diffusion metrics
AD="${OUT}/atlas_AD_${ID}-${METRIC}.nii.gz"
FA="${OUT}/atlas_FA_${ID}-${METRIC}.nii.gz"
MD="${OUT}/atlas_MD_${ID}-${METRIC}.nii.gz"
RD="${OUT}/atlas_RD_${ID}-${METRIC}.nii.gz"
CFA="${OUT}/un-atlas_CFA_${ID}-${METRIC}.nii.gz"
#uCFA="${TENSORDIR}/atlas_CFA_${ID}_unrefined.nii.gz"
#if [[ ! -f $uCFA ]] ; then
#	uCFA=`find ${TENSORDIR}/refined/${METRIC}/ -type f -iname \*colorFA.nrrd`
#	fi
#CFA="${OUT}/atlas_CFA_${ID}-${METRIC}.nii.gz"

# command for diffusion metrics
cmd="crlTensorScalarParameter $MTENSOR"
cmd="$cmd -a $AD"
cmd="$cmd -f $FA"
cmd="$cmd -m $MD"
cmd="$cmd -r $RD"
echo $cmd >> $SCRIPTS/run-updateTensorOutput.sh
echo "Scalar Parameters"
$cmd

echo "Tensor to RGB"
cmd="crlTensorToRGB ${TENSOR} ${CFA}"
echo $cmd >> $SCRIPTS/run-updateTensorOutput.sh
$cmd
#echo "Masking RGB"
#cmd="crlImageAlgebra $uCFA multiply $MASK $CFA"
#echo "$cmd" >> $SCRIPTS/run-updateTensorOutput.sh
#$cmd
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
