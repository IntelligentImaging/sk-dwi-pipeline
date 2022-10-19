#!/bin/bash
if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [DWI Case Dir]"
    echo "This script is used after running svrtk-bgen.sh to generate 'run-svrtk.sh's for a fetal diffusion pipeline case"
    echo "Supply a dwi directory (the one named with the subject id and has folders like 'volumes', 'svrtk', and 'b0b1')"
    echo "run-svrtk.sh will be found in svrtk/b0 and svrtk/b1 - both b0 and b1 recons will be run"
    echo "Creates a detached SVRTK docker image, and then uses it to execute the run script, then deletes the container"
	exit
	fi

# Server directory to be mounted
mpath=`readlink -f $1`

# Validate argument
if [[ ! -d $mpath ]] ; then
    echo error: $mpath is not a directory
    exit 1
fi
runs=`find $mpath/svrtk -name run-svrtk.sh`
if [[ ! -n $runs ]] ; then
    echo error: run-svrtk.sh not found in the subj/svrtk/b0 or b1 directories
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
echo "Executing SVRTK run script within container"
date
docker exec -t -i -w /home/data $dockname sh -c "sh svrtk/b0/run-svrtk.sh ; sh svrtk/b1/run-svrtk.sh"
echo
echo "Recon done"
date
echo "Stopping docker image"
docker stop $dockname
echo
