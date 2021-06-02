# 1. Get folder location as input
# 2. Get a list of folders
# 3. For each folder, create an entry in filenames
# 4. Pass the filename as an argument to the SVRnewSH binary
############################
# IMPORTS AND DEFINITIONS
############################
import sys
#import nibabel as nib
from pathlib import Path
import os
import subprocess as sp
from b0b1ReconLib import getBvals, listFilesInDir, resolveDirName, bashExec, findMaxVoxelSpacingWithIndex

############################
# DEBUG
############################
# refFile = '/common/projects/Shadab/fetal/Brain/1147s1/volumes/21_vol_0000_crop.nii.gz'

############################
# USER SETTINGS
############################
# REQUIRED
executable = '/home/ch191070/library/fetalReconstruction-SK_WORKING/source/bin/SVRreconstructionGPU'
# executable = '/home/ch191070/library/fetalReconstruction-SK/bin_Working_032417/SVRreconstructionGPU'
outputFileName = 'B0.nii'

# OPTIONAL, set these to an empty string to not use these options, e.g. maskFile=''
# If you don't provide a maskfile, one will be auto-generated and used.
# You can specify a mask file as below:
# maskFile = '/common/projects/Shadab/fetal/Brain/0633s1/volumes/mask_vol_0000_crop_iso.nii'
maskFile=''
resolution = sys.argv[3] # Set to '' if you want default (0.75) or set to a number like 1, 2 etc
print("RESOLUTON=", resolution)
print("RESOLUTION TYPE = ", type(resolution))

if '-1' in resolution:
	resolution = ''
else:
	resolution = float(resolution)

iterations = 0 # Default is 4
debug = False
debug_GPU = True
intensity_matching = False # If you turn it on, the intensity values in the output will not be in similar range as the input
disableBiasCorrection = False
useAllIdentityTrForReg = False
b0switch = True
b1switch = False # OVERRIDES B0 switch
PSFswitch = True # If T, set 3 args below. If F, below 3 will be ignored
psfX = '/home/ch191070/scripts/fetalDTI/PSFprofiles/sinc_xy_TruncSinc.txt'
psfY = '/home/ch191070/scripts/fetalDTI/PSFprofiles/sinc_xy_TruncSinc.txt'
psfZ = '/home/ch191070/scripts/fetalDTI/PSFprofiles/sinc_xy_TruncSinc.txt'

############################
# ARGUMENT PARSING
############################
b0b1select = sys.argv[1]
if not (b0b1select is 'b0' or 'b1'):
	raise ValueError('1st argument must be either b0 or b1, exiting program')
else:
	b0b1select = int(b0b1select[1])

try:
    refFile   = sys.argv[2]
except IndexError as err:
    print("ERROR: You need to provide a reference volumes as the 2nd argument")

folderPath = os.path.split(refFile)[0]
searchDiffFilesWithPrefix = 'vol_'

if b0b1select:
	tempFolderPrefix = 'tmpB1'
else:
	tempFolderPrefix = 'tmpB0'

############################
# PROCESSING
############################
# (1) Get a list of files to be used for B0 reconstruction:
dirs = [str(x) for x in Path(folderPath).iterdir() if x.is_dir() and not os.path.split(str(x))[1].startswith('tmp')]
dwiFiles = []
for dirToProcess in dirs:	 # Create a list of B0 files
	bvals = getBvals(dirToProcess + '/' + 'bvals') # Get a list of bvals
	tmpFiles = listFilesInDir( dirToProcess + '/' + searchDiffFilesWithPrefix +'*' ) # Get a list of files
	print("tmpFiles = \n")
	print(tmpFiles)

	if b0b1select: # IF true, b1 has been selected
		dwiFiles = dwiFiles + [tmpFiles[x] for x in range(len(tmpFiles)) if int(bvals[x])>10]
	else:
		dwiFiles = dwiFiles + [tmpFiles[x] for x in range(len(tmpFiles)) if int(bvals[x])<10]

	# if b1switch: # IF true, b1 has been selected
	# 	dwiFiles = dwiFiles + [tmpFiles[x] for x in range(len(tmpFiles)) if int(bvals[x])>10]
	# elif b0switch:
	# 	dwiFiles = dwiFiles + [tmpFiles[x] for x in range(len(tmpFiles)) if int(bvals[x])<10]
	# else:
	# 	dwiFiles = dwiFiles + [tmpFiles[x] for x in range(len(tmpFiles)) ]# if int(bvals[x])<10] # Keep ones with bvals<10 for B0

