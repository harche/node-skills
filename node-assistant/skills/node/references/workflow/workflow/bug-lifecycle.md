# Bug Lifecycle in Jira

## State Machine

```
NEW --> ASSIGNED --> POST --> MODIFIED --> ON_QA --> VERIFIED --> CLOSED
 |                   ^                                           ^
 |                   |                                           |
 +--- CLOSED --------+-------------------------------------------+
      (won't fix / duplicate / not a bug)
```

## State Definitions

### NEW

The bug has been filed but not yet reviewed or assigned.

- **Who sets it**: Reporter (automatically on creation).
- **What to do**: Awaits triage. The triage lead or on-call engineer reviews
  it during the weekly triage meeting or sooner for high-severity bugs.
- **Exit criteria**: Assign to an engineer and set priority/target release.

### ASSIGNED

The bug has been triaged, assigned to an engineer, and has a target release.

- **Who sets it**: Triage lead or the assignee.
- **What to do**: The assignee investigates, develops a fix, writes tests.
- **Exit criteria**: A PR with the fix is opened (move to POST).

### POST

A fix has been submitted as a PR but has not yet merged.

- **Who sets it**: The assignee, or automatically by Prow when a PR
  referencing this Jira issue is opened.
- **What to do**: PR is in review and CI. The assignee shepherds it through.
- **Exit criteria**: The PR merges (move to MODIFIED).

### MODIFIED

The fix has merged into the source branch.

- **Who sets it**: Automatically by Prow on PR merge, or manually by the
  assignee.
- **What to do**: The fix is in the build. QE picks it up for verification
  once it lands in a nightly or z-stream build.
- **Exit criteria**: QE verifies the fix works (move to ON_QA).

### ON_QA

The fix is available in a testable build and QE is verifying it.

- **Who sets it**: QE engineer.
- **What to do**: QE runs the reproduction steps and confirms the fix. If
  the fix doesn't work, QE moves it back to ASSIGNED with a comment.
- **Exit criteria**: QE confirms the fix (move to VERIFIED).

### VERIFIED

QE has confirmed the fix works in a real build.

- **Who sets it**: QE engineer.
- **What to do**: The bug is effectively done. It stays here until the
  release ships or the bug is administratively closed.
- **Exit criteria**: Release ships (move to CLOSED).

### CLOSED

The bug is resolved. The resolution field indicates how:

| Resolution | Meaning |
|-----------|---------|
| Done | Fix shipped |
| Won't Fix | Intentional behavior or out of scope |
| Duplicate | Duplicate of another issue |
| Cannot Reproduce | Unable to reproduce the reported issue |
| Not a Bug | Working as designed |

## Transitions Summary

| From | To | Trigger |
|------|----|---------|
| NEW | ASSIGNED | Triage: assign engineer, set priority |
| NEW | CLOSED | Triage: won't fix / duplicate / not a bug |
| ASSIGNED | POST | PR opened with Jira reference |
| ASSIGNED | CLOSED | Investigation shows not a bug |
| POST | MODIFIED | PR merges |
| POST | ASSIGNED | PR closed without merge (rework needed) |
| MODIFIED | ON_QA | Build available, QE picks up |
| MODIFIED | ASSIGNED | Fix reverted or incomplete |
| ON_QA | VERIFIED | QE confirms fix |
| ON_QA | ASSIGNED | Fix doesn't work, rework needed |
| VERIFIED | CLOSED | Release ships |

## Setting Priority and Severity

### Priority

Set during triage based on customer/release impact:

| Priority | Criteria |
|----------|----------|
| Blocker | Blocks GA release, data loss, security critical |
| Critical | Severe functional impact, no workaround |
| Major | Significant impact, workaround exists |
| Normal | Moderate impact, non-urgent |
| Minor | Cosmetic, minor inconvenience |

### Severity

Severity is typically aligned with priority but captures the technical
impact separately. It's set in the Severity field if available.

### Guidelines

- Customer escalations default to at least Major.
- CVEs: priority maps to CVSS score (Critical >= 9.0, High >= 7.0, etc.).
- CI blockers: at least Major; Blocker if blocking all merges.
- Regressions from previous release: at least Major.

## Target Release Assignment

Every bug must have a Target Release before leaving the ASSIGNED state.

- **Current GA stream** (e.g., 4.17.z): For bugs affecting the latest
  shipped release. Fix goes to the z-stream branch.
- **Next GA** (e.g., 4.18.0): For bugs that will be fixed in the next
  major release.
- **Backport**: If the fix also needs to go to older releases, set
  multiple target releases or clone the bug per release.

When in doubt, discuss with the team lead during triage.

## Linking Bugs to PRs

### Automatic Linking

Include the Jira key in the PR title:
```
OCPNODE-1234: Fix CRI-O container log rotation
```

Prow's Jira plugin detects the key and:
1. Adds a link from the Jira issue to the PR.
2. Transitions the issue to POST when the PR is opened.
3. Transitions to MODIFIED when the PR merges.

### Manual Linking

```bash
./scripts/jira.sh link OCPNODE-1234 https://github.com/openshift/cri-o/pull/567
```

## Issue Link Types

### Clone

Creates an independent copy of the issue. Use for:
- Backporting a bug to a different release.
- Splitting a bug into multiple issues.

Clones are linked with "is cloned by" / "is a clone of".

### Relates To

A loose relationship between issues. Use for:
- Related bugs in different components.
- Issues discovered during investigation of another bug.

### Blocks / Is Blocked By

A dependency relationship. Use for:
- Bug A must be fixed before Bug B can be fixed.
- An API change that blocks an operator change.

### Duplicates / Is Duplicated By

When two bugs describe the same defect. Close the duplicate with resolution
"Duplicate" and link to the original.

## Bug Triage Process

### Weekly Triage Meeting

The node team holds a weekly bug triage meeting. The triage lead:

1. **Reviews NEW bugs**: Walk through each untriaged bug.
   ```bash
   ./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND status = New ORDER BY created ASC'
   ```

2. **For each bug, decide**:
   - **Assign**: Set assignee, priority, target release, move to ASSIGNED.
   - **Close**: Not a bug, duplicate, or won't fix. Set resolution.
   - **Defer**: Needs more info. Comment requesting details, leave in NEW.

3. **Review blockers**: Check on progress for Blocker/Critical bugs.
   ```bash
   ./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND priority in (Blocker, Critical) AND resolution = Unresolved'
   ```

4. **Review aging bugs**: Bugs open > 30 days without updates.
   ```bash
   ./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND resolution = Unresolved AND updated <= -30d'
   ```

### Between Triage Meetings

- Blocker/Critical bugs: triage immediately, don't wait for the meeting.
- Customer escalations: assign same day.
- New bugs with clear owner: assignee can self-triage.

### Triage Checklist

For each bug, ensure:
- [ ] Clear reproduction steps in description
- [ ] Affected version set
- [ ] Priority set (not Undefined)
- [ ] Target release set
- [ ] Assignee set
- [ ] Correct component labels (crio, kubelet, mco, etc.)
- [ ] Related issues linked
