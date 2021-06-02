import os
import subprocess as sp
from subprocess import Popen
from pathlib import Path
import sys
# Set file paths
b0                      = sys.argv[1] #'/common/projects/Shadab/fetal/Brain/1147s1/b0b1/dwi_b0_1147s1_crop.nii.gz'
b1                      = b0.replace('dwi_b0_', 'dwi_b1_')
baseFolder 				= os.path.split(os.path.split(b0)[0])[0]
PID          			= os.path.split(baseFolder)[1] # Patient ID; e.g. 1147s1
t2folder                = baseFolder + '/t2'
b0b1folder              = baseFolder + '/b0b1'
t2img                   = t2folder + '/' + 't2_t2_' + PID + '_crop' + '.nii.gz'
t2_mask                 = t2folder + '/' + 't2_mask_' + PID + '.nii.gz'
t2_mask_dilated         = t2folder + '/' + 't2_mask_' + PID + '_dilated.nii.gz' #(Will be created by this program)
if not os.path.isfile( t2img ):
		t2img = t2folder + '/' + 't2_t2_' + PID + '.nii.gz'

############################
# Rigid Registrations
############################
# No mask
print('Register B0+B1 to T2 w/ NCC, MI (no mask)- four registrations')
commands = [
	('crlRigidRegistration', t2img, b0, b0b1folder+'/'+'t2_b0_'+PID+'_ncc.nii.gz', b0b1folder+'/'+'b0-t2_'+PID+'_ncc.tfm', '-t', '2', '-p', '2', '--metricName', 'normcorr'), 
	('crlRigidRegistration', t2img, b1, b0b1folder+'/'+'t2_b1_'+PID+'_ncc.nii.gz', b0b1folder+'/'+'b1-t2_'+PID+'_ncc.tfm', '-t', '2', '-p', '2', '--metricName', 'normcorr'),
	( 'crlRigidRegistration', t2img, b0, b0b1folder+'/'+'t2_b0_'+PID+'_mi.nii.gz', b0b1folder+'/'+'b0-t2_'+PID+'_mi.tfm', '-t', '2', '-p', '2', '-b', '64' ),
	( 'crlRigidRegistration', t2img, b1, b0b1folder+'/'+'t2_b1_'+PID+'_mi.nii.gz', b0b1folder+'/'+'b1-t2_'+PID+'_mi.tfm', '-t', '2', '-p', '2', '-b', '64' ),
	]
procs = [ Popen(i) for i in commands ]
for p in procs:
	p.wait()

# Create t2 image mask
print('Create dilated T2 image mask')
sp.call(( 'crlBinaryMorphology', t2_mask, 'dilate', '1', '6', t2_mask_dilated ))

# Dilated mask
print('Register B0+B1 to T2 w/ NCC, MI (dilated mask) - four registrations')
commands = [
    ('crlRigidRegistration', t2img, b0, b0b1folder+'/'+'t2_b0_'+PID+'_nccm.nii.gz', b0b1folder+'/'+'b0-t2_'+PID+'_nccm.tfm', '-t', '2', '-p', '2', '--metricName', 'normcorr', '--fixedImageMask', t2_mask_dilated ),
    ('crlRigidRegistration', t2img, b1, b0b1folder+'/'+'t2_b1_'+PID+'_nccm.nii.gz', b0b1folder+'/'+'b1-t2_'+PID+'_nccm.tfm', '-t', '2', '-p', '2', '--metricName', 'normcorr', '--fixedImageMask', t2_mask_dilated ),
    ( 'crlRigidRegistration', t2img, b0, b0b1folder+'/'+'t2_b0_'+PID+'_mim.nii.gz', b0b1folder+'/'+'b0-t2_'+PID+'_mim.tfm', '-t', '2', '-p', '2', '-b', '64', '--fixedImageMask', t2_mask_dilated ),
    ( 'crlRigidRegistration', t2img, b1, b0b1folder+'/'+'t2_b1_'+PID+'_mim.nii.gz', b0b1folder+'/'+'b1-t2_'+PID+'_mim.tfm', '-t', '2', '-p', '2', '-b', '64', '--fixedImageMask', t2_mask_dilated ),
    ]
procs = [ Popen(i) for i in commands ]
for p in procs:
        p.wait()

# Undilated mask
print('Register B0+B1 w/ NCC, MI (undilated mask)- four registrations')
commands = [
    ('crlRigidRegistration', t2img, b0, b0b1folder+'/'+'t2_b0_'+PID+'_nccmu.nii.gz', b0b1folder+'/'+'b0-t2_'+PID+'_nccmu.tfm', '-t', '2', '-p', '2', '--metricName', 'normcorr', '--fixedImageMask', t2_mask ),
    ('crlRigidRegistration', t2img, b1, b0b1folder+'/'+'t2_b1_'+PID+'_nccmu.nii.gz', b0b1folder+'/'+'b1-t2_'+PID+'_nccmu.tfm', '-t', '2', '-p', '2', '--metricName', 'normcorr', '--fixedImageMask', t2_mask ),
    ( 'crlRigidRegistration', t2img, b0, b0b1folder+'/'+'t2_b0_'+PID+'_mimu.nii.gz', b0b1folder+'/'+'b0-t2_'+PID+'_mimu.tfm', '-t', '2', '-p', '2', '-b', '64', '--fixedImageMask', t2_mask ),
    ( 'crlRigidRegistration', t2img, b1, b0b1folder+'/'+'t2_b1_'+PID+'_mimu.nii.gz', b0b1folder+'/'+'b1-t2_'+PID+'_mimu.tfm', '-t', '2', '-p', '2', '-b', '64', '--fixedImageMask', t2_mask ),
	]
procs = [ Popen(i) for i in commands ]
for p in procs:
	p.wait()

# Compose Transforms
print('Compose Transforms - DWI->T2 + T2->Atlas space')
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b0-t2_'+PID+'_ncc.tfm', b0b1folder+'/'+'b0-atlas_'+PID+'_ncc.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b0-t2_'+PID+'_mi.tfm', b0b1folder+'/'+'b0-atlas_'+PID+'_mi.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b1-t2_'+PID+'_ncc.tfm', b0b1folder+'/'+'b1-atlas_'+PID+'_ncc.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b1-t2_'+PID+'_mi.tfm', b0b1folder+'/'+'b1-atlas_'+PID+'_mi.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b0-t2_'+PID+'_nccm.tfm', b0b1folder+'/'+'b0-atlas_'+PID+'_nccm.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b0-t2_'+PID+'_mim.tfm', b0b1folder+'/'+'b0-atlas_'+PID+'_mim.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b1-t2_'+PID+'_nccm.tfm', b0b1folder+'/'+'b1-atlas_'+PID+'_nccm.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b1-t2_'+PID+'_mim.tfm', b0b1folder+'/'+'b1-atlas_'+PID+'_mim.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b0-t2_'+PID+'_nccmu.tfm', b0b1folder+'/'+'b0-atlas_'+PID+'_nccmu.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b0-t2_'+PID+'_mimu.tfm', b0b1folder+'/'+'b0-atlas_'+PID+'_mimu.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b1-t2_'+PID+'_nccmu.tfm', b0b1folder+'/'+'b1-atlas_'+PID+'_nccmu.tfm' ))
sp.call(( 'crlComposeAffineTransforms', t2folder+'/'+'t2-atlas_'+PID+'.tfm', b0b1folder+'/'+'b1-t2_'+PID+'_mimu.tfm', b0b1folder+'/'+'b1-atlas_'+PID+'_mimu.tfm' ))
