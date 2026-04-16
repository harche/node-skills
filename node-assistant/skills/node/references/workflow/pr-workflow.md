# PR Workflow for Node Components

## Overview

Node team contributions span multiple OpenShift repositories. Each repo has
slightly different CI and approval requirements, but the general workflow is
consistent across all of them.

## Repositories

Primary repos the node team touches:

| Repo | Owner | Notes |
|------|-------|-------|
| `openshift/machine-config-operator` | Node / MCO | Main MCO repo |
| `openshift/kubernetes` | Upstream rebase team + Node | Carries patches on top of upstream k8s |
| `cri-o/cri-o` | Node / CRI-O | Upstream CRI-O |
| `openshift/cri-o` | Node | Downstream CRI-O fork |
| `openshift/openshift-tests` | Multiple | E2E test definitions |
| `openshift/installer` | Installer team | Node occasionally contributes |
| `openshift/api` | API team | API type changes |
| `openshift/enhancements` | All teams | Enhancement proposals |
| `containers/buildah` | Node / Buildah | Upstream Buildah |
| `containers/podman` | Node / Podman | Upstream Podman |
| `containers/common` | Node | Shared container libraries |
| `openshift/node-observability-operator` | Node | Node observability |

## General Workflow

### 1. Create a Feature Branch

```bash
git checkout -b OCPNODE-1234-my-feature
```

Branch naming convention: `<JIRA-KEY>-<short-description>` or
`bug-<BZ-ID>-<short-description>`.

### 2. Develop and Test Locally

- Run unit tests before pushing: `make test` or equivalent per repo.
- For MCO: `make test` runs unit tests; `make verify` runs linters.
- For CRI-O: `make testunit` runs unit tests.

### 3. Push and Open PR

```bash
git push origin OCPNODE-1234-my-feature
```

Open the PR on GitHub. Follow the conventions in the detail docs below.

### 4. CI Runs Automatically

Prow triggers CI jobs on PR creation and on every push. See CI details below.

### 5. Get Reviews

Request review from appropriate OWNERS. Use `/cc @username` to add reviewers.
Two approvals are typically needed: `/lgtm` from a reviewer and `/approve`
from an approver.

### 6. Merge

Once CI is green and approvals are in place, the bot merges automatically.
No manual merge button clicks.

## Upstream vs Downstream PRs

### Upstream First

For CRI-O, Podman, Buildah, and any kubelet changes: always go upstream first.
The downstream carry or rebase picks it up later.

### Downstream-Only Carries

Some changes are OpenShift-specific (e.g., MCO behavior, downstream test
patches). These go directly to the `openshift/` fork.

Carry patches in `openshift/kubernetes` use the commit prefix
`UPSTREAM: <carry>:` or `UPSTREAM: <drop>:` to signal rebase intent.

## Cherry-Picks / Backports

Use the `/cherry-pick release-4.x` Prow command on a merged PR to
auto-generate a backport PR to older release branches. The cherry-pick bot
creates the PR; you still need approvals and green CI.

Manual cherry-pick:
```bash
git cherry-pick <commit-sha>
git push origin cherry-pick-branch
```

Then open a PR against the target release branch.

## Multi-Repo Changes

Some features span repos (e.g., kubelet + MCO + tests). Coordinate merges:

1. Land the lowest-dependency PR first (usually API or kubelet).
2. Update go.mod / vendor in dependent repos to pick up the change.
3. Land dependent PRs once the dependency is available in the build.

Use Jira links to tie related PRs across repos.

## Quick Reference

| Action | How |
|--------|-----|
| Request review | `/cc @username` |
| Approve | `/approve` |
| LGTM | `/lgtm` |
| Retest failed CI | `/retest` |
| Run specific test | `/test <job-name>` |
| Cherry-pick | `/cherry-pick release-4.x` |
| Hold merge | `/hold` |
| Release hold | `/hold cancel` |
| Assign to self | `/assign` |
| Add label | `/label <name>` |

## Detail References

- **PR Conventions**: [workflow/pr-conventions.md](workflow/pr-conventions.md) -- title format, commit messages, labels, sign-off
- **Code Review**: [workflow/pr-review.md](workflow/pr-review.md) -- OWNERS, approval commands, review expectations
- **CI Integration**: [workflow/pr-ci.md](workflow/pr-ci.md) -- required jobs, retesting, reading results
