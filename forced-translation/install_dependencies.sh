#!/bin/bash -e

cd tools
# clone moses
git clone https://github.com/marian-nmt/moses-scripts

# clone and build fast_align
git clone https://github.com/clab/fast_align.git
cd fast_align
mkdir build && cd build
cmake ..
make
