#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} -t [registration suffix] -d [dilation factor] -- [dwi_b0_SUBJID.nii.gz]
    Incorrect input supplied

    -t||--tfm       Specify registration to use for tensor computation and atlas transform (ex: b0mi, default=looks to see if there is only one transform available and uses that)
    -d||--dil       Specify dilation factor (default=4)
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

B0=`readlink -f ${1}`
b0b1=`dirname $B0`
CASEDIR="${B0%/b0b1*}"
CASEID=`basename $CASEDIR`
SCRIPTS="${CASEDIR}/scripts"

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
fi
echo Registration suffix is $REG

# Default dilation factor
if [[ ! -n $DIL ]] ; then let DIL=4 ; fi

# select available python3 version
if python3.5 -V | grep -q "Python 3.5" ; then
    echo Python3.5
    py="python3.5"
elif python3.6 -V | grep -q -e "Python3.6" -e "Python 3.6" ; then
    echo Python3.6
    py="python3.6"
else
    echo "Python 3.5 or 3.6 not found"
    echo "Exiting"
    exit
fi

cmd="$py ${SCRIPTS}/doSVRandTensorComputev5.py ${B0} ${REG} -dilateMask=${DIL}"
echo "$cmd" > ${SCRIPTS}/run-doSVRandTensorCompute.py.sh
$cmd
if [[ ! -f ${CASEDIR}/dti/atlas_tensor_${CASEID}_${REG}-CWLLS1.nii.gz ]] ; then
	echo "Something went wrong- tensor not generated"
else
	echo "Done. Check tensor output in dti/"
	echo "Refine t2/atlas_mask* overlaid with b0b1/atlas_b0* and b0b1/atlas_b1*"
	echo "Save refined mask as: t2/atlas_mask_CASEIDScanNum_1pt2_refine.nii.gz"
fi
