# Cherry-Pick Process

Step-by-step guide for cherry-picking fixes to OpenShift release branches.

## Prerequisites

- The fix PR is **merged** to master/main. Never cherry-pick from an unmerged PR.
- You have identified which release branches need the fix (see [Backport Criteria](backport-criteria.md)).
- You have push access to your fork of the repository.

## Step 1: Ensure Fix Is Merged to Master

Verify the original PR is merged. The merge commit SHA is what you will cherry-pick. Find it in the PR's merge event on GitHub or via:

```bash
git log --oneline upstream/master | grep "<PR title or bug ID>"
```

If the fix is a squash-merge (common in openshift/kubernetes), there will be a single commit SHA.

## Step 2: Identify Target Branches

Determine which `release-4.X` branches need the fix:

- Check the Jira bug for target releases
- Look at the OCP support lifecycle — typically the last 3-4 minor versions
- For CVEs, all supported releases
- For EUS releases (4.14, 4.16, etc.), these have extended support windows

Example: a fix merged to master (targeting 4.18) may need cherry-picks to `release-4.17`, `release-4.16`, `release-4.15`, and `release-4.14` (EUS).

## Step 3: Use the Prow Bot (Preferred)

On the merged PR in GitHub, comment:

```
/cherry-pick release-4.17
```

The `openshift-cherry-pick-robot` will:

1. Cherry-pick the merge commit onto a new branch
2. Open a new PR targeting `release-4.17`
3. Copy labels and reviewers from the original PR
4. Add a reference to the original PR in the body

Wait for the bot to respond (usually within minutes). If it succeeds, you will get a link to the new PR.

Repeat for each target branch:

```
/cherry-pick release-4.16
/cherry-pick release-4.15
```

## Step 4: Manual Cherry-Pick (When Bot Fails)

The bot fails when there are merge conflicts. You will see a comment from the bot explaining the failure. In that case, do a manual cherry-pick:

```bash
# Fetch latest branches
git fetch upstream

# Create a branch from the target release branch
git checkout -b cp-release-4.17-bugfix upstream/release-4.17

# Cherry-pick the commit with -x to record the original SHA
git cherry-pick -x <merge-commit-sha>

# If there are conflicts:
# 1. Resolve each conflicted file
# 2. git add <resolved-files>
# 3. git cherry-pick --continue

# Push to your fork
git push origin cp-release-4.17-bugfix
```

Then open a PR from your fork's branch to `upstream/release-4.17`.

### Resolving Conflicts

Common conflict patterns:

- **Import paths changed** — update imports to match the target branch
- **Function signatures differ** — adapt the fix to the target branch API
- **File was moved/renamed** — apply the fix to the file at its location on the target branch
- **Surrounding code changed** — carefully merge, preserving both the fix and the existing code on the branch

Always test locally after resolving conflicts:

```bash
make build
make test
```

## Step 5: PR Title and Body for Cherry-Picks

**Title format:**
```
[release-4.17] <original PR title>
```

**Body template:**
```markdown
Cherry-pick of #<original-PR-number>.

<Bug/Jira link if applicable>

/assign @<original-author>
```

If the cherry-pick required conflict resolution, note what was changed:

```markdown
Cherry-pick of #1234.

Conflicts resolved:
- pkg/kubelet/foo.go: adapted to older API (field `Bar` does not exist on 4.17)
```

## Step 6: Labels

Ensure the cherry-pick PR has:

| Label | Purpose |
|-------|---------|
| `backport` | Marks this as a cherry-pick |
| `cherry-pick-approved` | Some repos require explicit approval for backports |
| `jira/valid-bug` | Links to a valid Jira bug |
| `bugzilla/valid-bug` | Legacy; some repos still use Bugzilla linking |
| `approved` | Code review approval |
| `lgtm` | Looks-good-to-me from a reviewer |

For repos that require `cherry-pick-approved`, a staff engineer or team lead comments `/cherry-pick-approve`.

## Step 7: CI and Approval

The cherry-pick PR must pass CI on the target branch. Release branch CI may differ from master:

- Some tests may be skipped on older branches
- Upgrade tests run against different version pairs
- Conformance suites may differ

If CI fails:
1. Check if the failure is related to your change or a pre-existing flake
2. `/retest` for flaky tests
3. If the failure is real, fix it in the cherry-pick PR (do not modify the original commit — add a follow-up commit)

Get standard code review approval (`/lgtm` and `/approve`).

## Handling Multiple Branch Cherry-Picks

When cherry-picking to many branches, work from newest to oldest:

1. Cherry-pick to `release-4.17` first (closest to master, least likely to conflict)
2. Then `release-4.16`
3. Then `release-4.15`
4. Then `release-4.14` (EUS)

If a conflict arises on an older branch, the resolution from that branch often applies to even older branches too.

## Tracking Cherry-Pick Status

Use the Jira bug to track which releases have the fix:

- Set **Target Version** for each release that needs the fix
- As cherry-picks merge, the bot updates the bug status
- Verify all target versions show the fix as merged

For multi-repo fixes (e.g., kubelet + MCO), ensure cherry-picks land in all repos for each target release.
