# b0b1ReconLib.py
import sys
from pathlib import Path
import os
import subprocess as sp


def _resolveDotAndDoubleDot(folderPath):
	if folderPath == '.':
		return os.getcwd()

	if folderPath == '..':
		if os.getcwd() == '/':
			raise ValueError('You are in the base directory, there is no where to navigate using "cd.."')
		else:
			return os.path.split( os.getcwd() )[0]

def resolveDirName(dirPath):
	if dirPath == '.' or dirPath == '..':
		return _resolveDotAndDoubleDot( dirPath )
	else:
		return dirPath

def getBvals(bvalsTxt):
	with open(bvalsTxt) as wtFile:
		return wtFile.read().split()

def listFilesInDir(searchString=''):
	p = sp.Popen('ls '+searchString, stdout=sp.PIPE, shell=True)
	(out, err) = p.communicate()
	out = out.decode('utf-8')
	out = out.split('\n')
	out = [x for x in out if os.path.isfile(x)]
	return out

def bashExec(args):
  argStr = ''
  for elem in args:
	  argStr = argStr+elem+' '
  p = sp.Popen(argStr, shell=True)
  p.communicate()
  return argStr

def findMaxVoxelSpacingWithIndex(listItem):
	maxVal = -1
	index = -1
	for i,value in enumerate(listItem):
	    if value>maxVal:
	        maxVal=value
	        index=i
	return maxVal, index

def fileSizeInKB(fileLoc):
	return os.stat(fileLoc).st_size/1024.0

def execSPcall(execString):
	p = sp.Popen(execString, stdout=sp.PIPE, stderr=sp.PIPE, shell=True)
	output, error = p.communicate()
	if p.returncode != 0: 
		print("FAILED %d %s %s" % (p.returncode, output, error))
		sys.exit()
	else:
		pass#print(output.decode('utf-8'))