---
name: node
description: "OpenShift Node team assistant for development, deployment, testing, debugging, documentation, release, and workflow tasks. Covers kubelet, Machine Config Operator (MCO), CRI-O, crun, conmonrs, and OpenShift Kueue operator. Use this skill whenever the user asks about building, testing, deploying, or debugging any OpenShift node component — even if they don't say 'node team' explicitly. Triggers on mentions of kubelet, MCO, MachineConfig, CRI-O, crun, conmonrs, Kueue operator, RHCOS, must-gather, debug binary deployment, layered images, node e2e tests, Prow CI jobs, z-stream, backports, or any OpenShift node-layer development workflow."
---

## How to use this skill

This skill uses progressive disclosure. Do NOT read all reference files upfront. Instead:

1. Identify which domain the user's question falls into using the index below
2. Read ONLY the relevant domain-level reference file
3. That file will point you to deeper sub-references — read those only if needed

## Index

Root: `./references/`

```
|development:{kubelet-dev.md,mco-dev.md,crio-dev.md,crun-conmon.md,kueue-operator-dev.md}
|deployment:{debug-binary.md,layered-image.md,cluster-provisioning.md}
|testing:{e2e-testing.md,unit-testing.md,ci-jobs.md,test-cluster.md}
|debugging:{node-debug.md,must-gather.md,prometheus.md,sosreport.md,crash-analysis.md}
|docs:{writing-docs.md,release-notes.md,enhancement-proposals.md}
|release:{backports.md,z-stream.md,rebase.md}
|workflow:{pr-workflow.md,jira-support.md,on-call.md}
```

## Scripts

Helper scripts are available at `${CLAUDE_PLUGIN_ROOT}/scripts/`. Reference files will tell you which scripts to use and when. Do not run scripts without reading the relevant reference file first.
