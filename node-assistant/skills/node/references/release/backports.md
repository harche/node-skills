# Backporting Fixes to Release Branches

OpenShift uses a cherry-pick workflow for backporting fixes to release branches. All fixes land on the main development branch first, then get selectively cherry-picked to supported release branches.

## Source Repositories (Node Team)

The Node team maintains backports across several repositories:

- **openshift/kubernetes** — kubelet, kube-proxy, and other Kubernetes components
- **openshift/machine-config-operator** — MCO, MCD, node configuration
- **cri-o/cri-o** — container runtime (upstream, then synced to openshift/cri-o)
- **openshift/cri-o** — downstream CRI-O fork with OpenShift-specific patches
- **openshift/node-observability-operator** — node observability tooling
- **containers/conmon-rs** — container monitor

## Core Principle: Fix Forward

Every fix must be merged to the main branch (master/main) before backporting. This prevents regressions where a fix exists in an older release but not in newer ones. The only exception is release-specific code paths that do not exist on master.

## Backport Methods

### 1. Prow Bot Cherry-Pick (Preferred)

On the merged PR in GitHub, comment:

```
/cherry-pick release-4.17
```

The bot creates a new PR targeting `release-4.17` with the cherry-picked commit(s). This is the preferred method because it preserves metadata, links the backport to the original PR, and applies correct labels automatically.

To cherry-pick to multiple branches:

```
/cherry-pick release-4.17
/cherry-pick release-4.16
/cherry-pick release-4.15
```

Each command creates a separate PR.

### 2. Manual Cherry-Pick

When the bot fails (usually due to conflicts), do a manual cherry-pick:

```bash
git fetch upstream
git checkout -b cherry-pick-release-4.17 upstream/release-4.17
git cherry-pick -x <commit-sha>
# Resolve any conflicts
git push origin cherry-pick-release-4.17
```

Then create a PR targeting `release-4.17`.

## Backport PR Conventions

### Title Format

Backport PRs follow this title convention:

```
[release-4.17] <original PR title>
```

Example:
```
[release-4.17] Bug 2198745: Fix kubelet crash on cgroupv2 memory limit
```

### Labels

Backport PRs should carry:

- `backport` — indicates this is a cherry-pick
- `cherry-pick-approved` — required for some repos, signals the backport was approved
- `bugzilla/valid-bug` or `jira/valid-bug` — if linked to a bug tracker
- `lgtm` and `approved` — standard review labels

### PR Body

Reference the original PR:

```
Cherry-pick of #<original-PR-number>.

/assign @original-author
```

## Which Branches to Target

Determine which OCP versions need the fix based on:

1. **Severity** — critical bugs go to all supported releases
2. **Customer impact** — escalations may require backports to specific versions
3. **Supported lifecycle** — only backport to branches still receiving updates
4. **EUS status** — Extended Update Support releases have longer backport windows

Check the current release status at https://openshift-release.apps.ci.l]gapps.com/ and the OCP lifecycle page for supported versions.

## Common Issues

- **Conflicts** — code divergence between branches; resolve manually and note the resolution in the PR
- **Dependency drift** — a fix may depend on code that does not exist in the target branch; may require additional cherry-picks or adaptation
- **CI differences** — tests may behave differently on older branches; verify CI passes
- **API changes** — features or API fields may not exist in older releases

## Further Reading

- [Cherry-Pick Process](release/cherry-pick-process.md) — step-by-step cherry-pick workflow
- [Backport Criteria](release/backport-criteria.md) — when and what to backport
