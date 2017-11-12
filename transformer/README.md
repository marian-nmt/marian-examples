# Example for training transformer model

Files and scripts in this folder shows how to run transformer model ([Vaswani
et al, 2017](https://arxiv.org/abs/1706.03762)) on WMT-17 English-German data.
The problem-set is adapted from
[tensor2tensor](https://github.com/tensorflow/tensor2tensor) repository from
Google, i.e. 36,000 common BPE subwords for both languages.
No back-translations are used.


Assuming, you have four GPUs available (here 0 1 2 3), type the command below
to execute the complete example:

```
./run-me.sh 0 1 2 3
```

It executes a training run with `marian` using the following command:

```
..//build/marian \
    --model model/model.npz --type transformer \
    --train-sets data/corpus.bpe.en data/corpus.bpe.de \
    --max-length 100 \
    --vocabs model/vocab.ende.yml model/vocab.ende.yml \
    --mini-batch-fit -w 7000 --maxi-batch 1000 \
    --early-stopping 10 \
    --valid-freq 5000 --save-freq 5000 --disp-freq 500 \
    --valid-metrics cross-entropy perplexity translation \
    --valid-sets data/valid.bpe.en data/valid.bpe.de \
    --valid-script-path ./scripts/validate.sh \
    --valid-translation-output data/valid.bpe.en.output --quiet-translation \
    --valid-mini-batch 64 \
    --beam-size 6 --normalize 0.6 \
    --log model/train.log --valid-log model/valid.log \
    --enc-depth 6 --dec-depth 6 \
    --transformer-heads 8 \
    --transformer-postprocess-emb d \
    --transformer-postprocess dan \
    --transformer-dropout 0.1 --label-smoothing 0.1 \
    --learn-rate 0.0003 --lr-warmup 16000 --lr-decay-inv-sqrt 16000 --lr-report \
    --optimizer-params 0.9 0.98 1e-09 --clip-norm 5 \
    --tied-embeddings-all \
    --devices $GPUS --sync-sgd --seed 1111
```

This reproduces a system roughly equivalent to the basic 6-layer transformer
described in the original paper.

The training setting includes:
* Fitting mini-batch sizes to 7GB of GPU memory, which results in large mini-batches
* Validation on external data set using cross-entropy, perplexity and BLEU
* 6-layer encoder and 6-layer decoder
* Tied embeddings
* Label smoothing
* Learning rate warmup
* Multi-GPU training with synchronous SGD


The evaluation is performed on WMT test sets from 2014, 2015 and 2016 using
[sacreBLEU](https://github.com/mjpost/sacreBLEU), which provides hassle-free
computation of shareable, comparable, and reproducible BLEU scores.  The
WMT-213 test set is used as the validation set.

See the basic training example (`marian/examples/training-basics/`) for more
details.
