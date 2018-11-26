# Example for Training with Marian and SentencePiece

In this example, we modify the Romanian-English example from `examples/training-basics` to use Taku Kudo's 
[SentencePiece](https://github.com/google/sentencepiece) instead of a complicated pre/prost-processing pipeline. 
We also replace the evaluation scripts with Matt Post's [SacreBLEU](https://github.com/mjpost/sacreBLEU). Both tools greatly simplify the training and evaluation process by providing ways to have reversible hidden preprocessing and repeatable evaluation. 

## Building Marian with SentencePiece Support

Since version 1.7.0, Marian has built-in support for SentencePiece,
but this needs to be enabled at compile-time. We decided to make the compilation of SentencePiece
optional as SentencePiece has a number of dependencies - especially Google's Protobuf - that
are potentially non-trivial to install.

Following the the SentencePiece Readme, we list a couple of packages you would need to
install for a coule of Ubuntu versions:

On Ubuntu 14.04 LTS (Trusty Tahr):

```
sudo apt-get install libprotobuf8 protobuf-compiler libprotobuf-dev
```

On Ubuntu 16.04 LTS (Xenial Xerus):

```
sudo apt-get install libprotobuf9v5 protobuf-compiler libprotobuf-dev
```

On Ubuntu 17.10 (Artful Aardvark) and Later:

```
sudo apt-get install libprotobuf10 protobuf-compiler libprotobuf-dev
```

For more details see the documentation in the SentencePiece repo:
https://github.com/marian-nmt/sentencepiece#c-from-source

With these dependencies met, you can compile Marian as follows:

```
git clone https://github.com/marian-nmt/marian
cd marian
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DUSE_SENTENCEPIECE=ON
make -j 8
```

To test if `marian` has been compiled with SentencePiece support run

```
./marian --help |& grep sentencepiece
```

which should display the following new options:

```
  --sentencepiece-alphas VECTOR ...     Sampling factors for SentencePieceVocab; i-th factor corresponds to i-th vocabulary
  --sentencepiece-options TEXT          Pass-through command-line options to SentencePiece trainer
  --sentencepiece-max-lines UINT=10000000
```

## Execute the Example

Files and scripts in this folder have been adapted from the Romanian-English
sample from https://github.com/rsennrich/wmt16-scripts. We also add the
back-translated data from
http://data.statmt.org/rsennrich/wmt16_backtranslations/ as desribed in
http://www.aclweb.org/anthology/W16-2323. The resulting system should be
competitive or even slightly better than reported in the Edinburgh WMT2016
paper.

Assuming you one GPU, to execute the complete example type:

```
./run-me.sh
```

which downloads the Romanian-English training files and concatenates them into training files. 
No preprocessing is required as the Marian command will train a SentencePiece vocabulary from
the raw text. Next the translation model will be trained and after convergence, the dev and test
sets are translated and evaluated with sacreBLEU.

To use with a different GPUs than device 0 or more GPUs (here 0 1 2 3) use the command below:

```
./run-me.sh 0 1 2 3
```

## Step-by-step Walkthrough

In this section we repeat the content from the above `run-me.sh` script with explanations. You should be able to copy and paste the commands and follow through all the steps. 

We assume you are running these commands from the examples directory of the main Marian directory tree `marian/examples/training-basics-spm` and that the Marian binaries have been compiled in `marian/build`. The localization of the Marian binary relative to the current directory is therefore `../../build/marian`.

### Preparing the test and validation sets

We can use SacreBLEU to produce the original WMT16 development and test sets for Romanian-English. We first clone the SacreBLEU repository from our fork and then generate the test files. 

```
# get our fork of sacrebleu
git clone https://github.com/marian-nmt/sacreBLEU.git sacreBLEU

# create dev set
sacreBLEU/sacrebleu.py -t wmt16/dev -l ro-en --echo src > data/newsdev2016.ro
sacreBLEU/sacrebleu.py -t wmt16/dev -l ro-en --echo ref > data/newsdev2016.en

# create test set
sacreBLEU/sacrebleu.py -t wmt16 -l ro-en --echo src > data/newstest2016.ro
sacreBLEU/sacrebleu.py -t wmt16 -l ro-en --echo ref > data/newstest2016.en
```

### Downloading the training files

Similarly, we download the training files from different sources and concatenate them into two training files. Note, there is no preprocessing whatsoever. Downloading may take a while, the servers are not particularly fast. 

```
# change into data directory
cd data

# get En-Ro training data for WMT16
wget -nc http://www.statmt.org/europarl/v7/ro-en.tgz
wget -nc http://opus.lingfil.uu.se/download.php?f=SETIMES2/en-ro.txt.zip -O SETIMES2.ro-en.txt.zip
wget -nc http://data.statmt.org/rsennrich/wmt16_backtranslations/ro-en/corpus.bt.ro-en.en.gz
wget -nc http://data.statmt.org/rsennrich/wmt16_backtranslations/ro-en/corpus.bt.ro-en.ro.gz

# extract data
tar -xf ro-en.tgz
unzip SETIMES2.ro-en.txt.zip
gzip -d corpus.bt.ro-en.en.gz corpus.bt.ro-en.ro.gz

# create corpus files
cat europarl-v7.ro-en.en SETIMES2.en-ro.en corpus.bt.ro-en.en > corpus.en
cat europarl-v7.ro-en.ro SETIMES2.en-ro.ro corpus.bt.ro-en.ro > corpus.ro

# clean
rm ro-en.tgz SETIMES2.* corpus.bt.* europarl-*

# change back into main directory
cd ..
```

### Normalization of Romanian diacritics with SentencePiece

It seems that the training data is quite noisy and multiple similar characters are used in place of the one correct character.
Barry Haddow from Edinburgh who created the original normalization Python scripts noticed that removing diacritics on the Romanian side leads to a significant improvment in translation quality. And indeed we saw gains of up to 2 BLEU points due to normalization versus unnormalized text. The original scripts are located in the old Romanian-English example folder in `marian/examples/training-basics/scripts`. We do not need to use them here.

SentencePiece allows to specify normalization or replacement tables for character sequences. These replacements are applied before tokenization/segmentation and included in the SentencePiece model. Based on the mentioned preprocessing scripts, we manually create a tab-separated normalization rule file `data/norm_romanian.tsv` like this (see the [SentencePiece documentation on normalization](https://github.com/google/sentencepiece/blob/master/doc/normalization.md) for details):

```
015E    53 # Ş => S
015F    73 # ş => s
0162    54 # Ţ => T
0163    74 # ţ => t
0218    53 # Ș => S
0219    73 # ș => s
021A    54 # Ț => T
021B    74 # ț => t
0102    41 # Ă => A
0103    61 # ă => a
00C2    41 # Â => A
00E2    61 # â => a
00CE    49 # Î => I
00EE    69 # î => i
```

### Training the NMT model

Next, we execute a training run with `marian`. Note how the training command is called passing the 
raw training and validation data into Marian. A single joint SentencePiece model will be saved to 
`model/vocab.roen.spm`. The `*.spm` suffix is required and tells Marian to train a SentencePiece 
vocabulary. When the same vocabulary file is specified multiple times - like in this example - a single
vocabulary is built for the union of the corresponding training files. This also enables us to use
tied embeddings (`--tied-embeddings-all`).

We can pass the Romanian-specific normalizaton rules via the `--sentencepiece-options` command line
argument. The values of this option are passed on to the SentencePiece trainer, note the required single
quotes around the SentencePiece options: `--sentencepiece-options '--normalization_rule_tsv=data/norm_romanian.tsv'`.

Another new feature is the `bleu-detok` validation metric. When used with SentencePiece this should
give you in-training BLEU scores that are very close to sacreBLEU's scores. Differences may appear 
if unexpected SentencePiece normalization rules are used. You should still report only official
sacreBLEU scores for publications.

We are training of four GPUs defined with `--devices 0 1 2 3`. Change this to the required number of GPUs.

```
../../build/marian \
    --devices 0 1 2 3 \
    --type s2s \
    --model model/model.npz \
    --train-sets data/corpus.ro data/corpus.en \
    --vocabs model/vocab.roen.spm model/vocab.roen.spm \
    --sentencepiece-options '--normalization_rule_tsv=data/norm_romanian.tsv' \
    --dim-vocabs 32000 32000 \
    --mini-batch-fit -w 5000 \
    --layer-normalization --tied-embeddings-all \
    --dropout-rnn 0.2 --dropout-src 0.1 --dropout-trg 0.1 \
    --early-stopping 5 --max-length 100 \
    --valid-freq 10000 --save-freq 10000 --disp-freq 1000 \
    --cost-type ce-mean-words --valid-metrics ce-mean-words bleu-detok \
    --valid-sets data/newsdev2016.ro data/newsdev2016.en \
    --log model/train.log --valid-log model/valid.log --tempdir model \
    --overwrite --keep-best \
    --seed 1111 --exponential-smoothing \
    --normalize=0.6 --beam-size=6 --quiet-translation
```

The training should stop if cross-entropy on the validation set
stops improving.

### Translating the test and validation sets with evaluation

After training, the model with the highest translation validation score is used
to translate the WMT2016 dev set and test set with `marian-decoder`:

```
# translate dev set
cat data/newsdev2016.ro \
    | ../../build/marian-decoder -c model/model.npz.best-bleu-detok.npz.decoder.yml -d 0 1 2 3 -b 6 -n0.6 \
      --mini-batch 64 --maxi-batch 100 --maxi-batch-sort src > data/newsdev2016.ro.output

# translate test set
cat data/newstest2016.ro \
    | ../../build/marian-decoder -c model/model.npz.best-bleu-detok.npz.decoder.yml -d 0 1 2 3 -b 6 -n0.6 \
      --mini-batch 64 --maxi-batch 100 --maxi-batch-sort src > data/newstest2016.ro.output
```
after which BLEU scores for the dev and test set are reported.
```
# calculate bleu scores on dev and test set
sacreBLEU/sacrebleu.py -t wmt16/dev -l ro-en < data/newsdev2016.ro.output
sacreBLEU/sacrebleu.py -t wmt16 -l ro-en < data/newstest2016.ro.output
```
You should see results somewhere in the area of:
```

```
