#!/bin/bash

if [ $# -ne 5 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [T2 recon mask] [atlasspace T2 recon] [transform T2->Atlas] [CaseID] [Original T2 stack for orientation]"
    echo "ex: sh $0 mask_r3Drecon_registration.nii register_CASEID.nii.gz nxbmcr3DreconOfetus_best_x_FLIRTto_STA30.mat CASEID fetus_x.nii.gz"
	exit 1
	fi

argMASK=$1 # Brain mask image for T2 recon in T2 space
argREG=$2 # T2 recon registered to atlas space
argTFM=$3 # Transform for recon -> atlas space
CASEID=$4 # Subject ID
argSTACK=$5 # T2 stack which was used for orientation (fetus_xx.nii.gz)
# NOTE: If you find a file with a name like: 'r3DreconOfetus_best_18.nii.gz', 
# use 'fetus_18.nii.gz' as the input for this argument

# Set full paths
BRAINMASK=`readlink -f $argMASK`
REFERENCE=`readlink -f $argREG`
TRANSFORM=`readlink -f $argTFM`
BESTORIG=`readlink -f $argSTACK`
TFMPREFIX="t2-atlas"
# INCORRECT VERSION OR REORIENT
# REORIENT="/fileserver/fetal/bin/crlReorientReconstructedImage"
C3D="/fileserver/fetal/bin/c3d_affine_tool"
FIXMAT="/home/ch191070/scripts/fetalDTI/changeTFMnameInFileToAffine.py"
NIIDIR=`dirname $BESTORIG`
DRECON="${NIIDIR}/drecon.nii"
RRECON="${NIIDIR}/rrecon.nii"
TFM1="${NIIDIR}/transform1.tfm"
AFF="${NIIDIR}/affine1.tfm"
INV="${NIIDIR}/inverse1.tfm"
TFM2="${NIIDIR}/transform2.tfm"
FINALTFM="${NIIDIR}/${TFMPREFIX}_${CASEID}.tfm"
FINALINV="${NIIDIR}/${TFMPREFIX}_${CASEID}_inv.tfm"
outT2T2="${NIIDIR}/t2_t2_${CASEID}.nii"
outT2mask="${NIIDIR}/t2_mask_${CASEID}.nii.gz"
outATLAST2="${NIIDIR}/atlas_t2_${CASEID}.nii.gz"
outATLASmask="${NIIDIR}/atlas_mask_${CASEID}.nii.gz"

# Recreate the reoriented recon (same as r3DreconOfetus_best_x.nii.gz)
crlReorientReconstructedImage $DRECON $BESTORIG $RRECON $TFM1

if [[ -f $RRECON && -f $DRECON && $TFM1 ]] ; then
    # Change transform to affine
    crlAnyTransformToAffineTransform $TFM1 $AFF
    crlAnyTransformToAffineTransform $TFM1 $INV 1

    # Next few lines convert the FSL transform to ITK transform, if needed
    if ! grep -iq "Insight" $TRANSFORM ; then
        echo "Convert transform FSL -> ITK"
        # Requires Python 3
        if [[ -n `python3 -V` ]] ; then
            # This fixes the arrangement of the numeric values in the transform
            $C3D -ref $REFERENCE -src $RRECON $TRANSFORM -fsl2ras -oitk $TFM2
            # This fixes the text in the transform file
            FIXMATlocal="${NIIDIR}/`basename $FIXMAT`"
            cp $FIXMAT -v $FIXMATlocal 
            python3 $FIXMATlocal $TFM2
        else echo "Python3 not found"
            echo "Required for FSL->ITK transform conversion"
            exit 1
        fi
    else
        echo "Transform is already ITK"
        cp $TRANSFORM -v $TFM2
    fi

    crlComposeAffineTransforms $TFM2 $AFF $FINALTFM
    crlAnyTransformToAffineTransform $FINALTFM $FINALINV 1
# What was mask.nii.gz for?
#    skResampler $BRAINMASK $INV $DRECON nearest mask.nii.gz
    skResampler $DRECON $FINALTFM $REFERENCE bspline $outATLAST2
    skResampler $BRAINMASK $TFM2 $outATLAST2 nearest $outATLASmask
    skResampler $outATLASmask $FINALINV $DRECON nearest $outT2mask
else
    echo "Reorient failed ($RRECON, $DRECON, or $TFM1 inaccessbile)"
    exit 1
fi
cp $DRECON -v $outT2T2
gzip -f $outT2T2
# copy t2-atlas_CASEID.tfm, atlas*.nii.gz, and t2*.nii.gz to DWI folder for processing (5 files in total)
