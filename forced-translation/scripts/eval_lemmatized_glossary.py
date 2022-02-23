import os
import argparse

import stanza

def main():

    total_terms = 0
    correct_terms = 0

    args = parse_user_args()

    source_fact_file = os.path.realpath(args.source_file)
    hypothesis_file = os.path.realpath(args.hypothesis_file)

    factor_prefix = args.factor_prefix
    tgt_lang = args.tgt_lang

    lemmatizer = setup_stanza(tgt_lang)

    with open(source_fact_file, 'r') as source_f, \
         open(hypothesis_file, 'r') as hyps_f:
        for source_line, hyps_line in zip(source_f, hyps_f):
            # we lower case everything prior to lemmatize because sometimes the lemmatizer is sensible to casing
            hyps_line = hyps_line.strip().lower().split()
            hyps_lemmatized = lemmatize(lemmatizer, hyps_line)
            hyps_lemmatized = ' '.join(hyps_lemmatized)

            source_line = source_line.strip().lower().split()
            expected_terms = get_expected_terms(source_line, factor_prefix)

            for term in expected_terms:
                total_terms += 1
                term_lemmatized = lemmatize(lemmatizer, term)
                term_lemmatized = ' '.join(term_lemmatized)

                if term_lemmatized in hyps_lemmatized:
                    correct_terms += 1

    print(f"Lemmatized term exact match accuracy: {correct_terms/total_terms*100:.2f} %")


def setup_stanza(lang):
    stanza_dir = os.path.dirname(os.path.realpath(stanza.__file__))
    stanza_dir = os.path.join(stanza_dir, 'stanza_resources')
    stanza.download(lang=lang, model_dir=stanza_dir)
    # we assume that data is already received tokenized, thus tokenize_pretokenized = True
    return stanza.Pipeline(lang=lang,
                           dir=stanza_dir,
                           processors='tokenize,pos,lemma',
                           tokenize_pretokenized=True)



def lemmatize(pipeline, sentence):
    # stanza lemmatizer breaks if a line is passed as empty or blank, so we force it to
    # explicitly have at least one character
    if not sentence:
        sentence = ['\r']
    doc = pipeline([sentence])
    return [word.lemma if word.lemma else word.text for word in doc.sentences[0].words]


def get_expected_terms(toks, factor_prefix):
    target_factor = factor_prefix + '2'
    matches = []
    match = []
    for tok in toks:
        lemma, factor = tok.split('|')
        if factor == target_factor:
            match.append(lemma)
        else:
            if match:
                matches.append(match)
                match = []
    # also add last match in case we reached end of line
    if match:
        matches.append(match)
        match = []
    return matches


def parse_user_args():
    parser = argparse.ArgumentParser(description="Computes lemmatized term exact match accuracy")
    parser.add_argument('-s', '--source_file', help="source file path. Should already have the factors.", required=True)
    parser.add_argument('-hyps', '--hypothesis_file', help="hypothesis file path", required=True)
    parser.add_argument('--factor_prefix', type=str, default='p', help="prefix for the terminology factors.")
    parser.add_argument('-tl', '--tgt_lang', help="target language identifier", required=True)
    return parser.parse_args()


if __name__ == "__main__":
    main()
