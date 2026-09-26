import asyncio
import json

from agent import config
from agent.loop import CallSession
from tests.fakes import Clock, FakeASR, FakeLLM, FakePlayer, FakeTTS, silence, speech


def make(tmp_path):
    clock = Clock()
    s = CallSession(
        FakeASR(clock), FakeLLM(clock), FakeTTS(clock), FakePlayer(clock),
        log_path=str(tmp_path / "turns.jsonl"), clock=clock,
    )
    return s, clock


async def feed(session, clock, frames):
    for f in frames:
        clock.advance(f["ms"])
        await session.on_frame(f)


def test_turn_ends_after_endpoint_silence(tmp_path):
    s, clock = make(tmp_path)
    frames = speech(50) + silence(config.ENDPOINT_SILENCE_MS // 20)
    asyncio.run(feed(s, clock, frames))
    assert s.asr.calls == 1
    assert s.player.played


def test_short_pause_does_not_end_turn(tmp_path):
    s, clock = make(tmp_path)
    asyncio.run(feed(s, clock, speech(30) + silence(10) + speech(30)))
    assert s.asr.calls == 0


def test_turn_logged_with_all_marks(tmp_path):
    s, clock = make(tmp_path)
    asyncio.run(feed(s, clock, speech(50) + silence(config.ENDPOINT_SILENCE_MS // 20)))
    row = json.loads((tmp_path / "turns.jsonl").read_text().splitlines()[0])
    for mark in ("speech_end", "asr_final", "llm_first_token", "tts_first_audio"):
        assert isinstance(row[mark], int)
    assert row["speech_end"] <= row["asr_final"] <= row["llm_first_token"] <= row["tts_first_audio"]
