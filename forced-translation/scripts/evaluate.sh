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


# Evaluation steps (Lemmatized Glossary Accuracy and BLEU)
python $SCRIPTS/eval_lemmatized_glossary.py -s $DATA/$TEST_PREFIX.tok.fact.$SRC_LANG -tl $TGT_LANG -hyps $DATA/$TEST_PREFIX.hyps.debpe.$TGT_LANG > $DATA/lemmatized_gloss_acc_score
cat $DATA/$TEST_PREFIX.hyps.debpe.detok.$TGT_LANG | sacrebleu $DATA/$TEST_PREFIX.$TGT_LANG > $DATA/bleu_score

cat $DATA/lemmatized_gloss_acc_score
cat $DATA/bleu_score

# Exit success
exit 0
