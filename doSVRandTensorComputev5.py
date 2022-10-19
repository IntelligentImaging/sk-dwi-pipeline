import os
import subprocess as sp
from pathlib import Path
import sys

############################
# Imput parsing
############################

b0                  = sys.argv[1] #'/common/projects/Shadab/fetal/Brain/1147s1/b0b1/dwi_b0_1147s1.nii.gz'
# processingServer 	= sys.argv[2]
RegInp 				= sys.argv[2]

dilateFactor		= '4' # Dilate-by number is passed as string
volToUse   			= RegInp[0:2]
regMetric  			= RegInp[2:]
print ('Vol is ' + volToUse)
print('Registration metric is ' + regMetric)

# You can add any other properties that you'd like to be user-modifiable here.
if len(sys.argv) > 3:
	for i in range(3, len(sys.argv)):
		if sys.argv[i][:11] == '-dilateMask':
			dilateFactor = sys.argv[i][12:]
print('Dilate factor is ' + dilateFactor)

############################
# Setup and Declaration
############################
SVRexecutable           = '/fileserver/fetal/software/bin/regSliceToVolume'
computeTensorExecutable = '/fileserver/fetal/software/bin/computeTensor'
resampler 		        = 'crlResampler' # Located in crkit
print('SVR executable =  ' + SVRexecutable)
print('Compute tensor executable = ' + computeTensorExecutable)

b0_tensor               = b0.replace('.nii.gz', '_tensor.nii.gz')
b1                      = b0.replace('dwi_b0_', 'dwi_b1_')
baseFolder 				= os.path.split(os.path.split(b0)[0])[0]
PID          			= os.path.split(baseFolder)[1] # Patient ID; e.g. 1147s1
t2folder                = baseFolder + '/t2'
b0b1folder              = baseFolder + '/b0b1'
volFolder				= baseFolder + '/volumes'
dtiFolder				= baseFolder + '/dti'
dwi_to_atlas_tfm		= b0b1folder+'/'+volToUse+'-atlas_'+PID+'_'+regMetric+'.tfm'
resampledMask			= t2folder+'/'+'atlas_mask_'+PID+'_1pt2.nii.gz'
dilatedMask             = t2folder+'/'+'atlas_mask_'+PID+'_1pt2_dilated.nii.gz'

def listFilesWithSearchString(searchString=''):
	p = sp.Popen('ls '+searchString, stdout=sp.PIPE, shell=True)
	(out, err) = p.communicate()
	out = out.decode('utf-8')
	out = out.split('\n')
	out = [x for x in out if os.path.isfile(x)]
	return out

def getPython3version():
	pythons = listFilesWithSearchString('/usr/bin/python3.*')
	python3 = [item for item in pythons if len(item)==18] 
	if len(python3) == 0:
		return -1
	else:
		return python3[0]

############################
# DO SVR
############################
print('Do SVR')
sp.call(( SVRexecutable, '-f', b0, '-b', b1, '-d', volFolder, '-j', '2', '-m', '1', '-r', '5', '-x', '2.0', '-y', '1', '-z', '-1'  ))
print('SVR done')

############################
# RENAME ALL .tfm files
############################
print('Renaming .tfm files')
dirs = [str(x) for x in Path(volFolder).iterdir() if x.is_dir() and not os.path.split(str(x))[1].startswith('tmp')]
for dirToProcess in dirs:	 # Create a list of B0 files
	tmpFiles = [str(x) for x in Path(dirToProcess).iterdir() if x.is_file() and os.path.split(str(x))[1].endswith('.tfm') and not 'tensor' in os.path.split(str(x))[1] ]
	for i in tmpFiles:
		sp.call(( 'mv', i, i.replace('_crop-Estimated-', '_tensor-Estimated-') ))
		sp.call(( 'mv', '-v', i, i.replace('-Estimated-', '_tensor-Estimated-') ))

