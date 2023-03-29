#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [subj DWI directory] [mask for recon]
    Incorrect argument supplied
EOF
}

if [ $# -ne 2 ]; then
    show_help
    exit
fi 

subj=`readlink -f $1`
id=`basename $subj`
mask="$2"
svrtk="plane-svrtk"
mkdir -pv ${subj}/${svrtk}
svrmask="${svrtk}/mask_svrtk.nii.gz"
cp $mask -v ${subj}/${svrmask}
vols="${svrtk}/vols"

# record plane for each series
for dwi in ${subj}/volumes/* ; do
    if [[ -d $dwi ]] ; then 
        echo "${dwi}: ax, cor, or sag?"
        read plane
        if [[ ! $plane == "ax" && ! $plane == "cor" && ! $plane == "sag" ]] ; then
            echo "that's not ax, cor, or sag"
            exit 1
        else echo "${plane}" > ${dwi}/plane.txt
        fi
    fi
done

echo "Record images for each dir/bval step"
rm -fv ${vols}/{ax,cor,sag}/b*/images.txt
# rm -fv ${vols}/{ax,cor,sag}/b*/run-svrtk.sh

# volumes/ has the 3D split dwi volumes in separate folders for each scan
for dwi in ${subj}/volumes/* ; do
    if [[ -d $dwi ]] ; then 
        plane=`cat ${dwi}/plane.txt`
        planedir="${vols}/${plane}"
        mkdir -pv ${planedir}
        let x=0 # this assumes the volumes are named/numbered vol_0000, vol_0001, etc
        # Read the bvals text file for bvalues
        for b in `cat ${dwi}/bvals` ; do 
            lead=$(printf "%04d" $x) # changes the index to have four leading 0's
            echo ${dwi}/vol_${lead}.nii.gz $b # this is the volume-bvalue combo

            # This block of code is to check if there are similar bvalues (like 249 and 250). If so, they get combined. If there aren't, they get a new folder
            let FOUND=0
            anyprev=`find ${planedir} -type d -name b\*`
            if [[ -n $anyprev ]] ; then
                for any in $anyprev ; do
                    anynum=`echo $any | sed -e 's,b,,g' -e 's,.*\/,,g'`
                    DIFF=`echo "$b-$anynum" | bc`
                        if [[ $DIFF -gt -6 && $DIFF -lt 6 ]] ; then
                            dest="${planedir}/b${anynum}"
                            let FOUND=1
                            break
                        fi
                done
            fi
            # If this is the first volume for this plane, just set output directory
            if [[ $FOUND -ne 1 ]] ; then
                dest="${planedir}/b${b}"
            fi
            mkdir -pv ${dest}
            imlist="${dest}/images.txt"

            echo ${dwi}/vol_${lead}.nii.gz >> ${imlist}
            ((x++)) # increase index by one
        done
    fi
done


for svrdir in ${vols}/*/b* ; do
    if [[ -d $svrdir ]] ; then

        # SVRTK requires the number of input images
        svrlist="${svrdir}/images.txt"
        nim=`wc -l ${svrlist} | cut -d' ' -f1`

        base=`basename $svrdir`
        bval=`echo $base | sed -e 's,b,,g'`
        dside=`dirname $svrdir`
        side=`basename $dside`
        run="${svrdir}/run-svrtk.sh"
        rm ${run}
        svr="/home/data/${svrdir}/SVRTK_${side}-b${bval}-${id}.nii.gz"

        # Write script for recon
        echo "cd /home/data/${svrdir}" >> $run
        echo "mirtk reconstruct $svr $nim \\" >> $run
        for im in `cat $svrlist` ; do
            impath=`echo $im | sed 's,.*volumes,volumes,g'`
            echo "/home/data/$impath \\" >> $run
        done
        echo "-mask /home/data/$svrmask \\" >> $run
        # echo "-svr_only \\" >> $run
        echo "--debug" \\ >> $run
        echo "-resolution 0.75 \\" >> $run
        echo "-iterations 3" >> $run
        echo "cd /home/data" >> $run

        echo Wrote run script: $run
    fi
done

echo "Setting permissions for $svrtk to open for Docker"
chmod -R 777 $svrtk 2> /dev/null
