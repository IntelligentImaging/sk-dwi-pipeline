#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-g GPU device number] [-i number of recon iterations] [-m mask] -- [ROI crop or DWI subject folder]
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
        -i|--iter)
            if [[ -n $2 ]] ; then
                iter=$2 # recon iterations (default=4)
                shift
            else
                die 'error: Specify number of reconstruction iterations'
            fi
            ;;
        -m|--mask)
            if [[ -n $2 ]] ; then
                mask=$2 # specify mask file (default=generated from image crop)
                shift
            else
                die 'error: Mask file not specified'
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

# What is this script? It is a re-writing of Shadab's (two) original python b0b1 recon scripts. We run two reconstructions to obtain three images, called b0_1, b0_2, and b1.
# b0_1 and b1 are used for registration to t2 space. We do this so we can apply the t2-atlas registration to get to atlas space. They are the "image1_GPU.nii.gz" from Bernhard Kainz et al's SVRreconstrucationGPU code which Shadab modified for the diffusion reconstruction.
# b0_2 is the version that is used for computing tensor - this is a result of forward projection of all b=0 images that is computed with a PSF formulation. Because the iterative updates apply a non-linear filter and modify the intensity content, we do not use B0_1 for tensor computation even though it appears visually more appealing.
# Sometimes the iterative process fails (image*_GPU) though forward projection (Gaussian*) works. In that case we can use the Gaussian* files for registration instead.

# Look for input ROI
if [[ -f $1 ]] ; then
    crop=`readlink -f ${1}`
elif [[ -d $1 ]] ; then
    crop=`find $1/volumes -type f -name \*_vol\*crop.nii.gz -exec readlink -f {} \;`
else die 'error: Couldnt find a xx_vol_0000_crop.nii.gz'
fi

# Set variables
# Input files/dirs
subjdir="${crop%/volumes*}"
fpath=`readlink -f $subjdir`
volumes="${fpath}/volumes"
id=`basename ${fpath}`
b0b1="${fpath}/b0b1"
scripts="${fpath}/scripts"
# Working directory for recon
tmpB0=${b0b1}/tmpB0
tmpB1=${b0b1}/tmpB1
rm -rfv ${tmpB0} ${tmpB1}
mkdir -pv ${tmpB0} ${tmpB1}
# Output files
b0source="${tmpB0}/image1_GPU.nii.gz"
tensource="${tmpB0}/GaussianReconstruction_GPU3.nii"
b0dest="${b0b1}/dwi_b0_${id}.nii.gz" 
tendest="${b0b1}/dwi_b0_${id}_tensor.nii" 
b1source="${tmpB1}/image1_GPU.nii.gz"
b1alt="${tmpB1}/GaussianReconstruction_GPU3.nii"
b1dest="${b0b1}/dwi_b1_${id}.nii.gz" 

# Collect bvalues so we can reconstruct b0 and b1 files separately
echo Recording b-values for volumes
for dwi in ${volumes}/* ; do
    if [[ -d $dwi ]] ; then
        # Check that the directory appears to have 4D volumes and a bvals file
        vols=`find $dwi -maxdepth 1 -type f -name vol_\?\?\?\?.nii.gz`
        bvals="${dwi}/bvals"
        if [[ -n $vols && -f $bvals ]] ; then
            # Read the bvals text file for bvalues
            let x=0 # This assumes the volumes are named/numbered vol_0000, vol_0001, etc
            for b in `cat ${dwi}/bvals` ; do
                lead=$(printf "%04d" $x) # changes the index to have four leading 0's
                echo ${dwi}/vol_${lead}.nii.gz $b # this is the volume-bvalue combo
                # if 0, use for b0 recon, if greater than 0, use for b1 recon
                if [[ $b -eq 0 ]] ; then
                    b0s="${b0s} ${dwi}/vol_${lead}.nii.gz"
                elif [[ $b > 0 ]] ; then
                    b1s="${b1s} ${dwi}/vol_${lead}.nii.gz"
                fi
                ((x++)) # increase index by one
            done
        fi
    fi
done

# If no mask supplied, generate a mask based on the image crop ref file
if [[ ! -n $mask ]] ; then
    mask="${tmpB0}/mask_crop.nii.gz"
    crlBinaryThreshold $crop $mask -2 -1 0 1 # Make a binary mask for the entire image crop region
fi

# SVRreconstruction for B0s
if [[ ! $nob0 -eq 1 ]] ; then
    echo === B0 SVR Reconstruction ===
    cd $tmpB0
    cmd="SVRreconstructionGPU --input $b0s -o ${tmpB0}/b0.nii.gz --referenceVolume ${crop} --resolution=0.75 --mask $mask"
    if [[ -n $gpu ]] ; then cmd="$cmd -d $gpu" ; fi
    if [[ -n $iter ]] ; then cmd="$cmd --iterations $iter" ; fi
    echo "Command: $cmd"
    $cmd
    cp $b0source -v $b0dest # tmpB0/image1_GPU.nii.gz becomes dwi_b0_id.nii.gz
    cp $tensource -v $tendest # tmpB0/GaussianReconstruction_GPU3.nii becomes dwi_b0_id_tensor.nii
    cd -
else echo --nob0 was specified
fi

# SVR reconstruction for B1s
if [[ ! $nob1 -eq 1 ]] ; then
    echo === B1 SVR Reconstruction ===
    cd $tmpB1
    cmd="SVRreconstructionGPU --input $b1s -o ${tmpB0}/b1.nii.gz --referenceVolume ${crop} --resolution=0.75 --mask $mask"
    if [[ -n $gpu ]] ; then cmd="$cmd -d $gpu" ; fi
    if [[ -n $iter ]] ; then cmd="$cmd --iterations $iter" ; fi
    echo "Command: $cmd"
    $cmd 
    if [[ -f $b1source ]] ; then
        cp $b1source -v $b1dest # tmpB1/image1_GPU becomes dwi_b1_id.nii.gz
    elif [[ -f $b1alt ]] ; then
        cp $b1alt -v $b1dest # in case B1 recon fails
    fi
    cd -
else echo --nob1 was specified
fi

# Check outputs
if [[ -f $b0dest} ]] ; then
    echo "B0 = $b0dest" ; else echo "B0 not generated" ; err=1
fi
if [[ -f $tendest ]] ; then
    echo "B0_2 = $tendest" ; else echo "B0_2 not generated" ; err=1
fi
if [[ -f $b1dest ]] ; then
    echo "B1 = $b1dest" ; else echo "B1 not generated" ; err=1
fi
if [[ ! $err -ne 1 ]] ; then
    echo "Output to b0b1/"
    echo "Now prepare T2 data set (DTIfetal-t2atlas.sh), copy to caseID/t2 directory, and run registerB0B1toT2"
else echo "Something went wrong"
fi
