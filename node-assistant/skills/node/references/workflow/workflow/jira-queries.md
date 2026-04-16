# Common Jira Queries for Node Team

## Personal Queries

### My Open Bugs

```bash
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND assignee = currentUser() AND resolution = Unresolved ORDER BY priority DESC'
```

### My Sprint Items

```bash
./scripts/jira.sh search 'project = OCPNODE AND assignee = currentUser() AND sprint in openSprints() ORDER BY priority DESC'
```

### My Recently Updated

```bash
./scripts/jira.sh search 'project = OCPNODE AND assignee = currentUser() AND updated >= -7d ORDER BY updated DESC'
```

### My POST Items (Awaiting Merge)

```bash
./scripts/jira.sh search 'project = OCPNODE AND assignee = currentUser() AND status = POST ORDER BY updated ASC'
```

## Triage Queries

### Untriaged Bugs

Bugs with no priority set, awaiting triage:

```bash
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND status = New AND priority = Undefined ORDER BY created ASC'
```

### Untriaged Bugs (Broader)

Includes bugs that are New regardless of priority:

```bash
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND status = New ORDER BY created ASC'
```

### Bugs Missing Target Release

```bash
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND resolution = Unresolved AND "Target Release" is EMPTY ORDER BY priority DESC'
```

### Bugs Without Assignee

```bash
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND assignee is EMPTY AND resolution = Unresolved ORDER BY priority DESC'
```

## Priority-Based Queries

### Blocker Bugs

```bash
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND priority in (Blocker, Critical) AND resolution = Unresolved ORDER BY priority ASC, created ASC'
```

### Upgrade Blockers

```bash
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND labels = UpgradeBlocker AND resolution = Unresolved ORDER BY priority DESC'
```

### Release Blockers for a Specific Version

```bash
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND "Target Release" = "4.17.0" AND priority in (Blocker, Critical) AND resolution = Unresolved'
```

## Sprint and Backlog Queries

### Current Sprint Dashboard

```bash
./scripts/jira.sh sprint-dashboard "Node"
```

### Sprint Completion Status

```bash
./scripts/jira.sh search 'project = OCPNODE AND sprint in openSprints() ORDER BY status ASC, priority DESC'
```

### Backlog Items

```bash
./scripts/jira.sh search 'project = OCPNODE AND type in (Story, Task) AND sprint is EMPTY AND resolution = Unresolved ORDER BY priority DESC, created ASC'
```

### Backlog Bugs (Not Scheduled)

```bash
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND sprint is EMPTY AND resolution = Unresolved ORDER BY priority DESC'
```

## CVE Tracking

### Open CVEs

```bash
./scripts/jira.sh search 'project = OCPNODE AND labels = cve AND resolution = Unresolved ORDER BY priority DESC'
```

### CVEs by Severity

```bash
./scripts/jira.sh search 'project = OCPNODE AND labels = cve AND priority in (Blocker, Critical) AND resolution = Unresolved ORDER BY created ASC'
```

### CVEs Missing Fix Version

```bash
./scripts/jira.sh search 'project = OCPNODE AND labels = cve AND resolution = Unresolved AND fixVersion is EMPTY ORDER BY priority DESC'
```

## Escalation Tracking

### Active Escalations

```bash
./scripts/jira.sh search 'project = OCPNODE AND labels = escalation AND resolution = Unresolved ORDER BY priority DESC'
```

### Customer-Reported Issues

```bash
./scripts/jira.sh search 'project = OCPNODE AND labels in (customer, escalation) AND resolution = Unresolved ORDER BY priority DESC'
```

### Escalations Without Updates in 3 Days

```bash
./scripts/jira.sh search 'project = OCPNODE AND labels = escalation AND resolution = Unresolved AND updated <= -3d ORDER BY updated ASC'
```

## Bug Triage Views

### Weekly Triage Prep

All bugs needing triage discussion -- new, unassigned, or missing priority:

```bash
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND (status = New OR assignee is EMPTY OR priority = Undefined) AND resolution = Unresolved ORDER BY created ASC'
```

### Recently Closed Bugs (Past Week)

For triage review of what was resolved:

```bash
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND status changed to Closed after -7d ORDER BY resolved DESC'
```

### Bugs by Component

```bash
# CRI-O bugs
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND labels = crio AND resolution = Unresolved ORDER BY priority DESC'

# Kubelet bugs
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND labels = kubelet AND resolution = Unresolved ORDER BY priority DESC'

# MCO bugs
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND labels = mco AND resolution = Unresolved ORDER BY priority DESC'
```

### Bugs Aging Over 30 Days

```bash
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND resolution = Unresolved AND created <= -30d AND status != "ON_QA" ORDER BY created ASC'
```

## Release Queries

### All Open Issues for a Release

```bash
./scripts/jira.sh search 'project = OCPNODE AND "Target Release" = "4.17.0" AND resolution = Unresolved ORDER BY type ASC, priority DESC'
```

### Release Readiness

```bash
./scripts/jira.sh search 'project = OCPNODE AND "Target Release" = "4.17.0" AND type = Bug AND resolution = Unresolved AND priority in (Blocker, Critical) ORDER BY priority ASC'
```

### Completed Work for Release

```bash
./scripts/jira.sh search 'project = OCPNODE AND "Target Release" = "4.17.0" AND resolution = Done ORDER BY resolved DESC'
```

## Composite Commands

These `jira.sh` commands aggregate multiple queries:

```bash
# Full sprint status with breakdown
./scripts/jira.sh sprint-dashboard "Node"

# Your work items for standup
./scripts/jira.sh standup-data

# Bug overview across all priorities
./scripts/jira.sh bug-overview

# Deep dive into a specific issue (details + comments + links)
./scripts/jira.sh issue-deep-dive OCPNODE-1234
```

## Tips

- JQL string must be quoted when passed to `jira.sh search`.
- Use `currentUser()` for your own issues -- it resolves based on your auth.
- `openSprints()` matches any active sprint; `closedSprints()` matches past.
- Date functions: `-7d` (7 days ago), `-1w` (1 week), `-30d` (30 days).
- Combine queries with `AND` / `OR`; use parentheses for grouping.
- Add `ORDER BY` to control result ordering (default is relevance).
