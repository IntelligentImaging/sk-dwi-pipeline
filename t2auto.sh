#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-d CASE DIFF DIR] [-id SUBJ ID] -- [input T2 NII dir]
    Incorrect input supplied

    Optional arguments:
        -d      Points to a diffusion processing directory to which the output
                files will be copied

        -id     Sets the subject ID. By default the script will try to figure
                out the ID from the directory path
EOF
}

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -d|--dwi)
            if [[ -d "$2" ]] ; then
                DIFF=$2 # Specify
                shift
            else
                die 'error: Supplied DWI dir not found'
            fi
            ;;
        -id)
            if [[ -n "$2" ]] ; then
                CASEID="${2}" # Specify
                shift
            else
                die 'error: Subject ID not specified after -id'
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

# Verify script arguments
if [[ $# -ne 1 ]] ; then
    show_help
    die
fi
NII=`readlink -f $1`
if [[ ! $NII == *"nii"* && ! $NII == svrtk && -d $NII ]] ; then
    NII=`find $NII -type d -name nii -o -name svrtk`
fi
echo "Input T2 recon directory: $NII"
if [[ ! -d ${NII} ]] ; then
    echo "T2 nii dir not found, check path"
    echo $1
    exit 1
fi

DIFFt2="${DIFF}/t2"
# t2Atlas prep script for processing
T2sh="${FETALDTI}/createAtlasT2andMaskFile.sh"

# Use find to locate T2 files (oriented recon, mask, recon atlas space, transform, and T2 stack used for orientation)
echo "Finding T2 files..."
DIR=`dirname ${NII}`
if [[ ! -n $CASEID ]] ; then CASEID=`basename ${DIR}` ; fi
RDIR="${NII}/registration"
# Find oriented T2 recon
T2=`find ${RDIR} -maxdepth 1 -iname nxb\*z | sort | head -n1`
if [[ ! -f $T2 ]] ; then
    echo "error: T2 recon (registration/nxb*z) not found"
    exit 1
fi

# Find oriented T2 recon mask
MASK=`find ${RDIR} -maxdepth 1 -name mask_\*_registration\*`
NMASKS=`echo $MASK | wc -w`
if [[ $NMASKS -gt 1 ]] ; then
    echo "error: More than one mask found"
    echo "Check t2 registration folder"
    exit 1
elif [[ ! -f $MASK ]] ; then
    echo "error: T2 recon mask (mask_ID_registration*) not found"
    echo "Check t2 registration folder"
    exit 1
fi
# Find atlas space T2 recon
REG=`find ${RDIR} -maxdepth 1 -iname register\*nii\* -o -iname atlas_t2final\*nii\* | head -n1`
if [[ ! -f $REG ]] ; then
    echo "error: Atlas-registrered recon (registration/atlas_t2final* or register*) not found"
    exit 1
fi
# Find transform from T2 recon to atlas
TFM=`find ${NII}/registration -maxdepth 1 -iname \*nx\*txt -o -iname \*nx\*mat -o -iname \*nx\*tfm -o -iname tfm\*nx\*txt -o -iname \*r3D\*mat -o -iname tfm_\*.txt | head -n1`
NTFMS=`echo $TFM | wc -w`
if [[ ! -f $TFM ]] ; then
    echo "error: Transform not found"
    echo "check case recon registration folder"
    exit 1
fi

# Process T2 files
echo "=== All files found for CaseID $CASEID ==="
echo "T2 recon: $T2"
echo "T2 mask: $MASK"
echo "T2 final recon atlas space: $REG"
echo "Transform (T2->Atlas): $TFM"

# "Run" script
SCRIPT="${NII}/run-createT2Atlas.sh"
# Copy process script to case dir and run command
cmd="bash $T2sh $T2 $MASK $REG $TFM"
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
    if [[ -n $DIFF ]] ; then
        echo "copy to DWI dir"
        cp ${AT} ${ATm} ${TM} ${TMm} ${outTFM} -v ${DIFFt2}/
        cp ${outFINAL} -v ${DIFFt2}
    else echo "DWI dir not supplied"
    fi
else echo "Something went wrong- missing outputs"
fi
echo
