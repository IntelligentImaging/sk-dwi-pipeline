#!/bin/bash
if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [CASEID]"
	echo "Run in study folder"
	exit
	fi
ID=$1
mkdir -p ${ID}/b0b1 ${ID}/dti ${ID}/t2 ${ID}/volumes ${ID}/DICOM ${ID}/nrrd ${ID}/scripts ${ID}/removed
# cp /home/ch191070/scripts/fetalDTI/prepDWI.py -uvp ${ID}/scripts/
cp /home/ch191070/scripts/fetalDTI/createB0B1v3.py -uvp ${ID}/scripts/
cp /home/ch191070/scripts/fetalDTI/createCompositeDiffusionImagev2.py -uvp ${ID}/scripts/
cp /home/ch191070/scripts/fetalDTI/registerB0B1toT2-multicrl.py -uvp ${ID}/scripts/
cp /home/ch191070/scripts/fetalDTI/processSlicerTFMv2.py -uvp ${ID}/scripts/
cp /home/ch191070/scripts/fetalDTI/doSVRandTensorComputev5.py -uvp ${ID}/scripts/
cp /home/ch191070/scripts/fetalDTI/b0b1ReconLib.py -uvp ${ID}/scripts/
