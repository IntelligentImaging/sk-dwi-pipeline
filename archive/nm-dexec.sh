#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} -b0 -b1 -m -- [input]
    Incorrect input supplied
    This script is to be run starts a detached NiftyMIC docker container to execute the run-nm.sh script.
    Supply a DWI directory with folders like 'volumes', 'niftymic' and 'b0b1'
    By default, reconstructs both the b0 and b1 images

    Optional arguments:
    -b0             Only reconstruct b0
    -b1             Only reconstruct b1
    -m              Before b0b1 reconstruction, run niftymic_segment_fetal_brain to
                    produce brain masks. Note that the nm-dgen.sh script determines
                    whether run-nm.sh will use the niftymic masks or not.
EOF
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -b0|--b0)
            let b0=1 # We will reconstruct b0
            ;;
        -b1|--b1)
            let b1=1 # We will reconstruct b1
            ;;
        -m|--mask)
            let mask=1 # We will run niftymic_segment_fetal_brains
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

# Validate argument
if [[ ! -d $mpath ]] ; then
    echo error: $mpath is not a directory
    exit 1
fi
runs=`find $mpath/niftymic -name run-nm.sh`
if [[ ! -n $runs ]] ; then
    echo error: run-nm.sh not found in the subj/svrtk/b0 or b1 directories
    exit 1
fi

# Path to mount inside container
conpath="/home/data"
# random string
dockname="nm-$RANDOM"

echo "Container will be named $dockname"
echo "Mount path within container: $conpath"
echo "Initializing NiftyMIC Docker container"
docker run -id --name $dockname --rm --mount type=bind,source=${mpath},target=${conpath} renbem/niftymic /bin/bash
echo

# If we are masking with NiftyMIC, we will run the mask script
if [[ -n $mask ]] ; then
    echo "Execute niftymic_segment_fetal_brains run script"
    docker exec -t -i -w /home/data $dockname sh -c "sh niftymic/run-masks.sh"
    echo
fi

# Run b0 and b1 recons if the option is set, or run both for the default behavior
if [[ -n $b0 ]] || [[ -z $b1 && -z $b0 ]] ; then
    echo "Execute b0 recon"
    docker exec -t -i -w /home/data $dockname sh -c "sh niftymic/b0/run-nm.sh"
    echo
fi
if [[ -n $b1 ]] || [[ -z $b0 && -z $b1 ]] ; then
    echo "Execute b1 recon"
    docker exec -t -i -w /home/data $dockname sh -c "sh niftymic/b1/run-nm.sh"
    echo
fi

# Stop docker
echo "Stopping docker image"
docker stop $dockname
echo
