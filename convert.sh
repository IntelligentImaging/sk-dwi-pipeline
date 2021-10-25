#!/bin/bash

if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [dwi case directory]"
	exit
fi

idpath=`readlink -f $1`
if [[ ! -d $idpath ]] ; then
    echo "Path does not exist"
    exit 1
fi

id=`basename $idpath`
DICOM="${idpath}/DICOM"
NRRD="${idpath}/nrrd"
VOLUMES="${idpath}/volumes"

for dcm in ${DICOM}/* ; do
    if [[ -d $dcm ]] ; then
    
        # INITIAL DCM2NIIX CONVERT, RENAME FILES, GENERATE SLICE TIMING
        echo "Converting $dcm"
        base=`basename $dcm`
        out4D="${NRRD}/${base}"
        out3D="${VOLUMES}/${base}"
        mkdir -pv ${out4D} ${out3D}
        dcm2niix -z y -f %s_%d -w 1 -o ${out4D} ${dcm}
        nifti=`find ${out4D} -type f -name \*.nii.gz`
        nbase=`basename $nifti .nii.gz`
        echo
        
        echo "Rename bvals and bvecs"
        bvals="${out4D}/bvals"
        bvecs="${out4D}/bvecs"
        mv -v ${out4D}/${nbase}.bval ${bvals}
        mv -v ${out4D}/${nbase}.bvec ${bvecs}
        echo "bvals = $bvals"
        echo "bvecs = $bvecs"       
        echo
        
        # |v| SLICE TIMING |v|
        echo "Generate slice timing"
        json=`find ${out4D} -type f -name \*json | head -n1`
        sliceT="${out4D}/sliceTiming.txt"
        # image="${out4D}/${base}.nii.gz"
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
        echo

        # FSL SPLIT and copy to volumes folderi
        echo "Split 4D to 3D"
        fslsplit ${nifti} ${out3D}/vol_ -t
        echo

        # Copy bvals, bvecs, and sliceTiming.txt to the recon directory
        echo "Copy to reconstruction directory"
        cp ${bvals} ${bvecs} ${sliceT} -v ${out3D} 
        
        echo
    fi
done
