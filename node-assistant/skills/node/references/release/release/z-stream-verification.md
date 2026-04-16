# Z-Stream Verification

How fixes are verified before shipping in a z-stream release.

## Verification Overview

Every bug fix in a z-stream must be verified before the release ships. Verification confirms that:

1. The fix resolves the reported issue
2. The fix does not introduce regressions
3. The fix works in the context of the full OCP release (not just in isolation)

## Nightly Build Testing

After a fix merges to a release branch, it gets picked up by the next nightly build.

### Nightly Build Pipeline

```
Fix merges to release-4.X
    -> Nightly build assembles new payload
    -> Periodic CI jobs run against the nightly
    -> Results visible on release controller
```

The release controller at https://openshift-release.apps.ci.l.gapps.com/ shows:

- Build status for each nightly
- Which CI jobs passed/failed
- Whether the nightly is accepted or rejected

A nightly is **accepted** when all critical periodic jobs pass. Accepted nightlies become candidates for z-stream release.

### Node-Relevant Periodic Jobs

Jobs that exercise node components on release branches:

- `periodic-ci-openshift-release-master-ci-4.X-e2e-aws` — general e2e on AWS
- `periodic-ci-openshift-release-master-ci-4.X-e2e-gcp` — general e2e on GCP
- `periodic-ci-openshift-release-master-ci-4.X-upgrade-from-stable-4.X` — upgrade testing
- `periodic-ci-openshift-release-master-ci-4.X-e2e-aws-serial` — serial tests including node-specific tests
- Node-specific conformance: `[sig-node]` tagged tests

Monitor these jobs for regressions after your fix lands.

## QE Verification on Candidate Builds

Once a candidate build is selected for the z-stream, QE begins formal verification.

### QE Verification Process

1. **QE picks up bugs in ON_QA state** — these are bugs with fixes in the candidate build
2. **QE reproduces the original issue** on a previous build (without the fix)
3. **QE deploys the candidate build** with the fix
4. **QE verifies the fix** resolves the issue
5. **QE marks the bug as VERIFIED** in Jira

### What QE Checks

For node component fixes, QE typically verifies:

- **Kubelet fixes**: pod lifecycle, node status reporting, resource management, device plugins
- **CRI-O fixes**: container creation/deletion, image pulling, runtime behavior
- **MCO fixes**: machine config rendering, node updates, drain/reboot cycles
- **Upgrade scenarios**: the fix does not break upgrades from the previous z-stream

### Developer Assistance to QE

Help QE verify your fixes effectively:

- Add clear reproduction steps to the Jira bug
- Specify which test scenarios to run
- Provide a test cluster configuration if the bug requires specific setup (e.g., cgroupv2, specific instance types, particular workloads)
- If the fix is not easily observable (internal state change, race condition fix), suggest how to verify it

## Upgrade Testing

Z-stream releases must support upgrades from the previous z-stream. Upgrade testing is critical for node components.

### Upgrade Test Matrix

| Test | Description |
|------|-------------|
| Minor-to-minor | 4.(X-1).latest -> 4.X.candidate |
| Z-to-z | 4.X.(Y-1) -> 4.X.Y candidate |
| EUS-to-EUS | 4.(X-2).latest -> 4.X.candidate (EUS only) |

### Node-Specific Upgrade Concerns

During upgrades, node components restart in a specific order:

1. MCO rolls out new machine configs
2. Nodes drain workloads
3. CRI-O restarts with new version
4. Kubelet restarts with new version
5. Node reboots (if kernel or OS update)
6. Workloads are re-scheduled

Your fix must not break any step in this sequence. Things to watch for:

- **Version skew**: during rolling upgrades, kubelet and CRI-O versions may differ briefly
- **Config changes**: MCO-managed configs must be backward compatible
- **Container continuity**: containers created by the old CRI-O version must work with the new version
- **Drain behavior**: kubelet drain logic must handle in-flight pods correctly

## Regression Testing

Beyond verifying the specific fix, regression testing ensures nothing else broke.

### Automated Regression Suites

CI runs the following regression suites on candidate builds:

- **Kubernetes conformance** — upstream conformance tests covering node behavior
- **OpenShift extended tests** — OCP-specific tests including node, MCO, runtime tests
- **Upgrade tests** — full upgrade cycle with workload validation
- **Platform-specific tests** — AWS, GCP, Azure, vSphere, bare metal variations

### Manual Regression Testing

QE may run additional manual tests for high-risk changes:

- Node scaling (adding/removing nodes)
- Workload disruption during node operations
- Resource exhaustion scenarios (disk, memory, PIDs)
- Feature gate behavior changes

## Signing Off on Fixes

### Developer Sign-Off

Before QE begins verification, confirm:

- [ ] Fix merged to the correct release branch
- [ ] CI passes on the release branch with the fix
- [ ] No related test failures in nightly jobs
- [ ] Jira bug has accurate reproduction steps
- [ ] Target release is set correctly

### QE Sign-Off

QE marks the bug VERIFIED when:

- [ ] Original issue is confirmed fixed in the candidate build
- [ ] No regressions observed in related functionality
- [ ] Upgrade testing passes with the fix included
- [ ] Any special test scenarios (from the developer) are validated

### Release Sign-Off

At the go/no-go meeting:

- All blocker bugs must be VERIFIED
- All non-blocker bugs should be VERIFIED (but can ship as ON_QA with risk acceptance)
- CI dashboards show green for the candidate build
- No outstanding CVEs without fixes in the candidate

## When Verification Fails

If QE finds the fix does not work or introduces a regression:

1. QE moves the bug back to ASSIGNED with a comment explaining the failure
2. Developer investigates — may need an additional fix
3. The additional fix goes through the same process (master first, cherry-pick, CI)
4. If the fix cannot be corrected in time, it may be reverted from the release branch
5. Revert PRs follow the same review process as regular PRs
