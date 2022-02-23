#!/bin/bash

# exit when any command fails
set -d

FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT=$FILE_DIR/..
TOOLS=$REPO_ROOT/tools

FAST_ALIGN=${FAST_ALIGN:-$TOOLS/fast_align/build}


# check the existance of fast_align
if [ ! -e $FAST_ALIGN/fast_align ] ; then
    echo "fast_align executable not found. You may have to setup the FAST_ALIGN variable with the path to fast_align"
    echo "Exiting..."
    exit 1
fi

if [ ! -e $FAST_ALIGN/atools ] ; then
    echo "atools executable not found. You may have to setup the FAST_ALIGN variable with the path to fast_align"
    echo "Exiting..."
    exit 1
fi


# parse options
while getopts ":s:t:" opt; do
  case $opt in
    s)
        source_file="$OPTARG"
        ;;
    t)
        target_file="$OPTARG"
        ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done


# check if files exist
test -z $source_file && { echo "Missing Argument: source file not set"; exit 1; }
test -z $target_file && { echo "Missing Argument: target file not set"; exit 1; }

test -e $source_file || { echo "Error: $source_file file not found."; exit 1; }
test -e $target_file || { echo "Error: $target_file file not found."; exit 1; }


# the alignments will be store in the same directory as the source_file
data_dir="$(cd "$(dirname "$source_file")"; pwd )"

alignment_forward=$data_dir/alignment_forward
alignment_reverse=$data_dir/alignment_reverse
alignment=$data_dir/alignment


# align
paste $source_file $target_file | sed 's/\t/ ||| /g' > $data_dir/corpus.tmp
$FAST_ALIGN/fast_align -ovd -i $data_dir/corpus.tmp  > $alignment_forward
rm $data_dir/corpus.tmp

# align reverse
paste $source_file $target_file | sed 's/\t/ ||| /g' > $data_dir/corpus.tmp
$FAST_ALIGN/fast_align -ovd -r -i $data_dir/corpus.tmp > $alignment_reverse
rm $data_dir/corpus.tmp

# symmetrize
$FAST_ALIGN/atools -i $alignment_forward -j $alignment_reverse -c "grow-diag"  > $alignment
rm $alignment_forward $alignment_reverse

# Exit success
exit 0