###########################
# Tensor Computations
###########################
# Resample atlas mask isotropically with 1.2mm resolution
print('Resample atlas mask to isotropic')
sp.call(( 'crlResampleToIsotropic', t2folder+'/'+'atlas_mask_'+PID+'.nii.gz', 'nearest', resampledMask, '-x', '1.2', '-y', '1.2', '-z', '1.2' ))
print('Dilating Mask')
sp.call(( 'crlBinaryMorphology', resampledMask, 'dilate', '1', dilateFactor, dilatedMask  )) # outputs 'atlas_mask_'+PID+'_1pt2_dilate.nii.gz'
print('Removing temp files')
sp.call(( 'rm', '-rfv', baseFolder+'/volumes/tmpB0', baseFolder+'/volumes/tmpB1' ))
print('Computing tensor')
sp.call(( computeTensorExecutable, '-b', b0_tensor, '-s', dilatedMask, '-f', dwi_to_atlas_tfm, '-d', baseFolder+'/volumes', '-t', 'CWLLS1', '-o', 'atlas_tensor_'+PID+'_'+volToUse+regMetric, '-w', '2', '-g', '0.63405' ))
print('Compute tensor complete')

###########################
# Calculate Tensor Derived Scalars
###########################
# Move all tensor files to DTI folder:
# List all nrrd files in volumes folder 
print('Moving tensor files to dti/ folder')
tmpFiles = [str(x) for x in Path(volFolder).iterdir() if x.is_file() and os.path.split(str(x))[1].endswith('.nrrd')]
for i in tmpFiles:
	sp.call(( 'mv', '-v', i, dtiFolder))

# Convert to float and clean tensor
#tmpFiles = [str(x) for x in Path(dtiFolder).iterdir() if x.is_file() and os.path.split(str(x))[1].endswith('LLS1.nrrd')]
print('Computing FA and color FA images')
tmpFiles = [str(x) for x in Path(dtiFolder).iterdir() if x.is_file() and os.path.split(str(x))[1].find('LLS') and os.path.split(str(x))[1].endswith('.nrrd')]
for i in tmpFiles:
	tensorFileName = os.path.splitext(os.path.split(i)[1])[0]
	sp.call(( 'crlCastSymMatDoubleToFloat', i, dtiFolder+'/'+tensorFileName+'.nii.gz' ))
	sp.call(( 'crlTensorClean', '-z', '-i', dtiFolder+'/'+tensorFileName+'.nii.gz', '-o', dtiFolder+'/'+tensorFileName+'.nii.gz' ))

# Transform B0/B1 images to atlas space
print('Transforming B0/B1 to atlas space in b0b1 folder')
sp.call(( resampler, b0, dwi_to_atlas_tfm, resampledMask, 'bspline', b0b1folder+'/'+'atlas_b0_'+PID+'.nii.gz' ))
sp.call(( resampler, b1, dwi_to_atlas_tfm, resampledMask, 'bspline', b0b1folder+'/'+'atlas_b1_'+PID+'.nii.gz' ))
    
# tmpFiles = [str(x) for x in Path(dtiFolder).iterdir() if x.is_file() and os.path.split(str(x))[1].endswith('CWLLS1.nrrd')]
# for i in tmpFiles:
# 	# We will extract reg method and tensor method used from the file name
# 	# File name follows this convention: atlas_tensor_PID_regMethod-tensorMethod.nrrd, e.g.: atlas_tensor_0792s2_b0mi-LLS.nrrd
# 	tensorMethod = i[ i.rfind('-')+1 : -5 ]
# 	regMethod    = i[ i.rfind('_')+1 : i.rfind('-') ]

# 	if not os.path.exists( dtiFolder+'/'+ regMethod ):
# 		os.mkdir( dtiFolder +'/'+ regMethod )

# 	# sp.call(( 'sh', '/home/ch191070/dti.sh', 'tensor.nrrd', resampledMask, outputFolder, resampledMask))
# 	sp.call(( 'sh', '/home/ch191070/code/fetalDTI/dti.sh', i, resampledMask, dtiFolder+'/'+regMethod+'/'+tensorMethod, resampledMask ))
