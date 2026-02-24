# dwi-recon-pipeline

This is a set of scripts used to process diffusion fetal images at the CRL.

## 2025 Version

The original reconstruction binary code is gone, and there seems to be incompatibilities between it and modern systems.
We've started work on adapting the code to use SVRTK for reconstruction purposes instead, which are then fed into computeTensor, same as before.
This cuts out a number of dependencies and changes some steps, so the original instructions have been archived below.

### Dependencies
- CRKIT
- dcm2niix
- MRtrix3
- Apptainer (or Docker, if you must)

### Installation
  1. Download this repository
  2. Add `export FetalDTI=/path/to/repo` to your .bashrc
  3. Add `export PATH=$PATH:/path/to/fetalmri/software/bin` to your .bashrc

### Processing Steps
  1. Create a template directory: `sh dwi-recon-pipeline/dtiTemplate.sh CASEID`
  2. Convert and prep data: `sh dwi-recon-pipeline/convert.sh [--crl] [CASE DIR]`
  3. Validate data quality and, if necessary, cut down to 2-4 volumes. You can move unwanted series from dcm2niix/ to removed/
  4. Make a binary mask manually or with : `itksnap volumes/XX_BrainDWI/vol_0000.nii.gz` or `sh dwi-recon-pipeline-main/make_volROIs.sh [CASE DIR]`
  5. Create composite B0/B1's (run script): `sh dwi-recon-pipeline/svrtk-dgen.sh -n 5 [CASE/nrrd] [mask file]` (-n controls the max number of input volumes used for reconstruction)
  6. Execute run script: `sh dwi-recon-pipeline/svrtk-dexec.sh [CASE DIR]`
  7. Verify you have T2 reconstruction outputs available in `[CASE/t2/]`. You can generate them with: `sh dwi-recon-pipeline/t2auto.sh PATH/TO/reconstruction/CASEID/nii/ PATH/TO/diffusion/CASEID/`
  8. Register B0B1 to T2 space: `sh /fileserver/fetal/scripts/DTIfetal/register.sh [dwi_b0_SUBJID.nii.gz]`
  9. Keep only one registration attempt, clearing the rest: `sh dwi-recon-pipeline/cleanupRegs.sh [b0b1/t2_bx_id_metric.nii.gz]`
  10. Compute tensor image: `sh dwi-recon-pipeline/tensor_compute.sh [CASE DIR]`
  11. refine `t2/atlas_mask_CASEID_1pt2.nii.gz`, save as `t2/atlas_mask_CASEID_1pt2_refine.nii.gz`
  12. Mask tensor, generate dwi maps, RGB, etc: `sh dwi-recon-pipeline/tensor_post.sh [CASE DIR]`
  13. Run TrackVis to create a .trk tract file: `sh dwi-recon-pipeline/runTrackVis.sh [CASE DIR]`


## ARCHIVED VERSION

Dependencies
- CRKIT
- dcm2niix
- python3 (nibabel) and docker for running Davood's Color FA code
- Boost 1.58
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
  6. You might need to do this: `sudo apt install libgsl27 ; sudo ln /usr/lib/x86_64-linux-gnu/libgsl.so.27 /usr/lib/x86_64-linux-gnu/libgsl.so.0`
  7. You might need to do this: `sudo apt install libtbb12 ; sudo ln /usr/lib/x86_64-linux-gnu/libtbb.so.12 /usr/lib/x86_64-linux-gnu/libtbb.so.2`
  8. You might need to do this: `sudo apt install cudart12 ; sudo ln /usr/lib/x86_64-linux-gnu/libcudart.so.12 /usr/lib/x86_64-linux-gnu/libcudart.so.8.0`

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
  9. Compute tensor image: `sh dwi-recon-pipeline/tensor_compute.sh [b0b1/dwi_b0_SUBJID.nii.gz]`
  10. refine `t2/atlas_mask_CASEID_1pt2.nii.gz`, save as `t2/atlas_mask_CASEID_1pt2_refine.nii.gz`
  11. Mask tensor, generate dwi maps, RGB, etc: `sh dwi-recon-pipeline/tensor_post.sh [CASE DIR]`
  12. Run TrackVis to create a .trk tract file: `sh dwi-recon-pipeline/runTrackVis.sh [CASE DIR]`
