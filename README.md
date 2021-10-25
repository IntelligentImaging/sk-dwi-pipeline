# dwi-recon-pipeline

This is a set of scripts used to process diffusion fetal images at the CRL.

Dependencies
CRKIT
dcm2niix
python3 (and nibabel)
gsl
cuda8.0
fsl (for fslsplit)
TVtool (for generating RGB)

All of these tools are installed on the CRL server, along with the reconstruction binaries.

The general workflow is:
  1. Create a template directory: sh dwi-recon-pipeline/dtiTemplate.sh CASEID
  2. Copy all DWI series to CASEID/DICOM
  3. Convert and prep data: sh dwi-recon-pipeline/convert.sh [CASEID]
  4. Validate data quality and, if necessary, cut down to 2-4 volumes
  5. Crop an example b0 image for ROI initialization: itksnap volumes/XX_BrainDWI/vol_0000.nii.gz
  6. Create composite B0/B1's: sh dwi-recon-pipeline/createB0B1.sh [B0 Crop] \
  \
For the final steps you will require a couple files from the T2 reconstruction.
  7. Regenerate atlas and T2-space images and transforms: sh dwi-recon-pipeline/t2auto.sh PATH/TO/reconstruction/CASEID/nii/ PATH/TO/diffusion/CASEID/
  8. Register B0B1 to T2 space: sh /fileserver/fetal/scripts/DTIfetal/registerB0B1toT2-multi.sh [b0b1/dwi_b0_SUBJID.nii.gz]
  9. Review registration attempts and note the best registration to t2_t2 found in t2/
  10. Compute tensor image: sh dwi-recon-pipeline/doSVRandTensorCompute.sh [b0b1/dwi_b0_SUBJID.nii.gz] [SERVER] [BEST ALIGNMENT SUFFIX]
  11. refine t2/atlas_mask_CASEID_1pt2.nii.gz, save as t2/atlas_mask_CASEID_1pt2_refine.nii.gz
  12. Mask tensor, generate dwi maps, RGB, etc: sh dwi-recon-pipeline/tensor_post.sh [CASE DIR]
  13. Run TrackVis to create a .trk tract file: sh dwi-recon-pipeline/runTrackVis.sh [CASE DIR]
