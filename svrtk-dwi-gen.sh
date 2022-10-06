#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [opt: -t ITK transform to atlas space] [case DWI dir] [mask ROI]
    Incorrect input supplied
    This script takes a subject directory from our fetal diffusion processing pipeline
    and makes a subfolder and scripts for running SVRTK's diffusion reconstruction program
    (to be run through their docker)
EOF
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -t|--tfm)
            if [[ -f "$2" ]] ; then
                tfm=$2 # Specify
                shift
            else
                die 'error: Atlas transform not found'
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

# set variables
subj=`readlink -f $1`
id=`basename $subj`
mask=$2

# check arguments
if [[ ! -d ${subj}/b0b1 || ! -d ${subj}/nrrd ]] ; then
    echo "this doesn't look like a fetal DWI pipeline subject directory"
    show_help
fi

if [[ ! -f $mask ]] ; then
    echo supplied mask is not a file
    show_help
fi

if [[ ! -n $tfm ]] ; then
    tfm=`find ${subj}/b0b1 -maxdepth 1 -name b\*atlas_*tfm`
    wc=`echo $tfm | wc -w`
    if [[ $wc -gt 1 ]] ; then
        echo more than one transform found, try using -t option
        exit
    fi
    echo "atlas tfm = ${tfm}"
fi

# set more variables
nrrd="${subj}/nrrd"
svrtk="${subj}/svrtk"
mkdir -pv $svrtk
volumes="${subj}/volumes"
# we need a few files to create the .dof transform or run SVRTK
t2=`find ${subj}/t2/ -name t2_t2\*z -a ! -name t2_t2\*crop\*z` # t2 space recon (used for ITK->MIRTK transform conversion)
b0=`find ${subj}/b0b1 -name dwi_b0\*z -a ! -name dwi_b0\*crop\*z` # dwi space B0 (also used for transform conversion)
atlas=`find ${subj}/t2 -name atlas_t2_\*z` # atlas space t2 recon (used as target for SVRTK)
atlasbase=`basename $atlas`
atlas2="${svrtk}/${atlasbase}"
cp $atlas $svrtk # copy atlas image and dwi mask to SVRTK folder so the docker can see them
cp $mask $svrtk # dwi input mask
maskbase=`basename $mask`
listvol="${svrtk}/listvol.txt" # we store a list of the input vols here
if [[ -f $listvol ]] ; then rm ${listvol} ; fi
listb="${svrtk}/listb.txt" # we store a list of the unique bvalues here
if [[ -f $listb ]] ; then rm ${listb} ; fi ; touch $listb

# loop to generate .b file (bvals+bvecs) for each volume, used by SVRTK
for im in ${nrrd}/* ; do
    base=`basename $im`
    if [[ -d $im && -d ${volumes}/${base} ]] ; then
        echo Series: $base
        nifti=`find $im -name \*.nii.gz`
        bvals="${im}/bvals"
        b="${svrtk}/${base}.b"
        cp ${nifti} ${svrtk} # copy volume to SVRTK folder so the docker can see them
        # script to combine bvecs and bvals
        sh /home/ch162835/scripts/combineSVRTKb.sh ${im}/bvecs ${bvals} ${svrtk}/${base}.b
        echo ${base}.nii.gz >> ${listvol} # Write down the input volume for later
        # Write each novel (non-zero) b-value into the other text list
        for checkb in `cat $bvals` ; do
            if [[ $checkb -ne 0 ]] ; then
                if ! grep -q $checkb $listb ; then
                    echo "$checkb" >> $listb
                fi
            fi
        done
    fi
done

# Converting the transform to atlas space from ITK (.tfm) to MIRTK (.dof)
tfmbase=`basename $tfm .tfm`
echo convert ITK transform to MIRTK DOF
dof="${svrtk}/${tfmbase}.dof"
/fileserver/fetal/bin/c3d_affine_tool -ref $t2 -src $b0 -itk $tfm -oirtk ${svrtk}/${tfmbase}.dof
dofbase=`basename $dof`

# Writing the run script for SVRTK
number=`wc $listvol -w | cut -d' ' -f1` # Write each novel (non-zero) b-value into text list
# We make a separate run script for each bvalue
for reconb in `cat $listb` ; do
    run="${svrtk}/run-svrtk-dwi${reconb}.sh" # run script
    if [[ -f $run ]] ; then rm $run ; fi
    # mirtk reconstructDWI [output] [number of input vols] 
    echo "mirtk reconstructDWI reconDWI_b${reconb}.nii.gz $number \\" >> $run
    for vol in `cat ${listvol}` ; do
        echo "$vol" \\ >> $run # Write each input vol
    done
    for vol in `cat ${listvol}` ; do
        dotB=`echo $vol | sed -e 's,.nii.gz,.b,g'`
        echo "${dotB}" \\ >> $run # Write each corresponding input .b file
    done
    # [bvalue to reconstruct] [target atlas iamge] [atlas transform]
    echo "${reconb} ${atlasbase} ${dofbase}" \\ >> $run
    echo "-mask ${maskbase}" \\ >> $run # Mask for reconstruction
    # Other settings for SVRTK
    echo "-order 4 -motion_sigma 15 -resolution 1.5 -thickness 2 -sigma 20 -iterations 5 -template 0 -motion_model_hs -sr_sh_iterations 10 -resolution 1.75 -no_robust_statistics" >> $run
done

echo "Wrote $run"
