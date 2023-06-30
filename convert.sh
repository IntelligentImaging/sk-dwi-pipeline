#!/bin/bash

# DEFAULT DTI STRING LIST ---> #
STR=''*BRAIN-DTI*' -o -iname '*BRAIN_DTI*' -o -iname '*BRAIN-DTI*' -o -iname '*DTI_Fetal*' -o -iname '*IVIM_DWI*' -o -iname '*Diffusion*' -o -iname '*FetalDTI*' -o -iname '*BRAINDTI*' -o -iname '*SMS2_DTI*''
                

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [--mrtrix || --crl || --dcm2niix] [--noOver] [-d DICOM directory] [-s DWI string ] -- [Subject Directory]
    Incorrect input supplied
    
    Takes DWI series in DICOM/ and converts to 4D (placed in nrrd/) and 3D (placed in volumes/) formats. Must specify -d to give a path to a DICOM raw data if it's not already linked in Subj/DICOM/
    
    [Subj Dir] The subject's DWI processing directory

    Optional arguments:
        --mrtrix    Use mrtrix mrconvert to convert images and get bvals/bvecs

        --crl       Use crlDICOMConverter for DICOM->NHDR and
                    crlDWIConvertNHDRForFSL for bvecs/bvals

        --dcm2niix  Use dcm2niix to convert DICOM->.nii.gz and get bvals/bvecs

        --noOver    Do not overwrite files already in volumes/ 
            
        -d      Supply the raw data directory to convert. This script will set up symbolic links to the data. 
        
        -s      Specify string of DWI folder which will be converted.
                By default the script will look for DICOM series with the 
                following strings: BRAIN-DTI, BRAIN_DTI, DTI_Fetal, IVIM_DWI, Diffusion, FetalDTI, BRAINDTI, SMS2_DTI
                The default list can be edited at the top of the script
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
        -d|--dicom)
            if [[ -d "$2" ]] ; then
                DDIR=`readlink -f $2` # Specify a DICOM directory to link and convert
                shift
            else
                die 'error: "-d" requires a DICOM directory'
            fi
            ;;
        --dcm2niix)
            let useDCM=1
            ;;
        --mrtrix)
            let useMRTRIX=1
            ;;
        --crl)
            let useCRL=1
            ;;
        --noOver)
            let noOver=1
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
NII="${idpath}/dcm2niix"
VOLUMES="${idpath}/volumes"
NHDR="${idpath}/nhdr"
MRTRIX="${idpath}/mrconvert"

if [[ $useCRL -ne 1 && $useMRTRIX -ne 1 && $useDCM -ne 1 ]] ; then
    die 'You need to specify which conversion program to use'
fi


if [[ -n ${DDIR} ]] ; then
    echo "Check for existing DICOMs (find: 'no such file or directory' message here is OK)"
    check=`find ${DICOM}/ -mindepth 1 | head -n1` # Because this may be a symlink, we need the slash after ${DICOM}
    if [[ -n $check ]] ; then
        echo "DICOM dir already has files, do you need to clear it first?"
        exit 1
    fi
    echo "Create symlink to raw DICOMs"
    ln -s ${DDIR} ${DICOM}
else DDIR=$DICOM # In the case there is already a DICOM dir with data, this sets the folder
fi 

# Generate list of DICOM folders to convert
if [[ $sopt=1 ]] ; then
    allDCM=`find -L ${DDIR} -type d \( -iname \*${STR}\* \) -a ! \( -iname '*_ColFA*' -o -iname '*_FA*' -o -iname '*_ADC*' -o -iname '*TRACEW*'  -o -iname '*b0' -o -iname '*TENSOR' -o -iname '*Lung*' \)`
else 
    allDCM=`find -L ${DDIR} -type d \( -iname ${STR} \) -a ! \( -iname '*_ColFA*' -o -iname '*_FA*' -o -iname '*_ADC*' -o -iname '*TRACEW*' -o -iname '*b0' -o -iname '*TENSOR' -o -iname '*Lung*' \)`
fi

