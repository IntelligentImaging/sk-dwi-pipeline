#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input niftymic folder]
    Incorrect input supplied
    
    This creates casefolder/niftymic/skdwi and puts
    the T2 recon files needed for SK dwi pipeline
    (atlas and T2 space recons/mask, and t2-to-atlas transform)
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi 

nm=`readlink -f $1`
dir=`dirname $nm`
subj=`basename $dir`

tspace=${nm}/srr/recon_template_space
sspace=${nm}/srr/recon_subject_space
collect=${nm}/../../../collect_niftymics

if [[ ! -d ${tspace} || ! -d ${sspace} ]] ; then
    echo "Could not find template or subject space recon folders"
    exit 1
fi

at_srr=${tspace}/srr_template.nii.gz
if [[ -f ${collect}/${subj}-srr_template_maskEDIT.nii.gz ]] ; then
    at_mask=${collect}/${subj}-srr_template_maskEDIT.nii.gz
else
    at_mask=${tspace}/srr_template_mask.nii.gz
fi
subj_srr=${sspace}/srr_subject.nii.gz
# This is where we put masks processed with DK dmri3d (for when there were subject-space errors)
if [[ -f ${nm}/dmri3d/t2_t2/mask.nii.gz ]] ; then
    subj_mask=${nm}/dmri3d/t2_t2/ccmask.nii.gz
    crlMaskConnectedComponents ${nm}/dmri3d/t2_t2/mask.nii.gz ${subj_mask} 1 1000
else
    subj_mask=${sspace}/srr_subject_mask.nii.gz
fi
sitk=${tspace}/srr_template_transform_sitk.txt

skdwi=${nm}/skdwi
mkdir -pv ${skdwi}


# THIS CAUSED ISSUES, USING DMRI3D INSTEAD
# We sometimes have edited niftymic masks which we need to pull from the collect_niftymics folders. This is in order to have an accurate subject space mask, since we only edit in atlas space. I couldn't find an easy way to do this. 
# First I convert the ITK tfm to SITK
# Then I get the inverse transform and apply it
# transformconvert ${sitk} itk_import ${skdwi}/srr_template_transform_sitk.mat -force
# transformcalc ${skdwi}/srr_template_transform_sitk.mat rigid ${skdwi}/srr_template_transform_sitk_rigid.mat -force
# mrtransform -force -template ${subj_srr} -inverse -linear ${skdwi}/srr_template_transform_sitk_rigid.mat -interp nearest ${at_mask} ${skdwi}/invmask_Xsignwrong.nii.gz

# But for some reason the resulting mask is reversed along one axis.
# I used these steps Ali previously suggested to correcting this issue.
# I'm not sure why it first needs to be converted to nrrd and then back to nifti.
# fslswapdim ${skdwi}/invmask_Xsignwrong.nii.gz -x y z ${skdwi}/invmask_Xsignwrong_swap.nii.gz
# crlChangeFormat ${skdwi}/invmask_Xsignwrong_swap.nii.gz ${skdwi}/invmask_Xsignwrong_swap.nrrd
#crlChangeFormat ${skdwi}/invmask_Xsignwrong_swap.nrrd ${skdwi}/t2_mask_${subj}.nii.gz # finally we have the edited subject space mask. Notably this will have different image headers than the niftymic-produced subject space recon. Maybe I should also apply the inverse transform to the recon to keep everything consistent.



# Copy and label the files: atlas space recon+mask, subject space recon
cp ${at_srr}    -vup ${skdwi}/atlas_t2_${subj}.nii.gz
cp ${at_mask}   -vup ${skdwi}/atlas_mask_${subj}.nii.gz
cp ${subj_srr}  -vup ${skdwi}/t2_t2_${subj}.nii.gz
cp ${subj_mask} -vup ${skdwi}/t2_mask_${subj}.nii.gz
cp ${sitk}      -vup ${skdwi}/t2-atlas_${subj}.tfm
