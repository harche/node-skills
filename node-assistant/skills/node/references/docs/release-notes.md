# Writing Release Notes for OpenShift

## Overview

Release notes for OpenShift Container Platform are maintained in the `openshift/openshift-docs` repository alongside the product documentation. They follow a structured format tied to Jira issues and are organized by component area.

## Where Release Notes Live

```
openshift-docs/
  release_notes/
    ocp-4-<version>-release-notes.adoc    # Assembly for the version
  modules/
    release_notes/
      con_ocp-4-<version>-about.adoc      # "About this release" module
      ref_ocp-4-<version>-new-features.adoc
      ref_ocp-4-<version>-bug-fixes.adoc
      ref_ocp-4-<version>-known-issues.adoc
      ref_ocp-4-<version>-deprecated-removed.adoc
      ref_ocp-4-<version>-technology-preview.adoc
```

Each z-stream release (e.g., 4.16.3) typically adds entries to the existing version's release notes modules rather than creating new files.

## Node Team Release Note Categories

Node team release notes typically fall under these component headings within the release notes modules:

- **Nodes** -- kubelet configuration, node lifecycle, graceful shutdown, swap, cgroups, CPU/memory/topology managers, max pods, node disruption policies
- **Machine Config Operator** -- MachineConfig changes, OS updates, MCO behavior, node configuration drift, certificate rotation
- **Node Tuning Operator** -- Performance profiles, TuneD, huge pages, real-time kernel, low latency
- **Monitoring** -- Node-level metrics, alerting rule changes
- **CRI-O** -- Container runtime changes affecting node behavior

## Jira-to-Release-Note Workflow

1. Every Jira issue that warrants a release note must have the `release-note+` flag set (not `release-note-`).
2. The `Release Note Text` field in Jira contains the draft text. Write it in AsciiDoc.
3. During the release cycle, the docs team collects all `release-note+` issues and incorporates them into the release notes modules.
4. The Node team is responsible for reviewing the accuracy of node-related release note entries before publish.

**When to set `release-note+`:**
- New features or enhancements visible to users
- Bug fixes for issues that had user-facing impact
- Behavioral changes (even if not a "feature")
- Deprecations and removals
- Known issues that affect GA functionality

**When to set `release-note-`:**
- Internal refactoring with no user-facing change
- Test-only changes
- CI/build infrastructure changes

## Release Note Format

Every release note entry is a list item under its category. The format:

```asciidoc
* Previously, <description of the old behavior or problem>. With this update, <description of what changed>. (link:https://issues.redhat.com/browse/OCPBUGS-XXXXX[OCPBUGS-XXXXX])
```

### Bug Fix Format

```asciidoc
* Previously, when a node was cordoned during a MachineConfig update, the MCO would not properly resume draining pods if the node was uncordoned and re-cordoned. With this update, the MCO correctly tracks the drain state across cordon/uncordon cycles. (link:https://issues.redhat.com/browse/OCPBUGS-12345[OCPBUGS-12345])
```

Pattern: "Previously, [problem]. With this update, [fix]."

### New Feature Format

```asciidoc
* You can now configure swap memory on worker nodes by setting the `swapBehavior` field in the `KubeletConfig` custom resource. This enables workloads that benefit from swap to run more efficiently. For more information, see xref:nodes/nodes/nodes-nodes-swap-memory.adoc#nodes-nodes-swap-memory[Swap memory on nodes]. (link:https://issues.redhat.com/browse/OCPSTRAT-567[OCPSTRAT-567])
```

Pattern: "You can now [capability]. [Benefit]. For more information, see [xref]."

### Known Issue Format

```asciidoc
* When using `cgroupMode: "v2"` in the node configuration and the node has more than 110 pods, the kubelet might report excessive memory usage due to a cgroup tracking overhead. As a workaround, reduce the `maxPods` value to 100 or fewer. (link:https://issues.redhat.com/browse/OCPBUGS-67890[OCPBUGS-67890])
```

Pattern: "When [condition], [problem]. As a workaround, [mitigation]."

### Deprecation Notice Format

```asciidoc
* The `ForceRedeploymentReason` field in the `KubeletConfig` API is deprecated. In a future release, this field will be removed. Use the `spec.forceRollout` field instead.
```

Pattern: "[Thing] is deprecated. In a future release, [consequence]. Use [alternative] instead."

## Examples of Good Node Team Release Notes

**Good -- specific, actionable, links to Jira:**
```asciidoc
* Previously, when a node was running with cgroups v2 and the `memoryThrottlingFactor` was set in the kubelet configuration, the node would apply memory limits to containers using an incorrect multiplier, resulting in unexpected OOM kills. With this update, the memory throttling calculation correctly applies the configured factor. (link:https://issues.redhat.com/browse/OCPBUGS-11111[OCPBUGS-11111])
```

**Good -- feature with xref:**
```asciidoc
* You can now define node disruption policies to control how the Machine Config Operator handles node disruptions during configuration updates. This allows you to avoid unnecessary node reboots for certain configuration changes. For more information, see xref:machine_configuration/machine-config-node-disruption.adoc#machine-config-node-disruption[Node disruption policies]. (link:https://issues.redhat.com/browse/MCO-456[MCO-456])
```

**Bad -- too vague:**
```asciidoc
* Fixed a bug with node configuration.
```

**Bad -- too internal, not user-facing:**
```asciidoc
* Refactored the MCO's internal reconciliation loop to use a channel-based approach.
```

## Style Rules

- Always use "Previously" to start bug fix descriptions, not "Before this fix" or "In earlier versions."
- Always end with the Jira link in parentheses.
- Use `{product-title}` instead of hardcoding the product name.
- Reference specific API fields and objects in monospace.
- For features, always include an `xref:` to the relevant docs page.
- Keep entries to 2-3 sentences maximum.
- Do not assume the reader knows internal component names. Say "the Machine Config Operator" not "the MCO" on first reference (you can abbreviate afterward within the same entry if needed, but entries are standalone list items, so spell it out).

## Further Reading

- `docs/rn-templates.md` -- Copy-paste templates for each release note type
