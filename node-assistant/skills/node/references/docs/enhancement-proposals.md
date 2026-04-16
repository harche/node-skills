# Writing OpenShift Enhancement Proposals

## Overview

OpenShift enhancement proposals (EPs) live in the `openshift/enhancements` repository. They document the design, motivation, and implementation plan for significant changes to OpenShift. Every non-trivial feature, behavioral change, or API modification should have an EP.

## Repository Structure

```
openshift/enhancements/
  enhancements/
    node/                      # Node team enhancements
    machine-config/            # MCO enhancements
    node-tuning/               # NTO enhancements
    monitoring/                # Monitoring enhancements
    general/                   # Cross-cutting enhancements
    ...
  guidelines/                  # Process documentation
  this-week/                   # Weekly enhancement status updates
  hack/                        # Scripts for validation
  OWNERS                       # Repo-level approvers
```

### Node-Relevant Directories

- **`enhancements/node/`** -- kubelet configuration, node lifecycle, swap, cgroups, CPU/memory/topology managers, graceful shutdown, node disruption, device plugins, runtime class
- **`enhancements/machine-config/`** -- MCO, MachineConfig, MachineConfigPool, on-cluster layering, OS updates, node configuration drift, bootimages
- **`enhancements/node-tuning/`** -- NTO, performance profiles, TuneD, low latency, huge pages

## Enhancement Proposal Format

Each EP is a single Markdown file named descriptively:

```
enhancements/node/swap-memory-support.md
enhancements/machine-config/node-disruption-policies.md
```

## Required Sections

Every EP must contain the following sections. See `docs/ep-template.md` for the full template.

### Title and Metadata

```markdown
---
title: swap-memory-support
authors:
  - "@github-handle"
reviewers:
  - "@reviewer1"
  - "@reviewer2"
approvers:
  - "@approver1"
api-approvers:
  - "@api-approver1"
creation-date: 2024-01-15
last-updated: 2024-03-01
tracking-link:
  - https://issues.redhat.com/browse/OCPSTRAT-890
status: implementable
see-also:
  - "/enhancements/node/cgroups-v2.md"
---
```

### Summary

One paragraph (3-5 sentences) describing the enhancement at a high level. What is being proposed and why. A reader should be able to understand the gist of the entire proposal from the summary alone.

### Motivation

- **Problem statement:** What user problem or platform limitation does this address?
- **Goals:** What specifically will this enhancement achieve?
- **Non-goals:** What is explicitly out of scope?

### Proposal

The detailed design. This is the core of the EP. Include:

- User-facing API changes (CRDs, fields, flags)
- Architecture and component interaction
- Configuration options and defaults
- Workflow descriptions

### Design Details

#### API Extensions

Show the exact API objects and fields being added or modified:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
spec:
  kubeletConfig:
    swapBehavior: "LimitedSwap"    # new field
    failSwapOn: false              # existing field, new default behavior
