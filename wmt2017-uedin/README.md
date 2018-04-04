# Reproducing Edinburgh's WMT2017 system for en-de with Marian

Files and scripts in this folder show how to train a complete WMT-grade system
based on [Edinburgh's WMT submission description](http://www.aclweb.org/anthology/W17-4739) for en-de.

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
* Trains a shallow de-en model for back-translation
* Translates 10M lines from de to en
* Trains 4 deep RNN-based systems on original training data augmented with back-translated data for 8 epochs
* Trains 4 deep RNN-based systems on original training data augmented with back-translated data with right-to-left orientation for 8 epochs
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
The final system should be on-par or slighly better than the Edinburgh system due to better tuned hyper-parameters.

The model architecture should be identical to Edinburgh's submission detailed above and is being configured as:

```
$MARIAN/build/marian \
    --model model/ens$i/model.npz --type s2s \
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
    --enc-type bidirectional --enc-depth 1 --enc-cell-depth 4 \
    --dec-depth 1 --dec-cell-base-depth 8 --dec-cell-high-depth 1 \
    --tied-embeddings-all --layer-normalization \
    --dropout-rnn 0.1 --label-smoothing 0.1 \
    --learn-rate 0.0003 --lr-decay-inv-sqrt 16000 --lr-report \
    --optimizer-params 0.9 0.98 1e-09 --clip-norm 5 \
    --devices $GPUS --sync-sgd --seed $i$i$i$i  \
    --exponential-smoothing
```

