import os
import subprocess as sp
from pathlib import Path
import sys

dirToProc = sys.argv[1]
DICOMdir  = dirToProc +'/DICOM'
nrrdDir   = dirToProc +'/nrrd'
volsDir   = dirToProc + '/volumes'
folders   = [str(x) for x in Path(DICOMdir).iterdir() if x.is_dir()]

DICOMconverterExec = '/home/ch137122/bin/crlDICOMConverter'
# getSliceTimingSH = '/home/ch191070/scripts/fetalDTI/getSliceTimingv2.sh'
getSliceTimingSH = os.environ["FETALDTI"] + '/getSliceTimingv2.sh'
for folder in folders:
	os.chdir(folder)
	files = [str(x) for x in Path(folder).iterdir() if x.is_file()]
	sp.call(( DICOMconverterExec, '-d', folder, '-p', 'vol', '--createfolderperseries' ))
	sp.call(( 'sh', getSliceTimingSH, files[0]))
	newFolder = [str(x) for x in Path(folder).iterdir() if x.is_dir()]
	sp.call(( 'mv', folder+'/sliceTiming.txt', newFolder[0] ))
	sp.call(( 'mv', newFolder[0], nrrdDir ))


folders   = [str(x) for x in Path(nrrdDir).iterdir() if x.is_dir()]
for folder in folders:
	os.chdir(folder)
	dirName = os.path.split(folder)[1]
	sp.call(( 'mkdir', volsDir+'/'+dirName ))

	nhdrFile = [str(x) for x in Path('.').iterdir() if x.is_file() and str(x).endswith('.nhdr')]
	sp.call(( 'crlDWIConvertNHDRForFSL', '--data', 'vol_4D.nii.gz', '--bvals', 'bvals', '--bvecs', 'bvecs', '-i', nhdrFile[0] ))
	sp.call(( 'fslsplit', 'vol_4D.nii.gz', 'vol_', '-t' ))
	sp.call(( 'rm', 'vol_4D.nii.gz' ))

	filesToMove = [str(x) for x in Path('.').iterdir() if x.is_file() and str(x).startswith('vol') and str(x).endswith('.nii.gz')]
	filesToMove = filesToMove + ['sliceTiming.txt', 'bvals', 'bvecs']

	for fileTmp in filesToMove:
		sp.call(( 'mv', fileTmp, volsDir+'/'+dirName))
