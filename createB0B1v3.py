############################
# Setup and Imports
############################
import subprocess as sp
import os
import nibabel as nib
import sys
from b0b1ReconLib import fileSizeInKB, execSPcall

try:
    b0RefFile   = sys.argv[1]
except IndexError as err:
    print("ERROR: You need to provide a reference volume for B0 computation as the 1st argument: \n",
    	  "This typically looks like: /fileserver/projects/Shadab/fetal/Brain/1147s1/volumes2/21_vol_0000_crop.nii.gz",
    	  "Make sure to provide the full path")

folderPath   = os.path.split(b0RefFile)[0]
PID          = os.path.split(os.path.split(folderPath)[0])[1] # Patient ID; e.g. 1147s1
b0Folder 	 = 'tmpB0'
b1Folder 	 = 'tmpB1'
cropPx		 = 4
createCompositeImageScript = folderPath + '/../scripts/createCompositeDiffusionImagev2.py'

# QUE: WHAT ARE ALL THESE FILE NAMES FOR B0 AND B1 BELOW? THIS IS VERY CONFUSING!
# ANS: It does look confusing, but here is what is going on. We create two versions of B0
# let's call them B0_1 and B0_2, and one version of B1.
# B0_1 and B1 are used for registration purposes - these are the output of the superresolution
# process from Bernhard Kainz et al.'s code that we have modified extensively.
# B0_2 is the version that is used for computing tensor - this is a result of forward projection
# of all b=0 images that is computed with a PSF formulation. Because the iterative updates
# apply a non-linear filter and modify the intensity content, we do not use B0_1 for tensor
# computation even though it appears visually more appealing.
# Also, the superresolution pipeline results in edge slices having some artifacts,
# that's why we have a cropped version of B0_1 and B1 for avoiding errors in cost computation
# during registration.

# Finally, sometimes the iterative process fails, even though forward projection works. Which means
# we still have some images to use for registration with T2, though they may not be as visually 
# appealing as we expect from the output of the iterative update process (of superresolution pipeline)
# For this reason, we have define an alternative source of B0_1 and B1 for registration (with suffix 'Alt')

b0source 	 = 'image1_GPU.nii.gz'
b0sourceAlt  = 'GaussianReconstruction_GPU3.nii'
b0dest   	 = 'dwi_b0_'+PID+'.nii.gz'
b0dest_tensor= 'dwi_b0_'+PID+'_tensor.nii'
b0destAlt    = 'dwi_b0_'+PID+'.nii'
b0destCrop	 = 'dwi_b0_'+PID+'_crop'+'.nii.gz'

b1source 	 = 'image1_GPU.nii.gz'
b1sourceAlt  = 'GaussianReconstruction_GPU3.nii'
b1dest   	 = 'dwi_b1_'+PID+'.nii.gz'
b1destAlt  	 = 'dwi_b1_'+PID+'.nii'
b1destCrop   = 'dwi_b1_'+PID+'_crop'+'.nii.gz'

# IF the file size for B0_1 and B1 is less than the below specified number, we switch to 'alternative' source
# for B0_1 and B1. This implies that iterative update process failed even though forward projection is fine.
minFileSizeinKBForB0B1 = 100


def listFilesWithSearchString(searchString=''):
	p = sp.Popen('ls '+searchString, stdout=sp.PIPE, shell=True)
	(out, err) = p.communicate()
	out = out.decode('utf-8')
	out = out.split('\n')
	out = [x for x in out if os.path.isfile(x)]
	return out

def getPython3Version():
	pythons = listFilesWithSearchString('/usr/bin/python3.*')
	python3 = [item for item in pythons if len(item)==18] 
	if len(python3) == 0:
		return -1
	else:
		return python3[0]

python3 = getPython3Version()

############################
# Create B0:
############################

print('Create B0 SVR')
sp.call(( python3, createCompositeImageScript, 'b0', b0RefFile, '-1' ))

