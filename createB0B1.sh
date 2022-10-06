#!/bin/bash
if [ $# -ne 1 ]; then	
	echo "Shadab pipeline step 3"
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [B0 Crop]"
	echo "eg. /casepath/volumes/21_vol_0000_crop.nii.gz"
    echo "## This script WILL delete previous dwi_b0,b1,tensor outputs ##"
	exit
	fi

if [[ ! -f $1 ]] ; then
	echo "$1 doesn't exist - exiting"
	exit
	fi

VOL=`readlink -f ${1}`
CASEDIR="${VOL%/volumes*}"
VOLDIR="${CASEDIR}/volumes"
CASEID=`basename ${CASEDIR}`
B0="dwi_b0_${CASEID}.nii.gz" 
B1="dwi_b1_${CASEID}.nii.gz" 
TENSOR="dwi_b0_${CASEID}_tensor.nii" 
SCRIPTS="${CASEDIR}/scripts"
rm -rfv ${VOLDIR}/tmp*
rm -vf volumes/${B0} volumes/${TENSOR} volumes/${B1} b0b1/${B0} b0b1/${TENSOR} b0b1/${B1}

# select available python3 version
if python3.7 -V | grep -q "Python 3.7" ; then
        echo python3.7
        py="python3.7"
elif python3.5 -V | grep -q "Python 3.5" ; then
        echo python3.5
        py="python3.5"
elif python3.6 -V | grep -q -e "Python3.6" -e "Python 3.6" ; then
        echo python3.6
        py="python3.6"
elif python3 -V | grep -q -e "Python" ; then
        python3 -V
        py="python3"
else
        echo "Python 3 not found"
        echo "Exiting"
        exit
fi

cmd="$py ${SCRIPTS}/createB0B1v3.py ${VOL}"
echo "$cmd" > ${SCRIPTS}/run-createB0B1.py.sh
CONTENTS=`find ${CASEDIR}/volumes/ -maxdepth 1 -type d`
echo "# Volumes present: "$CONTENTS"" >> ${SCRIPTS}/run-createB0B1.py.sh
$cmd
if [[ -f ${CASEDIR}/b0b1/${B0} || -f ${CASEDIR}/volumes/${B0} ]] ; then
    echo "B0 successful"
else echo "B0 not generated"
fi
if [[ -f ${CASEDIR}/b0b1/${TENSOR} || -f ${CASEDIR}/volumes/${TENSOR} ]] ; then
    echo "Tensor successful"
else echo "Tensor not generated"
fi
if [[ -f ${CASEDIR}/b0b1/${B1} || -f ${CASEDIR}/volumes/${B1} ]] ; then
    echo "B1 successful"
else echo "B1 not generated"
fi
if [[ -f ${CASEDIR}/b0b1/${B0} && -f ${CASEDIR}/b0b1/${TENSOR} && -f ${CASEDIR}/b0b1/${B1} ]] ; then
    echo "Output to b0b1/"
    echo "Now prepare T2 data set (DTIfetal-t2atlas.sh), copy to caseID/t2 directory, and run registerB0B1toT2"
else echo "Something went wrong"
fi
