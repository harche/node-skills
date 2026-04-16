# Backport Criteria

Guidelines for deciding when and what to backport to OpenShift release branches.

## Always Backport

### Critical and High Severity Bugs

Any bug with `Severity: Critical` or `Severity: High` in Jira should be backported to all supported releases where the bug exists. These include:

- Node crashes (kubelet, CRI-O panics or fatal errors)
- Data loss or corruption (container filesystem, volumes)
- Security-sensitive issues (privilege escalation, container breakout)
- Cluster upgrade blockers
- Widespread workload disruption

### CVE Fixes

All CVE fixes must be backported to every supported release branch. CVEs follow a strict process:

1. Fix lands on master under embargo (private PR if needed)
2. Immediately cherry-pick to all supported release branches
3. Coordinate with Product Security for advisory timing
4. Track via the security tracker Jira project

No exceptions. Even low-severity CVEs get backported.

### Customer Escalations

Fixes for customer-reported issues with active escalations (CEE cases, Sev1/Sev2 support cases) should be backported to the customer's specific OCP version at minimum, and typically to all supported releases.

### Upgrade-Blocking Bugs

Any bug that blocks upgrades between supported versions must be backported. This includes issues in:

- Kubelet version skew handling
- CRI-O version compatibility
- MCO upgrade path logic
- Node draining/cordoning during upgrades

## Generally Safe to Backport

### Test-Only Fixes

Fixes that only modify test code (`_test.go` files, e2e test specs, test utilities) are low-risk backports. These improve CI signal on release branches without changing product behavior. Backport when:

- The test fix prevents CI flakes on the release branch
- The test covers a code path that exists on the release branch
- The test framework or helpers are compatible with the release branch

### Documentation and Comment Fixes

Updates to code comments, godoc, or inline documentation are safe to backport but usually low priority. Only backport if the incorrect documentation causes operational confusion.

### Small, Well-Scoped Bug Fixes

Bugs with a clear, small fix (few lines changed, well-understood code path) are good backport candidates. The smaller the diff, the lower the risk.

## Generally Do NOT Backport

### Feature Work

New features go forward-only. They land on master and ship in the next minor release. Backporting features to release branches is against OpenShift policy because:

- Features require full QE validation
- Features may introduce new APIs that break version guarantees
- Features increase the surface area for regressions

Exceptions are extremely rare and require PM and staff engineering approval.

### Refactoring

Code refactoring (renaming, restructuring, extracting functions) should not be backported. Refactoring:

- Changes the code without fixing a user-facing problem
- Creates unnecessary merge conflicts for future cherry-picks
- Increases risk with no user-facing benefit on the release branch

### Performance Optimizations (Without a Bug)

Performance improvements that are not tied to a specific customer-reported performance bug should not be backported. They carry regression risk without addressing a concrete issue.

### Dependency Bumps (Without a Fix)

Do not backport dependency version bumps unless they contain a specific fix needed on the release branch. Gratuitous dependency updates on release branches are high-risk.

## Risk Assessment

When evaluating a backport, consider:

| Factor | Lower Risk | Higher Risk |
|--------|-----------|-------------|
| Diff size | Few lines | Large diff |
| Code path | Narrow, well-tested | Broad, affects many paths |
| Test coverage | Good existing tests | Poor or no tests |
| Dependencies | Self-contained | Requires other changes |
| Branch age | Recent release | Older release |
| Customer impact | Specific fix for known issue | Speculative improvement |

For higher-risk backports, consider:

- Adding extra test coverage in the cherry-pick PR
- Getting additional reviewers familiar with the release branch
- Testing on a real cluster before merging
- Discussing in the team standup or backport review meeting

## Currently Supported OCP Versions

OpenShift follows a support lifecycle with three phases:

### Full Support
The latest GA minor release and the previous minor release receive full support with regular z-stream updates. Currently this includes the latest two minor versions.

### Maintenance Support
Older minor releases in maintenance receive critical and security fixes only. Backports to these branches should be limited to CVEs and critical bugs.

### Extended Update Support (EUS)
Even-numbered minor releases (4.14, 4.16, etc.) receive Extended Update Support. EUS releases:

- Have a longer support window (typically 18 months from GA)
- Receive backports longer than non-EUS releases
- Are the preferred upgrade path for customers on EUS-to-EUS upgrades
- Require extra attention for node components since EUS-to-EUS upgrades skip intermediate versions

### EUS Considerations for Node Team

EUS-to-EUS upgrades (e.g., 4.14 -> 4.16) are particularly sensitive for the node team because:

- Kubelet version skew spans two minor Kubernetes versions
- CRI-O must handle containers created two minor versions ago
- MCO must handle machine config changes across two versions
- Node-level feature gates may change across the skipped version

Always verify that node component changes are compatible with EUS upgrade paths when backporting to EUS branches.

## Decision Tree

1. Is it a CVE? -> **Backport to all supported releases**
2. Is it a critical/high severity bug? -> **Backport to all supported releases**
3. Is it a customer escalation? -> **Backport to at least the customer's version**
4. Is it a test-only fix? -> **Backport if the test is relevant on the branch**
5. Is it a feature? -> **Do NOT backport**
6. Is it refactoring? -> **Do NOT backport**
7. Is it a small bug fix? -> **Backport to supported releases, assess risk**
8. Unsure? -> **Discuss with the team lead**
