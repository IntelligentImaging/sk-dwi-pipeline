#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [subj converted data dir] 
    Incorrect argument supplied
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi 

subj=`readlink -f $1`
id=`basename $subj`
volumes="${subj}/volumes"
b0b1="${subj}/b0b1"
b0dir="${b0b1}/tmpB0"
b1dir="${b0b1}/tmpB1"
runb0=${b0dir}/run-b0.sh
runb1=${b1dir}/run-b1.sh
b0SVR="/home/data/b0b1/tmpB0/SVRTK-dwi_b0_${id}.nii.gz"
b1SVR="/home/data/b0b1/tmpB1/SVRTK-dwi_b1_${id}.nii.gz"
b0list="${b0dir}/b0list.txt"
b1list="${b1dir}/b1list.txt"

crop=`find $volumes -maxdepth 1 -type f -name \*crop.nii.gz | head -n1`
basecrop=`basename $crop`
mask="${volumes}/mask_crop.nii.gz"
crlBinaryThreshold $crop $mask -2 -1 0 1 # make a binary mask of the crop image

mkdir -pv ${b0dir} ${b1dir}
if [[ -f $runb0 ]] ; then rm $runb0 ; fi
if [[ -f $runb1 ]] ; then rm $runb1 ; fi
if [[ -f $b0list ]] ; then rm $b0list ; fi
if [[ -f $b1list ]] ; then rm $b1list ; fi

# volumes/ has the 3D split dwi volumes in separate folders for each scan
for dwi in ${volumes}/* ; do
    if [[ -d $dwi ]] ; then 
        base=`basename $dwi`
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

# SVRTK requires the number of input images
nb0=`wc -l ${b0list} | cut -d' ' -f1`
nb1=`wc -l ${b1list} | cut -d' ' -f1`

# Write script for b0 recon
echo "cd /home/data/b0b1/tmpB0" >> $runb0
echo "SVRreconstructionGPU --input \\" >> $runb0
for im in `cat $b0list` ; do
	impath=`echo $im | sed 's,.*volumes,volumes,g'`
    echo "/home/data/$impath \\" >> $runb0
done
echo "--output /home/data/b0b1/tmpB0/b0.nii.gz \\" >> $runb0
echo "--referenceVolume /home/data/volumes/$basecrop \\" >> $runb0
echo "--resolution=0.75 \\" >> $runb0
echo "--mask /home/data/volumes/mask_crop.nii.gz" >> $runb0
echo "cd /home/data" >> $runb0

# Write script for b1 recon
echo "cd /home/data/b0b1/tmpB1" >> $runb1
echo "SVRreconstructionGPU --input \\" >> $runb1
for im in `cat $b1list` ; do
	impath=`echo $im | sed 's,.*volumes,volumes,g'`
    echo "/home/data/$impath \\" >> $runb1
done
echo "--output /home/data/b0b1/tmpB1/b1.nii.gz \\" >> $runb1
echo "--referenceVolume /home/data/volumes/$basecrop \\" >> $runb1
echo "--resolution=0.75 \\" >> $runb1
echo "--useGPUReg \\" >> $runb1
echo "--iterations=2 \\" >> $runb1
echo "--mask /home/data/volumes/mask_crop.nii.gz" >> $runb1
echo "cd /home/data" >> $runb1

echo Wrote run scripts:
echo $runb0
echo $runb1
echo "Setting permissions for $svrtk to open for Docker"
chmod -R 777 $svrtk 2> /dev/null
