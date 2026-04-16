# Z-Stream Workflow

The end-to-end workflow for getting a fix into a z-stream release, from bug filing through shipment.

## Jira Bug Lifecycle

Bugs flow through these Jira states during the z-stream process:

```
NEW -> ASSIGNED -> POST -> MODIFIED -> ON_QA -> VERIFIED -> CLOSED
```

### State Definitions

**NEW** — Bug is filed but not yet picked up by a developer. Triage assigns component, severity, and priority.

**ASSIGNED** — A developer is working on the fix. The assignee field is set.

**POST** — A fix PR has been submitted (posted) but not yet merged. The PR link is added to the bug's external tracker. The bug moves to POST automatically when a PR referencing the bug is opened.

**MODIFIED** — The fix PR is merged. The code change is in the release branch. For cherry-picks, MODIFIED means the backport has merged on the target release branch, not just master.

**ON_QA** — The fix is included in a build that QE can test. This transition usually happens automatically when the fix appears in a candidate or nightly build. QE picks up the bug for verification.

**VERIFIED** — QE has confirmed the fix works as expected in the candidate build. The bug is verified and ready to ship.

**CLOSED** — The fix has shipped in a z-stream release. The advisory is published.

### State Transitions for Node Team

Typical developer workflow:

1. Bug assigned to you -> status is ASSIGNED
2. You create a fix PR on master -> bug stays ASSIGNED
3. Fix PR merges on master -> bug may still be ASSIGNED (master fix alone does not change state for z-stream)
4. You cherry-pick to `release-4.X` -> bug moves to POST
5. Cherry-pick merges -> bug moves to MODIFIED
6. Fix appears in nightly build -> bug moves to ON_QA
7. QE verifies -> bug moves to VERIFIED

## Setting Target Release in Jira

Every z-stream bug needs a **Target Release** set in Jira:

- Format: `4.X.z` (e.g., `4.16.z`) — this means the fix targets the next z-stream for 4.16
- A bug can have multiple target releases if it needs fixing on multiple branches
- The target release determines which advisory the fix rolls into

To set it:
1. Open the bug in Jira
2. Set **Target Version** to the appropriate `4.X.z`
3. Ensure the **Component** is correct (e.g., `Node`, `CRI-O`, `Machine Config Operator`)

## Z-Stream Exception Process

If a fix misses the z-stream cut-off but is critical:

1. File a z-stream exception request in Jira
2. Set the `ZStreamException` flag
3. Provide justification: customer impact, severity, risk assessment
4. The program manager and release engineering review the request
5. If approved, the fix is added to the in-progress z-stream
6. If denied, it waits for the next z-stream

Exceptions are granted for:

- CVEs with active exploits
- Critical bugs affecting many customers
- Upgrade blockers
- Regressions introduced in the current z-stream candidate

Exceptions are typically denied for:

- Low-severity bugs
- Fixes with large diffs or high risk
- Fixes without adequate test coverage

## Advisory (Errata) System

Z-stream releases ship as advisories (erratas) through the Red Hat advisory system:

### Advisory Types

- **RHBA** (Red Hat Bug Advisory) — bug fixes only
- **RHSA** (Red Hat Security Advisory) — contains CVE fixes
- **RHEA** (Red Hat Enhancement Advisory) — enhancements (rare for z-streams)

### How Advisories Work

1. Release engineering creates an advisory for the upcoming z-stream
2. Builds (container images) are attached to the advisory
3. Each build corresponds to a component (e.g., `ose-hyperkube` for kubelet, `cri-o` for CRI-O)
4. QE verifies the bugs listed in the advisory
5. When all bugs are verified and blockers resolved, the advisory ships

### Node Team Builds in Advisories

The Node team's builds that commonly appear in advisories:

| Build | Repository | Component |
|-------|-----------|-----------|
| `ose-hyperkube` | openshift/kubernetes | kubelet, kube-proxy |
| `cri-o` | openshift/cri-o | CRI-O runtime |
| `machine-config-operator` | openshift/machine-config-operator | MCO, MCD |
| `cluster-node-tuning-operator` | openshift/cluster-node-tuning-operator | NTO, TuneD |

## Ship-It Process

The final steps before a z-stream ships:

1. **Candidate build passes CI** — all blocking jobs green
2. **All blocker bugs verified** — QE signs off
3. **Go/no-go meeting** — stakeholders review outstanding issues
4. **Advisory moves to QE** — final validation pass
5. **Advisory moves to REL_PREP** — release engineering prepares shipment
6. **Advisory ships** — images pushed to registry, customers can update

### Node Team Responsibilities at Ship-It

- Ensure all node-component blocker bugs are VERIFIED
- Monitor CI for last-minute regressions in node jobs
- Be available for escalations if a node issue blocks shipment
- Review the advisory to confirm correct builds are attached

## Tracking and Communication

- **Z-stream tracker Jira query**: filter by `Target Version = 4.X.z` and your component
- **Slack channels**: `#release-status` for overall status, `#forum-ocp-node` for node-specific items
- **Release calendar**: check the OCP release calendar for upcoming z-stream dates
- **Weekly z-stream review**: attend the release status sync to stay informed on blockers
