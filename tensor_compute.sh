#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-t reg-suffix] [-d dilation] [-nr] [-nt] -- [dwi_b0_SUBJID.nii.gz]
    Incorrect input supplied

    -t || --tfm     Specify registration to use for tensor computation and atlas transform
                    (ex: b0mi, default looks to see if there is only one transform
                    available and uses that)
    -d  || --dil    Specify dilation factor (default=4)
    -nr || --noreg  Will skip slice to volume registration
    -nt || --noten  Will skip tensor compute
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
        -t|--tfm)
            if [[ -n "$2" ]] ; then
                let REG=$2 # Specify
                shift
            else
                die 'error: No transform specified'
            fi
            ;;
        -d|--dil)
            if [[ "$2" -ge 0 ]] ; then
                DIL="${2}" # Specify
                shift
            else
                die 'error: Dilation factor not specified'
            fi
            ;;
        --) # end of optionals
            shift
            break
            ;;
        -nr|--noreg)
            let noreg=1 # will skip SVR step
            ;;
        -nt|--noten)
            let noten=1 # will skip tensor compute step
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

b0=`readlink -f ${1}`
b0b1=`dirname $b0`
CASEDIR="${b0%/b0b1*}"
id=`basename $CASEDIR`
dti="${CASEDIR}/dti"
b1="${b0b1}/dwi_b1_${id}.nii.gz"
b0_tensor="${b0b1}/dwi_b0_${id}_tensor.nii"
t2="${CASEDIR}/t2"
volumes="${CASEDIR}/volumes"

# Choose which registration to use, if none given
if [[ ! -n $REG ]] ; then
    echo "No reg metric specified, looking for one"
    look=`find ${b0b1} -maxdepth 1 -type f -name b\?-t2_\*.tfm`
    howmany=`echo $look | wc -w`
    if [[ $howmany -eq 1 ]] ; then
        base=`basename $look`
        bpick=`echo $base | sed 's,\(b[0-1]\).*,\1,g'` # picks out whether it's "b0" or "b1"
        mpick=`echo $base | sed 's,b[0-1]-t2_.*_\(.*\)\.tfm,\1,g'` # picks out which reg metric was used
        REG="${bpick}${mpick}"
    elif [[ $howmany -gt 1 ]] ; then
        echo "More than one transform found. You need to specify which transform to use."
    elif [[ $howmany -eq 0 ]] ; then
        echo "No transform found"
    fi
    # If a registration was specified, we grab whether it was b0 or b1 and which metric here
else
    bpick=`echo $REG | sed 's,\(b[0-1]\).*,\1,g'`
    mpick=`echo $REG | sed 's,b[0-1]\(.*\),\1,g'`
fi
echo Registration suffix is $REG


tfm="${b0b1}/${bpick}-atlas_${id}_${mpick}.tfm" # DWI to atlas transform
mask="${t2}/atlas_mask_${id}.nii.gz" # resampled mask
rmask="${t2}/atlas_mask_${id}_1pt2.nii.gz" # resampled mask
dmask="${t2}/atlas_mask_${id}_1pt2_dilated.nii.gz" # dilated mask
output="atlas_tensor_${id}_${bpick}${mpick}"

# Default dilation factor
if [[ ! -n $DIL ]] ; then let DIL=4 ; fi

# Slice-to-Volume Registration (SVR) - dwi stacks to the reconstructed b0b1 images
if [[ $noreg -eq 0 ]] ; then
    echo "${id}: Slice-to-Volume Registration"
    regSliceToVolume --fixed $b0 --b1Image $b1 --dir $volumes -j 2 -m 1 -r 5 -x 2.0 -y 1 -z -1
    echo SVR done

    # Rename stack transforms for tensor executable
    # We use b0_1 and b1 for SVR, but b0_2 for computeTensor, so we need to rename the transforms
    transforms=`find ${volumes} -mindepth 1 -maxdepth 2 -name dwi_b0_${id}-Estimated-vol_\?\?\?\?.tfm`
    for vol in $transforms ; do
        volrename=`echo $vol | sed 's,-Estimated,_tensor-Estimated,g'`
        mv -v $vol $volrename
    done
else
    echo --noreg is set, skipping SVR
fi

if [[ $noten -eq 0 ]] ; then
    # Tensor computation
    # Resample atlas make isotropically with 1.2mm resolution
    echo "Resample mask to isotropic"
    crlResampleToIsotropic $mask nearest $rmask -x 1.2 -y 1.2 -z 1.2
    echo "Dilate mask"
    crlBinaryMorphology $rmask dilate 1 $DIL $dmask
    echo "${id}: Compute tensor"
    dummyb0="${b0_tensor}.gz" # computeTensor does string manipulation for some reason, we need to supply it with a "gz" ending which it stripts off
    computeTensor --baseB0Image $dummyb0 --AtlasBrainMask $dmask --atlasTransformName $tfm --dir $volumes --dtiMethod CWLLS1 --outputTensor $output 
    # computeTensor also saves output to the same directory as the --dir argument so we need to move them to the dti folder
    mv -v ${volumes}/${output}* $dti/
    echo "Compute tensor complete"

    echo "${id}: Post-process"
    for ten in ${dti}/${output}*nrrd ; do
        tenbase=`basename $ten .nrrd`
        tenfinal="${dti}/${tenbase}.nii.gz"
        echo "Convert to float"
        crlCastSymMatDoubleToFloat $ten $tenfinal
        echo "Tensor clean"
        # We overwrite with tensor clean because this is how Shadab's original pipeline did it
        crlTensorClean --compressOutput --inputFile $tenfinal --outputFile $tenfinal
    done
else
    echo --noten is set, skipping tensor compute
fi

echo "Transform b0 and b1 recons to atlas space"
crlResampler $b0 $tfm $rmask bspline ${b0b1}/atlas_b0_${id}.nii.gz
crlResampler $b1 $tfm $rmask bspline ${b0b1}/atlas_b1_${id}.nii.gz

# Check output
if [[ ! -f ${CASEDIR}/dti/atlas_tensor_${id}_${REG}-CWLLS1.nii.gz ]] ; then
	echo "Something went wrong- tensor not generated"
else
	echo "Done. Check tensor output in dti/"
	echo "Refine t2/atlas_mask* overlaid with b0b1/atlas_b0* and b0b1/atlas_b1*"
	echo "Save refined mask as: t2/atlas_mask_${id}_1pt2_refine.nii.gz"
fi
