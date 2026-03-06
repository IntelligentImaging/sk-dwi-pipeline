#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} -t [specify tensor] -- [CASE DIR] 
    Incorrect input supplied
	Produces AD, FA, CFA, MD, RD from tensor"
    By default uses dti/*CWLLS.nii.gz and t2/atlas_mask*_1pt2_refine.nii.gz"
    Optional argument -t [tensor.nii.gz] specified a tensor to use
EOF
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -t|--tensor)
            if [[ -f "$2" ]] ; then
                TENSOR=$2 # Specify
                shift
            else
                die 'error: Tensor not found'
            fi
            ;;
        --) # end of optionals
            shift
            break
            ;;
        -)?*
            printf 'warning: unknown option (ignored: %s\m' "$1" >&2
            ;;
        *) # default case, no optionals
            break
    esac
    shift
done

if [ $# -ne 1 ]; then
    show_help
    exit
fi 

DIR=`readlink -f $1`

echo "Searching for tensor and mask"
if [[ ! -n $TENSOR ]] ; then 
    TENSOR=`find ${DIR}/dti -maxdepth 1 -type f -name atlas_tensor\*CWLLS1.nii.gz | head -n1`
fi
echo Tensor = $TENSOR
TBASE=`basename $TENSOR`
TTBASE="${TBASE%%.*}"
MASK=`find ${DIR}/t2 -maxdepth 1 -type f -name atlas_mask\*1pt2_refine.nii.gz` 
if [[ ! -f $MASK ]] ; then
    MASK=`find ${DIR}/t2 -maxdepth 1 -type f -name atlas_mask\*1pt2.nii.gz`
    if [[ ! -f $MASK ]] ; then
        echo "err: mask not found (check CASEDIR/t2)"
        exit 1
    fi
fi
echo MASK = $MASK

FULLPATH=`readlink -f $TENSOR`
CASEDIR="${FULLPATH%/dti*}"
TENSORDIR="${CASEDIR}/dti"
OUT="${TENSORDIR}/masked"
SHDIR=`dirname $0`
mkdir -pv ${OUT}
SCRIPTS="${CASEDIR}/scripts"
mkdir -pv $SCRIPTS
RUN="${SCRIPTS}/run-tensor_post.sh"
if [[ -f $RUN ]] ; then rm -v $RUN ; fi
CFApy="${SHDIR}/cfa_from_tensor.py"

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

## Crop
#echo "Crop tensor"
##cmd="crlMaskImage2 -i $TENSOR -m $MASK -o $MTENSOR"
#cmd="fslmaths $TENSOR -mul $MASK $MTENSOR"
#echo $cmd >> $RUN
#$cmd




echo "masking tensor"
TCROPTMP=${DIR}/TCROP-${RANDOM}
mkdir -pv ${TCROPTMP}
let x=0
while [[ $x -lt 6 ]] ; do
    mrconvert -quiet ${TENSOR} -coord 4 ${x} -axes 0,1,2 ${TCROPTMP}/tensorsplit${x}.nii.gz -force
    mrcalc -quiet ${TCROPTMP}/tensorsplit${x}.nii.gz ${MASK} -multiply ${TCROPTMP}/mtensorsplit${x}.nii.gz -force
    ((x++))
done

mrcat -quiet ${TCROPTMP}/mtensorsplit*.nii.gz ${MTENSOR} -force
rm -rf ${TCROPTMP}

# Diffusion metrics
AD="${OUT}/atlas_AD_${ID}-${METRIC}.nii.gz"
FA="${OUT}/atlas_FA_${ID}-${METRIC}.nii.gz"
MD="${OUT}/atlas_MD_${ID}-${METRIC}.nii.gz"
RD="${OUT}/atlas_RD_${ID}-${METRIC}.nii.gz"
CFA="${OUT}/atlas_CFA_${ID}-${METRIC}.nii.gz"

# Command for diffusion metrics
if [[ -f $MTENSOR ]] ; then
	echo "Masked tensor: $MTENSOR"
    cmd="crlTensorScalarParameter $MTENSOR"
    cmd="$cmd -a $AD"
    cmd="$cmd -f $FA"
    cmd="$cmd -m $MD"
    cmd="$cmd -r $RD"
    echo $cmd >> $RUN
    echo "Generate scalar parameters"
    echo $cmd
    # cmd="TVtool -in ${MTENSOR} -out ${CFA} -rgb"
    cmd="python $CFApy $MTENSOR $CFA"
    echo $cmd >> $RUN
    echo "Generate color FA"
    $cmd
else echo "Masked tensor was NOT created"
fi

if [[ ! -f ${AD} || ! -f ${FA} || ! -f ${MD} || ! -f ${RD} || ! -f ${CFA} ]] ; then
	echo "Error: Output diffusion parameter(s) missing from ${OUT}"
else
	echo "Diffusion parameters located in ${OUT}"
fi
