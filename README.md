# Marian examples

Examples, tutorials and use cases for the Marian toolkit.

More information on https://marian-nmt.github.io

## Examples

* `transformer-intro` -- an introduction to training your first transformer model if you are new to Marian and NMT
* `translating-amun` -- examples for translating with Amun
* `training-basics` -- the complete example for training a WMT16-scale model
* `training-basics-sentencepiece` -- as `training-basics`, but uses built-in SentencePiece for data processing, requires Marian v1.7+
* `transformer` -- scripts for training the transformer model
* `wmt2017-uedin` -- building a WMT2017-grade model for en-de based on Edinburgh's WMT2017 submission
* `wmt2017-transformer` -- building a better than WMT2017-grade model for en-de, beating WMT2017 submission by 1.2 BLEU
* `wmt2017-transformer` -- building a better than WMT2017-grade model for en-de, beating WMT2017 submission by 1.2 BLEU
* `forced-translation` -- an example showing how to apply forced translation using bilingual terminology dictionary

## Templates

* `example-library` -- example using Marian as a library demonstrating basic graph operations, available as a repository [template](https://github.com/marian-nmt/marian-example-library/generate)

### Usage

First download common tools:
```shell
cd tools
make all
cd ..
```

Next, go to the chosen directory and run `run-me.sh`, e.g.:
```shell
cd training-basics
./run-me.sh
```

The README file in each directory provides more detailed description.

## Acknowledgements

The development of Marian received funding from the European Union's
_Horizon 2020 Research and Innovation Programme_ under grant agreements
688139 ([SUMMA](http://www.summa-project.eu); 2016-2019),
645487 ([Modern MT](http://www.modernmt.eu); 2015-2017),
644333 ([TraMOOC](http://tramooc.eu/); 2015-2017),
644402 ([HiML](http://www.himl.eu/); 2015-2017),
the European Union's Connecting Europe Facility project
2019-EU-IA-0045 ([User-focused Marian](https://marian-project.eu); 2020-2022),
the Amazon Academic Research Awards program, and
the World Intellectual Property Organization.

This software contains source code provided by NVIDIA Corporation.
