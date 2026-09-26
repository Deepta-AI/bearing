"""Settings for the booking agent."""

# Silence after the caller's last speech frame before the turn is treated as finished.
ENDPOINT_SILENCE_MS = 1200

# Media stream settings sent to the telephony provider when the call connects.
MEDIA = {
    "encoding": "mulaw",
    "sample_rate": 8000,
    "echo_cancellation": False,
}

# Region of the model and TTS endpoints. The telephony edge is in ap-south.
MODEL_REGION = "us-east"

SYSTEM_PROMPT = (
    "You are the booking assistant for a clinic. Help the caller book, move or "
    "cancel an appointment. Keep answers short."
)

TURN_LOG = "logs/turns.jsonl"
