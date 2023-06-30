#!/bin/bash

show_help () {
cat << EOF
    Incorrect argument supplied
    USAGE: sh ${0##*/} -nr -nt -np -im0 -m mask.nii.gz -- [DWI case dir]
    Testing tensor compute using SVRTK recons
    Takes previously generated atlas transform and applies it to SVRTK b0/b1 recons
    Then runs tensor compute and cleans the tensor
    
    Optional arguments:
        -nr || --noreg      Will skip slice to volume registration
        -nt || --noten      Will skip tensor compute
        -np || --nopost     Will skip Clean/Crop/DWI maps
        -im0 || --image0    Use 'fuzzy' image0 b0 recon istead of final recon- similar to SK pipeline
        -m  || --mask       Specify DWI mask for post-processing

    (Useful if this is already complete)

EOF
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -nr|--noreg)
            let noreg=1 
            ;;
        -nt|--noten)
            let noten=1
            ;;
        -np|--nopost)
            let nopost=1
            ;;
        -im0|--image0)
            let im0=1
            ;;
        -m|--mask)
            if [[ -f $2 ]] ; then
                tmask=$2
                shift
            else "No mask supplied" ; show_help
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

fpath=`readlink -f $1`
id=`basename $fpath`
echo Input data $fpath
svrtk=${fpath}/svrtk
reg=${svrtk}/reg
ten=${svrtk}/tensor
vol=${svrtk}/volumes 
mkdir -pv $reg $ten

# B0 recon
# b0=`find $svrtk/b0 -name bSVRTK\*z`
b0=`find $svrtk/b0 -name SVRTK\*z`
b0dum="${reg}/dwi_b0_${id}.nii.gz"
b0ten="${reg}/dwi_b0_${id}_tensor.nii.gz"
cp ${b0} -v ${b0dum}
b0reg=`echo $b0dum | sed -e 's,dwi_,atlas_,g'`
# B1 recon
# b1=`find $svrtk/b1 -name bSVRTK\*z`
b1=`find $svrtk/b1 -name SVRTK\*z`
b1dum="${reg}/dwi_b1_${id}.nii.gz"
cp ${b1} -v ${b1dum}
b1reg=`echo $b1dum | sed 's,dwi_,atlas_,g'`
# Transform and mask
tfm=`find ${reg} -name b\*-atlas\*tfm`
# mask=`find ${id}/t2 -name atlas_mask\*1pt2_refine.nii.gz`
mask=`find ${fpath}/t2 -name atlas_mask_${id}.nii.gz`
rmask="${ten}/atlas_mask_${id}_iso.nii.gz"
dilmask="${ten}/atlas_mask_${id}_diso.nii.gz"
# cp ${mask} -vn ${ten}
tmask2="${reg}/tmask.nii.gz" # this will be the final mask for tensor post-processing
tensorbase="tensorSVRTK_${id}"

if [[ -f $b0 && -f $b1 && $tfm ]] ; then
    echo Resample
    echo $id b0
    # Atlas space B0 recon (not used for anything in this script)
    crlResampler $b0 $tfm $mask bspline $b0reg
    echo $id b1
    # Atlas space B1 recon (not used for anything in this script)
    crlResampler $b1 $tfm $mask bspline $b1reg
    # Resample mask for DWI
    echo Resample mask to isotropic for DWI
    crlResampleToIsotropic $mask nearest $rmask -x 1.2 -y 1.2 -z 1.2
    # Dilate refine mask
    echo Dilate mask
    crlBinaryMorphology $rmask dilate 1 2 $dilmask
    if [[ $noreg -eq 0 ]] ; then
        echo Reg Slices
        regSliceToVolume -f $b0dum -b $b1dum -d $vol -j 2 -m 1 -r 5 -x 2.0 -y 1 -z -1
        echo "Renaming transforms to have '-Estimated' tag"
        rename ${id}-Estimated ${id}_tensor-Estimated ${svrtk}/volumes/*/dwi*tfm
    fi
    if [[ ${noten} -eq 0 ]] ; then
        if [[ $im0 -gt 0 ]] ; then
            echo "Parsing -im0 argument - using fuzzy image0 for tensor computation"
            image0="${svrtk}/b0/image0.nii.gz"
            cp $image0 -v $b0ten
        else
            echo "Using final SVRTK b0 recon for tensor computation (use -im0 instead to use fuzzy version)" 
            cp $b0dum -v $b0ten
        fi
        echo Compute Tensor
        gunzip -fv $b0ten
        computeTensor -b $b0ten -s $dilmask -f $tfm -d $vol -t CWLLS1 -o $tensorbase -w 2 -g 0.63405
        # FYI the output goes into the volumes folder
    fi
    if [[ ${nopost} -eq 0 ]] ; then
        echo "Convert to float and tensor clean"
        for im in ${vol}/${tensorbase}*.nrrd ; do
            base=`basename $im .nrrd`
            crlCastSymMatDoubleToFloat $im ${ten}/${base}.nii.gz
            crlTensorClean -z -i ${ten}/${base}.nii.gz -o ${ten}/c${base}.nii.gz
        done
        if [[ -f $mask ]] ; then
            echo "Mask image"
            if [[ -n $tmask ]] ; then
                echo "User specified tensor mask"
                cp $tmask -v $tmask2
            else
                echo "Mask is the resampled mask"
                cp $rmask -v $tmask2
            fi
            for im in ${ten}/c*z ; do
                cleanbase=`basename $im`
                crlMaskImage2 -i ${im} -m $tmask2 -o ${ten}/m-${cleanbase}.nii.gz
            done
            echo "Generate CFA"
            mten=`find $ten -name m-c\*CWLLS1.nii.gz | head -n1`
                python ${FETALDTI}/cfa_from_tensor.py ${mten} ${ten}/SVRTK-atlas_CFA_${id}.nii.gz
            echo
        else
            echo "Mask not found, can't crop or make CFA"
        fi
    fi
else
    echo "One of b0, b1 or tfm-to-atlas not found"
fi
