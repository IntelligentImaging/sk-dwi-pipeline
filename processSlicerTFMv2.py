import os
import subprocess as sp
from subprocess import Popen
from pathlib import Path
import sys
# Compute SVR
rigidMaskRegExec = '/home/ch191070/code/DWIvolumeRegistration/Build/bmRigidRegistraion'
b0in                    = sys.argv[1] #'/common/projects/Shadab/fetal/Brain/1147s1/b0b1/dwi_b0_1147s1_crop.nii.gz'
dwi_to_t2_Slicer_tfm    = sys.argv[2]

skResampler 			= '/home/ch191070/code/MyCodes/skResampler/Build/skResampler'
b0                      = os.path.abspath(b0in)
b1                      = b0.replace('dwi_b0_', 'dwi_b1_')
baseFolder 				= os.path.split(os.path.split(b0)[0])[0]
PID          			= os.path.split(baseFolder)[1] # Patient ID; e.g. 1147s1
t2folder                = baseFolder + '/t2'
b0b1folder              = baseFolder + '/b0b1'
t2img                   = t2folder + '/' + 't2_t2_' + PID + '.nii.gz'
t2_mask                 = t2folder + '/' + 't2_mask_' + PID + '.nii.gz'
t2_mask_undilated       = t2folder + '/' + 't2_mask_' + PID + '_undilated.nii.gz' #(Will be created by this program)
t2_mask_dilated         = t2folder + '/' + 't2_mask_' + PID + '_dilated.nii.gz' #(Will be created by this program)
if not os.path.isfile( t2img ):
		t2img = t2folder + '/' + 't2_t2_' + PID + '.nii.gz'


# Generate B0B1 tranformed using slicer tfm (resample)
print('Resampling dwi_b0 and dwi_b1 with Slicer transform')
sp.call(( skResampler, b0, dwi_to_t2_Slicer_tfm, t2img, 'bspline', b0b1folder+'/'+'t2_b0_'+PID+'_Slicer.nii.gz' ))
sp.call(( skResampler, b1, dwi_to_t2_Slicer_tfm, t2img, 'bspline', b0b1folder+'/'+'t2_b1_'+PID+'_Slicer.nii.gz' ))

# Seed rigid registration using b0/b1 and t2 with different metrics using slicer initialization
# No mask
print('Register B0+B1 Slicer Init to T2 w/ NCC, MI (no mask)- four registrations')
commands = [
    ('crlRigidRegistration', t2img, b0, b0b1folder+'/'+'t2_b0_'+PID+'_Slicerncc.nii.gz', b0b1folder+'/'+'b0-t2_'+PID+'_Slicerncc.tfm', '-l', dwi_to_t2_Slicer_tfm, '-p', '2', '--metricName', 'normcorr'),
    ( 'crlRigidRegistration', t2img, b0, b0b1folder+'/'+'t2_b0_'+PID+'_Slicermi.nii.gz', b0b1folder+'/'+'b0-t2_'+PID+'_Slicermi.tfm', '-l', dwi_to_t2_Slicer_tfm,'-p', '2', '-b', '64'),
    ( 'crlRigidRegistration', t2img, b1, b0b1folder+'/'+'t2_b1_'+PID+'_Slicerncc.nii.gz', b0b1folder+'/'+'b1-t2_'+PID+'_Slicerncc.tfm', '-l', dwi_to_t2_Slicer_tfm,'-p', '2', '--metricName', 'normcorr'),
    ( 'crlRigidRegistration', t2img, b1, b0b1folder+'/'+'t2_b1_'+PID+'_Slicermi.nii.gz', b0b1folder+'/'+'b1-t2_'+PID+'_Slicermi.tfm', '-l', dwi_to_t2_Slicer_tfm,'-p', '2', '-b', '64'),
    ]
procs = [Popen(i) for i in commands ]
for p in procs:
    p.wait()


# Create t2 image mask
print('Create dilated T2 image mask')
sp.call(( 'crlBinaryMorphology', t2_mask, 'dilate', '1', '6', t2_mask_dilated ))

