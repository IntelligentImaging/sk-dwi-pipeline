#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} -nr -- [input]
    Testing tensor compute using SVRTK recons
    Takes previously generated atlas transform and applies it to SVRTK b0/b1 recons
    Then runs tensor compute and cleans the tensor

    Optionial argument -nr sets "No Reg"- will skip slice to volume registration
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

id=$1
sta=/fileserver/fetal/segmentation/templates/STA_GEPZ/STA32.nii.gz
svrtk=${id}/svrtk
reg=${id}/svrtk/reg
ten=${id}/svrtk/tensor
vol=${id}/volumes 
volcopy=${svrtk}/volumes
mkdir -pv $reg $ten
cp $vol/* -r $volcopy
b0=`find $svrtk/b0 -name bSVRTK\*z`
b0reg=`basename $b0 | sed 's,dwi_,atlas_,g'`
b0dum="${reg}/dwi_b0_${id}_tensor.nii.gz"
b1=`find $svrtk/b1 -name bSVRTK\*z`
b1reg=`basename $b1 | sed 's,dwi_,atlas_,g'`
b1dum="${reg}/dwi_b1_${id}.nii.gz"
tfm=`find ${reg} -name b\*-atlas\*tfm`
mask=`find ${id}/t2 -name atlas_mask\*1pt2_refine.nii.gz`
dilated=`find $id/t2 -name atlas_mask\*1pt2\*dilate.nii.gz`
tensorbase="tensorSVRTK_${id}"
cp ${mask} -vn ${reg}
echo Resample
if [[ -f $b0 && -f $b1 && $tfm ]] ; then
    echo $id b0
    if [[ ! -f ${reg}/${b0reg} ]] ; then
        crlResampler $b0 $tfm $mask bspline ${reg}/${b0reg}
    fi
    cp ${reg}/${b0reg} -vn ${b0dum}
    cp ${reg}/${b1reg} -vn ${b1dum}
    echo $id b1
    if [[ ! -f ${reg}/${b1reg} ]] ; then
        crlResampler $b1 $tfm $mask bspline ${reg}/${b1reg}
    fi
    if [[ $noreg -gt 0 ]] ; then
        echo Reg Slices
        regSliceToVolume -f ${b0dum} -b ${b1dum} -d $volcopy -j 2 -m 1 -r 5 -x 2.0 -y 1 -z -1
    fi
    echo Compute Tensor
    check=`find $ten -name $tensorbase\*`
    if [[ ! -n ${check} ]] ; then
        computeTensor -b $b0dum -s $dilated -f $tfm -d $volcopy -t CWLLS1 -o $tensorbase -w 2 -g 0.63405
        cp ${volcopy}/${tensorbase}* -vn ${ten}/
    fi
    echo "Convert to float and tensor clean"
    for im in ${ten}/*nrrd ; do
        base=`basename $im .nrrd`
        crlCastSymMatDoubleToFloat $im ${ten}/${base}.nii.gz
        crlTensorClean -z -i ${ten}/${base}.nii.gz -o ${ten}/c${base}.nii.gz
    done
    echo
fi
