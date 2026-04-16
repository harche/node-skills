# Z-Stream Release Process

Z-stream releases are patch-level updates to an existing OpenShift minor version (e.g., 4.16.12 to 4.16.13). They deliver bug fixes, security patches, and targeted improvements without introducing new features.

## Z-Stream vs Y-Stream

| Aspect | Z-Stream (4.X.Y -> 4.X.Y+1) | Y-Stream (4.X -> 4.X+1) |
|--------|-------------------------------|--------------------------|
| Scope | Bug fixes, CVEs only | New features + bug fixes |
| Cadence | Roughly every 2 weeks | Roughly every 4 months |
| Risk | Low — small, targeted changes | Higher — new functionality |
| Branch | `release-4.X` (same branch) | New `release-4.X+1` branch |
| QE cycle | Focused regression testing | Full feature + regression testing |
| Rebase | No upstream rebase | Kubernetes rebase included |

## Z-Stream From the Node Team Perspective

The Node team contributes to z-stream releases through:

1. **Fixing bugs** on master and cherry-picking to release branches
2. **Verifying fixes** in nightly and candidate builds
3. **Monitoring CI** on release branches for regressions
4. **Responding to blockers** that delay z-stream shipment

### Node Components in Z-Streams

Components the Node team owns that ship in z-streams:

- **kubelet** (via openshift/kubernetes)
- **CRI-O** (via openshift/cri-o, synced from cri-o/cri-o)
- **Machine Config Operator / Daemon** (openshift/machine-config-operator)
- **Node Tuning Operator** (openshift/cluster-node-tuning-operator)
- **conmon / conmon-rs** — container monitor

Each component builds independently and produces an image that gets assembled into the OCP release payload.

## Z-Stream Candidate Selection

Not every fix merged to a release branch automatically ships in the next z-stream. The process:

1. **Fixes merge** to `release-4.X` branch
2. **Nightly builds** pick up the merged changes
3. **CI runs** against the nightly, catching regressions
4. **Release engineering** selects a candidate build for the z-stream
5. **QE validates** the candidate
6. **Advisory (errata) is published** with the z-stream

A fix must be merged early enough in the z-stream cycle to be included. Late merges may slip to the next z-stream.

## Z-Stream Blocker Bugs

A bug can be flagged as a z-stream blocker:

- Set `Blocker` flag in Jira to the target z-stream version
- Blocker bugs **must** be resolved before the z-stream ships
- If the fix cannot land in time, the blocker must be explicitly waived by the program manager

Node team bugs that commonly become blockers:

- Kubelet crashes or restart loops
- CRI-O failures causing pod creation errors
- MCO rendering failures preventing node updates
- Upgrade failures during node drain or reboot

## Timeline: Typical Z-Stream Cadence

A z-stream cycle runs roughly 2 weeks:

| Day | Activity |
|-----|----------|
| Day 1-7 | Fixes merge to release branch, nightly builds |
| Day 7-8 | Candidate build selected |
| Day 8-12 | QE validation, blocker triage |
| Day 12-13 | Final go/no-go decision |
| Day 14 | Advisory published, z-stream ships |

This is approximate. Blockers, holidays, or infrastructure issues can shift the timeline.

## Monitoring Z-Stream Health

Track z-stream status for your components:

- **Release controller**: https://openshift-release.apps.ci.l.gapps.com/ — shows build and CI status for each release branch
- **Jira queries**: filter bugs by target release and component to see outstanding fixes
- **CI dashboards**: monitor `periodic-ci-*-release-4.X-*` jobs for regression signals
- **Slack**: `#forum-ocp-node` and `#release-status` for real-time updates

## Further Reading

- [Z-Stream Workflow](release/z-stream-workflow.md) — Jira states, advisory system, and ship-it process
- [Z-Stream Verification](release/z-stream-verification.md) — QE verification, testing, and sign-off
