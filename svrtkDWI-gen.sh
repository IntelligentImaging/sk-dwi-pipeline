#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-p] || [data directory to reconstruct] [mask for recon] [atlas transform]
    Incorrect argument supplied

            This script sets up SVRTK recon scripts for our diffusion data. Each
            bvalue will be processed separately. 
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

if [ $# -ne 3 ]; then
    show_help
    exit
fi 

images=$1
fullpath=`readlink -f $1`
subj=`dirname $fullpath`
id=`basename $subj`
mask="$2"
tfm="$3"

if [[ ! -d ${images} || ! -f $mask || ! -f $mask ]] ; then
    die 'One of the input arguments does not exist'
fi

svrtk="svrtkDWI"
echo "${images}" >> ${subj}/${svrtk}/imageInput.txt
input="${subj}/${svrtk}/input"
mkdir -pv ${input}
svrmask="${svrtk}/mask_svrtk.nii.gz"
cp $mask -v ${subj}/${svrmask}
recon="${svrtk}/recon"
dof="${input}/dwi-atlas_${id}.dof"

# Check for required files

# dSVRTK requires several pre-existing inputs:
#   an atlas space T2 volume
#   a DOF format transform from DWI to atlas space (generated in this script)
#   and a binary mask
# Since we need to generate the DOF transform, we also need:
#   The dwi-space DWI used for the registration
whichb=`echo $tfm | sed -e 's,.*b\([0-1]\)\-.*,\1,g'`
src="${subj}/b0b1/dwi_b${whichb}_${id}.nii.gz"
atlas_t2="${subj}/t2/atlas_t2final_${id}.nii.gz"
cp $atlas_t2 -vu ${input}/

# This section is going to make three arrays for each of the 4D DWI images:
# name of the image, gradients file for the image
# That way we can group each recon by bvalue and direction
echo "Record images for each dir/bval step"
declare -a dwi_ar
declare -a grad_ar
let z=0 # Index for DWI image
for dwi in ${images}/* ; do    

        # Find bvals and bvecs and set the output MIRTK b-gradient file name
        bvecs=`find $dwi -maxdepth 1 -name bvecs`
        bvals=`find $dwi -maxdepth 1 -name bvals`
        basegrad=`basename $dwi`
        grad_ar[$z]=${input}/${basegrad}.b        

        # Copy the 4D image and rename to use as the input image
        dwi_ar[$z]=${input}/${basegrad}.nii.gz
        fourD=`find $dwi \( -name ${basegrad}\*.nii.gz -o -name vol\*diffusion\*.nhdr \)`
        if [[ ${fourD} == *"nhdr" ]] ; then
            echo convert nhdr to .nii.gz
            crlDWIConvertNHDRForFSL -i ${fourD} --data ${dwi_ar[$z]} --bvecs ${input}/bvecs --bvals ${input}/bvals --automirrorx 0
            bvals=${input}/bvals
            bvecs=${input}/bvecs
        else
            cp ${fourD} -v ${dwi_ar[$z]}
        fi

        # Sometimes the scanner saves bvalues inconsistently (like 249 and 250)
        # This section of code checks each value, and if there are slight variations,
        # Changes the numbers to be more consistent (so like change the 250's to 249's).
        fix=${input}/fix-${basegrad}.bval # This will be the 'corrected' bvals file
        fixnums=""
        declare -a barray
        let x=0 # Index for checking bvalues 
        for b in `cat ${dwi}/bvals` ; do # check each bvalue 
            for any in ${barray[@]} ; do # against all previous 
                DIFF=`echo "$b-$any" | bc` # calculate the difference between the two numbers
                    # If the difference is less than 6, we've found a match
                    # and change the current bvalue to just match the similar one
                    if [[ $DIFF -gt -6 && $DIFF -lt 6 ]] ; then
                        let b=$any
                        break
                    fi
            done
            barray[$x]=$b # Add last bval to the growing array of bvals
            dest=${recon}/b${b} 
            mkdir -pv ${dest} # Make a directory where the recon will process

            ((x++)) # increase bval index by one

        done
        echo ${barray[@]}
        rm $fix
        echo "${barray[@]}" > $fix # Prints our bval array into a 'fixed' bvals

        # Convert from FSL bvals/bvecs to MIRTK format
        echo convert bvals and bvecs to MIRTK format
        sh /home/ch162835/scripts/combineSVRTKb.sh $bvecs $fix ${grad_ar[$z]}

        # Convert the existing DWI-to-atlas transform from ITK to DOF 
        echo c3d convert atlas transform from ITK to DOF
        /fileserver/fetal/bin/c3d_affine_tool -ref $atlas_t2 -src $src -itk $tfm -oirtk ${dof}

    ((z++)) # increase DWI image index by one
done

echo "Writing the run scripts for the SVRTK docker"
for svrdir in ${recon}/b* ; do
    if [[ -d $svrdir ]] ; then
        svrbval=`echo $svrdir | sed -e 's,.*\/,,g' -e 's,b,,g'` # grab bval from directory name
        run="${svrdir}/run-svrtk.sh" # This is the run script
        rm ${run}
        svr="/home/data/${svrdir}/SVRTK_b${svrbval}-${id}.nii.gz" # Output recon

        # SVRTK requires the number of input images for each recon
        nim=${#dwi_ar[@]}

        # Begin writing script for recon
        # Syntax is:
        # $ mirtk reconstructDWI [output.nii.gz] [num images] [im1] [im2] [grad1] [grad2] [bval to reconstruct] [t2 atlas target] [dof transform to atlas] [-mask mask] 
        echo "cd /home/data/${svrdir}" >> $run # SVRTK saves temp files in the current directory
        echo "mirtk reconstructDWI $svr $nim \\" >> $run 

        let ck=0 # Add input images one-by-one
        while [[ $ck -lt $z ]]; do
            imbase=`basename ${dwi_ar[$ck]} .nii.gz`
            echo "/home/data/${svrtk}/input/${imbase}.nii.gz \\" >> $run
            echo "${imbase}" 
            ((ck++))
        done

        let ck=0 # Add input gradients files (.b) one-by-one
        while [[ $ck -lt $z ]]; do
            imbase=`basename ${dwi_ar[$ck]} .nii.gz`
            echo "/home/data/${svrtk}/input/${imbase}.b \\" >> $run
            ((ck++))
        done

        # Add bvalue to reconstruct, target atlas image, and DOF transform
        echo "${svrbval} \\" >> $run
        echo "/home/data/${svrtk}/input/atlas_t2final_${id}.nii.gz \\" >> $run
        echo "/home/data/${svrtk}/input/dwi-atlas_${id}.dof \\" >> $run 
        echo "-mask /home/data/$svrmask \\" >> $run
        # echo "-svr_only \\" >> $run
        # echo "-debug" \\ >> $run # This saves the intermediate file, including slice transforms
        echo "-resolution 0.75 \\" >> $run
        echo "-iterations 3" >> $run
        echo "cd /home/data" >> $run # Return to the starting directory

        echo Wrote run script: $run
        echo
    fi
done

echo "Setting permissions for $svrtk to open for Docker"
chmod -R 777 $svrtk 2> /dev/null
