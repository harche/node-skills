---
name: node
description: "OpenShift Node team assistant for development and deployment tasks. Covers kubelet, Machine Config Operator (MCO), CRI-O, crun, conmonrs, and OpenShift Kueue operator. Use this skill whenever the user asks about building or deploying any OpenShift node component — even if they don't say 'node team' explicitly. Triggers on mentions of kubelet, MCO, MachineConfig, CRI-O, crun, conmonrs, Kueue operator, debug binary deployment, layered images, or any OpenShift node-layer development workflow."
---

## How to use this skill

Reference files contain only **tribal knowledge and non-obvious nuances** — things you cannot learn by reading the source code. For everything else (build commands, repo layout, dependencies, test targets, configuration options), **browse the repo directly**:

- If the repo is the current working directory, use Glob/Grep/Read.
- If not, use `gh` for quick lookups, or clone into `/tmp` for in-depth exploration (faster local lookups, no rate limits).

1. Identify which domain the user's question falls into using the index below
2. Read ONLY the relevant reference file for nuances and team-specific context
3. For discoverable details, go to the source code

## Index

Root: `./references/`

```
|development:{kubelet-dev.md,mco-dev.md,crio-dev.md,crun-conmon.md,kueue-operator-dev.md}
|deployment:{debug-binary.md}
```

## Scripts

Helper scripts are available at `${CLAUDE_PLUGIN_ROOT}/scripts/`. Reference files will tell you which scripts to use and when. Do not run scripts without reading the relevant reference file first.
