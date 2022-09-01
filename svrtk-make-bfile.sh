#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [bvec] [bval]
    Incorrect input supplied
    This script takes separate bvec and bval files written in rows and transposes
    and combines them into one file.
    For bvecs we'll go from:
        x1 x2 x3 x4 x5 ...
        y1 y2 y3 y4 y5 ...
        z1 z2 z3 z4 z5 ...
    to:
        x1 y1 z1
        x2 y2 z2
        x3 y3 z3
        x4 y4 z4
        x5 y5 z5
    ...PLUS the bvalue at the end of each line, so:
        x1 y2 z1 bval1
        x2 y2 z3 bval2
        ... etc     
EOF
}

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

if [[ $# -ne 2 || ! -f $1 || ! -f $2 ]]; then
    die
    exit
fi 

function transpose {
awk '
{ 
    for (i=1; i<=NF; i++)  {
        a[NR,i] = $i
    }
}
NF>p { p = NF }
END {    
    for(j=1; j<=p; j++) {
        str=a[1,j]
        for(i=2; i<=NR; i++){
            str=str" "a[i,j];
        }
        print str
    }
}' $1 
}

bvec=$1
bval=$2
base=`basename $bvec .bvec`
tbvec=${base}.tbvec
tbval=${base}.tbval
output=${base}.b

transpose $1 > ${tbvec}
transpose $2 > ${tbval}

unset vec val
declare -a vec
declare -a val
let x=0 ; let y=0
while read line ; do vec[$x]=$line ; ((x++)) ;done < $tbvec
while read line ; do val[$y]=$line ; ((y++)) ;done < $tbval
rm $output
let z=0 ; while [[ $z -lt $x ]] ; do echo "${vec[$z]} ${val[$z]}" >> $output ; ((z++)) ; done
