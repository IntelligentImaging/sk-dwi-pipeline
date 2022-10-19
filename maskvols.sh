#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input]
    Incorrect input supplied
    Requires a conda installation which can run the dmris3D tool
    To start the environment: $ conda activate d2 
    Known to be installed on coffee and noble
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi 

subj=`readlink -f $1`
volumes=${subj}/volumes
script="/fileserver/fetal/software/dmri_segmentation_3d/dMRI_volume_segmentation.py"

# Check if conda is installed
# if [[ -z `conda` ]] ; then
#     echo "Conda is not installed on $hostname"
#     show_help
# fi

# Run code on each series in volumes/
# Will mask all vol_x.nii.gz files without "mask" in the name
for dwi in ${volumes}/* ; do
    if [[ -d $dwi ]] ; then
        echo "Series: ${dwi}"
        python $script ${dwi} /fileserver/fetal/software/dmri_segmentation_3d gpu_num=0
    fi
done
