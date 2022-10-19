#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input] [output]
    Davood's DWI brain segmentation. Masks a single volume and copies it to the specified location.
EOF
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -d|--dilate)
            if [[ -n "$2" ]] ; then
                dil="$2" # Specify
                shift
            else
                die 'error: Dilation factor not set'
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

if [[ $# -ne 2 || ! -f $1 ]]; then
    show_help
    exit
fi

input=$1
output=$2
script="/fileserver/fetal/software/dmri_segmentation_3d/dMRI_volume_segmentation.py"

tmpdir=tmp$RANDOM
mkdir -pv $tmpdir
base=`basename ${1} .nii.gz`
image=${tmpdir}/${base}.nii.gz
pyout=${tmpdir}/${base}_mask.nii.gz
cp $input -v $image
python $script $tmpdir /fileserver/fetal/software/dmri_segmentation_3d gpu_num=0 $dil
cp ${pyout} -v ${output}
rm -rf $tmpdir
