# infra: the repository layout and why one directory per environment

Read when you place a new module, environment root, overlay, alert or dashboard.

```
modules/<name>/           main.tf variables.tf outputs.tf versions.tf, one concern each
envs/{dev,qa,prod}/       main.tf backend.tf variables.tf outputs.tf terraform.tfvars.example
k8s/base/                 kustomization.yaml deployment service pdb hpa
k8s/overlays/{dev,qa,prod}/  kustomization.yaml: namespace, replicas, image tag or digest
monitoring/alerts/        Prometheus rule files, every alert with runbook_url
monitoring/dashboards/    Grafana dashboard JSON, one file per service
scripts/                  bash, shellcheck clean; plan.sh is the only plan entry point
docs/runbooks/            one runbook per alert (runbook), linked from the rule
Makefile                  the only entry point: help setup init plan check fix doctor
```

Directory-per-environment rather than workspaces: each environment has its
own state, backend prefix, credentials, variable values and pipeline job,
so a wrong `workspace select` cannot plan dev values against prod state, an
MR diff shows exactly which environment changes, and environments can pin
different module versions during a rollout.
