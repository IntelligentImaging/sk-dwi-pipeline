for f in vol_00??.nii.gz ;do echo $f ; mask=`echo $f | sed 's,.nii.gz,_mask.nii.gz,g'` ; crlN4biasfieldcorrection $f b$f $mask ; done
