#!/bin/bash

# DEFAULT DTI STRING LIST ---> #
STR=''*BRAIN-DTI*' -o -iname '*BRAIN_DTI*' -o -iname '*BRAIN-DTI*' -o -iname '*DTI_Fetal*' -o -iname '*IVIM_DWI*' -o -iname '*Diffusion*' -o -iname '*FetalDTI*' -o -iname '*BRAINDTI*' -o -iname '*SMS2_DTI*''
                

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [--mrtrix || --crl || --dcm2niix] [--noOver] [-d DICOM directory] [-s DWI string ] -- [Subject Directory]
    Incorrect input supplied
    
    Takes DWI series in DICOM/ and converts to NIFTI or NHDR formats. Must specify -d to give a path to a DICOM raw data if it's not already linked in Subj/DICOM/
    
    [Subj Dir] The subject's DWI processing directory

    Optional arguments:
        --mrtrix    Use mrtrix mrconvert to convert images and get bvals/bvecs

        --crl       Use crlDICOMConverter for DICOM->NHDR and
                    crlDWIConvertNHDRForFSL for bvecs/bvals
            
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
        --mrtrix|mrconvert)
            let useMRTRIX=1
            ;;
        --crl)
            let useCRL=1
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

function slicetime_dcm {
	
	sliceT="$1"

	timetag=`dcmdump +L +P "0019,1029" $ex` # should be DCM tag for slice timings
    let time_error=0
	if [[ -n $timetag ]] ; then
		echo "Found slice timings DICOM tag [0019,1029]"
		echo "${timetag}" > $sliceT
	else
		echo "error: did not find slice timings from the usual dicom tag"
        let time_error=1 # this tells us the DICOM tag method failed
	fi
	}

function slicetime_json {

	json=`find ${odir} -type f -name \*json | head -n1`
    if [[ -f $json ]] ; then
    	image="${vol4D}"

    	# Find starting location of timing info
    	tim=`grep SliceTiming $json -n | cut -d':' -f1`

    	# Add one to go to the next line
    	let lbeg=$tim+1
    	echo SliceTimings begin on line $lbeg of the json

    	# Count number of slices
    	#z=`crlImageStats ${vol4D} | grep "Size:" | cut -d' ' -f4 | sed 's,\],,'`
        z=`mrinfo ${vol4D} -size | cut -d' ' -f1`

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
    	# By hook or by crook, we should have the slice timings now

    else
        echo "No JSON found"
    fi
	
}


idpath=`readlink -f $1`
if [[ ! -d $idpath ]] ; then
    echo "Path does not exist"
    exit 1
fi

id=`basename $idpath`
DICOM="${idpath}/DICOM"
VOLUMES="${idpath}/volumes"
NHDR="${idpath}/nrrd"
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
	echo DICOM series: $dcm
    
    wc=`find $dcm -type f | wc -w`
    if [[ $wc -lt 10 ]] ; then
        echo "Not many files in $dcm, this might be an aborted series. Skipping."
        continue
    fi

	ex=`find $dcm -type f | head -n1` # Example DICOM for tags

	# Get series number
	SerNumFull=`dcmdump +L +P "0020,0011" $ex`
	SerNum=`echo $SerNumFull | sed -e 's,.*\[,,g' -e 's,\].*,,g'`
	SerDscFull=`dcmdump +L +P "0008,103e" $ex`
	SerDsc=`echo $SerDscFull | sed -e 's,.*\[,,g' -e 's,\].*,,g' -e 's, ,_,g'`

        # If CRL option is set, convert with CRL tools
        if [[ $useCRL -eq 1 ]] ; then
            odir="${NHDR}/run_${SerNum}"
            bvals="${odir}/bvals"
            bvecs="${odir}/bvecs"
            vol4D="${odir}/${SerNum}_${SerDsc}.nii.gz"
            mkdir -pv ${odir}
	    convDCM="crlDICOMConverter -d ${dcm} -p ${odir}/vol"
	    convHDR="crlDWIConvertNHDRForFSL -i ${odir}/vol*diffusion*nhdr --data ${vol4D} --bvecs ${bvecs} --bvals ${bvals} --automirrorx 0"
            singularity exec docker://arfentul/crkit:latest /bin/bash -c "${convDCM}"
            singularity exec docker://arfentul/crkit:latest /bin/bash -c "${convHDR}"

	    slicetime_dcm ${odir}/sliceTiming.txt
        fi

        # If MRTRIX option is set, we also convert using MRCONVERT
        if [[ $useMRTRIX -eq 1 ]] ; then
            odir="${MRTRIX}/${SerNum}_${SerDsc}"
            mkdir -pv ${odir}
            bvals="${odir}/bvals"
            bvecs="${odir}/bvecs"
            vol4D="${odir}/${SerNum}_${SerDsc}.nii.gz"
            echo "Creating mrtrix mrconvert to extract standardized bvecs"
            mrconvert ${dcm} ${vol4D} -export_grad_fsl ${bvecs} ${bvals} -json_export "${odir}/${SerNum}_${SerDsc}.json" # -force
        fi

        slicetime_dcm ${odir}/sliceTiming.txt
        if [[ ${time_error}=1 ]] ; then
            slicetime_json
        fi

    fi
done