for dcm in ${allDCM} ; do
    if [[ -d $dcm ]] ; then
        # INITIAL DCM2NIIX CONVERT, RENAME FILES, GENERATE SLICE TIMING
        # We also convert with dcm2niix because it gives us a backup if slicetiming wasn't pulled from dicom tags
        echo "Converting $dcm"
        base=`basename $dcm`
        out4D="${NII}/${base}"
        out3D="${VOLUMES}/${base}"
        mkdir -pv ${out4D}
        dcm2niix -z y -f %s_%d -w 1 -o ${out4D} ${dcm}
        nifti=`find ${out4D} -type f -name \*.nii.gz`
        if [[ ! -f $nifti ]] ; then
            echo "Conversion didn't run for some reason. Trying next image."
            continue
        fi

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
        sliceT="${out4D}/sliceTiming.txt"
        # DCMDUMP METHOD FOR GETTING SLICE TIMINGS #
        ex=`find $dcm -type f | head -n1`
        tagcheck=`dcmdump +L +P "0019,1029" $ex`
        if [[ -n $tagcheck ]] ; then
            echo "Found slice timings DICOM tag [0019,1029]"
            dcmdump +L +P "0019,1029" $ex > $sliceT
        # IF THAT DIDN'T WORK, WE LOOK AT THE JSON INSTEAD
        else 
            echo "Generate slice timing"
            json=`find ${out4D} -type f -name \*json | head -n1`
            image="${out4D}/${base}.nii.gz"
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
        fi 
        # By hook or by crook, we should have the slice timings now
        echo "Slice timing file: $sliceT"
        echo

        # If CRL option is set, we also convert using CRL tools
        if [[ $useCRL -eq 1 ]] ; then
            # Nested folders don't work here, need to re-assign input
            nest=`find $dwi -mindepth 1 -type d`
            if [[ -n $nest ]] ; then
                dwi=$nest
            fi
            crlbvals="${NHDR}/${base}/bvals"
            crlbvecs="${NHDR}/${base}/bvecs"
            crl4D="${NHDR}/${base}/${base}.nii.gz"
            echo "Creating CRL NHDR to extract standardized bvecs"
            mkdir -pv $NHDR/${base}
            crlDICOMConverter -d ${dcm} -p ${NHDR}/${base}/vol 
            crlDWIConvertNHDRForFSL -i ${NHDR}/${base}/vol*diffusion*nhdr --data ${crl4D} --bvecs ${crlbvecs} --bvals ${crlbvals} --automirrorx 0
        fi

        # If MRTRIX option is set, we also convert using MRCONVERT
        if [[ $useMRTRIX -eq 1 ]] ; then
            mrbvals="${MRTRIX}/${base}/bvals"
            mrbvecs="${MRTRIX}/${base}/bvecs"
            crl4D="${MRTRIX}/${base}/${base}.nii.gz"
            echo "Creating mrtrix mrconvert to extract standardized bvecs"
            mkdir -pv $MRTRIX/${base}
            mrconvert ${dcm} ${MRTRIX}/${base}/${base}.nii.gz -export_grad_fsl ${mrbvecs} ${mrbvals}
        fi

        # FSL SPLIT and copy to volumes folder, using the selected converted data (dcm2niix, mrconvert, or crl)
        if [[ $useMRTRIX -eq 1 && $noOver -ne 1 ]] ; then
            echo "Split 4D to 3D: mrconvert volumes"
            mkdir ${out3D}
            fslsplit ${crl4D} ${out3D}/vol_ -t
            echo "Copy gradient info and slice timing to volumes/"
            cp ${mrbvals} ${mrbvecs} ${sliceT} -v ${out3D}
        elif [[ $useCRL -eq 1 && $noOver -ne 1 ]] ; then
            echo "Split 4D to 3D: CRL converted volumes"
            mkdir ${out3D}
            fslsplit ${crl4D} ${out3D}/vol_ -t
            echo "Copy gradient info and slice timing to volumes/"
            cp ${crlbvals} ${crlbvecs} ${sliceT} -v ${out3D}
        elif [[ $useDCM -eq 1 && $noOver -ne 1 ]] ; then
            echo "Split 4D to 3D: dcm2niix converted volumes" 
            mkdir ${out3D}
            fslsplit ${nifti} ${out3D}/vol_ -t
            echo "Copy gradient info and slice timing to volumes/"
            cp ${bvals} ${bvecs} ${sliceT} -v ${out3D} 
        else
            echo "--noOver was set, not overwriting volumes/ folder"
        fi
        echo

    fi
done
