#!/usr/bin/env bash
set -euo pipefail

MOSES_SCRIPTS="$PWD/../tools/moses-scripts/scripts"

SRC="en"
TRG="de"

cd data
if [ -e corpus.clean.$SRC ] && [ -e  corpus.clean.$TRG ]; then
  echo "No action needed"
  exit 0
fi


for lang in $SRC $TRG; do
  # Remove non-printing characters
  cat corpus.$lang \
    | perl $MOSES_SCRIPTS/tokenizer/remove-non-printing-char.perl \
    > .corpus.norm.$lang
    # | perl $MOSES_SCRIPTS/tokenizer/normalize-punctuation.perl -l $lang \  # could optionally norm quotes
done

# Contrain length between 1 100
perl $MOSES_SCRIPTS/training/clean-corpus-n.perl .corpus.norm $SRC $TRG .corpus.trim 1 100

# Deduplicate
paste <(cat .corpus.trim.$SRC) <(cat .corpus.trim.$TRG) \
  | LC_ALL=C sort -S 50% | uniq \
  > .corpus.uniq.$SRC$TRG.tsv

cat .corpus.uniq.$SRC$TRG.tsv | cut -f 1 > corpus.clean.$SRC
cat .corpus.uniq.$SRC$TRG.tsv | cut -f 2 > corpus.clean.$TRG

# Clean up
rm .corpus.*
