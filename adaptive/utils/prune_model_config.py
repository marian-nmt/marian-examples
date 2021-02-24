import sys
import yaml
import argparse
import shutil
from pathlib import Path


def prune(model_config_file, decoder_config_file):
    whitelist = {"model", "vocabs", "log-level", "quiet", "quiet-translation", "seed", "clip-gemm",
                 "interpolate-env-vars", "relative-paths", "type", "dim-vocabs", "dim-emb", "dim-rnn", "enc-type",
                 "enc-cell", "enc-cell-depth", "enc-depth", "dec-cell", "dec-cell-base-depth", "dec-cell-high-depth",
                 "dec-depth", "skip", "layer-normalization", "right-left", "best-deep", "tied-embeddings",
                 "tied-embeddings-src", "tied-embeddings-all", "transformer-heads", "transformer-no-projection",
                 "transformer-dim-ffn", "transformer-ffn-depth", "transformer-ffn-activation", "transformer-dim-aan",
                 "transformer-aan-depth", "transformer-aan-activation", "transformer-aan-nogate",
                 "transformer-decoder-autoreg", "transformer-tied-layers", "transformer-guided-alignment-layer",
                 "transformer-preprocess", "transformer-postprocess-emb", "transformer-postprocess", "dropout-rnn",
                 "dropout-src", "dropout-trg", "grad-dropping-rate", "grad-dropping-momentum", "grad-dropping-warmup",
                 "transformer-dropout", "transformer-dropout-attention", "transformer-dropout-ffn", "cost-type",
                 "overwrite", "no-reload", "after-epochs", "after-batches", "disp-freq", "disp-label-counts",
                 "save-freq",
                 "max-length", "max-length-crop", "no-shuffle", "no-restore-corpus", "tempdir", "sqlite", "sqlite-drop",
                 "cpu-threads", "mini-batch", "mini-batch-words", "maxi-batch", "maxi-batch-sort", "optimizer",
                 "optimizer-params", "optimizer-delay", "sync-sgd", "learn-rate", "lr-report", "lr-decay",
                 "lr-decay-strategy", "lr-decay-start", "lr-decay-freq", "lr-decay-reset-optimizer",
                 "lr-decay-repeat-warmup", "lr-decay-inv-sqrt", "lr-warmup", "lr-warmup-start-rate", "lr-warmup-cycle",
                 "lr-warmup-at-reload", "label-smoothing", "clip-norm", "exponential-smoothing",
                 "guided-alignment-cost",
                 "guided-alignment-weight", "data-weighting-type", "embedding-normalization", "embedding-fix-src",
                 "embedding-fix-trg", "multi-node", "multi-node-overlap", "beam-size", "normalize", "max-length-factor",
                 "word-penalty", "allow-unk", "n-best"}

    decoder_config = yaml.load(decoder_config_file, Loader=yaml.FullLoader)
    model = Path(decoder_config["models"][0])
    vocabs = [Path(x) for x in decoder_config["vocabs"]]

    model_config = yaml.load(model_config_file, Loader=yaml.FullLoader)

    # Some Marian versions produce lr-decay-inv-sqrt as a list
    if "lr-decay-inv-sqrt" in model_config and type(model_config["lr-decay-inv-sqrt"]) is list:
        model_config["lr-decay-inv-sqrt"] = model_config["lr-decay-inv-sqrt"][0]

    pruned_config = {k: v for k, v in model_config.items() if k in whitelist}
    pruned_config["relative-paths"] = "true"

    # Copy model and vocabs to config dir
    if not Path(model.name).exists():
        shutil.copy2(model, model.name)
    pruned_config["model"] = model.name

    for vocab in vocabs:
        if not Path(vocab.name).exists():
            shutil.copy2(vocab, vocab.name)

    pruned_config["vocabs"] = [v.name for v in vocabs]

    model_config_file.close()
    yaml.dump(pruned_config, sys.stdout)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("model_npz_yml", type=argparse.FileType('r'))
    parser.add_argument("decoder_yml", type=argparse.FileType('r'))
    args = parser.parse_args()
    prune(args.model_npz_yml, args.decoder_yml)
