#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-nob0 || -nob1 ]] -- [DWI Case Dir]
    Incorrect input supplied
    BK DOCKER VERSION
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

# Validate argument
if [[ ! -d $mpath ]] ; then
    die "error: $mpath is not a directory"
fi
if [[ ! -d ${mpath}/b0b1/tmpB0 || ! -d ${mpath}/b0b1/tmpB1 ]] ; then
    die 'error: tmpB0 or tmpB1 folders not found'
fi
runs=`find $mpath/b0b1 -name run-b\?.sh`
if [[ ! -n $runs ]] ; then
    die "error: run-b0.sh or run-b1.sh not found in the subj/b0b1/tmpB0 or b1 directories"
fi

# Path to mount inside container
conpath="/home/data"
# random string
dockname="BK-$RANDOM"

echo "Container will be named $dockname"
echo "Mount path within container: $conpath"
echo "Initializing BK Docker container"
docker run -id --name $dockname --rm --mount type=bind,source=${mpath},target=${conpath} dittothat/fetalreconstruction:cuda6.5 /bin/bash
echo
if [[ $nob0 -ne 1 ]] ; then
    echo "Executing b0 recon within container"
    date
    docker exec -t -i -w /home/data $dockname sh -c "sh b0b1/tmpB0/run-b0.sh"
    echo
    echo "B0 recon done"
else echo "--nob0 is set, skipping b0 reconstruction"
fi
if [[ $nob1 -ne 1 ]] ; then
    echo "Executing b1 recon within container"
    date
    docker exec -t -i -w /home/data $dockname sh -c "sh b0b1/tmpB1/run-b1.sh"
    echo
    echo "B1 recon done"
else echo "--nob1 is set, skipping b1 reconstruction":
fi
echo "Stopping docker image"
docker stop $dockname
echo
