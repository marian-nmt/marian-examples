# Example: Marian as a library

This serves as a minimal example of a CMake project with a [marian][marian]
dependency. The dependency to Marian in that repository is facilitated by a
submodule to [marian-dev]. The complete code is available from the
[marian-example-library] repository.


## Usage

### Compile
```shell
git clone https://github.com/marian-nmt/marian-example-library
cd marian-example-library
mkdir build
cd build
cmake ..
cmake --build .
```

### Run
```shell
./example
```

## About this example
The code in [src/main.cpp](src/main.cpp) builds a simple expression graph using
Marian. It mirrors the example found in Marian's [developer
documentation][dev_docs].

The expression graph represents `z = x*y + sin(x)`, with an absolute-error
applied to `z` as a loss function. It performs a forward and backward
evaluation of the graph, and a single update of the graph parameters from a
`Stochastic Gradient Descent` optimizer. Following the example, `x` takes the
place of a learnable parameter.

After the parameter update, the graph parameters are saved to
`example-model.npz`. You can inspect its contents with
[`script/read-npz.py`](/script/read-npz.py).

Please refer to the [marian][marian] project for further documentation.

## About this repository
There are example CI builds available for
  - Ubuntu
  - MacOS
  - Windows

These compile and run the example executable.

Additionally, the Marian submodule is updatable via dependabot.

<!-- Links -->
[marian]: https://marian-nmt.github.io/
[marian-dev]: https://github.com/marian-nmt/marian-dev
[marian-example-library]: https://github.com/marian-nmt/marian-example-library
[dev_docs]: https://marian-nmt.github.io/docs/api/graph.html
