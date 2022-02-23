#!/bin/bash

# This file transformer a simple vocabulary file, where each line has a token into a factored vocabulary

# exit when any command fails
set -e


# parse options
while getopts ":i:o:p:" opt; do
  case $opt in
    i)
        regular_vocab="$OPTARG"
        ;;
    o)
        factored_vocab="$OPTARG"
        ;;
    p)
        factor_prefix="$OPTARG"
        ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done


# Validate options
test -z $regular_vocab && { echo "Missing Argument: regular_vocab (option -i) not set"; exit 1; }
test -z $factored_vocab && { echo "Missing Argument: factored_vocab (option -o) not set"; exit 1; }
test -z $factor_prefix  && { echo "Factor prefix not specified (option -p). Prefix 'p' will be used"; }

factor_prefix=${factor_prefix:-"p"}

test -e $regular_vocab || { echo "Error: $regular_vocab file not found."; exit 1; }

# Create vocab
echo '_lemma' > $factored_vocab
echo "_${factor_prefix}
${factor_prefix}0 : _${factor_prefix}
${factor_prefix}1 : _${factor_prefix}
${factor_prefix}2 : _${factor_prefix}" >> $factored_vocab

factor_list="_has_${factor_prefix}"

echo '</s> : _lemma
<unk> : _lemma' >> $factored_vocab

cat $regular_vocab | grep -v '<\/s>\|<unk>' | sed 's/$/ : _lemma '"$factor_list"'/' >> $factored_vocab

# Exit success
exit 0
