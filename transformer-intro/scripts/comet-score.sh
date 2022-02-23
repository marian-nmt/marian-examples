#!/usr/bin/env bash
set -euo pipefail

# Compute Comet score
# Perform on CPU to avoid competing for GPU memory

# Usage:
# 1) Score against default validation set
#   ./comet-score hypothesis.txt
# 2) Score against a different source/reference
#   ./comet-score hypothesis.txt source.txt reference.txt

if [[ "$#" -eq 1 ]]; then
  src="data/valid.en"
  ref="data/valid.de"
elif [[ "$#" -eq 3 ]]; then
  src=$2
  ref=$3
else
  echo "Usage: $0 hypothesis.txt [source.txt reference.txt]"
  exit 1
fi

trg=$1

comet-score \
  --gpus 0 \
  -s ${src} \
  -t ${trg} \
  -r ${ref} \
  --model wmt20-comet-da \
  2> ./scripts/.comet.stderr.log \
  | tail -1 \
  | grep -oP "([+-]?\d+.\d+)"
