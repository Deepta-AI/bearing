# Serving a trained adapter with vLLM

Written by llm-fine-tuning for `<name>`. Fill the placeholders; keep the
commands in `docs/genai/training-<name>.md` beside the run plan.

## What goes in this file

The base checkpoint, the adapter path, the host that serves, the command
that starts vLLM, the gateway entry, and the check that proves the
gateway reaches it. Good looks like: a person can start serving from this
file alone, and `llm_access_check.py --live` prints the model as ready.

## Start the server

```
vllm serve <base checkpoint> \
  --enable-lora \
  --lora-modules <name>-v1=runs/<name>/full \
  --max-lora-rank 16 \
  --host 0.0.0.0 --port 8000 \
  --api-key "$VLLM_API_KEY"
```

vLLM speaks the OpenAI-compatible API at `http://<host>:8000/v1`. The
model id the gateway sends is the LoRA module name (`<name>-v1`).
Check the GPU first: `gpu_check.py --params-b <p> --method infer`.

## Gateway entry (llm/routing.yaml)

```
models:
  <name>-v1:
    provider: vllm
    base_url: ${LLM_VLLM_URL}        # http://<host>:8000/v1
    input_per_m: 0.00                 # your GPU cost per million tokens, estimated
    output_per_m: 0.00

routes:
  <feature>_v2:
    model: <name>-v1
    canary: 5
    fallback: { route: <feature> }    # the API model stays the fallback
```

## Prove it

```
python3 <kit>/skills/llm-gateway/scripts/llm_access_check.py --routing llm/routing.yaml --live
make eval EVAL=<name>                 # the same eval, now through the served model
```

The canary rises only when the eval on sampled traffic stays at or above
the prompt-only score and the error rate stays flat.

## Other places to run

- Hugging Face Jobs (paid plan): `huggingface-llm-trainer` writes and
  submits the TRL job; bring the adapter back here to serve.
- Your own GPUs without this template: `trl-training` (the TRL CLI).
- SageMaker: `hf-cloud-serving-image-selection` and
  `hf-cloud-sagemaker-production-defaults` pick the container and the
  autoscaling; point the gateway's `base_url` at the endpoint.
