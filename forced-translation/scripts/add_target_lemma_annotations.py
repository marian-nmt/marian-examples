import sys
import os
import argparse
import random

from collections import defaultdict

import stanza



def main():

    lines_annotated_counter = 0
    total_lines_counter = 0
    matches_counter = 0

    args = parse_user_args()

    src_lang = args.src_lang
    source_file = os.path.realpath(args.source_file)
    target_file = os.path.realpath(args.target_file)
    alignments_file = os.path.realpath(args.alignments_file)
    output_file = os.path.realpath(args.output_file)

    factor_prefix = args.factor_prefix

    # set random seed
    random.seed(args.seed)

    pos_tagger = setup_stanza(src_lang)

    # we gather the lines in chunks to make the lemmatization faster by passing several lines
    # to stanza at once, but to not load all the corpus in memory.
    chunk = {'src': [], 'trg': [], 'align': []}
    chunk_size = args.chunk_size

    with open(source_file, 'r') as source_f, \
         open(target_file, 'r') as target_f, \
         open(alignments_file, 'r') as alignments_f, \
         open(output_file, 'w') as output_f:

        for source_line, target_line, alignment in zip(source_f, target_f, alignments_f):

            chunk['src'].append(source_line.strip().split())
            chunk['trg'].append(target_line.strip().split())
            chunk['align'].append(prepare_alignments(alignment))

            if len(chunk['src']) < chunk_size:
                continue
            matches = choose_words_for_annotation(chunk['src'], chunk['align'], pos_tagger)
            lines_annotated_counter, total_lines_counter, matches_counter = update_counters(matches, lines_annotated_counter, total_lines_counter, matches_counter)
            factored_sentences = annotate(chunk['src'], chunk['trg'], matches, factor_prefix)
            write_to_file(factored_sentences, output_f)
            chunk = {'src': [], 'trg': [], 'align': []}

        # also annotate last chunk in case we reached EOF
        if chunk['src']:
            matches = choose_words_for_annotation(chunk['src'], chunk['align'], pos_tagger)
            update_counters(matches, lines_annotated_counter, total_lines_counter, matches_counter)
            factored_sentences = annotate(chunk['src'], chunk['trg'], matches, factor_prefix)
            write_to_file(factored_sentences, output_f)

    print(f"Annotated {lines_annotated_counter/total_lines_counter*100:.2f}% lines, with a total of {matches_counter} annotations. {matches_counter/lines_annotated_counter:.2f} annotations per line")

def setup_stanza(lang):
    stanza_dir = os.path.dirname(os.path.realpath(stanza.__file__))
    stanza_dir = os.path.join(stanza_dir, 'stanza_resources')
    stanza.download(lang=lang, model_dir=stanza_dir)
    # we assume that data is already received tokenized, thus tokenize_pretokenized = True
    return stanza.Pipeline(lang=lang, dir=stanza_dir, processors='tokenize,pos', tokenize_pretokenized=True)


def prepare_alignments(alignments):
    '''
    We expect alignments in the format: 0-0, 0-1, 1-1, 2-2
    Stores them in a dict like: {0: [0, 1], 1: [1], 2:[2]}
    '''
    align_dict = defaultdict(list)

    alignments = alignments.strip().split()
    for alignment in alignments:
        alignment = alignment.split('-')
        align_dict[int(alignment[0])].append(int(alignment[-1]))

    return align_dict


def choose_words_for_annotation(source_sentences, alignments, pos_tagger):
    '''
    Based on the aligments selects wich words to annotate.
    Returns the matches in the following format: (src_tok_idx, trg_tok_idx, nr_tokens_src_term, nr_tokens_trg_term)
    We randomly generate a value from 0.6 to 1 for each sentence. We generate another from 0 to 1 for each word.
    If the latter is greater than the former, and the word is either a noun or a verb we annotate that word with the
    corresponding target lemma.
    '''
    # get part of speech
    doc = pos_tagger(source_sentences)

    batch_matches = []
    for sentence, alignment in zip(doc.sentences, alignments):
        sentence_prob = random.uniform(0.6, 1)
        sentence_matches = []
        for idx, word in enumerate(sentence.words):
            word_prob = random.uniform(0, 1)
            if word.pos in ['NOUN', 'VERB']:
                if word_prob > sentence_prob:
                    # we check if the target tokens of the alignment are consecutive to avoid miss alignments
                    if alignment[idx] and checkConsecutive(alignment[idx]):
                        sentence_matches.append((idx, alignment[idx][0], 1, len(alignment[idx])))
        batch_matches.append(sentence_matches)
    return batch_matches


def annotate(source_sentences, target_sentences, all_matches, factor_prefix):
    '''
    Adds factors to the source based on the matches obtained with the alignments

    Ex I|p0 bought|p0 a|p0 car|p1 carro|p2
    '''
    source_sentences_fact = []
    for source, target, matches in zip(source_sentences, target_sentences, all_matches):
        matches = sorted(matches, key=lambda match: match[0], reverse=True)
        source = [word + '|%s0' % factor_prefix for word in source]
        for match in matches:
            source_start = match[0]
            target_start = match[1]
            source_end = match[0] + match[2]
            target_end = match[1] + match[3]
            target_n_gram = target[target_start : target_end]
            target_n_gram = [word + '|%s2' % factor_prefix for word in target_n_gram]
            for i in range(source_start, source_end):
                source[i] = source[i][:-1] + '1'
            source[source_end : source_end] = target_n_gram
        source_sentences_fact.append(source)

    return source_sentences_fact


def checkConsecutive(l):
    return sorted(l) == list(range(min(l), max(l)+1))


def update_counters(matches, lines_annotated_counter, total_lines_counter, matches_counter):
    for match in matches:
        total_lines_counter += 1
        if match:
            lines_annotated_counter += 1
            matches_counter += len(match)
    return lines_annotated_counter, total_lines_counter, matches_counter


def write_to_file(sentences, f):
    for sentence in sentences:
        f.write(' '.join(sentence) + '\n')


def parse_user_args():
    parser = argparse.ArgumentParser(description="Adds target lemma annotations to the source")
    parser.add_argument('-s', '--source_file', help="source file path", required=True)
    parser.add_argument('-t', '--target_file', help="target file path", required=True)
    parser.add_argument('-o', '--output_file', help="output file path", required=True)
    parser.add_argument('--alignments_file', help="alignments file path", required=True)
    parser.add_argument('-sl', '--src_lang', help="source language identifier", required=True)
    parser.add_argument('--chunk_size', type=int, default=5000, help="line chunk size to feed to the lemmatizer")
    parser.add_argument('--factor_prefix', type=str, default='p', help="prefix for the terminology factors. Factors vocab will be [|prefix0, |prefix1, |prefix2]")
    parser.add_argument('--seed', type=int, default=1111, help="Set the random seed value")
    return parser.parse_args()


if __name__ == "__main__":
    main()
