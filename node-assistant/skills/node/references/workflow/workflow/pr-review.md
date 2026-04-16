# Code Review Process

## OWNERS and APPROVERS Structure

OpenShift uses Prow's OWNERS-based approval model. Every repo has a root
`OWNERS` file, and subdirectories can override or extend with their own.

```yaml
# Example OWNERS file
approvers:
  - senior-dev-a
  - senior-dev-b
reviewers:
  - dev-c
  - dev-d
  - senior-dev-a
  - senior-dev-b
```

### Roles

| Role | Capability | Typical Seniority |
|------|-----------|-------------------|
| Reviewer | `/lgtm` | Any team member listed in `reviewers` |
| Approver | `/approve` | Senior engineers / component owners listed in `approvers` |

Both `/lgtm` AND `/approve` are required for merge. They must come from
different people (self-lgtm/approve is blocked by Prow).

### OWNERS Hierarchy

OWNERS files are inherited. An approver at the repo root can approve changes
anywhere. A subdirectory approver can only approve changes in their subtree.

Prow automatically suggests reviewers based on OWNERS files and file paths
touched by the PR. You can override with explicit `/cc` commands.

## Prow Review Commands

### Core Commands

```
/lgtm              # Add LGTM label (reviewer approval)
/lgtm cancel        # Remove LGTM (e.g., after new changes pushed)
/approve            # Add approved label (approver approval)
/approve cancel     # Remove approval
/cc @user           # Request review from a specific person
/uncc @user         # Remove review request
/assign @user       # Assign PR to someone
/unassign @user     # Unassign
```

### Label Commands

```
/label bug                  # Add a label
/remove-label bug           # Remove a label
/kind bug                   # Shorthand for /label kind/bug
/kind feature
/priority critical-urgent   # Shorthand for /label priority/critical-urgent
```

### Workflow Commands

```
/hold               # Prevent merge even if all checks pass
/hold cancel         # Release the hold
/retest              # Rerun failed required CI jobs
/test <job-name>     # Run a specific optional CI job
/override <job>      # Override a stuck/broken required job (admin only)
/cherry-pick release-4.x  # Auto-create cherry-pick PR
```

## Review Expectations for Node Components

### What Reviewers Should Check

1. **Correctness**: Does the code do what the Jira issue asks for?
2. **Safety**: Node-level changes affect every node in the cluster. Consider:
   - Does this touch the critical path (kubelet, CRI-O, drain, reboot)?
   - Can this brick a node or cause a reboot loop?
   - Is there a rollback path?
3. **Testing**: Are there unit tests? E2E tests? Is the change covered by
   existing CI jobs?
4. **API compatibility**: Does this change any user-facing API, config, or
   behavior? If so, is it backward compatible?
5. **Performance**: Node components are latency-sensitive. Watch for:
   - Unnecessary API server calls from the node
   - Blocking operations in hot paths
   - Memory allocations in per-pod loops
6. **Error handling**: Node components must degrade gracefully. Check that
   errors are handled, logged, and don't crash the process.
7. **Logging**: Appropriate log levels (`klog.V(4)` for debug, `klog.Error`
   for actionable errors). No sensitive data in logs.

### Review Turnaround

- Target: first review within 1 business day.
- Bug fixes for current release: prioritize same-day review.
- Blockers and escalations: review immediately.
- If you can't review promptly, say so and suggest an alternate reviewer.

### Common Review Feedback Patterns

**"Needs rebase"** -- The PR has merge conflicts. Author needs to rebase on
the latest target branch.

**"Needs test"** -- The change lacks test coverage. Point to what should be
tested and suggest the test type (unit vs e2e).

**"Consider the upgrade path"** -- Node changes must work during rolling
upgrades where old and new versions coexist.

**"This needs an enhancement"** -- Significant behavior changes need an
accepted enhancement proposal before code review.

**"Check MCO interaction"** -- Kubelet or CRI-O changes often need
corresponding MCO changes to deploy config.

## Requesting Review from Specific People

### When to Explicitly Request

- Cross-component changes: `/cc` someone who owns the other component.
- Security-sensitive changes: `/cc` a security-aware reviewer.
- API changes: `/cc` an API reviewer.
- Changes to areas you're unfamiliar with: `/cc` the subdirectory owner.

### Finding the Right Reviewer

```bash
# Check OWNERS for the files you changed
cat pkg/daemon/OWNERS

# Look at git log for recent contributors to the area
git log --oneline -10 -- pkg/daemon/
```

Prow auto-assigns from OWNERS, but for targeted feedback, explicit `/cc` is
better.

## Cross-Repo PRs

Some features span multiple repositories. Common patterns:

### Kubelet + MCO

A kubelet configuration change often requires:
1. **openshift/kubernetes**: The kubelet code change.
2. **openshift/machine-config-operator**: MCO to deploy the new config.
3. **openshift/openshift-tests**: E2E tests for the new behavior.

Coordinate by:
- Opening all PRs and linking them via Jira.
- Noting dependencies in each PR description ("Depends on openshift/kubernetes#12345").
- Merging in dependency order. Use `/hold` on dependent PRs until the
  dependency merges.

### CRI-O + Kubelet

CRI-O changes that affect the CRI interface need matching kubelet awareness:
1. Land the CRI-O change upstream first.
2. Sync downstream `openshift/cri-o`.
3. If kubelet needs updating, coordinate with the `openshift/kubernetes` PR.

### API + Operator

Changes to API types (`openshift/api`) must merge before operator PRs that
use the new types. Use vendoring to pull in the new API.

## Review Etiquette

- Be specific and constructive. Link to docs or examples.
- Distinguish blocking feedback from suggestions: prefix non-blocking
  comments with "nit:" or "suggestion:".
- If you approve with minor comments, `/lgtm` and note that remaining items
  are non-blocking.
- Respond to all review comments before requesting re-review.
- Don't force-push while reviews are in progress without notifying reviewers
  (GitHub collapses their comments).
