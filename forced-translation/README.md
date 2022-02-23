# Apply forced translation using Marian

This repository aims to give a walkthrough on how to train an end-to-end pipeline, providing the needed scripts and training guidelines to be able to successfully apply forced translation using Marian, fulfilling this way the second milestone of the [Marian-CEF](https://github.com/marian-cef/marian-dev) EU project.

This milestone aims to support users in improving translation quality by injecting translations from their own bilingual terminology dictionaries. To expand coverage and support morphologically rich languages, it also supports inflecting entries in the bilingual terminology dictionary.

We followed the approach taken in the following paper:<br/>
> T. Bergmanis and M. Pinnis.  *Facilitating terminology translation with target lemma annotations.*  InProceedings of the 16th Conference of the European Chapter of the Association for Computational Linguistics:  Main  Volume,  pages  3105–3111,  Online,  Apr.  2021.  Association  for  Computational Linguistics. (https://www.aclweb.org/anthology/2021.eacl-main.271).

All information about the experiments that we ran with the code provided in this repository, which data to use to reproduce them and the results can be found in the [docs](docs/Experiments.md) folder.<br/>
The details regarding the technique used to be able to do forced translation are detailed in the paper cited above.

We will now proceed with a description of how to use the repo.

## Install

Download and compile [Marian-NMT](https://github.com/marian-cef/marian-dev). For now it is needed to install the linked marian-cef version of Marian to use all the capabilities related to input factors, but as soon as the code is merged to marian-dev the link will be updated. Once Marian is installed add the path to the marian executables folder in the `.env` file.

Run the following script to install [fast_align](https://github.com/clab/fast_align) and the marian selection of the [moses-scripts](https://github.com/marian-nmt/moses-scripts).

```
./install_dependencies.sh
```
In case you already have them installed in your machine and don't want to download them again just update the path to its folders in the `.env` file.

After creating a new virtual environment install the python dependencies. You will need python 3.6.
```
pip install -r requirements.txt
```

## Run

### Files set up and `.env` file

To run the end-to-end pipeline with a ready to use example, that trains a model with Europarl data for the en-pt language pair just execute the following commands and move to the [trigger pipeline](#Trigger-pipeline) section of this README.
```
cd test_data
./download_data
cd ..
```

To run the end-to-end pipeline with your one custom data, start by placing in the same folder your corpus divided into training, validation and test set. Note that all data generated during the pipeline execution will be stored in that same folder. Then populate the `.env` file in accordance. As an example if you want to translate from English to Romanian and you named your files `train.en dev.en test.en; train.ro dev.ro test.ro` part of your `.env` file should look this:
```
DATA=path/to/data/folder
TRAIN_PREFIX=train
VALID_PREFIX=valid
TEST_PREFIX=test

SRC_LANG=en
TGT_LANG=ro
```
Also add to the same data folder the bilingual glossary that you will use for inference and name it `glossary.SRC_LANGTGT_LANG.tsv`, so in the `en-ro` example that we are following the name should be `glossary.enro.tsv`. This file should be a simple two column tab separated file with the source and target terms in each line.</br>
Also add to the `.env` file the path to where you want the model to be saved and also the prefix to use in the factors (We will use 'p' in the example). More info about the factors is [here](https://github.com/marian-cef/marian-dev/blob/master/doc/factors.md). Finally add the indexes of the gpus that you want to use (space separated).
```
FACTOR_PREFIX=p

MODEL_DIR=path/to/model_dir

GPUS="0"
```

If you only want to use the needed scripts to perform this task and use your own pipeline, an explanation of how to use each one of the essential scripts can be found in the [scripts](scripts/README.md) folder.

### Trigger pipeline
After everything is ready to go just execute:
```
./run-me.sh
```
This will execute the end-to-end pipeline. It will preprocess all the data, train a model, and subsequently translate the test set, forcing the terminology you provided in the glossary to appear in the translations of your test set. The lemmatization step in the preprocessing is neural based, so even using a GPU you should expect it to take a couple of hours to run. The training will take at least 24h (depending on the hardware you have to run it).
A brief description of the end-to-end pipeline can be found [here](docs/Pipeline.md).