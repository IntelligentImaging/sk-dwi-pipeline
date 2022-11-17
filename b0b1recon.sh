#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-g GPU device number] [ROI crop or DWI subject folder]
    Incorrect input supplied
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
        -g|--gpu)
            if [[ -n $2 ]] ; then
                gpu=$2 # Specify which GPU device to use
                shift
            else
                die 'error: GP device number not specified. Check nvidia-smi'
            fi
            ;;
        --nob0)
            let nob0=1
            ;;
        --nob1)
            let nob1=1
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

# Look for input ROI
if [[ -f $1 ]] ; then
    crop=`readlink -f ${1}`
elif [[ -d $1 ]] ; then
    crop=`find $1/volumes -type f -name \*_vol\*crop.nii.gz -exec readlink -f {} \;`
else die 'error: Couldnt find a xx_vol_0000_crop.nii.gz'
fi

subjdir="${crop%/volumes*}"
fpath=`readlink -f $subjdir`
volumes="${fpath}/volumes"
id=`basename ${fpath}`
b0b1="${fpath}/b0b1"
B0="${b0b1}/dwi_b0_${id}.nii.gz" 
B1="${b0b1}/dwi_b1_${id}.nii.gz" 
TENSOR="${b0b1}/dwi_b0_${id}_tensor.nii" 
scripts="${fpath}/scripts"
tmpB0=${b0b1}/tmpB0
tmpB1=${b0b1}/tmpB1
rm -rfv ${tmpB0} ${tmpB1}
mkdir -pv ${tmpB0} ${tmpB1}


# CONTENTS=`find ${CASEDIR}/volumes/ -maxdepth 1 -type d`
b0list="${tmpB0}/b0list.txt"
b0source="${tmpB0}/image1_GPU.nii.gz"
b0sourceAlt="${tmpB0}/GaussianReconstruction_GPU3.nii"
b1list="${tmpB1}/b1list.txt"
b1source="${tmpB1}/image1_GPU.nii.gz"
# b1sourceAlt="${tmpB1}/GaussianReconstruction_GPU3.nii"
b1dest="${b0b1}/dwi_b1_${id}.nii.gz"

# Collect b-values
echo Recording b-values for volumes
for dwi in ${volumes}/* ; do
    if [[ -d $dwi ]] ; then
        bvals="${dwi}/bvals"

        # we're gonna find the bvalues for each vol now
        let x=0 # this assumes the volumes are named/numbered vol_0000, vol_0001, etc
        # Read the bvals text file for bvalues
        for b in `cat ${dwi}/bvals` ; do
            lead=$(printf "%04d" $x) # changes the index to have four leading 0's
            echo ${dwi}/vol_${lead}.nii.gz $b # this is the volume-bvalue combo
            # if 0, use for B0 recon, if greater than 0, use for B1 recon
            if [[ $b -eq 0 ]] ; then
                echo ${dwi}/vol_${lead}.nii.gz >> ${b0list}
            elif [[ $b > 0 ]] ; then
                echo ${dwi}/vol_${lead}.nii.gz >> ${b1list}
            fi
            ((x++)) # increase index by one
        done
    fi
done

b0s=`cat $b0list`
b1s=`cat $b1list`

if [[ ! $nob0 -eq 1 ]] ; then
    echo = = B0 SVR Reconstruction = =
    cd $tmpB0
    cmd="SVRreconstructionGPU --input $b0s -o ${tmpB0}/b0.nii.gz --referenceVolume ${crop} --iterations=4 --resolution=0.75"
    if [[ -n $gpu ]] ; then
        cmd="$cmd -d $gpu"
    fi
    $cmd
    cp $b0source -v $B0
    cp $b0sourceAlt -v $TENSOR
    cd -
else echo --nob0 was specified
fi

if [[ ! $nob1 -eq 1 ]] ; then
    echo = = B1 SVR Reconstruction = =
    cmd="SVRreconstructionGPU --input $b1s -o ${tmpB0}/b1.nii.gz --referenceVolume ${crop} --iterations=4 --resolution=0.75"
    if [[ -n $gpu ]] ; then
        cmd="$cmd -d $gpu"
    fi
    $cmd 
    cp $b1source -v $B1
else echo --nob1 was specified
fi

# Check outputs
if [[ -f ${B0} ]] ; then
    echo "B0 = $B0" ; else echo "B0 not generated" ; err=1
fi
if [[ -f ${CASEDIR}/b0b1/${TENSOR} ]] ; then
    echo "B0_2 = $TENSOR" ; else echo "B0_2 not generated" ; err=1
fi
if [[ -f ${B1} ]] ; then
    echo "B1 = $B1" ; else echo "B1 not generated" ; err=1
fi
if [[ ! $err -ne 1 ]] ; then
    echo "Output to b0b1/"
    echo "Now prepare T2 data set (DTIfetal-t2atlas.sh), copy to caseID/t2 directory, and run registerB0B1toT2"
else echo "Something went wrong"
fi
