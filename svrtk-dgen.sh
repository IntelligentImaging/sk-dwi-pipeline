#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [subj converted data dir] [mask for recon]
    Incorrect argument supplied
EOF
}

if [ $# -ne 2 ]; then
    show_help
    exit
fi 

data=`readlink -f $1`
subj=`dirname $data`
id=`basename $subj`
mask="$2"
svrtk="svrtk"
volumes="${subj}/svrtk/volumes"
mkdir -pv ${subj}/svrtk ${volumes}
cp $mask -v ${subj}/${svrtk}/mask_svrtk.nii.gz
svrmask="/home/data/${svrtk}/mask_svrtk.nii.gz"
b0dir=${svrtk}/b0
b1dir=${svrtk}/b1
runb0=${subj}/${b0dir}/run-svrtk.sh
runb1=${subj}/${b1dir}/run-svrtk.sh
b0SVR="/home/data/${b0dir}/SVRTK-dwi_b0_${id}.nii.gz"
b1SVR="/home/data/${b1dir}/SVRTK-dwi_b1_${id}.nii.gz"
b0list="${subj}/${b0dir}/b0list.txt"
b1list="${subj}/${b1dir}/b1list.txt"
mkdir -pv ${subj}/${b0dir} ${subj}/${b1dir}
if [[ -f $runb0 ]] ; then rm $runb0 ; fi
if [[ -f $runb1 ]] ; then rm $runb1 ; fi
if [[ -f $b0list ]] ; then rm $b0list ; fi
if [[ -f $b1list ]] ; then rm $b1list ; fi

# volumes/ has the 3D split dwi volumes in separate folders for each scan
for dwi in ${data}/* ; do
    if [[ -d $dwi ]] ; then 
        base=`basename $dwi`
        echo "Split DWI to 3D volumes with FSL"
        split="${volumes}/${base}"
        mkdir -pv ${split}
        fslsplit ${dwi}/*z ${split}/vol_ -t
        cp ${dwi}/bvals ${dwi}/bvecs ${subj}/dcm2niix/${base}/sliceTiming.txt -vp ${split}/

        let x=0 # this assumes the volumes are named/numbered vol_0000, vol_0001, etc
        # Read the bvals text file for bvalues
        for b in `cat ${dwi}/bvals` ; do 
            lead=$(printf "%04d" $x) # changes the index to have four leading 0's
            echo ${split}/vol_${lead}.nii.gz $b # this is the volume-bvalue combo
            # if 0, use for B0 recon, if greater than 0, use for B1 recon
            if [[ $b -eq 0 ]] ; then
                echo ${split}/vol_${lead}.nii.gz >> ${b0list}
            elif [[ $b > 0 ]] ; then
                echo ${split}/vol_${lead}.nii.gz >> ${b1list}
            fi
            ((x++)) # increase index by one
        done
    fi
done

# SVRTK requires the number of input images
nb0=`wc -l ${b0list} | cut -d' ' -f1`
nb1=`wc -l ${b1list} | cut -d' ' -f1`

# Write script for b0 recon
echo "cd /home/data/${b0dir}" >> $runb0
echo "mirtk reconstruct $b0SVR $nb0 \\" >> $runb0
for im in `cat $b0list` ; do
	impath=`echo $im | sed 's,.*svrtk/volumes,svrtk/volumes,g'`
    echo "/home/data/$impath \\" >> $runb0
done
echo "-mask $svrmask \\" >> $runb0
echo "-svr_only \\" >> $runb0
echo "-resolution 0.75 \\" >> $runb0
echo "-iterations 3" >> $runb0
echo "cd /home/data" >> $runb0

# Write script for b1 recon
echo "cd /home/data/${b1dir}" >> $runb1 
echo "mirtk reconstruct $b1SVR $nb1 \\" >> $runb1
for im in `cat $b1list` ; do
	impath=`echo $im | sed 's,.*svrtk/volumes,svrtk/volumes,g'`
    echo "/home/data/$impath \\" >> $runb1
done
echo "-mask $svrmask \\" >> $runb1
echo "-svr_only \\" >> $runb1
echo "-resolution 0.75 \\" >> $runb1
echo "-iterations 3" >> $runb1
echo "cd /home/data" >> $runb1

echo Wrote run scripts:
echo $runb0
echo $runb1
echo "Setting permissions for $svrtk to open for Docker"
chmod -R 777 $svrtk 2> /dev/null
