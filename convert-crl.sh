#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input dicom dir] [case dir]
    Incorrect input supplied

        Uses Simon's CRL-dicom-tools docker to convert images
        Container utilizes dcmdjpeg for decompression, pydicom for naming, dcm2niix for conversion
        Apptainer sif built from git lab CRL docker
        Note: Both input and output directories may need to be subdirectories of the PWD due to container scripts
EOF
}

if [ $# -ne 2 ]; then
    show_help
    exit
fi

if [[ ! -d $1 ]] ; then show_help ; exit ; fi

SHDIR=`dirname $0`
casedir=$2
odir=${casedir}/crl-convert
mkdir -pv ${odir}

singularity exec ~/sifs/dicom-tools /bin/bash -c "python3 /usr/local/bin/uncompress_dicoms.py ${1} ${odir}/dicomdir-uncompressed"

singularity exec ~/sifs/dicom-tools /bin/bash -c "python3 /usr/local/bin/sort_dicoms.py ${odir}/dicomdir-uncompressed ${odir}/dicomdir-sorted"

singularity exec ~/sifs/dicom-tools /bin/bash -c "python3 ${SHDIR}/dicom_tree_to_nifti.py  ${odir}/dicomdir-sorted  ${odir}/dicomdir-converted"

# copy to nrrd directory for pipeline
dtis=`find ${odir}/dicomdir-converted -type d -iname \*brain-dti\*`
mkdir ${casedir}/nrrd
for dti in $dtis ; do
	dir=`dirname $dti`
	ser=`basename $dir`
	cp ${dti} -r nrrd/run_${ser}
done

