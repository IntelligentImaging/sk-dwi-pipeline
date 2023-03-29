#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-p] || [subj DWI directory] [mask for recon] [atlas transform]
    Incorrect argument supplied

            This script sets up SVRTK recon scripts for our diffusion data. Each plane
            and each bvalue will be processed separately. By default, this script will
            ask you specify the plane for each input DWI and store it in each volume
            folder using a text file named plane.txt, which either reads "ax", "cor",
            or "sag". If this file exists, the script will not ask you again. 

    -p      Force the script to ask for image plane and overwrite existing plane.txt.
EOF
}

die() {
    printf '%s\n' "$1" >&2
    exit 1
}
while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -p|--plane)
            let overplane=1
            ;;
        --) # end of optionals
            shift
            break
            ;;
        -)?*
            printf 'warning: unknown option (ignored: %s\m' "$1" >&2
            ;;
        *) # default case, no optionals
            break
    esac
    shift
done

if [ $# -ne 3 ]; then
    show_help
    exit
fi 

subj=`readlink -f $1`
id=`basename $subj`
mask="$2"
tfm="$3"

if [[ ! -d ${subj}/nhdr ]] ; then
    die 'I dont see an nhdr folder here. Did you supply the base DWI directory? Have you run conver.sh yet?'
fi

svrtk="plane-dsvrtk"
input="${subj}/${svrtk}/input"
mkdir -pv ${input}
svrmask="${svrtk}/mask_svrtk.nii.gz"
cp $mask -v ${subj}/${svrmask}
recon="${svrtk}/recon"
dof="${input}/dwi-atlas_${id}.dof"

# Check for required files
t2_t2="${subj}/t2/t2_t2_${id}.nii.gz"
whichb=`echo $tfm | sed -e 's,.*b\([0-1]\)\-.*,\1,g'`
src="${subj}/b0b1/dwi_b${whichb}_${id}.nii.gz"
atlas_t2="${subj}/t2/atlas_t2final_${id}.nii.gz"
cp $atlas_t2 -vu ${input}/

# Record planes and set input image arrays
for dwi in ${subj}/nhdr/* ; do
    # Record plane, if we need it
    if [[ -d $dwi && ( ! -f ${dwi}/plane.txt || $overplane -eq 1 ) ]] ; then 
        echo "${dwi}: ax, cor, or sag?"
        read plane
        if [[ ! $plane == "ax" && ! $plane == "cor" && ! $plane == "sag" ]] ; then
            echo "that's not ax, cor, or sag"
            exit 1
        else echo "${plane}" > ${dwi}/plane.txt
        fi
    fi
done

echo "Record images for each dir/bval step"
rm -fv ${recon}/{ax,cor,sag}/b*/images.txt

# volumes/ has the 3D split dwi volumes in separate folders for each scan
declare -a dwi_ar
declare -a plane_ar
declare -a grad_ar
let z=0
for dwi in ${subj}/nhdr/* ; do
    if [[ -d $dwi ]] ; then 

        # Convert crl bvecs/bvals to MIRTK format
        bvecs=`find $dwi -maxdepth 1 -name bvecs`
        bvals=`find $dwi -maxdepth 1 -name bvals`
        basegrad=`basename $dwi`
        grad_ar[$z]=${input}/${basegrad}.b        

        # Copy the 4D image to use as the input image
        dwi_ar[$z]=${input}/${basegrad}.nii.gz
        fourD=`find $dwi -name dwi4D.nii.gz`
        cp ${fourD} -v ${dwi_ar[$z]}

        # Grab plane we entered earlier
        plane_ar[$z]=`cat ${dwi}/plane.txt`
        mkdir -pv ${recon}/${plane_ar[$z]}

        # Read the bvals text file for bvalues
        fix=${input}/fix-${basegrad}.bval
        fixnums=""
        declare -a barray
        let x=0 
        for b in `cat ${dwi}/bvals` ; do 
            # This block of code is to check if there are similar bvalues (like 249 and 250). If so, they get combined. If there aren't, they get a new folder
            for any in ${barray[@]} ; do
                DIFF=`echo "$b-$any" | bc`
                    if [[ $DIFF -gt -6 && $DIFF -lt 6 ]] ; then
                        # echo detected similar num
                        let b=$any
                        break
                    #else echo no similar num
                    fi
            done
            barray[$x]=$b
            dest=${recon}/${plane_ar[$z]}/b${b}
            mkdir -pv ${dest}

            ((x++)) # increase index by one

        done
        echo ${barray[@]}
        rm $fix
        echo "${barray[@]}" > $fix

        # Convert from FSL bvals/bvecs to MIRTK format
        echo convert bvals and bvecs to MIRTK format
        sh /home/ch162835/scripts/combineSVRTKb.sh $bvecs $fix ${grad_ar[$z]}

        # Take the existing DWI-to-atlas transform from ITK to DOF 
        echo c3d convert atlas transform from ITK to DOF
        /fileserver/fetal/bin/c3d_affine_tool -ref $t2_t2 -src $src -itk $tfm -oirtk ${dof}

        ((z++))
    fi
done

for svrdir in ${recon}/*/b* ; do
    if [[ -d $svrdir ]] ; then

        svrplane=`echo $svrdir | sed -e 's,\/b.*,,g' -e 's,.*recon\/,,g'`
        svrbval=`echo $svrdir | sed -e 's,.*\/,,g' -e 's,b,,g'`
        run="${svrdir}/run-svrtk.sh"
        rm ${run}
        svr="/home/data/${svrdir}/SVRTK_${svrplane}-b${svrbval}-${id}.nii.gz"

        # SVRTK requires the number of input images for each recon
        nim=`cat ${subj}/nhdr/*/plane.txt | grep $svrplane | wc -w`

        # Write script for recon
        echo "cd /home/data/${svrdir}" >> $run
        echo "mirtk reconstructDWI $svr $nim \\" >> $run

        # Add input images one-by-one
        let ck=0
        while [[ $ck -lt $z ]]; do
            if [[ ${plane_ar[$ck]} == $svrplane ]] ; then
                imbase=`basename ${dwi_ar[$ck]} .nii.gz`
                echo "/home/data/${svrtk}/input/${imbase}.nii.gz \\" >> $run
                echo "${imbase}" 
            fi
            ((ck++))
        done

        # Add input gradients files (.b) one-by-one
        let ck=0
        while [[ $ck -lt $z ]]; do
            if [[ ${plane_ar[$ck]} == $svrplane ]] ; then
                imbase=`basename ${dwi_ar[$ck]} .nii.gz`
                echo "/home/data/${svrtk}/input/${imbase}.b \\" >> $run
            fi
            ((ck++))
        done

        # Add bvalue to reconstruct, target atlas image, and DOF transform
        echo "${svrbval} \\" >> $run
        echo "/home/data/${svrtk}/input/atlas_t2final_${id}.nii.gz \\" >> $run
        echo "/home/data/${svrtk}/input/dwi-atlas_${id}.dof \\" >> $run 
        echo "-mask /home/data/$svrmask \\" >> $run
        # echo "-svr_only \\" >> $run
        echo "-debug" \\ >> $run
        echo "-resolution 0.75 \\" >> $run
        echo "-iterations 3" >> $run
        echo "cd /home/data" >> $run

        echo Wrote run script: $run
        echo
    fi
done

echo "Setting permissions for $svrtk to open for Docker"
chmod -R 777 $svrtk 2> /dev/null
