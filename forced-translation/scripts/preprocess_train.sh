#!/bin/bash

# exit if something wrong happens
set -e


# source env variables
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/../.env


# Tokenize
echo "Tokenizing..."
cat $DATA/$TRAIN_PREFIX.$SRC_LANG | $MOSES/scripts/tokenizer/tokenizer.perl -a -l $SRC_LANG > $DATA/$TRAIN_PREFIX.tok.$SRC_LANG
cat $DATA/$TRAIN_PREFIX.$TGT_LANG | $MOSES/scripts/tokenizer/tokenizer.perl -a -l $TGT_LANG > $DATA/$TRAIN_PREFIX.tok.$TGT_LANG


# Escape special carachters so that we can use factors in marian
echo "Escaping special carachters..."
sed -i $DATA/$TRAIN_PREFIX.tok.$SRC_LANG -e 's/#/\&htg;/g' -e 's/:/\&cln;/g' -e 's/_/\&usc;/g' -e 's/|/\&ppe;/g' -e 's/\\/\&esc;/g'
sed -i $DATA/$TRAIN_PREFIX.tok.$TGT_LANG -e 's/#/\&htg;/g' -e 's/:/\&cln;/g' -e 's/_/\&usc;/g' -e 's/|/\&ppe;/g' -e 's/\\/\&esc;/g'


# Lemmatize target
echo "Lemmatizing target..."
python $SCRIPTS/lemmatize.py  -i $DATA/$TRAIN_PREFIX.tok.$TGT_LANG -o $DATA/$TRAIN_PREFIX.tok.lemmas.$TGT_LANG -l $TGT_LANG


# Align source with target lemmas
echo "Aligning..."
FAST_ALIGN=$FAST_ALIGN $SCRIPTS/align.sh -s $DATA/$TRAIN_PREFIX.tok.$SRC_LANG -t $DATA/$TRAIN_PREFIX.tok.lemmas.$TGT_LANG


# Add target annotations to source and apply factors
echo "Adding target annotations..."
python $SCRIPTS/add_target_lemma_annotations.py --source_file $DATA/$TRAIN_PREFIX.tok.$SRC_LANG --target_file $DATA/$TRAIN_PREFIX.tok.lemmas.$TGT_LANG --alignments_file $DATA/alignment -sl $SRC_LANG -o $DATA/$TRAIN_PREFIX.tok.fact.$SRC_LANG


# We remove the factors from the annotated data to apply truecase and BPE, and later we extend the factors to the subworded text
cat $DATA/$TRAIN_PREFIX.tok.fact.$SRC_LANG | sed "s/|${FACTOR_PREFIX}[0-2]//g" > $DATA/$TRAIN_PREFIX.tok.nofact.$SRC_LANG


# Train truecase
echo "Training truecase..."
mkdir -p $DATA/models
$MOSES/scripts/recaser/train-truecaser.perl -corpus $DATA/$TRAIN_PREFIX.tok.nofact.$SRC_LANG -model $DATA/models/tc.$SRC_LANG
$MOSES/scripts/recaser/train-truecaser.perl -corpus $DATA/$TRAIN_PREFIX.tok.$TGT_LANG -model $DATA/models/tc.$TGT_LANG


# Apply truecase
echo "Applying truecase..."
$MOSES/scripts/recaser/truecase.perl -model $DATA/models/tc.$SRC_LANG < $DATA/$TRAIN_PREFIX.tok.nofact.$SRC_LANG > $DATA/$TRAIN_PREFIX.tok.nofact.tc.$SRC_LANG
$MOSES/scripts/recaser/truecase.perl -model $DATA/models/tc.$TGT_LANG < $DATA/$TRAIN_PREFIX.tok.$TGT_LANG > $DATA/$TRAIN_PREFIX.tok.tc.$TGT_LANG


# Train BPE
echo "Training BPE..."
subword-nmt learn-joint-bpe-and-vocab --input $DATA/$TRAIN_PREFIX.tok.nofact.tc.$SRC_LANG $DATA/$TRAIN_PREFIX.tok.tc.$TGT_LANG -s 32000 -o $DATA/models/$SRC_LANG$TGT_LANG.bpe --write-vocabulary $DATA/models/vocab.bpe.$SRC_LANG $DATA/models/vocab.bpe.$TGT_LANG


# Apply BPE
echo "Applying BPE..."
subword-nmt apply-bpe -c $DATA/models/$SRC_LANG$TGT_LANG.bpe --vocabulary $DATA/models/vocab.bpe.$SRC_LANG --vocabulary-threshold 50 < $DATA/$TRAIN_PREFIX.tok.nofact.tc.$SRC_LANG > $DATA/$TRAIN_PREFIX.tok.nofact.tc.bpe.$SRC_LANG
subword-nmt apply-bpe -c $DATA/models/$SRC_LANG$TGT_LANG.bpe --vocabulary $DATA/models/vocab.bpe.$TGT_LANG --vocabulary-threshold 50 < $DATA/$TRAIN_PREFIX.tok.tc.$TGT_LANG > $DATA/$TRAIN_PREFIX.tok.tc.bpe.$TGT_LANG


# Extend BPE splits to factored corpus
echo "Applying BPE to factored corpus..."
python $SCRIPTS/transfer_factors_to_bpe.py --factored_corpus $DATA/$TRAIN_PREFIX.tok.fact.$SRC_LANG --bpe_corpus $DATA/$TRAIN_PREFIX.tok.nofact.tc.bpe.$SRC_LANG -o $DATA/$TRAIN_PREFIX.tok.fact.tc.bpe.$SRC_LANG


# Create regular joint vocab
echo "Creating vocab..."
cat $DATA/$TRAIN_PREFIX.tok.nofact.tc.bpe.$SRC_LANG $DATA/$TRAIN_PREFIX.tok.tc.bpe.$TGT_LANG | $MARIAN/marian-vocab > $DATA/vocab.$SRC_LANG$TGT_LANG.yml


# Create regular vocab
echo "Creating factored vocab..."
cat $DATA/vocab.$SRC_LANG$TGT_LANG.yml | sed 's/\"//g;s/:.*//g' > $DATA/vocab.$SRC_LANG$TGT_LANG.yml.tmp # makes the regular vocab only a token per line
$SCRIPTS/create_factored_vocab.sh -i $DATA/vocab.$SRC_LANG$TGT_LANG.yml.tmp -o $DATA/vocab.$SRC_LANG$TGT_LANG.fsv -p $FACTOR_PREFIX
rm $DATA/vocab.$SRC_LANG$TGT_LANG.yml.tmp

# Exit success
exit 0
