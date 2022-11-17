#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [opt: specify tensor] -- [CASE DIR]
    Incorrect input supplied
	Runs TrackVis dti_tracker to produce .trk file for viewing with TrackVis
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
                MTENSOR=$2 # Specify
                shift
            else
                die 'error: Tensor file not found'
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

# Set directories
CASEDIR=`readlink -f $1`
if [[ ! -d $CASEDIR ]] ; then
    echo $CASEDIR is not a directory
    exit 1
fi
ID=`basename $CASEDIR`
echo $ID
TVDIR="${CASEDIR}/trk"
mkdir -pv $TVDIR

# Find pipeline output and set names compatible with Trackvis
#B0=`find ${CASEDIR}/b0b1/ -type f -iname atlas_b0_${ID}\* | head -n1`
MASK=`find ${CASEDIR}/t2/ -type f -iname atlas_mask_${ID}\*refine.nii\* | head -n1`
if [[ ! -n $MTENSOR ]] ; then
    MTENSOR=`find ${CASEDIR}/dti/masked/ -type f -iname m-atlas_tensor_${ID}\* | head -n1`
fi
ADC=`find ${CASEDIR}/dti/masked/ -type f -iname atlas_AD_${ID}\* | head -n1`
FA=`find ${CASEDIR}/dti/masked/ -type f -iname atlas_FA_${ID}\* | head -n1`
#CFA=`find ${CASEDIR}/dti/masked/ -type f -iname atlas_CFA_${ID}\* | head -n1`
TRK="${TVDIR}/tracts_${ID}.trk"
OUTMASK="mask.nii"
if [[ $MASK = *.gz ]] ; then
	OUTMASK="${OUTMASK}.gz"
	fi

# Copy to Trackvis directory
#cp $B0 -v ${TVDIR}/crl_b0.nii.gz
cp $MASK -v ${TVDIR}/${OUTMASK}
gzip -f ${TVDIR}/mask.nii
cp $MTENSOR -v ${TVDIR}/crl_tensor.nii.gz
cp $ADC -v ${TVDIR}/crl_adc.nii.gz
cp $FA -v ${TVDIR}/crl_fa.nii.gz
#cp $CFA -v ${TVDIR}/crl_fa_color.nii.gz
echo FACT
cmd="dti_tracker ${TVDIR}/crl ${TVDIR}/tracts_${ID}_fact.trk -it nii.gz -m ${TVDIR}/mask.nii.gz"
echo $cmd > ${TVDIR}/run-tracker.sh
$cmd
#echo TL
#cmd="dti_tracker ${TVDIR}/crl ${TVDIR}/tracts_${ID}_tl.trk -it nii.gz -m ${TVDIR}/mask.nii.gz -tl"
#echo $cmd >> ${TVDIR}/run-tracker.sh
#$cmd
echo
