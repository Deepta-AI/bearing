"""The one function the booking service calls to turn a call recording into text."""

import os

ENGINE = os.environ.get("ASR_ENGINE", "engine_b")


def transcribe(audio_path: str, lang_hint: str | None = None) -> str:
    """Return the transcript of one call recording.

    The engine client is not wired up yet; ENGINE picks which one it will be.
    """
    raise NotImplementedError(f"{ENGINE} client not wired up yet")
