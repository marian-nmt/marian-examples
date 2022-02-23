import os
import argparse

from collections import defaultdict

def main():

    lines_annotated_counter = 0
    total_lines_counter = 0
    matches_counter = 0

    args = parse_user_args()

    source_file = os.path.realpath(args.source_file)
    target_file = os.path.realpath(args.target_file)
    glossary_file = os.path.realpath(args.glossary)
    output_file = os.path.realpath(args.output_file)

    factor_prefix = args.factor_prefix
    test_mode = args.test

    with open(glossary_file) as glossary_f:
        glossary, longest_source_length = read_glossary(glossary_f)

    with open(source_file, 'r') as source_f, \
         open(target_file, 'r') as target_f, \
         open(output_file, 'w') as output_f:
            for source_line, target_line in zip (source_f, target_f):
                source_line = source_line.strip().split()
                target_line = target_line.strip().split()
                matches = find_glossary_matches(source_line, target_line, glossary, longest_source_length, test_mode)
                source_line = annotate(source_line, matches, factor_prefix)
                output_f.write(' '.join(source_line) + '\n')
                lines_annotated_counter, total_lines_counter, matches_counter = update_counters(matches, lines_annotated_counter, total_lines_counter, matches_counter)

    print(f"Annotated {lines_annotated_counter/total_lines_counter*100:.2f}% lines, with a total of {matches_counter} annotations. {matches_counter/lines_annotated_counter:.2f} annotations per line")


def read_glossary(glossary_file):
    # skip header line
    assert next(glossary_file) is not None

    glossary = defaultdict(set)
    longest_source_length = 0

    for line in glossary_file:
        fields = line.split('\t')
        # the glossaries matches are done lowercased
        source = tuple(fields[0].lower().split())
        target = tuple(fields[-1].lower().split())
        if not len(source) > 10:
            glossary[source].add(target)
            if len(source) > longest_source_length:
                longest_source_length = len(source)
    return glossary, longest_source_length


def find_n_gram(sentence, n_gram, used):
  length = len(n_gram)
  for i in range(len(sentence) - length + 1):
    if tuple(sentence[i : i + length]) == tuple(n_gram):
      if not any(used[i : i + length]):
        return i
  return None


def find_glossary_matches(source_sentence, target_sentence, glossary, max_length, test_mode):
    matches = []
    source_used = [False for _ in source_sentence]
    target_used = [False for _ in target_sentence]

    # lower case sentences to find the matches
    source_sentence = tuple([x.lower() for x in source_sentence])
    target_sentence = tuple([x.lower() for x in target_sentence])

    # We loop over source spans, starting with the longest ones and going down to unigrams
    for length in range(max_length, -1, -1):
        for source_n_gram_idx in range(0, len(source_sentence) - length + 1):
            source_n_gram = tuple(source_sentence[source_n_gram_idx : source_n_gram_idx + length])
            # If any of the source words have already matched a glossary entry then
            # they're not allowed to match another one
            if any(source_used[source_n_gram_idx : source_n_gram_idx + length]):
                continue
            if source_n_gram in glossary:
                #if we aren't annotating a file for inference, we also check if the term's translation appears in the target side.
                if not test_mode:
                    for target_n_gram in glossary[source_n_gram]:
                        target_n_gram_idx = find_n_gram(target_sentence, target_n_gram, target_used)
                        if target_n_gram_idx != None:
                            for i in range(target_n_gram_idx, target_n_gram_idx + len(target_n_gram)):
                                target_used[i] = True
                            break
                    else:
                        # if the target was not found do not annotate
                        target_n_gram = None
                else:
                    target_n_gram = next(iter(glossary[source_n_gram]))

                if target_n_gram:
                    matches.append((source_n_gram, source_n_gram_idx,  target_n_gram))
                    for i in range(source_n_gram_idx, source_n_gram_idx + len(source_n_gram)):
                        source_used[i] = True
    return matches


def annotate(source, matches, factor_prefix):
    '''
    Adds factors to the source based on the matches obtained

    Ex I|p0 bought|p0 a|p0 car|p1 carro|p2
    '''
    matches = sorted(matches, key=lambda match: match[1], reverse=True)
    source = [word + '|%s0' % factor_prefix for word in source]
    for match in matches:
        source_term_gram, source_start, target_term_gram = match
        source_end = source_start + len(source_term_gram)

        target_term_gram = [word + '|%s2' % factor_prefix for word in target_term_gram]

        for i in range(source_start, source_end):
            source[i] = source[i][:-1] + '1'
        source[source_end : source_end] = target_term_gram
    return source


def update_counters(matches, lines_annotated_counter, total_lines_counter, matches_counter):
    total_lines_counter += 1
    if matches:
        lines_annotated_counter += 1
        matches_counter += len(matches)
    return lines_annotated_counter, total_lines_counter, matches_counter


def parse_user_args():
    parser = argparse.ArgumentParser(description="Adds glossary annotations to the source")
    parser.add_argument('-s', '--source_file', help="source file path", required=True)
    parser.add_argument('-t', '--target_file', help="target file path", required=True)
    parser.add_argument('-o', '--output_file', help="output file path", required=True)
    parser.add_argument('-g', '--glossary', help="Glossary file path", required=True)
    parser.add_argument('--factor_prefix', type=str, default='p', help="prefix for the terminology factors. Factors vocab will be [|prefix0, |prefix1, |prefix2]")
    parser.add_argument('--test', action='store_true', help="Annotate in test mode, so the term in not checked to appear in the target")
    return parser.parse_args()


if __name__ == "__main__":
    main()