# Check file size of b0source
if fileSizeInKB(folderPath+'/'+b0Folder+'/'+b0source) < minFileSizeinKBForB0B1:
	sp.call(( python3, createCompositeImageScript, 'b0', b0RefFile, '1.2' ))
	sp.call(( python3, createCompositeImageScript, 'b0', b0RefFile, '-1' ))
	# Check file size of b0source, if it is still less than 50 KB, use GaussianRecon and move ahead.
	fileSize = fileSizeInKB(folderPath+'/'+b0Folder+'/'+b0source)
	if fileSize < minFileSizeinKBForB0B1 :
		b0source = b0sourceAlt
		b0dest   = b0destAlt
else:
	print('B0 file size is okay')

sp.call(( 'cp', folderPath+'/'+b0Folder+'/'+b0source,    '-v', folderPath+'/'+b0dest    ))
sp.call(( 'cp', folderPath+'/'+b0Folder+'/'+b0sourceAlt, '-v', folderPath+'/'+b0dest_tensor    ))

############################
# Create B1:
############################

print('Create B1 SVR')
sp.call(( python3, createCompositeImageScript, 'b1', folderPath+'/'+b0dest, '-1' ))

# Check file size of b0source
if fileSizeInKB(folderPath+'/'+b1Folder+'/'+b1source) < minFileSizeinKBForB0B1:
	sp.call(( python3, createCompositeImageScript, 'b1', folderPath+'/'+b0dest, '1.2' ))
	sp.call(( python3, createCompositeImageScript, 'b1', folderPath+'/'+b0dest, '-1' ))
	# Check file size of b0source, if it is still less than 50 KB, use GaussianRecon and move ahead.
	fileSize = fileSizeInKB(folderPath+'/'+b1Folder+'/'+b1source)
	if fileSize < minFileSizeinKBForB0B1 :
		b1source = b1sourceAlt
		b1dest   = b1destAlt
else:
	print('B1 file size is okay')

sp.call(( 'cp', folderPath+'/'+b1Folder+'/'+b1source,    folderPath+'/'+b1dest    ))

############################
# Crop B0 and B1
############################

print('Crop B0 and B1')
# Setup image cropping, we do it because the image1_gpu produced by BK code has border artifacts
imgSize      = nib.load(folderPath+'/'+b0Folder+'/'+b0source).shape
imgSizeX     = imgSize[0]-cropPx*2
imgSizeY     = imgSize[1]-cropPx*2
imgSizeZ     = imgSize[2]-cropPx*2
# Below, we keep the image starting at the 5th pixel (indexing from 0 onwards)
cropString   = str(cropPx)+','+str(cropPx)+','+str(cropPx)+',' + str(imgSizeX) + ',' + str(imgSizeY) + ',' + str(imgSizeZ)

# Crop b0 and b1 images to remove border artifcats
# sp.call(( 'crlCropImage', '-i', folderPath+'/'+b0dest, '-o', folderPath+'/'+b0destCrop, '-x', cropString ))
# sp.call(( 'crlCropImage', '-i', folderPath+'/'+b1dest, '-o', folderPath+'/'+b1destCrop, '-x', cropString ))
# sp.call(( 'crlCropImage', '-i', folderPath+'/'+b0dest_tensor, '-o', folderPath+'/'+b0dest_tensor, '-x', cropString ))

############################
# Move Everything to b0b1 folder
############################

print('Moving files')
b0b1folder = os.path.split(folderPath)[0]+'/b0b1'
if os.path.isdir(b0b1folder+'/'+b0Folder) :
	sp.call(( 'rm', '-rfv', b0b1folder+'/'+b0Folder  ))
	sp.call(( 'rm', '-rfv', b0b1folder+'/'+b1Folder  ))
sp.call(( 'mv', '-v', folderPath+'/'+b0Folder, b0b1folder  ))
sp.call(( 'mv', '-v', folderPath+'/'+b1Folder, b0b1folder  ))
sp.call(( 'mv', '-v', folderPath+'/'+b0dest, b0b1folder  ))
sp.call(( 'mv', '-v', folderPath+'/'+b1dest, b0b1folder  ))
# sp.call(( 'mv', folderPath+'/'+b0destCrop, b0b1folder  ))
# sp.call(( 'mv', folderPath+'/'+b1destCrop, b0b1folder  ))
sp.call(( 'mv', '-v', folderPath+'/'+b0dest_tensor, b0b1folder  ))
