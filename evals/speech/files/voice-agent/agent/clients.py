"""Clients for the speech recognition, model and speech synthesis endpoints.

Each client offers a one-shot call and a streaming call. The loop only uses
the one-shot calls today.
"""

import json
import urllib.request

from agent import config


class ASRClient:
    def __init__(self, url):
        self.url = url

    async def transcribe(self, frames):
        body = b"".join(f["pcm"] for f in frames)
        req = urllib.request.Request(self.url, data=body, method="POST")
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.load(resp)["text"]


class LLMClient:
    def __init__(self, url):
        self.url = url

    async def complete(self, messages):
        """The whole reply, returned once the model has finished."""
        req = urllib.request.Request(
            self.url,
            data=json.dumps({"messages": messages, "region": config.MODEL_REGION}).encode(),
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.load(resp)["text"]

    async def stream(self, messages):
        """Yield the reply in text chunks as the model produces them."""
        req = urllib.request.Request(
            self.url + "?stream=1",
            data=json.dumps({"messages": messages, "region": config.MODEL_REGION}).encode(),
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            for line in resp:
                if line.strip():
                    yield json.loads(line)["delta"]


class TTSClient:
    def __init__(self, url):
        self.url = url

    async def synthesize(self, text):
        """All audio chunks for the text, returned once synthesis has finished."""
        req = urllib.request.Request(self.url, data=text.encode(), method="POST")
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read()
        return [data[i : i + 1600] for i in range(0, len(data), 1600)]

    async def stream(self, text):
        """Yield audio chunks as soon as each is synthesised."""
        req = urllib.request.Request(self.url + "?stream=1", data=text.encode(), method="POST")
        with urllib.request.urlopen(req, timeout=30) as resp:
            while chunk := resp.read(1600):
                yield chunk
