# PR Conventions

## PR Title Format

Titles must reference the tracking issue:

```
Bug XXXXX: <short description>          # Bugzilla-tracked bug fix
OCPNODE-XXXX: <short description>       # Jira-tracked work item
NO-JIRA: <short description>            # Trivial fix, no tracker needed (use sparingly)
```

For upstream repos (cri-o/cri-o, containers/podman, etc.), follow upstream
conventions -- typically just a descriptive title without a bug prefix.

For `openshift/kubernetes` carry patches:
```
UPSTREAM: <carry>: <description>        # Patch carried across rebases
UPSTREAM: <drop>: <description>         # Patch dropped on next rebase
UPSTREAM: 12345: <description>          # Cherry-pick of upstream PR #12345
```

## Commit Message Conventions

### Structure

```
OCPNODE-1234: Short summary (50 chars or less)

Detailed explanation of what changed and why. Wrap at 72 characters.
Reference related issues, PRs, or upstream commits as needed.

Signed-off-by: Your Name <your.email@redhat.com>
```

### Rules

- First line: imperative mood, 50 chars max, references Jira/BZ key.
- Blank line between subject and body.
- Body: explain *why*, not just *what*. The diff shows what changed.
- Wrap body at 72 characters.
- Include `Signed-off-by` line (see DCO section below).

### Multi-Commit PRs

Some repos allow multi-commit PRs (e.g., `openshift/kubernetes` carries).
Most OpenShift repos use squash merge, so intermediate commit messages matter
less -- but the PR title and description become the squash commit message.

## Required Labels by Repo

### openshift/machine-config-operator

| Label | When |
|-------|------|
| `lgtm` | Added by `/lgtm` from a reviewer |
| `approved` | Added by `/approve` from an OWNERS approver |
| `bugzilla/valid-bug` or `jira/valid-bug` | Required for bug-fix PRs |
| `docs-approved` | If docs impact; use `/label docs-approved` if no docs needed |
| `px-approved` | Product experience approval if UI/UX impact |
| `qe-approved` | QE sign-off if test plan needed |

### openshift/kubernetes

Same as above, plus:
- Carry patches need `tide/merge-method-merge` to preserve individual commits.
- Must have valid upstream reference or `<carry>` / `<drop>` tag.

### cri-o/cri-o (upstream)

Uses standard GitHub review model, no Prow labels. Two approvals required
from OWNERS. CI must pass.

### openshift/cri-o

Prow-managed. Same label set as MCO.

## PR Description Template

Most OpenShift repos auto-populate a PR template. Fill in all sections:

```markdown
## What does this PR do?

<Concise description of the change>

## Which issue(s) does this PR fix?

Fixes https://issues.redhat.com/browse/OCPNODE-XXXX

## How to verify?

<Steps to test the change, or pointer to test coverage>

## Additional context

<Any extra context: related PRs, upstream issues, design decisions>
```

The `Fixes` or `Relates to` prefix with a Jira URL lets Prow automatically
set labels and transition the Jira issue.

## Linking to Jira Issues

### Automatic Linking

Include the Jira key in the PR title (`OCPNODE-1234: ...`). Prow's Jira
plugin recognizes this and links the PR to the issue.

### Manual Linking

Use `jira.sh` to add a PR link to a Jira issue:
```bash
./scripts/jira.sh link OCPNODE-1234 https://github.com/openshift/machine-config-operator/pull/4567
```

### Jira Status Transitions

When a PR with a valid Jira reference merges, the Jira plugin can
automatically transition the issue (e.g., from ASSIGNED to POST). This
depends on the repo's Prow config.

## Squash vs Merge Commit Policy

| Repo | Policy |
|------|--------|
| `openshift/machine-config-operator` | Squash merge (default) |
| `openshift/kubernetes` | Merge commit (preserves carry history) |
| `cri-o/cri-o` | Squash merge |
| `openshift/cri-o` | Squash merge |
| `openshift/api` | Squash merge |
| `openshift/enhancements` | Squash merge |

To override the default (if permitted):
```
/label tide/merge-method-merge
/label tide/merge-method-squash
```

## DCO Sign-Off

All commits to OpenShift repos must include a Developer Certificate of Origin
sign-off line:

```
Signed-off-by: Your Name <your.email@redhat.com>
```

Add it automatically with:
```bash
git commit -s -m "OCPNODE-1234: Fix something"
```

Configure git to always sign off:
```bash
git config --global format.signOff true
```

If you forget, amend the last commit:
```bash
git commit --amend -s --no-edit
git push --force-with-lease
```

The DCO Prow plugin blocks merge if sign-off is missing.

## OWNERS Files and Approval Requirements

Every directory can have an `OWNERS` file:

```yaml
approvers:
  - user-a
  - user-b
reviewers:
  - user-c
  - user-d
```

- **Reviewers** can `/lgtm` -- signals the code looks good.
- **Approvers** can `/approve` -- signals the change is acceptable for the component.
- Both `/lgtm` and `/approve` are required for merge.
- OWNERS files are hierarchical: a root approver can approve any file.

To check who can approve a file:
```bash
# Look at OWNERS in the file's directory and parent directories
cat path/to/dir/OWNERS
```

For node-specific components in MCO, check:
- `pkg/daemon/OWNERS`
- `pkg/controller/node/OWNERS`
- Root `OWNERS`
