#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [subj DWI dir]
    Incorrect input supplied
    This script performs the 4D -> 3D splitting and conversion of the DWI pipeline,
    without the need to supply DICOMs (for when you already have nrrds and don't want
    to convert from DICOM to nrrd/NIFTI.
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi 

proc=`readlink -f $1`
id=`basename $proc`
nrrd="${proc}/nrrd"
volumes="${proc}/volumes"
echo $id
for series in ${nrrd}/* ; do
echo $series
    base=`basename $series`
    in4D=`find ${series} -name \*nii.gz`
    sernum=`echo $series | sed -e 's,.*_,,g' -e 's,\.*,,g'`
    out3D="${volumes}/d${sernum}"
    mkdir -pv ${out3D}

    # |v| SLICE TIMING |v|
    sliceT="${series}/sliceTiming.txt"
    echo "Generate slice timing"
    json=`find ${series} -type f -name \*json | head -n1`
    # Find starting location of timing info
    tim=`grep Timing $json -n | cut -d':' -f1`
    # Add one to go to the next line
    let lbeg=$tim+1
    echo SliceTimings begin on line $lbeg of the json
    # Count number of slices
    z=`crlImageStats ${nifti} | grep "Size:" | cut -d' ' -f4 | sed 's,\],,'`
    # Number of times we will need to advance to next line
    let slices=$z-1
    # Get last line of Timings
    lend=`echo ${lbeg} + ${slices} | bc`
    echo Timings go from line $lbeg to $lend
    # Extract lines
    sing=`sed -ne "${lbeg},${lend}p" < $json`
    final=`echo $sing | sed -e 's/, /\\\/g' -e 's/ \],//g'`
    echo "Slice timings:"
    echo $final
    echo "(0019,1029) FD ${final} # 288,36 Genereated by Clem script" > $sliceT
    echo "Slice timing file: $sliceT"

    echo "Split 4D to 3D"
    fslsplit ${in4D} ${out3D}/vol_ -t

    echo "Copy bvals, bvecs, sliceTimings to volumes/ folder"
    cp ${series}/*.bval  -v ${out3D}/bvals
    cp ${series}/*.bvec  -v ${out3D}/bvecs
    cp ${sliceT}         -v ${out3D}
done
