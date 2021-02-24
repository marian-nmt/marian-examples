import argparse
import json
from websocket import create_connection
import requests
from flask import Flask, jsonify, request
import sys

app = Flask(__name__)

parser = argparse.ArgumentParser()
parser.add_argument('--tm-server', type=str, default="http://localhost:8088")
parser.add_argument('--marian-server', type=str, default="ws://localhost:8089")
parser.add_argument('--port', type=int, default=8087)
args = parser.parse_args()


@app.route('/translate', methods=['POST'])
def translate():
    # {'meta': {'uid': 'name', 'language': 'en'}, 'input': 'hello world'}
    req = request.json
    context = __fetch_context(args.tm_server, req)
    sys.stderr.write(f"src: {req['input']}, context: {context} \n")
    marian_output = __call_marian(args.marian_server, req['input'], context)
    return jsonify(marian_output), 201


@app.route('/save', methods=['POST'])
def add_sentence():
    # {'meta': {'uid': 'name', 'language': 'en'}, 'source': 'hello world', 'target': 'sveika pasaule'}
    req = request.json
    result = requests.post(args.tm_server + "/save", json=req).json()
    return jsonify(result), 201


@app.route('/delete', methods=['POST'])
def drop_index():
    # {'uid': 'name'}
    req = request.json
    result = requests.post(args.tm_server + "/delete", json=req).json()

    return jsonify(result), 201


def __call_marian(url, input, context):
    ws = create_connection(url + '/translate')

    if any(c == "" for c in context):
        ws.send(json.dumps({'input': input}))
    else:
        ws.send(json.dumps({'input': input, 'context': [context]}))

    result = ws.recv()
    ws.close()
    result_json = json.loads(result.strip())
    return result_json


def __fetch_context(url, req):
    result = requests.post(url + "/get", json=req).json()
    return ["\n".join(result["sourceContext"]), "\n".join(result["targetContext"])]


app.run(debug=True, port=args.port, host='0.0.0.0')
