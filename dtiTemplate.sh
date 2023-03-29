#!/bin/bash
if [ ! -d $FETALDTI ] ; then
    echo '$FETALDTI is not set in your .bashrc or the folder does not exist'
    echo "add something like: FETALDTI=/home/ch162835/DTIfetal-local to your .bashrc"
    exit
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then	
	echo "Incorrect argument supplied!"
    echo "usage: sh $0 [CASEID] [DICOMs (optional)]"
	echo "Run in study folder"
    echo "Optional argument DICOMs will set up a symbolic link to the raw data which will be converted by pipeline scripts (DO NOT USE WITH WASHU DATA)"
	exit
	fi

ID=$1 # CaseID
echo $ID

echo "Setting up pipeline dirs"
mkdir -p ${ID}/b0b1 ${ID}/dti ${ID}/t2 ${ID}/volumes ${ID}/nrrd ${ID}/scripts ${ID}/removed
# echo "Copying scripts"
# cp $FETALDTI/createB0B1v3.py -uvp ${ID}/scripts/
# cp $FETALDTI/createCompositeDiffusionImagev2.py -uvp ${ID}/scripts/
# cp $FETALDTI/registerB0B1toT2-multicrl.py -uvp ${ID}/scripts/
# cp $FETALDTI/processSlicerTFMv2.py -uvp ${ID}/scripts/
# cp $FETALDTI/doSVRandTensorComputev5.py -uvp ${ID}/scripts/
# cp $FETALDTI/b0b1ReconLib.py -uvp ${ID}/scripts/

if [[ -n $2 ]] ; then
echo "Setting up symbolic link to raw DICOM dir"
    if [[ ! -d $2 ]] ; then
        echo "DICOM directory does not exist; check path"
        exit
    fi
    DICOM=`find ${2} -type d -name DICOM`
    if [[ ! -d ${ID}/DICOM ]] ; then
        ln -s ${DICOM} "${ID}/DICOM"
    else echo " --DICOM dir or symlink already exists"
    fi
fi
echo
