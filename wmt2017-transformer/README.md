# Beating Edinburgh's WMT2017 system for en-de with Marian's Transformer model

Files and scripts in this folder show how to train a complete better than (!) WMT-grade system
based on Google's Transformer model [Vaswani et al, 2017](https://arxiv.org/abs/1706.03762)
and [Edinburgh's WMT submission description](http://www.aclweb.org/anthology/W17-4739) for en-de.

This example is a combination of [Reproducing Edinburgh's WMT2017 system for en-de with Marian](../wmt2017-uedin/)
and the example for [Transformer training](../transformer)

If you use this, please cite:

Marcin Junczys-Dowmunt , Roman Grundkiewicz, Tomasz Dwojak, Hieu Hoang, Kenneth Heafield, Tom Neckermann, Frank Seide, Ulrich Germann, Alham Fikri Aji, Nikolay Bogoychev, André F. T. Martins, Alexandra Birch (2018). Marian: Fast Neural Machine Translation in C++ (https://arxiv.org/abs/1804.00344)

    @article{junczys2018marian,
      title={Marian: Fast Neural Machine Translation in C++},
      author={Marcin Junczys-Dowmunt and Roman Grundkiewicz and Tomasz Dwojak and Hieu Hoang and Kenneth Heafield and Tom Neckermann and Frank Seide and Ulrich Germann and Alham Fikri Aji and Nikolay Bogoychev and André F. T. Martins and Alexandra Birch},
      journal={arXiv preprint arXiv:1804.00344},
      url={https://arxiv.org/abs/1804.00344}
      year={2018}
    }

This examples script does the following:

* Downloads WMT2017 bilingual data for en-de
* Downloads a small subset of WMT2017 monolingual news data
* Preprocesses the above files to produce BPE segmented training data
* Trains a shallow RNN de-en model for back-translation
* Translates 10M lines from de to en
* Trains 4 default transformer models on original training data augmented with back-translated data for 8 epochs
* Trains 4 default transformer models on original training data augmented with back-translated data with right-to-left orientation for 8 epochs
* Produces n-best lists for the validation set (newstest-2016) and test sets 2014, 2015 and 2017 using the left-to-right ensemble of 4 models.
* Rescores n-best lists with 4 right-to-left models
* Produces final rescores and resorted outputs and scores them with [sacreBLEU](https://github.com/mjpost/sacreBLEU)

Assuming four GPUs are available (here 0 1 2 3), execute the command below
to run the complete example

```
./run-me.sh 0 1 2 3
```

We assume GPUs with at least 12GB of RAM are used. Change the WORKSPACE setting in the script for smaller RAM, but
be aware that this changes batch size and might lead to slighly reduced quality.

The model architecture should be identical to Google's transformer paper, but follow procedures from the Edinburgh submission.
The model is configured as follows:

```
$MARIAN/build/marian \
    --model model/ens$i/model.npz --type transformer \
    --train-sets data/all.bpe.en data/all.bpe.de \
    --max-length 100 \
    --vocabs model/vocab.ende.yml model/vocab.ende.yml \
    --mini-batch-fit -w $WORKSPACE --mini-batch 1000 --maxi-batch 1000 \
    --valid-freq 5000 --save-freq 5000 --disp-freq 500 \
    --valid-metrics ce-mean-words perplexity translation \
    --valid-sets data/valid.bpe.en data/valid.bpe.de \
    --valid-script-path ./scripts/validate.sh \
    --valid-translation-output data/valid.bpe.en.output --quiet-translation \
    --beam-size 12 --normalize=1 \
    --valid-mini-batch 64 \
    --overwrite --keep-best \
    --early-stopping 5 --after-epochs $EPOCHS --cost-type=ce-mean-words \
    --log model/ens$i/train.log --valid-log model/ens$i/valid.log \
    --enc-depth 6 --dec-depth 6 \
    --tied-embeddings-all \
    --transformer-dropout 0.1 --label-smoothing 0.1 \
    --learn-rate 0.0003 --lr-warmup 16000 --lr-decay-inv-sqrt 16000 --lr-report \
    --optimizer-params 0.9 0.98 1e-09 --clip-norm 5 \
    --devices $GPUS --sync-sgd --seed $i$i$i$i  \
    --exponential-smoothing
```

## Results

Running the complete script from start to end should result in numbers similar to the following,
improving on Edinburgh's system submission to WMT2017 by 1.2 BLEU:

|System           | test2014 | test2015 | test2016 (valid) | test2017 |
|-----------------|----------|----------|------------------|----------|
| Sys1 | 28.20 | 29.90 | 35.62 | 28.77 |
| Sys2 | 27.98 | 30.15 | 35.51 | 28.66 |
| Sys3 | 28.51 | 30.24 | 35.92 | 28.87 |
| Sys4 | 28.27 | 30.51 | 35.76 | 28.66 |
| Ensemble of 4 | 28.96 | 30.98 | 36.44 | 29.42 |
| R2L Rerank | 29.08    | 31.04    | 36.80            | 29.50    |
|Edinburgh WMT17  | --       |  --      | 36.20            | 28.30    |

It seems R2L reranking does not do much for the transformer, you might want to omit it. We left it in there
to make sure and to have all components of the Edinburgh recipe.
Training all components for more than 8 epochs is likely to improve results further.
So could increasing model dimensions (e.g. with `--dim-emb 1024` or `--transformer-dim-ffn 4096`), but that will
require careful hyperparamter tuning, especially dropout regularization, for instance adding:

```
--dim-emb 1024 \
--transformer-dim-ffn 4096 \
--transformer-dropout-attention 0.1 \
--transformer-dropout-ffn 0.1 \
```

This would be more similar to Google's Transformer-Big architecture. This will also likely require to reduce workspace to
around 8500 or 8000 on multiple 12GB GPUs. Another good way might be to invest time into better back-translation etc.
