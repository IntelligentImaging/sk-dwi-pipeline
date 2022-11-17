
show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input tensor] [tensor mask] [output CFA]
    Incorrect input supplied
EOF
}

if [ $# -ne 3 ]; then
    show_help
    exit
fi 

tensor=$1
mask=$2
CFA=$3

dir=`dirname $tensor`
base=`basename $tensor`
mten=${dir}/m-${base}

crlMaskImage2 -i $tensor -m $mask -o $CFA
python $FETALDTI/cfa_from_tensor.py $mten $CFA
