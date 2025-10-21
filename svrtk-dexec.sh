#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-nob0 || -nob1 ]] -- [DWI Case Dir]
    Incorrect input supplied
    This script is used after running svrtk-bgen.sh to generate 'run-svrtk.sh's for a fetal diffusion pipeline case
    Supply a dwi directory (the one named with the subject id and has folders like 'volumes', 'svrtk', and 'b0b1')
    run-svrtk.sh will be found in svrtk/b0 and svrtk/b1 - both b0 and b1 recons will be run
    Creates a detached SVRTK docker image, and then uses it to execute the run script, then deletes the container
    -nob0       Skips b0 recon
    -nob1       Skips b1 recon
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
        -nob0|--nob0)
            let nob0=1
            ;;
        -nob1|--nob1)
            let nob1=1
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

# Server directory to be mounted
mpath=`readlink -f $1`
id=`basename $mpath`

# Validate argument
if [[ ! -d $mpath ]] ; then
    die "error: $mpath is not a directory"
fi
if [[ ! -d ${mpath}/svrtk ]] ; then
    die 'error: svrtk folder not found'
fi
runs=`find $mpath/svrtk -name run-svrtk.sh`
if [[ ! -n $runs ]] ; then
    die "error: run-svrtk.sh not found in the subj/svrtk/b0 or b1 directories"
fi

# Path to mount inside container
conpath="/home/data"
# random string
dockname="SVRTK-$RANDOM"

echo "Container will be named $dockname"
echo "Mount path within container: $conpath"
echo "Initializing SVRTK Docker container"
docker run -id --name $dockname --rm --mount type=bind,source=${mpath},target=${conpath} fetalsvrtk/svrtk /bin/bash
echo
if [[ $nob0 -ne 1 ]] ; then
    echo "Executing b0 SVRTK recon within container"
    date
    docker exec -t -i -w /home/data $dockname sh -c "sh svrtk/b0/run-svrtk.sh"
    echo
    echo "B0 recon done"
else echo "--nob0 is set, skipping b0 reconstruction"
fi
if [[ $nob1 -ne 1 ]] ; then
    echo "Executing b1 SVRTK recon within container"
    date
    docker exec -t -i -w /home/data $dockname sh -c "sh svrtk/b1/run-svrtk.sh"
    echo
    echo "B1 recon done"
else echo "--nob1 is set, skipping b1 reconstruction":
fi
echo "Stopping docker image"
docker stop $dockname
echo

if [[ ! -f ${mpath}/svrtk/b0/SVRTK-dwi_b0_${id}.nii.gz || ! -f ${mpath}/svrtk/b1/SVRTK-dwi_b1_${id}.nii.gz || ! -f ${mpath}/svrtk/b0/image0.nii.gz ]] ; then
	echo "WARNING: At least one of b0_1, b0_2 or b1 were not generated. Check output"
fi

# Copy SVRTK recon outputs to b0b1 folder
cp ${mpath}/svrtk/b0/SVRTK-dwi_b0_${id}.nii.gz -vup ${mpath}/b0b1/dwi_b0_${id}.nii.gz
cp ${mpath}/svrtk/b0/image0.nii.gz -vup ${mpath}/b0b1_b0_${id}_tensor.nii.gz
cp ${mpath}/svrtk/b1/SVRTK-dwi_b1_${id}.nii.gz -vup ${mpath}/b0b1/dwi_b1_${id}.nii.gz
gzip -d ${mpath}/b0b1_b0_${id}_tensor.nii.gz # computeTensor binary needs this uncompressed
