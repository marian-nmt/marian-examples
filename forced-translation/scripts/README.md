# Scripts description

In this folder you can find a list of the scripts needed to do forced translation with marian that you must include in your pipeline, and/or execute the end-to-end pipeline implemented in this repo.

Here is a description of what the scripts do, how to use them, and their command line interface.

## [lemmatize.py](lemmatize.py)

This script lemmatizes a corpus using the [stanza](https://github.com/stanfordnlp/stanza) toolkit. Note that the scripts lemmatizes all the words. 
It expects the corpus to be tokenized. 
Also, we recommend using a GPU to run it in order to be faster. To run it just do:
```
python lemmatize.py -i path/to/input_text -l lang_id -o path/to/output_text
```
## [align.sh](align.sh)

This script is just a wrapper around the execution of the [fast_align](https://github.com/clab/fast_align) calls, to generate alignments between two files. It generates source-target and target-source alignments, to later symmetrize them and output only one final alignments file. The alignments file will be stored in the source file directory. It will look for fast_align executables in the tools dir of this repo, but you can explicitly set the fast_align path if needed by setting the FAST_ALIGN variable. To execute run:

```
FAST_ALIGN=path/to/fast_align_execs ./align.sh -s path/to/source_file -t path/to/target_file
```

## [add_target_lemma_annotations.py](add_target_lemma_annotations.py)

This script annotates the source data with the target lemmas, taking into account the alignments. The alignments should have the same number of lines as the corpus and the default fast_align format for each line. For example: `0-0 0-1 1-2 2-2`. It will only annotate nouns and verbs and use the random selection based on the probabilities thresholds described [here](../docs/Pipeline.md). Since we use stanza to do the POS identification we recommend using a GPU to be faster. To run it do:

```
python add_target_lemma_annotations.py -s path/to/source_file -t path/to/target_lemmatized_file --alignments_file path/to/alignments -sl source_lang_id -o path/to/output_file
```

## [add_glossary_annotations.py](add_glossary_annotations.py)

This script is very similar to the one described above, with the difference that instead of relying on the alignments to inject the annotations, it looks for matches and respective translations in a provided bilingual glossary. This glossary should be a `.tsv` file with two tab separated columns like this:

```
en  de
screwdriver Schraubendreher
sealant Dichtungsmittel
seat belt   Sicherheitsgurt

```

This scripts runs in two different modes. If executing without the `--test` option it will run in training mode, which mean that it will look in the target sentence as well for target term matches, and ensures that only sentences were the glossary terms also appears on the target reference are annotated. If run with `--test`, it looks in the source side only.

To run the script do:
```
python add_glossary_annotations.py -s path/to/source_tokenized_file -t path/to/target_tokenized_file -o path/to/output_file -g path/to/glossary_file --test
```

## [create_factored_vocab.sh](create_factored_vocab.sh)

This scripts creates the factored vocab in the format required by marian. More details about this [here](https://github.com/marian-cef/marian-dev/blob/master/doc/factors.md). You need to provide a file with a token per line like this:
```
</s>
<unk>
.
,
the
a
de
```

We also expect that when creating the vocab you have escaped in the corpus the special characters (#, _, |, :, \\), otherwise you might observe some misbehaviours. You may also specify the factor prefix, otherwise `p` will be assumed. To create the factor vocab run:
```
./create_factored_vocab.sh -i path/to/regular/vocab  -o path/to/factored_vocab.fsv -p "factor_prefix"
```

## [transfer_factors_to_bpe.py](transfer_factors_to_bpe.py)

This script extends the BPE splits to the factored text. Given that we need to apply the factors prior to applying the BPE, and we subsequentillyneed to extend the splits to the factored corpus. For example, if you annotate the sentence "`I|p0 live|p0 in|p0 Germany|p1 Deutschland|p2 .|p0`", and after applying BPE you get "`I live in Ger@@ many Deutsch@@ land .`", you want the final format of the sentence to be: "`I|p0 live|p0 in|p0 Ger@@|p1 many|p1 Deutsch@@|p2 land|p2 .|p0`".

To run it do:
```
python transfer_factors_to_bpe.py --factored_corpus path/to/factored_file --bpe_corpus path/to/bpeed_file --output_file path/to/output_file
```

## [eval_lemmatized_glossary.py](eval_lemmatized_glossary.py)

This script receives two files, the annotated file with the glossary terms and the factors, and the depeed hypothesis, and calculates the lemmatized term exact match accuracy. To do so, it lemmatizes the hypothesis of the system and lemmatizes the annotated glossary terms in the source and counts the percentage of the lemmatized annotated target glossaries that appeared correctly in the lemmatized target hypothesis.
To run it do:
```
python scripts/eval_lemmatized_glossary.py -s path/to/factored_file -tl target_lang_id -hyps path/to/debpeed_hypothesis
```

## Other scripts

The scripts `preprocess_train.sh`, `preprocess_test.sh`, `postprocess.sh` and `evaluate.sh` implement preprocess, postprocess and evaluation tasks to execute the end-to-end pipeline and are only for code organization purposes. They are meant to be executed via the top level script `run-me.sh` in the main repo root and not run standalone.
