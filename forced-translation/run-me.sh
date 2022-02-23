#!/bin/bash

# exit when any command fails
set -e


# load variables
REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $REPO_ROOT/.env


# check the existance of marian
if [ ! -e $MARIAN/marian ] || [ ! -e $MARIAN/marian-vocab ]; then
    echo "marian executable not found. You may have to setup the MARIAN variable with the path to the marian executable in the .env file"
    echo "Exiting..."
    exit 1
fi


# check the existance of input the files in the correct format
for prefix in $TRAIN_PREFIX $VALID_PREFIX $TEST_PREFIX; do
    for lang in $SRC_LANG $TGT_LANG; do
        test -e $DATA/$prefix.$lang || { echo "Error: File $DATA/$prefix.$lang file not found. Check your .env file. The file path must be \$DATA/\$PREFIX.\$LANG"; exit 1; }
    done
done


#########################
## end-to-end pipeline ##
#########################


# Preprocess training data
echo "Preprocessing train data..."
$SCRIPTS/preprocess_train.sh


# Preprocess valid data
echo "Preprocessing valid data..."
$SCRIPTS/preprocess_test.sh -p $VALID_PREFIX


# Train Model
echo "Training started..."
mkdir -p $MODEL_DIR
$MARIAN/marian -m $MODEL_DIR/model.npz \
                -t $DATA/$TRAIN_PREFIX.tok.fact.tc.bpe.$SRC_LANG $DATA/$TRAIN_PREFIX.tok.tc.bpe.$TGT_LANG \
                --valid-sets $DATA/$VALID_PREFIX.tok.fact.tc.bpe.$SRC_LANG $DATA/$VALID_PREFIX.tok.tc.bpe.$TGT_LANG \
                -v $DATA/vocab.$SRC_LANG$TGT_LANG.fsv $DATA/vocab.$SRC_LANG$TGT_LANG.yml \
                --type transformer \
                --dec-depth 6 --enc-depth 6 \
                --dim-emb 512 \
                --transformer-dropout 0.1 \
                --transformer-dropout-attention 0.1 \
                --transformer-dropout-ffn 0.1 \
                --transformer-heads 8 \
                --transformer-preprocess "" \
                --transformer-postprocess "dan" \
                --transformer-dim-ffn 2048 \
                --tied-embeddings-all \
                --valid-mini-batch 4 \
                --valid-metrics cross-entropy perplexity \
                --valid-log $MODEL_DIR/valid.log \
                --log $MODEL_DIR/train.log \
                --early-stopping 5 \
                --learn-rate 0.0003 \
                --lr-warmup 16000 \
                --lr-decay-inv-sqrt 16000 \
                --lr-report true \
                --exponential-smoothing 1.0 \
                --label-smoothing 0.1 \
                --optimizer-params 0.9 0.98 1.0e-09 \
                --optimizer-delay 6 \
                --keep-best \
                --overwrite \
                --mini-batch-fit \
                --sync-sgd \
                --devices $GPUS \
                --workspace 9000 \
                --factors-dim-emb 8 \
                --factors-combine concat \
                --disp-freq 100 \
                --save-freq 5000 \
                --valid-freq 5000 \


# Preprocess test data
echo "Preprocessing test data..."
$SCRIPTS/preprocess_test.sh -p $TEST_PREFIX


# Translate test data
echo "Translating test data..."
$MARIAN/marian-decoder -c $MODEL_DIR/model.npz.decoder.yml \
                -i $DATA/$TEST_PREFIX.tok.fact.tc.bpe.$SRC_LANG \
                -o $DATA/$TEST_PREFIX.hyps.$TGT_LANG


# Postprocessing test data
echo "Postprocessing test data..."
$SCRIPTS/postprocess.sh -p $TEST_PREFIX


# Evaluate test data
echo "Evaluating test data..."
$SCRIPTS/evaluate.sh -p $TEST_PREFIX


# exit success
exit 0
