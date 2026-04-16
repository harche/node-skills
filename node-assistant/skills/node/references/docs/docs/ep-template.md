# Enhancement Proposal Template

Full template for OpenShift enhancement proposals in `openshift/enhancements`. Copy this template, fill in all sections, and remove the guidance comments.

---

## Template

````markdown
---
title: <short-kebab-case-title>
authors:
  - "@<github-handle>"
reviewers:
  - "@<reviewer-github-handle>"    # component they own or review area
approvers:
  - "@<approver-github-handle>"
api-approvers:
  - "@<api-approver-handle>"       # required if adding/changing APIs
creation-date: YYYY-MM-DD
last-updated: YYYY-MM-DD
tracking-link:
  - https://issues.redhat.com/browse/<JIRA-ID>
status: provisional
see-also:
  - "/enhancements/node/<related-ep>.md"
replaces:
  - "/enhancements/node/<old-ep>.md"     # if this replaces an older EP
---

# <Title>

## Summary

<!-- 3-5 sentences. A reader should understand the gist of the entire
     proposal from this section alone. -->

## Motivation

<!-- Why is this change needed? What problem does it solve? -->

### User Stories

<!-- Concrete user stories that motivate this enhancement. -->

* As a cluster administrator, I want to <action> so that <benefit>.
* As a workload developer, I want to <action> so that <benefit>.

### Goals

<!-- Bulleted list of specific, measurable goals. -->

1. <Goal 1>
2. <Goal 2>

### Non-Goals

<!-- Explicitly list what this proposal does NOT aim to do. -->

1. <Non-goal 1>
2. <Non-goal 2>

## Proposal

<!-- Detailed description of the proposed change. This is the core of the
     EP. Include API changes, architecture, workflows, and configuration. -->

### Workflow Description

<!-- Step-by-step description of how users interact with this feature.
     Include both the happy path and error paths. -->

**Cluster administrator enables the feature:**

1. The administrator creates/modifies a <CR name> object:
   ```yaml
   apiVersion: <group>/<version>
   kind: <Kind>
   metadata:
     name: <name>
   spec:
     <field>: <value>
   ```
2. The <operator> detects the change and <action>.
3. The node <resulting behavior>.

### API Extensions

<!-- Exact API objects and fields being added or modified. Show the Go
     struct or YAML. Include validation rules and defaults. -->

```go
type <TypeName>Spec struct {
    // <FieldName> configures <what it does>.
    // +optional
    // +kubebuilder:default=<default-value>
    // +kubebuilder:validation:Enum={"Value1","Value2"}
    <FieldName> string `json:"<fieldName>,omitempty"`
}
```

Corresponding YAML:

```yaml
apiVersion: <group>/<version>
kind: <Kind>
spec:
  <fieldName>: "<value>"
```

**Validation rules:**
- `<fieldName>` must be one of: `<Value1>`, `<Value2>`.
- Default value: `<default>`.

### Topology Considerations

#### Hypershift / Hosted Control Planes

<!-- Does this feature work with hosted control planes? Any differences? -->

#### Standalone Clusters

<!-- Standard OCP cluster behavior. -->

#### Single-node Deployments or MicroShift

<!-- Does this work on SNO? Any special considerations? -->

### Implementation Details/Notes/Constraints

<!-- Technical implementation notes. Dependencies, phasing, constraints. -->

### Risks and Mitigations

<!-- Table format preferred. -->

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| <Risk description> | High/Medium/Low | High/Medium/Low | <Mitigation> |

### Drawbacks

<!-- Why might we NOT want to do this? -->

## Open Questions

<!-- Unresolved questions that need answers before moving to implementable. -->

1. <Question 1>
2. <Question 2>

## Design Details

### Test Plan

<!-- How will this be tested? -->

**Unit tests:**
- <Component>: test <behavior>

**E2E tests:**
- Test that <scenario produces expected result>
- Test that <failure scenario is handled>

**Upgrade tests:**
- Test upgrade from version without feature to version with feature
- Verify <expected state after upgrade>

**Negative tests:**
- Test invalid <field> values are rejected
- Test behavior when <dependency> is unavailable

### Graduation Criteria

#### Dev Preview -> Tech Preview

- Feature gate `<FeatureGateName>` exists behind `TechPreviewNoUpgrade` feature set
- E2E tests pass
- Documentation exists as Tech Preview

#### Tech Preview -> GA

- Feature gate moves to `Default` feature set (enabled by default) or becomes configurable via stable API
- Upgrade/downgrade testing complete
- Performance/scale testing complete
- Docs updated to remove Tech Preview caveats
- At least one release cycle at Tech Preview

#### Removing a deprecated feature

- Announced deprecation in release notes at least two releases prior
- Migration path documented
- Feature gate removed or defaulted to disabled

### Upgrade / Downgrade Strategy

<!-- What happens during upgrade/downgrade? -->

**Upgrade:**
- Nodes running the previous version do not have <feature>.
- During rolling upgrade, <behavior during mixed-version state>.
- After all nodes are upgraded, <final state>.

**Downgrade:**
- If <feature> was enabled, downgrading to a version without support will <consequence>.
- <Data/config migration needed?>

**MachineConfig rollout:**
- Enabling this feature <does/does not> trigger a node reboot.
- The MCO <will/will not> need to render a new MachineConfig.

