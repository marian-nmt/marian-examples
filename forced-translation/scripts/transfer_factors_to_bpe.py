import os
import argparse


def main():
    args = parse_user_args()

    factored_file = os.path.realpath(args.factored_corpus)
    bpeed_file = os.path.realpath(args.bpe_corpus)
    output_file = os.path.realpath(args.output_file)

    with open(factored_file, 'r', encoding='utf-8') as f_factored, \
         open(bpeed_file, 'r', encoding='utf-8') as f_bpeed, \
         open(output_file, 'w', encoding='utf-8') as f_output:

         for l_fact, l_bpe in zip(f_factored, f_bpeed):

            l_fact_toks = l_fact.strip().split()
            l_bpe_toks = l_bpe.strip().split()

            l_bpe_factors = []

            fact_toks_idx = 0
            for bpe_tok in l_bpe_toks:
                current_factor = get_factor(l_fact_toks[fact_toks_idx])
               	if bpe_tok[-2:] != '@@':
                    fact_toks_idx += 1
                l_bpe_factors.append(bpe_tok+current_factor)

            if len(l_bpe_toks) != len(l_bpe_factors):
                raise Exception('Unequal number of bpe tokens in original bpe line {} and factored bpe line {}'
                                .format(l_bpe_toks, l_bpe_factors))

            f_output.write(' '.join(l_bpe_factors) + '\n')


def get_factor(token):
    separator_idx = token.index("|")
    return token[separator_idx:]


def parse_user_args():
    parser = argparse.ArgumentParser(description='Extend BPE splits to factored corpus')
    parser.add_argument('--factored_corpus', required=True, help='File with factors')
    parser.add_argument('--bpe_corpus', required=True, help='File with bpe splits')
    parser.add_argument('--output_file', '-o', required=True, help='output file path')
    return parser.parse_args()


if __name__ == "__main__":
    main()
