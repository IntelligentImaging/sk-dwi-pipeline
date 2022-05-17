#!/bin/bash
if [ ! -d $FETALDTI ] ; then
    echo '$FETALDTI is not set in your .bashrc or the folder does not exist'
    echo "add something like: FETALDTI=/home/ch162835/DTIfetal-local to your .bashrc"
    exit
fi

if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [CASEID]"
	echo "Run in study folder"
	exit
	fi
ID=$1
mkdir -p ${ID}/b0b1 ${ID}/dti ${ID}/t2 ${ID}/volumes ${ID}/nrrd ${ID}/scripts ${ID}/removed
cp $FETALDTI/createB0B1v3.py -uvp ${ID}/scripts/
cp $FETALDTI/createCompositeDiffusionImagev2.py -uvp ${ID}/scripts/
cp $FETALDTI/registerB0B1toT2-multicrl.py -uvp ${ID}/scripts/
cp $FETALDTI/processSlicerTFMv2.py -uvp ${ID}/scripts/
cp $FETALDTI/doSVRandTensorComputev5.py -uvp ${ID}/scripts/
cp $FETALDTI/b0b1ReconLib.py -uvp ${ID}/scripts/
