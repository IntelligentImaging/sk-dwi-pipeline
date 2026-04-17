#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-n image limit per scan] [-m ROI mask] -- [subj converted data dir]
    
    This script sorts volumes by bvalues before assigning volumes to be used for reconstruction.
    By default, the lowest b-value will be used first. 

    -n N    Sets image limit for each series folder in initial b0b1 reconstructions.
            For example, "-n 6" for a subject with three diffusion scans would mean 
            a maximum of 18 total volumes are reconstructed for both B0 and B1.

    -m MASK Specifies ROI mask file; otherwise script will look in case directory for a
            file named mask_*.nii.gz. 
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
        -n)
            if [[ "$2" -gt 0 ]] ; then
                let LIMIT=$2 # Specify how many volumes to take from each scan
                shift
            else
                die 'error: -n argument should be a number of volumes to include from each series'
            fi
            ;;
        -m)
            if [[ -f $2 ]] ; then
                mask=$2
                shift
            else
                die 'error: mask not found'
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

if [[ ! -n $LIMIT ]] ; then let LIMIT=999 ; fi # default limit (aka no limit)

data=`readlink -f $1`
convertername=`basename $data` 
if [[ ! -d $data || $convertername == volumes || $convertername == DICOM || $convertername == b0b1 || $convertername == dti || $convertername == t2 ]] ; then
    echo "You may have failed to supply the converted directory path. Exiting."
    exit
fi

subj=`dirname $data`
id=`basename $subj`
svrtk="svrtk"
volumes="${subj}/volumes"

# Look for a mask if one was not supplied
if [[ ! -n $mask ]] ; then
    mask=`find $subj -maxdepth 1 -type f -name mask_\*.nii.gz`
    if [[ ! -n $mask ]] ; then
        die "Could not find mask in $data"
    fi
fi

mkdir -pv ${subj}/svrtk ${volumes}
cp $mask -v ${subj}/${svrtk}/mask_svrtk.nii.gz
svrmask="${svrtk}/mask_svrtk.nii.gz"
b0dir=${svrtk}/b0
b1dir=${svrtk}/b1
runb0=${subj}/${b0dir}/run-svrtk.sh
runb1=${subj}/${b1dir}/run-svrtk.sh
b0SVR="${b0dir}/SVRTK-dwi_b0_${id}.nii.gz"
b1SVR="${b1dir}/SVRTK-dwi_b1_${id}.nii.gz"
b0list="${subj}/${b0dir}/b0list.txt"
b1list="${subj}/${b1dir}/b1list.txt"
mkdir -pv ${subj}/${b0dir} ${subj}/${b1dir}
if [[ -f $runb0 ]] ; then rm $runb0 ; fi
if [[ -f $runb1 ]] ; then rm $runb1 ; fi
if [[ -f $b0list ]] ; then rm $b0list ; fi
if [[ -f $b1list ]] ; then rm $b1list ; fi

for dwi in ${data}/*/*.nii.gz ; do
    if [[ -f $dwi ]] ; then 
        base=`basename $dwi .nii.gz`
	    dwidir=`dirname $dwi`

        echo "Split DWI from 4D series to 3D volumes"
        split="${volumes}/${base}"
        mkdir -pv ${split}

        ndim=`mrinfo -size ${dwi} | cut -d' ' -f4`
        let count=0
        while [[ $count -lt $ndim ]] ; do
            count4=$(printf "%04d" $count)
            printf "\rvolume: ${count4}"
            mrconvert -quiet ${dwi} -coord 3 ${count} -axes 0,1,2 ${split}/vol_${count4}.nii.gz -force # split volumes
            ((count++))
        done
        echo

	bvals=`find ${dwidir} -name \*bval\*`
	bvecs=`find ${dwidir} -name \*bvec\*`
	if [[ ! -f  ${dwidir}/sliceTiming.txt ]] ; then
		echo no slice timing file found, checking for json
		json=`find ${dwidir} -name \*json`
		if [[ -f ${json} ]] ; then
			echo exporting slice timing from json	
			jq -c '.SliceTiming' ${json} >> ${dwidir}/sliceTiming.txt
		else echo "no json found"
		fi
	else
		cp ${dwidir}/sliceTiming.txt -v ${split}/
	fi	

        cp ${dwidir}/sliceTiming.txt -vup ${split}/
	cp ${bvals} -vup ${split}/bvals
	cp ${bvecs} -vup ${split}/bvecs

        # Make a sorted array with the bvalue-volume pairs
        declare -a BVALS
        let count=0
        for b in `cat ${split}/bvals` ; do
            count4d=$(printf "%04d" $count)
            BVALS[$count]="$b,$count4d"
            ((count++))
        done
        IFS=$'\n' SORTED=($(sort <<<"${BVALS[*]}")); unset IFS

        let count=0
        let b0x=0 # this assumes the volumes are named/numbered vol_0000, vol_0001, etc
        let b1x=0

        # Read the array and put x of b0's and b1's for each recon according to the set limit
        while [[ $b0x -lt $LIMIT || $b1x -lt $LIMIT ]] ; do
            volbval=`echo ${SORTED[$count]} | cut -d',' -f1`
            volnum=`echo ${SORTED[$count]} | cut -d',' -f2`

            #echo this is the volbval: $volbval
            if [[ ! -n $volbval ]] ; then 
                echo "no more volumes to sort"
                break
            fi

            # if 0, use for B0 recon, if greater than 0, use for B1 recon
            if [[ $volbval -eq 0 && $b0x -lt $LIMIT ]] ; then

                echo ${base}/vol_${volnum}.nii.gz $volbval # this is the volume-bvalue combo
                echo ${split}/vol_${volnum}.nii.gz >> ${b0list}
                ((b0x++))

            elif [[ $volbval > 0 && $b1x -lt $LIMIT ]] ; then

                if [[ $b0x -lt $LIMIT ]] ; then
                    echo "== No more B0's in series =="
                    b0x=$LIMIT
                fi

                echo ${base}/vol_${volnum}.nii.gz $volbval
                echo ${split}/vol_${volnum}.nii.gz >> ${b1list}

                ((b1x++))
            fi

            #if [[ $b0x -ge $LIMIT && $b1x -ge $LIMIT ]] ; then break ; fi

            ((count++)) # increase index by one
        done
    fi
done

# SVRTK requires the number of input images
nb0=`wc -l ${b0list} | cut -d' ' -f1`
nb1=`wc -l ${b1list} | cut -d' ' -f1`

# Write script for b0 recon
echo "mirtk reconstruct $b0SVR $nb0 \\" >> $runb0
for im in `cat $b0list` ; do
	impath=`echo $im | sed 's,.*volumes,volumes,g'`
    echo "$impath \\" >> $runb0
done
echo "-mask $svrmask \\" >> $runb0
echo "-svr_only \\" >> $runb0
echo "-resolution 0.75 \\" >> $runb0
echo "-iterations 1" >> $runb0

# Write script for b1 recon
echo "mirtk reconstruct $b1SVR $nb1 \\" >> $runb1
for im in `cat $b1list` ; do
	impath=`echo $im | sed 's,.*volumes,volumes,g'`
    echo "$impath \\" >> $runb1
done
echo "-mask $svrmask \\" >> $runb1
echo "-svr_only \\" >> $runb1
echo "-resolution 0.75 \\" >> $runb1
echo "-iterations 1" >> $runb1

echo Wrote run scripts:
echo $runb0
echo $runb1
echo "Setting permissions for $svrtk to open for Docker"
chmod -R 777 $svrtk 2> /dev/null