# for i in dwiFiles:
# 	print(i)

# (3) Create a folder for temporary recon files
if not os.path.exists( folderPath + '/' + tempFolderPrefix ):
	os.mkdir( folderPath+'/' + tempFolderPrefix )

os.chdir( folderPath+'/' + tempFolderPrefix )

# CHECK IF YOU HAVE ONLY ONE FILE
if len(dwiFiles)==1:
	# Create a copy of the file in tmpB0 folder
	voxSize = nib.load(dwiFiles[0]).header.get_zooms()
	maxSpacing, maxSpacingIdx = findMaxVoxelSpacingWithIndex(voxSize[:3])
	secVol = folderPath+'/' + tempFolderPrefix + '/'+'resampled_'+os.path.split(dwiFiles[0])[1]
	resampledVoxSize = list(voxSize[:3])
	resampledVoxSize[maxSpacingIdx] = maxSpacing - 0.25
	sp.call(( 'crlResampleToIsotropic', dwiFiles[0], 'linear', secVol, '-x', str(resampledVoxSize[0]), '-y', str(resampledVoxSize[1]), '-z', str(resampledVoxSize[2]) ))
	dwiFiles = dwiFiles + [secVol]
	#binary1 = '/home/ch191070/code/MyCodes/CreateOutputGeometryFileForResampler/Build/CreateOutputGeometryFileForResampler'
	#sp.call(( binary1, dwiFiles[0], 'resampledGeometryFile.nii.gz' ))
	#sp.call(( 'crlResampler', dwiFiles[0], '/home/ch191070/code/MyCodes/identity.tfm', 'resampledGeometryFile.nii.gz', 'linear', secVol ))

# (4) Create data structure to input into recon program, and run recon program 
# ~/library/fetalReconstruction-master/source/DO_NOT_DELETE_bin/SVRreconstructionGPU -o recon.nii -i fetus*.nii -m  mask*.nii --referenceVolume $1
args =  [executable, '-o', outputFileName]
args = args + ['--referenceVolume', refFile]

# Don't use the method below to also feed the refFile as an input to the reconstruction algorithm.
# What ends up happening is that refFile when registered to refFile (as a reference) will end up
# leading to an identity transform or something similar. Therefore voxels of refFile (the input) will be very
# close to the grid points of refFile the reference volume; refFile the reference volume provides the 
# spatial grid where we compute the final voxel therefore refFile itself ends up having the highest priority
# which result in B1 looking a lot like B0.

# args = args + ['-i'] + [refFile] + dwiFiles 

args = args + ['-i'] + dwiFiles
if resolution != '':
	args = args + ['--resolution='+str(resolution)]
if debug:
	args = args + ['--debug=1']
if debug_GPU:
	args = args + ['--debug_gpu']
if disableBiasCorrection:
	args = args + ['--disableBiasCorrection']
if not intensity_matching:
	args = args + ['--no_intensity_matching=false']
if iterations > 0:
	args = args + ['--iterations='+str(iterations)]
if useAllIdentityTrForReg:
	args = args + ['--useAllIdentityTrForReg']
if PSFswitch:
	args = args + ['--PSFswitch', '--psfX', psfX, '--psfY', psfY, '--psfZ', psfZ]
if maskFile == '':
	maskFile = 'mask_' + os.path.split(refFile)[1]
	# crlBinaryThreshold ../Brain/0633s1/volumes/cropped-vol_0000.nii.gz ../Brain/0633s1/volumes/temp.nii -2 -1 0 1
	maskArgs = ['crlBinaryThreshold', refFile, maskFile, '-2', '-1', '0', '1' ]
	bashExec(maskArgs)
args = args + ['-m',  folderPath + '/' + tempFolderPrefix + '/' + os.path.split(maskFile)[1]]

argStr = bashExec(args)
#argStr = bashExec(args)

print("ARGSTR:\n"+argStr)