# Dilated mask
print('Register B0+B1 Slicer init to T2 w/ NCC, MI (dilated mask) - four registrations')
commands = [
    ('crlRigidRegistration', t2img, b0, b0b1folder+'/'+'t2_b0_'+PID+'_Slicernccm.nii.gz', b0b1folder+'/'+'b0-t2_'+PID+'_Slicernccm.tfm', '-t', '2', '-p', '2', '--metricName', 'normcorr', '--fixedImageMask', t2_mask_dilated ),
    ('crlRigidRegistration', t2img, b1, b0b1folder+'/'+'t2_b1_'+PID+'_Slicernccm.nii.gz', b0b1folder+'/'+'b1-t2_'+PID+'_Slicernccm.tfm', '-t', '2', '-p', '2', '--metricName', 'normcorr', '--fixedImageMask', t2_mask_dilated ),
    ( 'crlRigidRegistration', t2img, b0, b0b1folder+'/'+'t2_b0_'+PID+'_Slicermim.nii.gz', b0b1folder+'/'+'b0-t2_'+PID+'_Slicermim.tfm', '-t', '2', '-p', '2', '-b', '64', '--fixedImageMask', t2_mask_dilated ),
    ( 'crlRigidRegistration', t2img, b1, b0b1folder+'/'+'t2_b1_'+PID+'_Slicermim.nii.gz', b0b1folder+'/'+'b1-t2_'+PID+'_Slicermim.tfm', '-t', '2', '-p', '2', '-b', '64', '--fixedImageMask', t2_mask_dilated ),
    ]
procs = [ Popen(i) for i in commands ]
for p in procs:
    p.wait()

# Undilated mask
print('Register B0+B1 Slicer init w/ NCC, MI (undilated mask)- four registrations')
commands = [
    ('crlRigidRegistration', t2img, b0, b0b1folder+'/'+'t2_b0_'+PID+'_Slicernccmu.nii.gz', b0b1folder+'/'+'b0-t2_'+PID+'_Slicernccmu.tfm', '-t', '2', '-p', '2', '--metricName', 'normcorr', '--fixedImageMask', t2_mask ),
    ('crlRigidRegistration', t2img, b1, b0b1folder+'/'+'t2_b1_'+PID+'_Slicernccmu.nii.gz', b0b1folder+'/'+'b1-t2_'+PID+'_Slicernccmu.tfm', '-t', '2', '-p', '2', '--metricName', 'normcorr', '--fixedImageMask', t2_mask ),
    ( 'crlRigidRegistration', t2img, b0, b0b1folder+'/'+'t2_b0_'+PID+'_Slicermimu.nii.gz', b0b1folder+'/'+'b0-t2_'+PID+'_Slicermimu.tfm', '-t', '2', '-p', '2', '-b', '64', '--fixedImageMask', t2_mask ),
    ( 'crlRigidRegistration', t2img, b1, b0b1folder+'/'+'t2_b1_'+PID+'_Slicermimu.nii.gz', b0b1folder+'/'+'b1-t2_'+PID+'_Slicermimu.tfm', '-t', '2', '-p', '2', '-b', '64', '--fixedImageMask', t2_mask ),
        ]
procs = [ Popen(i) for i in commands ]
for p in procs:
    p.wait()

# Compose Transforms
print('Compose Transforms - DWI->T2 + T2->Atlas space')
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b0-t2_'+PID+'_Slicerncc.tfm', b0b1folder+'/'+'b0-atlas_'+PID+'_Slicerncc.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b0-t2_'+PID+'_Slicermi.tfm', b0b1folder+'/'+'b0-atlas_'+PID+'_Slicermi.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b1-t2_'+PID+'_Slicerncc.tfm', b0b1folder+'/'+'b1-atlas_'+PID+'_Slicerncc.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b1-t2_'+PID+'_Slicermi.tfm', b0b1folder+'/'+'b1-atlas_'+PID+'_Slicermi.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b0-t2_'+PID+'_Slicernccm.tfm', b0b1folder+'/'+'b0-atlas_'+PID+'_Slicernccm.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b0-t2_'+PID+'_Slicermim.tfm', b0b1folder+'/'+'b0-atlas_'+PID+'_Slicermim.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b1-t2_'+PID+'_Slicernccm.tfm', b0b1folder+'/'+'b1-atlas_'+PID+'_Slicernccm.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b1-t2_'+PID+'_Slicermim.tfm', b0b1folder+'/'+'b1-atlas_'+PID+'_Slicermim.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b0-t2_'+PID+'_Slicernccmu.tfm', b0b1folder+'/'+'b0-atlas_'+PID+'_Slicernccmu.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b0-t2_'+PID+'_Slicermimu.tfm', b0b1folder+'/'+'b0-atlas_'+PID+'_Slicermimu.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b1-t2_'+PID+'_Slicernccmu.tfm', b0b1folder+'/'+'b1-atlas_'+PID+'_Slicernccmu.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b1-t2_'+PID+'_Slicermimu.tfm', b0b1folder+'/'+'b1-atlas_'+PID+'_Slicermimu.tfm' ))
