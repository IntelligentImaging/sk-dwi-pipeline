#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-nob0 || -nob1 ]] -- [DWI Case Dir]
    Incorrect input supplied
    This script is used after running svrtk-bgen.sh to generate 'run-svrtk.sh's for a fetal diffusion pipeline case
    Supply a dwi directory (the one named with the subject id and has folders like 'volumes', 'svrtk', and 'b0b1')
    run-svrtk.sh will be found in svrtk/b0 and svrtk/b1 - both b0 and b1 recons will be run
    Creates a detached SVRTK docker image, and then uses it to execute the run script, then deletes the container
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
    echo error: $mpath is not a directory
    exit 1
fi
runs=`find $mpath/s-svrtk -name run-svrtk.sh`
if [[ ! -n $runs ]] ; then
    echo error: run-svrtk.sh not found in the subj/s-svrtk/b0 or b1 directories
    exit 1
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
for svr in $runs ; do
    echo "Executing SVRTK recon within container: $svr"
    rest=`echo $svr | sed -e 's,.*s-svrtk,s-svrtk,g'`
    date
    docker exec -t -i -w /home/data $dockname sh -c "sh ${rest}"
    echo
    echo "Recon done"
done
echo "Stopping docker image"
docker stop $dockname
echo
