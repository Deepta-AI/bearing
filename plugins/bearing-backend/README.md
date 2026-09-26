# bearing-backend

An optional plugin of the Bearing marketplace: stack conventions and
scaffold templates for backend and platform code.

## What it contains

`skills/`: 5 stack skills, each with its guidelines, review checklist and
repository templates:

- `go`: Go services and CLIs
- `python`: Python services and CLIs
- `node`: Node services
- `data-pipeline`: dbt and Airflow pipelines
- `infra`: Terraform and Kubernetes

Call them as `/bearing-backend:<name>`; the workflow skills in `bearing`
load them when a repository uses the stack.

## Install

Inside Claude Code:

```
/plugin marketplace add Deepta-AI/bearing
/plugin install bearing@bearing
/plugin install bearing-backend@bearing
```

`bearing` is required; this plugin needs it. `bearing-backend` and
`bearing-apps` are optional: install the ones your repositories use.

## More

Documentation, the installer and the source: <https://github.com/Deepta-AI/bearing>.
Licence: MIT (see `LICENSE`).
