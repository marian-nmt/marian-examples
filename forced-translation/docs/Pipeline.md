# End-to-end pipeline description

In this file we explain in detail the end-to-end pipeline implemented in this repo, which was also the pipeline used in our [experiments](./Experiments.md) and how we trained the system so that it had a forced translation behavior.

By forced translation we mean a mechanism by which we can provide signals at runtime to the system that will force it to generate a specific translation for a given input word or phrase. 
This is a helpful solution for handling the terminology, allowing us to consult a bilingual glossary at run time and force the system to produce the desired target translations. 
Take this sentence for example:

```
Germany is part of the European Union .
```
We want to force the translation of the term `European Union` to be `Europäischen Union`. To do so, we inject these translations into the source sentence and use input factors (more info [here](https://github.com/marian-cef/marian-dev/blob/master/doc/factors.md)) to provide the proper signal for each of the words. We use `p0` for words that are not in the glossary, `p1` for the source version of the terms that we want to force translate, and `p2` for the desired translations of the given terms. The above sentence becomes:

```
Germany|p0 is|p0 part|p0 of|p0 the|p0 European|p1 Union|p1 Europäischen|p2 Union|p2 .|p0
```


By training the system with these annotations and factor inputs we expect that the system learns a *copy and inflect behavior* whenever it sees a `p1` followed by a `p2`.

This is an effective solution for many languages, in particular for the ones that have reach morphologies.
In those cases we might want to inflect the terms when translating, mainly due to the fact that usually glossaries only have the nominal forms of each term, not being feasible to have all the possible inflections. For example in this sentence:

```
I|p0 live|p1 Leben|p2 in|p0 Portugal|p0 .|p0
```

Even though we annotated the translation of `live` with the infinitive form `Leben`, we want the translation to be the correct inflection `lebe`.

To tackle this, instead of annotating the training corpus with the inflected forms of the terms, we annotate it with the target lemmas, and let the system to learn copying and inflecting the term translations into the target. 
To do this, we lemmatized the target corpus (Using [stanza](https://github.com/stanfordnlp/stanza) [[2](#References)]) and then obtained the word alignments (with [fast_align](https://github.com/clab/fast_align)) of the source (tokenized) and  target (tokenized and lemmatized). 
We then used these alignments to annotate some of the source words (with their corresponding lemmatized target translations). 
Following the paper [[1](#References)] from which we based this work, we only annotated verbs and nouns.
To decide about the sentences and words to annotate, we first randomly generate a number in the range of [0.6, 1.0) for each sentence.
Then for each source sentence we iterate over all its words and generate another number from the interval  of [0.0, 1.0). 
If the randomly sampled number for the word is larger than the one of the sentence and also if the word is either noun or verb, we annotate it with its corresponding target lemma. Otherwise, we skip the word and annotate it with `p0`.
 In contrast to the approach presented in the paper that duplicated the sentences which contain at least one annotated term (one with the term annotation and one without) here we only keep the annotated version and do not add the original version to the training corpus.


To conclude here is a summary of the pipeline:

1. Start by tokenizing the source and the target training corpus;
2. Escape some special characters in order to be able to use factors (see [this](https://github.com/marian-cef/marian-dev/blob/master/doc/factors.md#other-suggestions));
3. Lemmatize the target corpus;
4. Align the source words with the target lemmas;
5. Annotate the source data based on the alignments and apply the factors (i.e. add `p0`, `p1`, and `p2` to the annotated source sentence);
6. Train and apply the truecaser model to the annotated corpus (but with the factors removed from it).
7. Train a joint BPE model and apply it to both source (annotated) and target (tokenized).
8. Extend the BPE splits to the annotated text (which contains factors). 
Imagine that we annotated the sentence "`I|p0 live|p0 in|p0 Germany|p1 Deutschland|p2 .|p0`". After applying BPE we get "`I live in Ger@@ many Deutsch@@ land .`", so we want the final format of the sentence to be: "`I|p0 live|p0 in|p0 Ger@@|p1 many|p1 Deutsch@@|p2 land|p2 .|p0`";
9. Create a regular joint vocab and extend that to the factor vocab format expected by Marian;
10. Train the NMT model;
11. For inference, the preprocessing steps are the same as the ones for the training, with the exception of steps 3 to 5 (and skipping the training of the truecaser and BPE models in steps 6 and 7), because for inference we do the annotations based on an input glossary and not based on the alignment as we do for training;
12. Translate the test set;
13. Postprocess the hypothesis (debpe, detruecase, deescape special characters, detokenize).



## References ##

[1] T. Bergmanis and M. Pinnis.  *Facilitating terminology translation with target lemma annotations.*  InProceedings of the 16th Conference of the European Chapter of the Association for Computational Linguistics:  Main  Volume,  pages  3105–3111,  Online,  Apr.  2021.  Association  for  Computational Linguistics. (https://www.aclweb.org/anthology/2021.eacl-main.271).

[2] Qi, P., Zhang, Y., Zhang, Y., Bolton, J., & Manning, C. (2020). Stanza: A Python Natural Language Processing Toolkit for Many Human Languages. In Proceedings of the 58th Annual Meeting of the Association for Computational Linguistics: System Demonstrations. (https://arxiv.org/pdf/2003.07082.pdf).
