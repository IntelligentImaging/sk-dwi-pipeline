#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input DWI scan]
    Incorrect input supplied

    This script is for use with our fetal dwi pipeline subject folders if you need to manually removed problematic volumes.
    First, delete the problem volumes (vol_0025.nii.gz, for example)
    There will now be a mismatch between the amount of values in bvals/bvecs and the remaining volumes. This script will attempt to edit bvals and bvecs, and rename the individual volumes to be compatible with the dwi pipeline binaries
    After the script runs, the volumes will be renamed in ascending order starting from vol_0000.nii.gz and the values associated with the removed volumes will no longer be in the value text files.
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

if [ $# -ne 1 ]; then
    show_help
    exit
fi 

if [[ -d $1 ]] ; then
    indir=$1
else die "$indir is not a volume directory"
fi

bvals="${indir}/bvals"
cp ${bvals} ${indir}/bvals.bak
bvecs="${indir}/bvecs"
cp ${bvecs} ${indir}/bvecs.bak

# Count up the number of volumes, bvals, and bvecs
vols=`find $indir -maxdepth 1 -name vol_\?\?\?\?.nii.gz`
numvols=`echo $vols | wc -w`
numval=`cat $bvals | wc -w`  
numvec=`cat $bvecs | wc -w`
numvec2=`echo $numvec/3 | bc`
echo $numvols volumes found
echo $numval values in bvals
echo $numvec2 vectors in bvecs


if [[ $numvols -ne $numval ]] ; then
    echo "Number of volumes does not match bvals"

    # dcm2niix bvecs formats has three rows (for x, y, and z directions)
    # To make manipulating the text file easier we split it into three files, one for each row
    echo "Split bvecs into files for manipulation"
    let linex=1
    while read line ; do
        echo $line > bvecs_${linex}.txt
        ((linex++))
    done < $bvecs

    # Set up arrays and index info from bvals and bvecs
    echo "Index volumes and values in arrays"
    declare -a ARvol ARbval ARbvecx ARbvecy ARbvecz
    let x=0
    # We will be checking to see if each volume exists later, and omitting values for volumes which are missing
    while [[ $x -lt $numval ]] ; do
        x4=$(printf "%04d" $x)
        ARvol[$x]=${indir}/vol_${x4}.nii.gz
        ((x++))
    done
    let x=0
    # Indexes each bvalue found in bvals
    for bval in `cat $bvals` ; do
        ARbval[$x]=$bval
        ((x++))
    done
    # Indexes each bvector for x, y, and z in separate files
    let x=0
    for bvec in `cat bvecs_1.txt` ; do
        ARbvecx[$x]=$bvec
        ((x++))
    done
    let x=0
    for bvec in `cat bvecs_2.txt` ; do
        ARbvecy[$x]=$bvec
        ((x++))
    done
    let x=0
    for bvec in `cat bvecs_3.txt` ; do
        ARbvecz[$x]=$bvec
        ((x++))
    done

    # Here we only take values with existing volumes and write them into new bvals and bvecs text files
    let count=0
    while [[ $count -lt $numval ]] ; do
        if [[ -f ${ARvol[$count]} ]] ; then
                stringval="${stringval}${ARbval[$count]} "
                stringvecx="${stringvecx}${ARbvecx[$count]} "
                stringvecy="${stringvecy}${ARbvecy[$count]} "
                stringvecz="${stringvecz}${ARbvecz[$count]} "
        fi
        ((count++))
    done
    # We'll be temporarily saving our new bvals and bvecs here
    obvals="${indir}/obvals"
    obvecs="${indir}/obvecs"
    echo "${stringval}" > $obvals
    echo "${stringvecx}" > $obvecs
    echo "${stringvecy}" >> $obvecs
    echo "${stringvecz}" >> $obvecs

    # Now we need to rename the vol_xxxx.nii.gz files to be in ascending number from 0000 up. We need to start from 0000 and can't skip numbers due to how the DWI recon binaries selects input volumes.
    echo "Renaming volume files to be in ascending order"
    let count=0
    for old in ${indir}/vol_????.nii.gz ; do
        new="${ARvol[$count]}"
        if [[ ! $old == $new ]] ; then
            mv -v ${old} ${new}
        fi
        ((count++))
    done

    # Overwrite the original bvals and bvecs and remove temporary files
    mv ${obvals} ${bvals}
    mv ${obvecs} ${bvecs}
    rm bvecs_{1,2,3}.txt

else echo "There is no mismatch between volumes and the values found in bvals and bvecs. Either this scan doesn't require editing or you need to remove volumes."
fi
