import json
from websocket import create_connection

def translate(data, port=8080):
    ws = create_connection("ws://localhost:{}/translate".format(port))
    ws.send(data)
    result = ws.recv()
    ws.close()
    return result.rstrip()


if __name__ == "__main__":

    srcLine = "this is a pre-process@@ ed source langu@@ age side example sentence for Adap@@ tive Mar@@ ian"

    contSrc = "\n".join(["this is a pre-process@@ ed source langu@@ age side context sentence 1", "another sentence"] )
    contTrg = "\n".join(["šis ir priekš@@ aprstrā@@ dāts avot@@ valodas konteksta teikums", "vēl viens"] )

    contexts = [[contSrc, contTrg]]
    input_data = {'input': srcLine, 'context': contexts}
    input_json = json.dumps(input_data)
    output_json = translate(input_json)
    output_data = json.loads(output_json)
    print(output_data['output'].replace("@@ ", ""))
