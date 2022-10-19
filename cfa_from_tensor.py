#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Oct 18 18:29:10 2022

@author: ch209389, edits by ch162835
"""
import numpy as np
import os
from os import listdir
from os.path import isfile, join
import sys
import nibabel as nib

'''
Converts tensor image to color-FA image.

Usage:
python [tensor] [output CFA] 

It creates color-FA image for every tensor image in dir. Saves them in dir, 
appending "CFA" to each tensor image filename.
'''

assert len(sys.argv)!=1, 'Usage: python script.py [tensor] [output CFA]'
IMAGE = sys.argv[1]
OUTPUT = sys.argv[2]

def from_lower_triangular(D):
    tensor_indices = np.array([[0, 1, 3],
                               [1, 2, 4],
                               [3, 4, 5]])
    return D[..., tensor_indices]

def cfa_from_tensor(my_tensor):
    try:
        eigenvals, eigenvecs = np.linalg.eigh(my_tensor)
        order = eigenvals.argsort()[::-1]
        eigenvecs = eigenvecs[:, order]
        eigenvals = eigenvals[order]
        
        ev1, ev2, ev3 = eigenvals
        all_zero = (eigenvals == 0).all(axis=0)
        fa = np.sqrt(0.5 * ((ev1 - ev2) ** 2 +
                            (ev2 - ev3) ** 2 +
                            (ev3 - ev1) ** 2) /
                     ((eigenvals * eigenvals).sum(0) + all_zero))
        
        cfa= np.abs( eigenvecs[:,0]*fa )
                
    except:
        fa= 0
        cfa= [0,0,0]
        
    return fa, cfa

tensor = nib.load( IMAGE )
tensor_affine= tensor.affine
tensor = np.squeeze( tensor.get_fdata() )
wlls_tensor= from_lower_triangular(tensor)
sx, sy, sz= wlls_tensor.shape[:3]
cfa= np.zeros((sx,sy,sz,3))

for ix in range(sx):
    for iy in range(sy):
        for iz in range(sz):
            
            if wlls_tensor[ix,iy,iz,0,0]:
                
                _, cfa[ix,iy,iz,:] = cfa_from_tensor(wlls_tensor[ix,iy,iz,:,:])


cfa = nib.Nifti1Image(cfa, tensor_affine)
nib.save(cfa, OUTPUT)



