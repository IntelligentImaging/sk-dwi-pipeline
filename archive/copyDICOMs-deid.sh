if [ $# -ne 2 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [Raw Case Dir] [Diff Proc Case Dir]"
    echo "Copies DICOM series from the raw dir to a diffusion case dir"
    echo "Also anonymizes"
	exit
	fi

RAW=$1
PROC=$2
dicomdir=`find ${RAW} -type d -name DICOM`
if [[ -d ${dicomdir} ]] ; then
    ID=`basename $PROC`
    acqs=( $(find ${dicomdir} -type d -iname \*BRAIN\*DTI\*Slices -o -iname \*BRAIN\*DTI\*500 -o -iname \*BRAIN\*DTI\*ORIG -o -iname \*DTI\*Fetal\*Slices -o -iname \*MultiB\*directions -o -iname \*BRAIN\*DTI\*Slices_3mm) )
    installdir="${PROC}/DICOM/"

    echo "${#acqs[@]} series matched:"
    echo "${acqs[@]}"
    for series in ${acqs[@]} ; do
        sh /home/ch162835/scripts/deidentify4-cva.sh ${series} ${installdir} ${ID}
    done
else
    echo "No DICOM folder found in ${RAW}"
fi
