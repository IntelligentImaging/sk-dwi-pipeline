#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [case folder]
    Incorrect input supplied
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi 
ID=$1

echo "Setting up pipeline dirs: ${ID}"
mkdir -p ${ID}/DICOM ${ID}/b0b1 ${ID}/dti ${ID}/t2 ${ID}/volumes ${ID}/removed
