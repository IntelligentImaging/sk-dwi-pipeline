#!/bin/bash

show_help () {
cat << EOF
    Incorrect argument supplied
    USAGE: sh ${0##*/} -nr -- [input]
    Testing tensor compute using NiftyMIC recons
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
        -nt|--noten)
            let noten=1
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
echo "Input data: $fpath"
id=`basename $fpath`
nm=${fpath}/niftymic
reg=${nm}/reg
ten=${nm}/tensor
vol=${fpath}/volumes 
volcopy=${nm}/volumes
mkdir -pv $reg $ten

echo Copying volumes for NiftyMIC processing
for vdir in ${vol}/* ; do
    if [[ -d $vdir ]] ; then
        vbase=`basename $vdir`
        mkdir -pv ${volcopy}/${vbase}
        cp ${vdir}/vol_????.nii.gz ${vdir}/bvals ${vdir}/bvecs ${vdir}/sliceTiming.txt -n ${volcopy}/${vbase}
    fi
done

# B0
b0="${nm}/b0/srr/recon_subject_space/srr_subject.nii.gz"
b0reg="${reg}/atlas_b0_${id}.nii.gz"
b0dum="${reg}/dwi_b0_${id}_tensor.nii.gz"
cp $b0 -v $b0dum
# B1
b1="${nm}/b1/srr/recon_subject_space/srr_subject.nii.gz"
b1reg="${reg}/atlas_b1_${id}.nii.gz"
b1dum="${reg}/dwi_b1_${id}.nii.gz"
cp $b1 -v $b1dum
# Transform and mask
tfm=`find ${reg} -name b\*-atlas\*tfm`
mask=`find ${fpath}/t2 -name atlas_mask\*1pt2_refine.nii.gz`
dilated=`find ${fpath}/t2 -name atlas_mask\*1pt2\*dilated.nii.gz`
cp ${mask} -vn ${reg}
tensorbase="tensorNiftyMIC_${id}"

echo Resample
if [[ -f $b0 && -f $b1 && $tfm ]] ; then
    echo $id b0
    # Atlas space B0 recon (not used for anything in this script)
    crlResampler $b0 $tfm $mask bspline ${b0reg}
    echo $id b1
    # Atlas space B1 recon (not used for anything in this script)
    crlResampler $b1 $tfm $mask bspline ${b1reg}
    if [[ $noreg -eq 0 ]] ; then
        echo Reg Slices
        regSliceToVolume -f ${b0dum} -b ${b1dum} -d $volcopy -j 2 -m 1 -r 5 -x 2.0 -y 1 -z -1
    fi
    if [[ ${noten} -eq 0 ]] ; then
        echo Compute Tensor
        computeTensor -b $b0dum -s $dilated -f $tfm -d $volcopy -t CWLLS1 -o $tensorbase -w 2 -g 0.63405
        cp ${volcopy}/${tensorbase}* -vn ${ten}/
    fi
    echo "Convert to float and tensor clean"
    for im in ${volcopy}/${tensorbase}*.nrrd ; do
        base=`basename $im .nrrd`
        crlCastSymMatDoubleToFloat $im ${ten}/${base}.nii.gz
        crlTensorClean -z -i ${ten}/${base}.nii.gz -o ${ten}/c${base}.nii.gz
    done
    echo "Mask image"
    for im in ${ten}/c*z ; do
        cleanbase=`basename $im`
        crlMaskImage2 -i $im -m $mask -o ${ten}/m-${cleanbase}.nii.gz 
    done
    echo "Generate CFA"
    mten=`find $ten -name m-c\*CWLLS1.nii.gz | head -n1`
    python ${FETALDTI}/cfa_from_tensor.py ${mten} ${ten}/NiftyMIC-atlas_CFA_${id}.nii.gz
    echo
fi
