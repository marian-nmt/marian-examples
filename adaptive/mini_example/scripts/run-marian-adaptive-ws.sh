#!/bin/bash

MODEL_CONFIG=$1
PORT=$2
DL_UPDATES=$3
DL_EPOCHS=$4
DL_BATCH=$5
DL_LR=$6

MARIAN=/path/to/marian

python prune_model_config_for_marian_adaptive.py $MODEL

$MARIAN/marian-adaptive --port $PORT -c  $MODEL_CONFIG.da.yml  --after-batches $DL_UPDATES --after-epochs $DL_EPOCHS --learn-rate $DL_LR --mini-batch $DL_BATCH 

