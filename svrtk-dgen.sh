#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-n image limit per scan] -- [subj converted data dir] [mask for recon]
    Incorrect argument supplied

    -n		Sets image limit for each volume folder. For example, "-n 6" for a subject with
		three diffusion scans would mean only 18 total volumes are reconstructed.
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
        -n)
            if [[ "$2" -gt 0 ]] ; then
                let LIMIT=$2 # Specify how many volumes to take from each scan
                shift
            else
                die 'error: -n argument should be a number of volumes to include from each series'
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



if [ $# -ne 2 ]; then
    show_help
    exit
fi 

if [[ ! -n $LIMIT ]] ; then let $LIMIT=999 ; fi # default limit (aka no limit)

data=`readlink -f $1`
subj=`dirname $data`
id=`basename $subj`
mask="$2"
svrtk="svrtk"
volumes="${subj}/volumes"
mkdir -pv ${subj}/svrtk ${volumes}
cp $mask -v ${subj}/${svrtk}/mask_svrtk.nii.gz
svrmask="${svrtk}/mask_svrtk.nii.gz"
b0dir=${svrtk}/b0
b1dir=${svrtk}/b1
runb0=${subj}/${b0dir}/run-svrtk.sh
runb1=${subj}/${b1dir}/run-svrtk.sh
b0SVR="${b0dir}/SVRTK-dwi_b0_${id}.nii.gz"
b1SVR="${b1dir}/SVRTK-dwi_b1_${id}.nii.gz"
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
        echo "Split DWI from 4D series to 3D volumes"
        split="${volumes}/${base}"
        mkdir -pv ${split}

        #fslsplit ${dwi}/*z ${split}/vol_ -t
        ndim=`mrinfo -size ${dwi}/${base}.nii.gz | cut -d' ' -f4`
        let count=0
        while [[ $count -lt $ndim ]] ; do
            count4=$(printf "%04d" $count)
            mrconvert -force -quiet ${dwi}/${base}.nii.gz -coord 3 ${count} -axes 0,1,2 ${split}/vol_${count4}.nii.gz
            ((count++))
        done

        cp ${dwi}/bvals ${dwi}/bvecs ${subj}/dcm2niix/${base}/sliceTiming.txt -vp ${split}/

        let x=0 # this assumes the volumes are named/numbered vol_0000, vol_0001, etc
        # Read the bvals text file for bvalues
        for b in `cat ${dwi}/bvals` ; do 
		if [[ $x -lt $LIMIT ]] ; then
		    lead=$(printf "%04d" $x) # changes the index to have four leading 0's
		    echo ${split}/vol_${lead}.nii.gz $b # this is the volume-bvalue combo
		    # if 0, use for B0 recon, if greater than 0, use for B1 recon
		    if [[ $b -eq 0 ]] ; then
			echo ${split}/vol_${lead}.nii.gz >> ${b0list}
		    elif [[ $b > 0 ]] ; then
			echo ${split}/vol_${lead}.nii.gz >> ${b1list}
		    fi
	    	else
		    echo "Input vol limit has been reached $x >= $LIMIT"
            break	
		fi
            ((x++)) # increase index by one
        done
    fi
done

# SVRTK requires the number of input images
nb0=`wc -l ${b0list} | cut -d' ' -f1`
nb1=`wc -l ${b1list} | cut -d' ' -f1`

# Write script for b0 recon
echo "mirtk reconstruct $b0SVR $nb0 \\" >> $runb0
for im in `cat $b0list` ; do
	impath=`echo $im | sed 's,.*volumes,volumes,g'`
    echo "$impath \\" >> $runb0
done
echo "-mask $svrmask \\" >> $runb0
echo "-svr_only \\" >> $runb0
echo "-resolution 0.75 \\" >> $runb0
echo "-iterations 3" >> $runb0

# Write script for b1 recon
echo "mirtk reconstruct $b1SVR $nb1 \\" >> $runb1
for im in `cat $b1list` ; do
	impath=`echo $im | sed 's,.*volumes,volumes,g'`
    echo "$impath \\" >> $runb1
done
echo "-mask $svrmask \\" >> $runb1
echo "-svr_only \\" >> $runb1
echo "-resolution 0.75 \\" >> $runb1
echo "-iterations 2" >> $runb1

echo Wrote run scripts:
echo $runb0
echo $runb1
echo "Setting permissions for $svrtk to open for Docker"
chmod -R 777 $svrtk 2> /dev/null
