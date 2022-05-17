## This script changes *name* of the transform in a transform file
## Script was used to help with converting a FSL transform to ITK transform
## using Ali's script /common/external/crl-rdynaspro8/ali/DWI/commonfiles/convertFSLtransformToITK.sh
# See /home/ch191070/scripts/fetalDTI/createAtlasSpaceT2andMask.sh for details

import sys
import fileinput

fileToSearch = sys.argv[1]
tfmNameToReplace = 'MatrixOffsetTransformBase_double_3_3'
tfmNameToReplaceWith = 'AffineTransform_double_3_3'

with fileinput.FileInput(fileToSearch, inplace=True, backup='.bak') as file:
	for line in file:
		print( line.replace(tfmNameToReplace, tfmNameToReplaceWith), end='' )