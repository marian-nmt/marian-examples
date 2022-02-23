import sys
import os

import argparse

import stanza


def main():
    args = parse_user_args()
    stanza_pipeline = setup_stanza(args.lang)

    input_file = os.path.realpath(args.input_file)
    output_file = os.path.realpath(args.output_file)

    # we gather the lines in chunks to make the lemmatization faster by passing several lines
    # to stanza at once, but to not load all the corpus in memory.
    chunk = []
    chunk_size = args.chunk_size
    with open(input_file, 'r') as f_in, open(output_file, "w") as f_out:
        for line in f_in:
            tokens = line.strip().split()
            # stanza lemmatizer breaks if a line is passed as empty or blank, so we force it to
            # explicitly have at least one character
            if not tokens:
                tokens = ['\r']
            chunk.append(tokens)

            if len(chunk) < chunk_size:
                continue

            lemma_sents = lemmatize(stanza_pipeline, chunk)
            write_to_file(lemma_sents, f_out)
            chunk = []

        # also lemmatize last chunk in case we reached EOF
        if chunk:
            lemma_sents = lemmatize(stanza_pipeline, chunk)
            write_to_file(lemma_sents, f_out)


def setup_stanza(lang):
    stanza_dir = os.path.dirname(os.path.realpath(stanza.__file__))
    stanza_dir = os.path.join(stanza_dir, 'stanza_resources')
    stanza.download(lang=lang, model_dir=stanza_dir)
    # we assume that data is already received tokenized, thus tokenize_pretokenized = True
    return stanza.Pipeline(lang=lang,
                           dir=stanza_dir,
                           processors='tokenize,pos,lemma',
                           tokenize_pretokenized=True)


def lemmatize(pipeline, text_batch):
    doc = pipeline(text_batch)
    lemmatized_sentences = []
    for sentence in doc.sentences:
        lemmatized_sentences.append([word.lemma if word.lemma else word.text for word in sentence.words])
    return lemmatized_sentences


def write_to_file(sentences, f):
    for sentence in sentences:
        f.write(' '.join(sentence) + '\n')


def parse_user_args():
    parser = argparse.ArgumentParser(description='Lemmatize all words in the corpus')
    parser.add_argument('--lang', '-l', required=True,  help='language identifier')
    parser.add_argument('--input_file', '-i', required=True, help='input file path')
    parser.add_argument('--output_file', '-o', required=True, help='output file path')
    parser.add_argument('--chunk_size', type=int, default=1000, help='line chunk size to feed to the lemmatizer')
    return parser.parse_args()


if __name__ == "__main__":
    main()
