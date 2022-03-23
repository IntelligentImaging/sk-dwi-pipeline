#!/bin/bash

# DEFAULT DTI STRING LIST ---> #
STR=''*BRAIN-DTI*' -o -iname '*BRAIN_DTI*' -o -iname '*DTI_Fetal*' -o -iname '*IVIM_DWI*' -o -iname '*Diffusion*' -o -iname '*FetalDTI*' -o -iname '*BRAINDTI*''
                

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-d DICOM directory] [-s DWI string ] -- [Subject Directory]
    Incorrect input supplied
    
    Takes DWI series in DICOM/ and converts to 4D (placed in nrrd/) and 3D (placed in volumes/) formats. Must specify -d to give a path to a DICOM raw data if it's not already linked in Subj/DICOM/
    
    Required argument:
    [Subject Directory] is the DWI processing directory- it will have folders named DICOM/
        t2/ b0b1/ nrrd/ volumes/ scripts/

    Optional arguments:
        -d  Supply the raw data directory to convert. This script will set up symbolic
            links to the data. 
        
        -s  Specify string of DWI folder which will be converted.
            By default the script will look for DICOM series with the 
            following strings: BRAIN-DTI, BRAIN_DTI, DTI_Fetal, IVIM_DWI, Diffusion,
                FetalDTI, BRAINDTI
EOF
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -d|--dicom)
            if [[ -d "$2" ]] ; then
                DDIR=$2 # Specify a DICOM directory to link and convert
                shift
            else
                die 'error: "-d" requires a DICOM directory'
            fi
            ;;
        -s|--string)
            if [[ -n "$2" ]] ; then
                STR="${2}" # Specify string to select from DICOM dir
                let sopt=1
                shift
            else
                die 'error: "-s" requires you to specify a string to search'
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

idpath=`readlink -f $1`
if [[ ! -d $idpath ]] ; then
    echo "Path does not exist"
    exit 1
fi

id=`basename $idpath`
DICOM="${idpath}/DICOM"
NRRD="${idpath}/nrrd"
VOLUMES="${idpath}/volumes"

if [[ ! -d $DICOM ]] ; then ln -s ${DDIR} ${DICOM} ; fi # create a symlink to the raw data
if [[ ! -n ${DDIR} ]] ; then DDIR=`readlink -f $DICOM` ; fi # grab the path to the raw directory if we don't already have one
# Generate list of DICOM folders to convert
if [[ $sopt=1 ]] ; then
    allDCM=`find ${DDIR} -type d \( -iname \*${STR}\* \) -a ! \( -iname '*_ColFA' -o -iname '*_FA' -o -iname '*_ADC' -o -iname '*TRACEW' \)`
else 
    allDCM=`find ${DDIR} -type d \( -iname ${STR} \) -a ! \( -iname '*_ColFA' -o -iname '*_FA' -o -iname '*_ADC' -o -iname '*TRACEW' \)`
fi

for dcm in ${allDCM} ; do
    if [[ -d $dcm ]] ; then
        # INITIAL DCM2NIIX CONVERT, RENAME FILES, GENERATE SLICE TIMING
        echo "Converting $dcm"
        base=`basename $dcm`
        out4D="${NRRD}/${base}"
        out3D="${VOLUMES}/${base}"
        mkdir -pv ${out4D} ${out3D}
        dcm2niix -z y -f %s_%d -w 1 -o ${out4D} ${dcm}
        nifti=`find ${out4D} -type f -name \*.nii.gz`
        nbase=`basename $nifti .nii.gz`
        echo
        
        echo "Rename bvals and bvecs"
        bvals="${out4D}/bvals"
        bvecs="${out4D}/bvecs"
        mv -v ${out4D}/${nbase}.bval ${bvals}
        mv -v ${out4D}/${nbase}.bvec ${bvecs}
        echo "bvals = $bvals"
        echo "bvecs = $bvecs"       
        echo
        
        # |v| SLICE TIMING |v|
        echo "Generate slice timing"
        json=`find ${out4D} -type f -name \*json | head -n1`
        sliceT="${out4D}/sliceTiming.txt"
        # image="${out4D}/${base}.nii.gz"
        # Find starting location of timing info
        tim=`grep Timing $json -n | cut -d':' -f1`
        # Add one to go to the next line
        let lbeg=$tim+1
        echo SliceTimings begin on line $lbeg of the json
        # Count number of slices
        z=`crlImageStats ${nifti} | grep "Size:" | cut -d' ' -f4 | sed 's,\],,'`
        # Number of times we will need to advance to next line
        let slices=$z-1
        # Get last line of Timings
        lend=`echo ${lbeg} + ${slices} | bc`
        echo Timings go from line $lbeg to $lend
        # Extract lines
        sing=`sed -ne "${lbeg},${lend}p" < $json`
        final=`echo $sing | sed -e 's/, /\\\/g' -e 's/ \],//g'`
        echo "Slice timings:"
        echo $final
        echo "(0019,1029) FD ${final} # 288,36 Genereated by Clem script" > $sliceT
        echo "Slice timing file: $sliceT"
        echo

        # FSL SPLIT and copy to volumes folderi
        echo "Split 4D to 3D"
        fslsplit ${nifti} ${out3D}/vol_ -t
        echo

        # Copy bvals, bvecs, and sliceTiming.txt to the recon directory
        echo "Copy to reconstruction directory"
        cp ${bvals} ${bvecs} ${sliceT} -v ${out3D} 
        
        echo
    fi
done
