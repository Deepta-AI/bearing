"""In-memory stand-ins for the endpoints, with a fake clock the test advances."""


class Clock:
    def __init__(self):
        self.t = 0.0

    def __call__(self):
        return self.t

    def advance(self, ms):
        self.t += ms / 1000


class FakeASR:
    def __init__(self, clock, text="i want to book for tomorrow", delay_ms=150):
        self.clock, self.text, self.delay_ms = clock, text, delay_ms
        self.calls = 0

    async def transcribe(self, frames):
        self.calls += 1
        self.clock.advance(self.delay_ms)
        return self.text


class FakeLLM:
    def __init__(self, clock, reply="Sure. Which doctor would you like to see? Morning or evening?", delay_ms=900):
        self.clock, self.reply, self.delay_ms = clock, reply, delay_ms
        self.cancelled = False

    async def complete(self, messages):
        self.clock.advance(self.delay_ms)
        return self.reply

    async def stream(self, messages):
        for i, word in enumerate(self.reply.split(" ")):
            self.clock.advance(self.delay_ms / 3 if i == 0 else 20)
            yield word + " "


class FakeTTS:
    def __init__(self, clock, per_sentence_ms=250):
        self.clock, self.per_sentence_ms = clock, per_sentence_ms

    async def synthesize(self, text):
        sentences = [s for s in text.replace("?", ".").split(".") if s.strip()]
        self.clock.advance(self.per_sentence_ms * len(sentences))
        return [s.strip().encode() for s in sentences]

    async def stream(self, text):
        for s in [s for s in text.replace("?", ".").split(".") if s.strip()]:
            self.clock.advance(self.per_sentence_ms)
            yield s.strip().encode()


class FakePlayer:
    def __init__(self, clock, chunk_ms=600):
        self.clock, self.chunk_ms = clock, chunk_ms
        self.played = []
        self.stopped = False

    async def play(self, chunk):
        self.clock.advance(self.chunk_ms)
        self.played.append(chunk)

    async def stop(self):
        self.stopped = True


def speech(n):
    return [{"speech": True, "ms": 20, "pcm": b"\x00" * 160}] * n


def silence(n):
    return [{"speech": False, "ms": 20, "pcm": b"\xff" * 160}] * n
