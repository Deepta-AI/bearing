"""One CallSession per phone call: listen, recognise, ask the model, speak."""

import json
import time

from agent import config


class CallSession:
    def __init__(self, asr, llm, tts, player, log_path=config.TURN_LOG, clock=time.monotonic):
        self.asr = asr
        self.llm = llm
        self.tts = tts
        self.player = player
        self.log_path = log_path
        self.clock = clock
        self.history = [{"role": "system", "content": config.SYSTEM_PROMPT}]
        self.frames = []
        self.in_speech = False
        self.silence_ms = 0
        self.speech_end = None
        self.playing = False
        self.turns = 0

    def now_ms(self):
        return round(self.clock() * 1000)

    async def on_frame(self, frame):
        """Handle one 20 ms frame of caller audio.

        frame: {"speech": bool (from the VAD), "ms": int, "pcm": bytes}
        """
        if self.playing:
            # The agent is talking; caller audio is ignored until it finishes.
            return
        if frame["speech"]:
            self.in_speech = True
            self.silence_ms = 0
            self.frames.append(frame)
            return
        if not self.in_speech:
            return
        if self.silence_ms == 0:
            self.speech_end = self.now_ms()
        self.silence_ms += frame["ms"]
        if self.silence_ms >= config.ENDPOINT_SILENCE_MS:
            self.in_speech = False
            self.silence_ms = 0
            await self.respond()

    async def respond(self):
        self.turns += 1
        marks = {"turn": f"turn-{self.turns}", "speech_end": self.speech_end}
        text = await self.asr.transcribe(self.frames)
        self.frames = []
        marks["asr_final"] = self.now_ms()
        self.history.append({"role": "user", "content": text})

        reply = await self.llm.complete(self.history)
        marks["llm_first_token"] = self.now_ms()
        self.history.append({"role": "assistant", "content": reply})

        audio = await self.tts.synthesize(reply)
        marks["tts_first_audio"] = self.now_ms()

        self.playing = True
        for chunk in audio:
            await self.player.play(chunk)
        self.playing = False
        self.log(marks)

    def log(self, marks):
        with open(self.log_path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(marks) + "\n")
