#!/bin/bash

# exit if something wrong happens
set -e

# source env variables
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/../.env


# parse options
while getopts ":p:" opt; do
  case $opt in
    p)
        prefix="$OPTARG"
        ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

# Validates files passed as argument
test -z $prefix && { echo "Missing Argument: file prefix needed (option -p)"; exit 1; }

test -e $DATA/$prefix.$SRC_LANG || { echo "Error: $DATA/$prefix.$SRC_LANG file not found."; exit 1; }
test -e $DATA/$prefix.$TGT_LANG || { echo "Error: $DATA/$prefix.$TGT_LANG file not found."; exit 1; }

# Tokenize
echo "Tokenizing..."
cat $DATA/$prefix.$SRC_LANG | $MOSES/scripts/tokenizer/tokenizer.perl -a -l $SRC_LANG > $DATA/$prefix.tok.$SRC_LANG
cat $DATA/$prefix.$TGT_LANG | $MOSES/scripts/tokenizer/tokenizer.perl -a -l $TGT_LANG > $DATA/$prefix.tok.$TGT_LANG


# Tokenize Glossary
echo "Tokenizing Glossary..."
cat $DATA/glossary.$SRC_LANG$TGT_LANG.tsv | cut -f1 > $DATA/glossary.$SRC_LANG.tmp
cat $DATA/glossary.$SRC_LANG$TGT_LANG.tsv | cut -f2 > $DATA/glossary.$TGT_LANG.tmp
cat $DATA/glossary.$SRC_LANG.tmp | $MOSES/scripts/tokenizer/tokenizer.perl -a -l $SRC_LANG > $DATA/glossary.tok.$SRC_LANG.tmp
cat $DATA/glossary.$TGT_LANG.tmp | $MOSES/scripts/tokenizer/tokenizer.perl -a -l $TGT_LANG > $DATA/glossary.tok.$TGT_LANG.tmp
paste $DATA/glossary.tok.$SRC_LANG.tmp $DATA/glossary.tok.$TGT_LANG.tmp > $DATA/glossary.$SRC_LANG$TGT_LANG.tok.tsv
rm $DATA/glossary.*.tmp


# Escape special carachters so that we can use factors in marian
echo "Escaping special carachters..."
sed -i $DATA/$prefix.tok.$SRC_LANG -e 's/#/\&htg;/g' -e 's/:/\&cln;/g' -e 's/_/\&usc;/g' -e 's/|/\&ppe;/g' -e 's/\\/\&esc;/g'
sed -i $DATA/$prefix.tok.$TGT_LANG -e 's/#/\&htg;/g' -e 's/:/\&cln;/g' -e 's/_/\&usc;/g' -e 's/|/\&ppe;/g' -e 's/\\/\&esc;/g'


# Add target annotations to source and apply factors
echo "Adding target annotations..."
python $SCRIPTS/add_glossary_annotations.py --source_file $DATA/$prefix.tok.$SRC_LANG \
                                                --target_file $DATA/$prefix.tok.$TGT_LANG \
                                                -o $DATA/$prefix.tok.fact.$SRC_LANG \
                                                -g $DATA/glossary.$SRC_LANG$TGT_LANG.tok.tsv \
                                                --test


# We remove the factors from the annotated data to apply truecase and BPE, and later we extend the factors to the subworded text
cat $DATA/$prefix.tok.fact.$SRC_LANG | sed "s/|${FACTOR_PREFIX}[0-2]//g" > $DATA/$prefix.tok.nofact.$SRC_LANG


# Apply truecase
echo "Applying truecase..."
$MOSES/scripts/recaser/truecase.perl -model $DATA/models/tc.$SRC_LANG < $DATA/$prefix.tok.nofact.$SRC_LANG > $DATA/$prefix.tok.nofact.tc.$SRC_LANG
$MOSES/scripts/recaser/truecase.perl -model $DATA/models/tc.$TGT_LANG < $DATA/$prefix.tok.$TGT_LANG > $DATA/$prefix.tok.tc.$TGT_LANG


# Apply BPE
echo "Applying BPE..."
subword-nmt apply-bpe -c $DATA/models/$SRC_LANG$TGT_LANG.bpe --vocabulary $DATA/models/vocab.bpe.$SRC_LANG --vocabulary-threshold 50 < $DATA/$prefix.tok.nofact.tc.$SRC_LANG > $DATA/$prefix.tok.nofact.tc.bpe.$SRC_LANG
subword-nmt apply-bpe -c $DATA/models/$SRC_LANG$TGT_LANG.bpe --vocabulary $DATA/models/vocab.bpe.$TGT_LANG --vocabulary-threshold 50 < $DATA/$prefix.tok.tc.$TGT_LANG > $DATA/$prefix.tok.tc.bpe.$TGT_LANG


# Extend BPE splits to factored corpus
echo "Applying BPE to factored corpus..."
python scripts/transfer_factors_to_bpe.py --factored_corpus $DATA/$prefix.tok.fact.$SRC_LANG --bpe_corpus $DATA/$prefix.tok.nofact.tc.bpe.$SRC_LANG -o $DATA/$prefix.tok.fact.tc.bpe.$SRC_LANG

# Exit success
exit 0
