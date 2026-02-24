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
