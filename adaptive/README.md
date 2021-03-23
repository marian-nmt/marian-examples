# Marian NMT dynamic adaptation example

This repository aims to provide working  self-contained example of Marian NMT system with dynamic adaptation.

The example builds and runs as 3 Docker containers
* Marian adaptive server 
* Translation memory service
* Wrapper service

**Marian NMT dynamic adaptation** works by fine-tuning model on context - (source, target) sentence pairs.
So for each translation Marian requires the input text and context for fine-tuning.

**Translation memory** provides the context sentences for Marian. 
The current implementation: https://github.com/tilde-nlp/lucene-sentence-search/
Provides with functionality to:
* Store indexed (source, target) sentence pairs.
* Retrieve similar sentences by BLEU.
* Drop sentence pairs.
 
**Wrapper** is just an additional service that simplifies API by forwarding calls to Translation Memory and Marian. Wrapper
service also serves as a simple example how Translation Memory and Marian interacts.

## Prerequisites

The example is built and run with _Docker_  and _docker-compose_ v1.28.0+ https://docs.docker.com/compose/install/ it also requires nvidia-container-runtime https://github.com/NVIDIA/nvidia-container-runtime
and a machine equipped with Nvidia GPU.

## How to build and run example

First download model files by running `bash download_model.sh` in the repo root directory. <br>
Then build and start the services by `docker-compose up`.<br>
Which will then load the downloaded marian model and expose the API on port 8088.

## Configuration

Wrapper, Marian and Translation Memory startup parameters are defined in `docker-compose.yml`
By default it's configured to load downloaded example marian model in `./marian-model` and run on `GPU: 0`.

## API

Wrapper service exposes 3 actions:

* `/translate` Translate input sentence, context is fetched from TM.
* `/save` Save (source, target) sentence pair in TM by user ID.
* `/delete` Drop all saved sentences in index by user ID.

Wrapper API call examples:

````
curl \
--header "Content-Type: application/json" \
--request POST \
--data '{"input":"Hello World !","meta": {"uid": "Artūrs", "srclang": "en"}}' \
http://localhost:8088/translate


Response:
{
  "output": "Sveikas pasaulis !"
}
````

```
curl \
--header "Content-Type: application/json" \
--request POST \
--data '{"source":"Hello World !", "target": "Sveika pasaule !", "meta": {"uid": "Artūrs", "srclang": "en"}}' \
http://localhost:8088/save

Response: 
{
  "errorMessage": null,
  "status": "OK"
}
```

```
curl \
--header "Content-Type: application/json" \
--request POST \
--data '{"uid": "Artūrs"}' \
http://localhost:8088/delete

Response: 
{
  "errorMessage": null,
  "status": "OK"
}
```

## Using different Translation Memory

Marian itself does not depend on a specific Translation Memory implementation. Different ways of acquiring context can
be employed. An example implementation of how `marian-adpative` server is called can be found
in `wrapper_service/wrapper_service.py`

```
ws://localhost:80/translate

Sent:
{
    "input": "Hello world !",
    "context": [
        "Source context sentence 1\nSource context sentence 2\nSource context sentence 3",
        "Target context sentence 1\nTarget context sentence 2\nTarget context sentence 3"
    ]
}

Received:
{
  "output": "Sveikas pasaulis !"
}
```
