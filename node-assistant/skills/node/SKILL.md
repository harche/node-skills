---
name: node
description: "OpenShift Node team assistant for development, deployment, testing, debugging, documentation, release, and workflow tasks. Covers kubelet, Machine Config Operator (MCO), CRI-O, crun, conmonrs, and OpenShift Kueue operator. Use this skill whenever the user asks about building, testing, deploying, or debugging any OpenShift node component — even if they don't say 'node team' explicitly. Triggers on mentions of kubelet, MCO, MachineConfig, CRI-O, crun, conmonrs, Kueue operator, RHCOS, must-gather, debug binary deployment, layered images, node e2e tests, Prow CI jobs, z-stream, backports, or any OpenShift node-layer development workflow. Also triggers on Jira issues (OCPNODE-*, OCPBUGS-*), Red Hat Knowledge Base, support cases, Prometheus metrics/PromQL, or Kubernetes/OpenShift documentation lookups."
---

## How to use this skill

1. Read [references/INDEX.md](references/INDEX.md) to find the relevant reference file
2. Read ONLY that reference file for tribal knowledge and team-specific context
3. For discoverable details (build commands, repo layout, test targets), browse the source code directly

If the repo is the current working directory, use Glob/Grep/Read. If not, use `gh` for quick lookups or clone for in-depth exploration.

## Scripts

Helper scripts are available at `${CLAUDE_PLUGIN_ROOT}/scripts/`. Reference files will tell you which scripts to use and when. Do not run scripts without reading the relevant reference file first.
