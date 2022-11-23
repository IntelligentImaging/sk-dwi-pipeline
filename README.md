# dwi-recon-pipeline

This is a set of scripts used to process diffusion fetal images at the CRL.

Dependencies
- CRKIT
- dcm2niix
- python3 (nibabel) and docker for running Davood's Color FA code
- gsl
- cuda8.0
- fsl (for fslsplit)
- TVtool (for generating RGB, alternate method)

All of these tools are installed on the CRL server, along with the reconstruction binaries.

Installation
  1. Download this repository
  2. Add `export FetalDTI=/path/to/repo` to your .bashrc
  3. Add `export PATH=$PATH:/fileserver/fetal/software/bin` to your .bashrc
  4. Add `export BOOST_ROOT=/fileserver/fetal/software/boost_1_58_0_sk` to your .bashrc
  5. Add `export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/fileserver/fetal/software/boost_1_58_0_sk/stage/lib` to your.bashrc

The general workflow is:
  1. Create a template directory: `sh dwi-recon-pipeline/dtiTemplate.sh CASEID`
  2. Convert and prep data: `sh dwi-recon-pipeline/convert.sh -d [DICOM DIR] [CASE DIR]`
  3. Validate data quality and, if necessary, cut down to 2-4 volumes
  4. Crop an example b0 image for ROI initialization: `itksnap volumes/XX_BrainDWI/vol_0000.nii.gz`
  5. Create composite B0/B1's: `sh dwi-recon-pipeline/b0b1recon.sh [B0 Crop]` \
  \
For the final steps you will require a couple files from the T2 reconstruction.
  6. Regenerate atlas and T2-space images and transforms: `sh dwi-recon-pipeline/t2auto.sh PATH/TO/reconstruction/CASEID/nii/ PATH/TO/diffusion/CASEID/`
  7. Register B0B1 to T2 space: `sh /fileserver/fetal/scripts/DTIfetal/register.sh [b0b1/dwi_b0_SUBJID.nii.gz]`
  8. Review registration attempts and note the best registration to t2_t2 found in `t2/`
  9. Compute tensor image: sh dwi-recon-pipeline/tensor_compute.sh `[b0b1/dwi_b0_SUBJID.nii.gz]`
  10. refine `t2/atlas_mask_CASEID_1pt2.nii.gz`, save as `t2/atlas_mask_CASEID_1pt2_refine.nii.gz`
  11. Mask tensor, generate dwi maps, RGB, etc: `sh dwi-recon-pipeline/tensor_post.sh [CASE DIR]`
  12. Run TrackVis to create a .trk tract file: `sh dwi-recon-pipeline/runTrackVis.sh [CASE DIR]`