### Version Skew Strategy

<!-- How does the feature behave when components are at different versions? -->

- Kubelet at version N-1 with controller at version N: <behavior>
- Kubelet at version N with controller at version N-1: <behavior>

### Operational Aspects of API Extensions

#### Failure Modes

<!-- What happens when things go wrong? -->

| Failure Mode | Impact | Detection | Recovery |
|-------------|--------|-----------|----------|
| <Failure> | <Impact> | <How detected> | <How to recover> |

#### Support Procedures

<!-- How does support troubleshoot issues with this feature? -->

1. Check <resource/log/metric>
2. If <condition>, then <action>

### Monitoring Requirements

<!-- New metrics, alerts, dashboards. -->

| Metric Name | Type | Description |
|-------------|------|-------------|
| `<metric_name>` | Gauge/Counter/Histogram | <What it measures> |

**New alerts:**
- `<AlertName>`: fires when <condition>. Severity: <warning/critical>.

## Alternatives

<!-- Other approaches considered and why they were rejected. -->

### Alternative 1: <Name>

<Description and why it was rejected.>

### Alternative 2: <Name>

<Description and why it was rejected.>

## Infrastructure Needed

<!-- Any new CI jobs, test infrastructure, or external resources needed. -->
````

---

## Node Team Specific Guidance

When filling out the template for a Node team enhancement, pay special attention to these areas:

### MCO Integration Section

If your feature requires node-level configuration delivered via MachineConfig, add a subsection under Proposal:

```markdown
### MCO Integration

- **New MachineConfig content:** <Describe what gets rendered into the MachineConfig>
- **Reboot required:** Yes/No. <Explain why>
- **MachineConfigPool targeting:** <Which pools are affected -- worker, master, custom?>
- **Rollout behavior:** <Sequential per pool? All at once?>
- **Drift detection:** <Does the MCO detect if this config drifts? How?>
```

### Kubelet Configuration Section

If your feature adds kubelet configuration fields:

```markdown
### Kubelet Configuration

- **KubeletConfig CR fields:**
  ```yaml
  spec:
    kubeletConfig:
      <newField>: <value>
  ```
- **Underlying kubelet flag:** `--<flag-name>`
- **Default value:** <value>
- **Requires kubelet restart:** Yes (handled by MCO reboot)
- **Feature gate dependency:** `<UpstreamFeatureGate>` (upstream), `<OpenShiftFeatureGate>` (OpenShift)
```

### CRI-O Impact Section

If your feature affects CRI-O:

```markdown
### CRI-O Changes

- **CRI-O configuration:** <What changes in crio.conf or drop-in files?>
- **Runtime behavior:** <How does container creation/deletion change?>
- **Pinns/conmon impact:** <Any changes to infrastructure containers?>
- **Version coordination:** <CRI-O version requirements>
```

---

## Example: Hypothetical Node Team Enhancement

Below is a condensed example of how a Node team EP might look for adding a new kubelet feature gate.

```markdown
---
title: kubelet-memory-qos-enforcement
authors:
  - "@node-dev"
reviewers:
  - "@node-lead"
  - "@mco-lead"
approvers:
  - "@staff-engineer"
api-approvers:
  - "@api-reviewer"
creation-date: 2025-06-01
last-updated: 2025-07-15
tracking-link:
  - https://issues.redhat.com/browse/OCPSTRAT-1234
status: implementable
---

# Kubelet Memory QoS Enforcement

## Summary

Enable the upstream Kubernetes `MemoryQoS` feature gate in OpenShift to
allow the kubelet to set memory.min and memory.high cgroup v2 parameters
on containers, providing better memory quality-of-service guarantees for
Guaranteed and Burstable pods.

## Motivation

Currently, the kubelet only sets memory.max (hard limit) on containers via
cgroups v2. The MemoryQoS feature adds memory.min (guaranteed minimum) and
memory.high (throttling threshold), which lets the kernel reclaim memory
from lower-priority containers before OOM-killing higher-priority ones.

### Goals

1. Expose the `MemoryQoS` feature gate via the OpenShift feature gate mechanism.
2. Enable `memory.min` for Guaranteed QoS pods based on their memory requests.
3. Enable `memory.high` for Burstable QoS pods based on a configurable throttling factor.

### Non-Goals

1. Changing the default cgroup driver (remains systemd).
2. Supporting cgroups v1 (MemoryQoS requires cgroups v2).

## Proposal

Add the `MemoryQoS` feature gate to the OpenShift feature gate registry.
When enabled, the kubelet sets cgroups v2 memory controller parameters:

- `memory.min` = container memory request (for Guaranteed pods)
- `memory.high` = container memory limit * memoryThrottlingFactor (for Burstable pods)

### API Extensions

New field in KubeletConfig:

    spec:
      kubeletConfig:
        memoryThrottlingFactor: 0.9   # default from upstream

### Upgrade / Downgrade Strategy

Upgrade: No impact. Feature is behind a feature gate, disabled by default.
The cgroup parameters are ignored by kernels that do not support them.

Downgrade: If the feature was enabled, downgrading removes the memory.min
and memory.high settings. Pods continue to run but lose QoS enforcement.
No data migration needed.

MachineConfig rollout: Enabling this feature requires a kubelet restart,
which the MCO handles by rebooting the node.
```
