#!/bin/bash

if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [raw subj dir]  [proc subj dwi dir]"
	exit
fi

input="${1}"
out="${2}/DICOM"

echo "Copy DWI's for $input"
# Put search terms in the find command below
find ${input} -type d -iname \*12dir -exec cp {} -rv ${out}/ \;
echo
