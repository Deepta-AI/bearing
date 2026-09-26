# Fine-tuned ticket classifier on vLLM

The ML team trained `ticket-classifier-v1` (LoRA on Qwen3-1.7B). Ops
serves it with vLLM on the GPU box, OpenAI-compatible API, model id
`ticket-classifier-v1`.

- The base URL (ending in `/v1`) will be in `LLM_VLLM_URL` on every
  environment that should use it. Ops sets it; do not hard-code a host.
- No API key on the internal network.
- Rollout: 5 percent of `ticket_classify` traffic first. The Haiku route
  stays in place and must answer if the vLLM box is down.
- Cost: the GPU box is a fixed cost; ops asks that calls are recorded
  at 0.02 USD per million input and 0.04 USD per million output tokens.
