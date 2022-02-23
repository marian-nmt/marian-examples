# Experiments description and results

In this file we will explain and describe the experiments that we conducted to validate the use of the implemented forced translation technique.

This was inspired by:<br>
> T. Bergmanis and M. Pinnis.  *Facilitating terminology translation with target lemma annotations.*  InProceedings of the 16th Conference of the European Chapter of the Association for Computational Linguistics:  Main  Volume,  pages  3105–3111,  Online,  Apr.  2021.  Association  for  Computational Linguistics. (https://www.aclweb.org/anthology/2021.eacl-main.271).

A description of all the steps of the pipeline can be found [here](./Pipeline.md).

## Data used

We ran experiments for four language pairs:
+ English-German
+ English-Latvian
+ English-Norwegian
+ English-Romanian

We gathered our corpora by merging several datasets from the [OPUS](https://opus.nlpl.eu/index.php) corpus bank. 
We applied some cleaning to the corpus where we removed duplicated and empty lines and lines that were the same between source and target. 
The validation set used was a subset of the corpus excluded from the training set for all the language pairs, except en-lv where we used the newstest from [2017 WMT](http://www.statmt.org/wmt17/translation-task.html). 
The testset for en-de and en-lv was the ATS test set mentioned in the paper cited above and available [here](https://github.com/tilde-nlp/terminology_translation). For the two remaining LPs, en-ro and en-no, in order to have a testset specific to a certain domain, we selected 800 lines from the [europarl corpus](https://opus.nlpl.eu/Europarl.php) for en-ro and 800 lines from the [Tilde MODEL - EMEA](https://tilde-model.s3-eu-west-1.amazonaws.com/Tilde_MODEL_Corpus.html) corpus for en-no, creating this way a testset specific to politics and to medicine respectively.

This resulted in the following data distribution (number of lines):

| Language Pair |  Train   | Valid | Test |
| :-----------: |:--------:| :---: | :--: |
| en-de         | 73,246,285 | 2,000  | 767  |
| en-lv         | 11,496,869 | 2,003  | 767  |
| en-nb         | 12,737,978 | 2,000  | 800 |
| en-ro         | 14,560,839 | 2,000  | 800 |

If you look at both the paper and the [pipeline description](./Pipeline.md) you can see that no glossary is used during training by this method, and it only uses glossasries during the inference. 

For en-de and en-lv we used the [ATS](https://github.com/tilde-nlp/terminology_translation) glossaries, also used in Tilde's paper. For the en-ro language pair we used the [IATE](https://iate.europa.eu/home) generic glossary, filtered by the domains related to the content of the created testset based on europarl (Poltics, International relations, European Union, Economics, etc.). For the en-nb language pair we use a glossary from [eurotermbank](https://www.eurotermbank.com/collections/49), that has entries related to medicine, to match the EMEA based testset domain.

During training this was the amount of annotated data with the target lemmas:

+ **en-de**: Annotated 58,63% lines with a total of 89,966,898 matches (2.13 matches per line).
+ **en-lv**: Annotated 58,24% lines with a total of 16,317,677 matches (2.43 matches per line).
+ **en-nb**: Annotated 56.98% lines with a total of 17,451,665 matches (2.40 matches per line).
+ **en-ro**: Annotated 57,44% lines with a total of 20,230,640 matches (2.41 matches per line).


Also some statistics regarding the annotations on the testsets with the glossary entries:

+ **en-de**:  Annotated 61.80% lines with a total of 694 matches (1.62 matches per line).
+ **en-lv**:  Annotated 57.50% lines with a total of 647 matches (1.74 matches per line).
+ **en-nb**:  Annotated 65.25% lines with a total of 631 matches (1.21 matches per line).
+ **en-ro**:  Annotated 58.62% lines with a total of 491 matches (1.05 matches per line).

## Training

All the training parameters and marian configuration options were exactly the same as the ones that you can find in the [training script](../run-me.sh) of the end-to-end pipeline of this repo.

## Results

### Automatic metrics

We evaluated based on [BLEU](https://www.aclweb.org/anthology/P02-1040.pdf) and [COMET](https://github.com/Unbabel/COMET), and we used the `wmt-large-da-estimator-1719` model for the latter.
Regarding the terminology accuracy, we used lemmatized term exact match accuracy to measure if the system chooses the correct lexemes.
To obtain these, we lemmatized the hypothesis of the systems and lemmatized the glossary (both the source and the target side) and counted the percentage of the lemmatized target glossaries that appeared correctly in the lemmatized target hypothesis.

| Lang. Pair |  BLEU   |  BLEU |   COMET | COMET | Acc. [%]  | Acc. [%]
| :-----------: |:--------:| :---: | :--: | :--: |:--: |:--: |
|        | Baseline | Fact. Model  | Baseline | Fact. Model  |Baseline | Fact. Model  |
| en-de         | 23.712 | **27.539**  | 0.411 |**0.580**  |53.03  |**95.53**  |
| en-lv         | 20.810 | **24.990**  |0.607  |**0.724**  |52.07  |**86.86**  |
| en-nb         | 32.682 |  **32.870** | **0.730** | 0.726  | 81.14 | **95.09**|
| en-ro         | 37.338 | **38.591** | 0.841 | **0.879** | 81.87| **95.32** |


The glossary accuracy does not capture
whether the term is inflected correctly or not, and so we also relied on human evaluation.

### Human evaluation

We followed the same procedure as the one in Tilde's paper cited above.
We randomly chose 100 lines that had term annotations, and asked two questions to the annotators when comparing the baseline and the factored model translation side by side:
+ Which system is better overall?
+ Rate the term translation in each of the systems with one of the following options: [Correct, Wrong lexeme, Wrong inflection, Other].

The results are the following:
#### **English-Latvian** ####

Which system is better overall?
| Baseline |  Both   | Factored Model |
| :-----------: |:--------:| :---: |
|     6    | 67 | 27  |

Rate the quality of the term translation:

|System| Correct |  Wrong lexeme   | Wrong inflection | Other|
|:-----------:| :-----------: |:--------:| :---: |:---: |
|Baseline|    43.3    | 44.7 | 2.7 |9.3|
|Fact. Model|    87.3    | 2.7 | 2.7  |7.3|

#### **English-German** ####

Which system is better overall?
| Baseline |  Both   | Factored Model |
| :-----------: |:--------:| :---: |
|     10    | 37 | 53  |

Rate the quality of the term translation:

|System| Correct |  Wrong lexeme   | Wrong inflection | Other|
|:-----------:| :-----------: |:--------:| :---: |:---: |
|Baseline|    50.4    | 47.9 | 0.0  |1.7|
|Fact. Model|     95.8    | 0 | 3.4  |0.8|

#### **English-Nowrwegian (bokmal)** ####
Which system is better overall?
| Baseline      |  Both    | Factored Model |
| :-----------: |:--------:| :------------: |
|       19      |   61     |        20      |

Rate the quality of the term translation:

|System| Correct |  Wrong lexeme   | Wrong inflection | Other |
|:----:|:-------:|:---------------:|:----------------:|:-----:|
|Baseline|  78.2 |        16.4     |       3.6       |  1.8 |
|Fact. Model|    97.3     | 0.0 |  2.7 | 0.0 |


#### **English-Romanian** ####

Which system is better overall?
| Baseline      |  Both    | Factored Model |
| :-----------: |:--------:| :------------: |
|        18     |     64   |      18        |

Rate the quality of the term translation:

|System| Correct |  Wrong lexeme   | Wrong inflection | Other |
|:----:|:-------:|:---------------:|:----------------:|:-----:|
|Baseline| 88.4  |       6.8      |     1.9         |  2.9 |
|Fact. Model|     94.2   | 1.0 |  2.9 |  1.9 |