```

#### Topology Considerations

For Node team EPs, address:

- **Single-node OpenShift (SNO)** -- Does this work on SNO? Any special considerations?
- **Multi-architecture clusters** -- Any arch-specific behavior (amd64 vs arm64 vs s390x)?
- **Hypershift / hosted control planes** -- Does this affect the hosted kubelet?

#### Implementation Details/Notes/Constraints

- Implementation phases if the work is staged
- Dependencies on upstream Kubernetes changes
- Feature gate names and graduation plan

#### Test Plan

- Unit test coverage
- E2E test scenarios
- Upgrade testing
- Negative/failure testing
- Performance/scale testing if applicable

#### Graduation Criteria

How the feature moves through maturity levels:

- **Dev Preview** -- Available behind a feature gate, no support guarantees
- **Tech Preview** -- Available behind `TechPreviewNoUpgrade` feature set, limited support
- **GA** -- Fully supported, enabled by default or via stable API

#### Upgrade / Downgrade Strategy

- What happens during upgrade from a version without this feature?
- What happens during downgrade to a version without this feature?
- Data migration considerations
- MachineConfig rollout impact (does this cause a node reboot on upgrade?)

#### Operational Aspects

- Monitoring: new metrics, alerts
- Failure modes and recovery
- Support procedures and troubleshooting

### Risks and Mitigations

Table of risks with severity, likelihood, and mitigation plan.

### Drawbacks

Why might we NOT want to do this?

### Alternatives

Other approaches considered and why they were rejected.

## Node Team Enhancement Considerations

When writing a Node team EP, always address these:

1. **MCO integration** -- If the feature requires node-level configuration, how does it interact with the MCO? Does it need a new `MachineConfig` field? Will it trigger a node reboot?

2. **Kubelet flags/configuration** -- If adding kubelet configuration, specify:
   - The exact `KubeletConfig` CR fields
   - Default values
   - Validation rules
   - How the MCO translates CR fields to kubelet config

3. **Feature gates** -- Every new feature must have a feature gate. Specify:
   - The upstream Kubernetes feature gate name (if applicable)
   - The OpenShift feature gate name
   - Which feature set enables it (`TechPreviewNoUpgrade`, `Default`)

4. **Node reboot impact** -- Clearly state whether enabling/changing this feature requires a node reboot. MCO-managed changes that modify kubelet config, kernel arguments, or systemd units typically trigger a reboot.

5. **CRI-O impact** -- If the feature affects container runtime behavior, describe the CRI-O changes needed and coordinate with the CRI-O team.

6. **Resource overhead** -- Quantify any additional CPU, memory, or disk usage on the node.

7. **Upgrade path** -- Describe behavior during rolling upgrade when some nodes have the feature and others do not.

## Review Process

### Who Reviews

- **EP reviewers** -- Listed in the `reviewers` field. Should include at least one Node team lead and relevant component owners.
- **API reviewers** -- If the EP introduces or modifies an API, it must be reviewed by an API approver. Listed in `api-approvers` field.
- **EP approvers** -- Listed in the `approvers` field. Typically team leads or staff engineers.

### Review Flow

1. **Open a PR** against `openshift/enhancements` with your EP file.
2. **Set status to `provisional`** in the metadata.
3. **Request reviews** from the people listed in reviewers/approvers.
4. Address feedback through PR comments and commits.
5. Once reviewers approve, the EP is merged with `provisional` status.
6. **Update to `implementable`** via a follow-up PR once the design is finalized and approved.
7. **Update to `implemented`** once the feature is merged and available in a release.

### Getting Through Review

- File the EP early -- do not wait until implementation is done.
- The motivation section is the most important. Reviewers want to understand *why* before *how*.
- Be concrete. Show actual YAML, actual API fields, actual config files. Avoid hand-waving.
- Address upgrade and downgrade explicitly. This is where most EPs get stuck in review.
- If the EP affects multiple components (kubelet + MCO + CRI-O), get reviewers from each.

## Lifecycle

```
provisional --> implementable --> implemented
                    |
                    v
               withdrawn / replaced
```

- **Provisional** -- The idea is accepted directionally, but design details may still change.
- **Implementable** -- The design is approved and implementation can proceed.
- **Implemented** -- The feature has shipped in a release.
- **Withdrawn** -- The proposal was abandoned.
- **Replaced** -- A new EP supersedes this one.

## Node Team Enhancement Examples

Look at these merged EPs for reference:

- `enhancements/node/swap-memory-support.md` -- Swap memory on nodes
- `enhancements/node/cgroups-v2.md` -- cgroups v2 migration
- `enhancements/node/cpu-manager-static-policy.md` -- CPU manager enhancements
- `enhancements/node/graceful-node-shutdown.md` -- Graceful node shutdown
- `enhancements/machine-config/node-disruption-policies.md` -- Node disruption actions
- `enhancements/machine-config/on-cluster-layering.md` -- On-cluster image layering
- `enhancements/machine-config/mco-network-configuration.md` -- MCO-managed network config

## Further Reading

- `docs/ep-template.md` -- Full enhancement proposal template with guidance
