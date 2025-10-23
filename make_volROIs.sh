#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [case directory]
    Incorrect input supplied
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi

subj=`readlink -f $1`
volumes=${subj}/volumes
niis=${subj}/dcm2niix

dmri3d=${subj}/dmri3d



for vol in $niis/* ; do
	if [[ -d $vol ]] ; then
		base=`basename $vol`
		mkdir -pv ${dmri3d}/${base}

		mrconvert ${vol}/${base}.nii.gz -coord 3 0 -axes 0,1,2 ${dmri3d}/${base}/vol_0000.nii.gz
		#cp ${vol}/vol_0000.nii.gz -vup ${dmri3d}/${base}

		singularity exec docker://arfentul/dmri3d /bin/bash -c "python /src/dMRI_volume_segmentation.py ${dmri3d}/${base} /src/ gpu_num=0 dilation_radius=-1"

		maskfilter -force -npass 4 ${dmri3d}/${base}/vol_0000_mask.nii.gz dilate maskfilter -force -npass 4 ${dmri3d}/${base}/vol_0000_dmask.nii.gz
		#mrconvert -force -datatype uint16le ${dmri3d}/${base}/vol_0000_dmask.nii.gz ${subj}/mask.nii.gz

	fi
done

