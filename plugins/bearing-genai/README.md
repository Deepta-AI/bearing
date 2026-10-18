# bearing-genai

An optional plugin of the Bearing marketplace: skills for products that call
a model, retrieve over documents, run agents, or train and serve ML models.

## What it contains

`skills/`: 12 skills (the GenAI flow's later tasks add more):

- `genai-design`: the solution design for a product that calls a model
- `rag`: retrieval over documents
- `llm-agent`: agents and their tools
- `llm-eval`: evaluation sets, graders and judges
- `llm-fine-tuning`: when and how to tune a model
- `llm-gateway`: one place every model call goes through
- `llm-guardrails`: input and output checks
- `prompt-registry`: versioned prompts
- `speech`: speech to text and text to speech
- `mcp-server`: Model Context Protocol servers
- `computer-vision`: image and video models
- `tabular-ml`: models over structured data

Call them as `/bearing-genai:<name>`; the workflow skills in `bearing`
load them when a repository calls a model.

## Install

Inside Claude Code:

```
/plugin marketplace add Deepta-AI/bearing
/plugin install bearing@bearing
/plugin install bearing-genai@bearing
```

`bearing` is required; this plugin needs it.

## More

Documentation, the installer and the source: <https://github.com/Deepta-AI/bearing>.
Licence: MIT (see `LICENSE`).
