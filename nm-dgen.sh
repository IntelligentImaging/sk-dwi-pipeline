#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-a ALPHA] [-m]  -- [subj DWI directory] 
    Incorrect argument supplied

    Optional arguments:
    -a ALPHA    Sets strength of smoothing effect. Default alpha is 0.01.
    -m          Adds a NiftyMIC pipeline step for masking the input volumes
EOF
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -a|--alpha)
            if [[ -n "$2" ]] ; then
                alpha=$2 # Specify
                shift
            else
                die 'error: Smoothing alpha not set'
            fi
            ;;
        -m|--mask)
            let domask=1 # This will run NiftyMIC's segment fetal brains
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

subj=`readlink -f $1`
id=`basename $subj`
nm="niftymic"
mkdir -pv ${subj}/${nm}
b0dir=${nm}/b0
b1dir=${nm}/b1
runb0=${subj}/${b0dir}/run-nm.sh
runb1=${subj}/${b1dir}/run-nm.sh
b0out=${b0dir}/srr
b1out=${b1dir}/srr
runmask=${nm}/run-masks.sh
# b0list="${subj}/${b0dir}/b0list.txt"
# b1list="${subj}/${b1dir}/b1list.txt"
mkdir -pv ${subj}/${b0dir} ${subj}/${b1dir} ${subj}/${b0dir}/{t2,mask} ${subj}/${b1dir}/{t2,mask}
if [[ -f $runb0 ]] ; then rm $runb0 ; fi
if [[ -f $runb1 ]] ; then rm $runb1 ; fi
# if [[ -f $b0list ]] ; then rm $b0list ; fi
# if [[ -f $b1list ]] ; then rm $b1list ; fi

if [[ ! -n $alpha ]] ; then alpha="0.01"; fi


# volumes/ has the 3D split dwi volumes in separate folders for each scan
for dwi in ${subj}/volumes/* ; do
    if [[ -d $dwi ]] ; then 
        let x=0 # this assumes the volumes are named/numbered vol_0000, vol_0001, etc
        base=`basename $dwi`
        # Read the bvals text file for bvalues
        for b in `cat ${dwi}/bvals` ; do 
            lead=$(printf "%04d" $x) # changes the index to have four leading 0's
            echo ${dwi}/vol_${lead}.nii.gz $b # this is the volume-bvalue combo
            # if 0, use for B0 recon, if greater than 0, use for B1 recon
            if [[ $b -eq 0 ]] ; then
                cp ${dwi}/vol_${lead}.nii.gz -uv ${subj}/${b0dir}/t2/${base}_vol_${lead}.nii.gz
                # Option check if we have pre-existing masks
                if [[ -z $domask ]] ; then
                    cp ${dwi}/vol_${lead}_mask.nii.gz -uv ${subj}/${b0dir}/mask/${base}_vol_${lead}_mask.nii.gz
                fi
            # These go to the b1 recon directory
            elif [[ $b > 0 ]] ; then
                cp ${dwi}/vol_${lead}.nii.gz -uv ${subj}/${b1dir}/t2/${base}_vol_${lead}.nii.gz
                # Option check if we have pre-existing masks
                if [[ -z $domask ]] ; then
                    cp ${dwi}/vol_${lead}_mask.nii.gz -uv ${subj}/${b1dir}/mask/${base}_vol_${lead}_mask.nii.gz
                fi
            fi
            ((x++)) # increase index by one
        done
    fi
done

# If the niftymic mask option is set, set up segment_fetal_brains code
if [[ -n $domask ]] ; then
    if [[ -f $runmask ]] ; then rm -v $runmask ; fi
    echo "#!/bin/bash" >> $runmask
    echo "niftymic_segment_fetal_brains --filenames \\" >> $runmask
    for im in ${subj}/${nm}/b*/t2/*z ; do
        impath=`echo $im | sed 's,.*niftymic\/b,/home/data/niftymic\/b,g'`
        echo "$impath \\" >> $runmask
    done
    echo "--filenames-masks \\" >> $runmask
    for im in ${subj}/${nm}/b*/t2/*z ; do
        mask=`echo $im | sed -e 's,.*\(b[0,1]\/\)t2,/home/data/niftymic/\1mask,g' -e 's,.nii.gz,_mask.nii.gz,g'`
        echo "$mask \\" >> $runmask
    done
    echo Wrote niftymic_segment_fetal_brains run script: $runmask
else
    echo "-m not set: we will use pre-existing masks"
fi

# Write script for b0 recon
# echo "cd ${b0dir}" >> $runb0
echo "niftymic_run_reconstruction_pipeline --filenames \\" >> $runb0
for im in ${subj}/${b0dir}/t2/*z ; do
	impath=`echo $im | sed 's,.*niftymic,niftymic,g'`
    echo "/home/data/$impath \\" >> $runb0
done
echo "--filenames-masks \\" >> $runb0
for im in ${subj}/${b0dir}/mask/*z ; do
    maskpath=`echo $im | sed -e 's,.*niftymic,niftymic,g'`
    echo "/home/data/$maskpath \\" >> $runb0
done
echo "--dir-output ${b0out} \\" >> $runb0
echo "--alpha $alpha" >> $runb0
# echo "cd /home/data" >> $runb0

# Write script for b1 recon
# echo "cd ${b1dir}" >> $runb1 
echo "niftymic_run_reconstruction_pipeline --filenames \\" >> $runb1
for im in ${subj}/${b1dir}/t2/*z ; do
	impath=`echo $im | sed 's,.*niftymic,niftymic,g'`
    echo "/home/data/$impath \\" >> $runb1
done
echo "--filenames-masks \\" >> $runb1
for im in ${subj}/${b1dir}/mask/*z ; do
    maskpath=`echo $im | sed -e 's,.*niftymic,niftymic,g'`
    echo "/home/data/$maskpath \\" >> $runb1
done
echo "--dir-output ${b1out} \\" >> $runb1
echo "--alpha $alpha" >> $runb1
# echo "cd /home/data" >> $runb1

echo Wrote NiftyMIC recon run scripts:
echo $runb0
echo $runb1
echo "Setting permissions for $nm to open for Docker"
chmod -R 777 $nm 2> /dev/null
