# Jira and Support Workflow

## Overview

The Node team uses Red Hat Jira (issues.redhat.com) for all work tracking:
bugs, features, tasks, and support escalations. The project key is **OCPNODE**.

## Investigating a Ticket

When answering questions about a ticket (PRs, related bugs, context), **look at the Jira data first** — the ticket's links, comments, and related issues already contain PRs, linked bugs, and context. Use `jira.sh issue-deep-dive <ticket>` to get the full picture. Do not search GitHub or the web unless the Jira data doesn't have what you need.

## CLI Access

Use the `jira.sh` script for command-line Jira operations:

```bash
./scripts/jira.sh <command> [args]
```

### Quick Reference Commands

| Command | Description |
|---------|-------------|
| `jira.sh get OCPNODE-1234` | Get issue details |
| `jira.sh search '<JQL>'` | Search issues with JQL |
| `jira.sh issue-deep-dive OCPNODE-1234` | Full issue details + comments + links |
| `jira.sh link OCPNODE-1234 <URL>` | Add external link to issue |
| `jira.sh sprint-dashboard "Node"` | Current sprint overview |
| `jira.sh standup-data` | Your recent work for standup |
| `jira.sh bug-overview` | Bug summary across priorities |

### Common One-Liners

```bash
# My open issues
./scripts/jira.sh search 'project = OCPNODE AND assignee = currentUser() AND resolution = Unresolved'

# Untriaged bugs
./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND status = New AND priority = Undefined'

# Link a PR to a Jira issue
./scripts/jira.sh link OCPNODE-1234 https://github.com/openshift/machine-config-operator/pull/4567

# Deep dive into a bug before standup
./scripts/jira.sh issue-deep-dive OCPNODE-1234
```

## Issue Types

| Type | Usage |
|------|-------|
| Bug | Defect in shipped or pre-ship code |
| Story | Feature work scoped to a sprint |
| Task | Non-feature work (CI, infra, docs, process) |
| Epic | Large feature spanning multiple stories |
| Sub-task | Breakdown of a story or task |
| Spike | Time-boxed investigation |

## Priority Levels

| Priority | Meaning | Response |
|----------|---------|----------|
| Blocker | Blocks release or customer | Immediate |
| Critical | Severe impact, workaround exists | Within 1 day |
| Major | Significant impact | Within sprint |
| Normal | Standard priority | Planned |
| Minor | Low impact | Backlog |
| Undefined | Not yet triaged | Triage ASAP |

## Workflow States

Issues move through: `NEW` -> `ASSIGNED` -> `POST` -> `MODIFIED` -> `ON_QA`
-> `VERIFIED` -> `CLOSED`. See the detail reference for the full lifecycle.

## Creating Issues

### Bug Template

When filing a bug, include:
- **Summary**: Clear, searchable title.
- **Description**: Steps to reproduce, expected vs actual behavior.
- **Component**: `Node` or specific sub-component.
- **Affects Version**: OCP version where the bug is observed.
- **Target Release**: OCP version for the fix (set during triage).
- **Priority**: Set if known, otherwise leave as Undefined for triage.
- **Labels**: Add `node`, plus relevant labels like `crio`, `kubelet`, `mco`.

### Story Template

- **Summary**: User-facing description of the feature.
- **Description**: Acceptance criteria, design pointers, dependencies.
- **Epic Link**: Link to parent epic if applicable.
- **Story Points**: Estimate during sprint planning.

## Sprint Process

The node team runs 3-week sprints. Key ceremonies:
- **Sprint Planning**: Review backlog, commit to sprint scope.
- **Daily Standup**: Status updates, blockers.
- **Sprint Review**: Demo completed work.
- **Retrospective**: Process improvements.

Use `jira.sh sprint-dashboard "Node"` to see current sprint status.

## Labels and Components

### Common Labels

| Label | Usage |
|-------|-------|
| `node` | General node team work |
| `crio` | CRI-O related |
| `kubelet` | Kubelet related |
| `mco` | Machine Config Operator related |
| `escalation` | Customer escalation |
| `cve` | Security vulnerability |
| `ci-blocker` | Blocking CI |
| `test-blocker` | Blocking test execution |
| `UpgradeBlocker` | Blocking upgrades |

## Detail References

- **Jira Queries**: [workflow/jira-queries.md](workflow/jira-queries.md) -- common JQL queries, triage views, dashboards
- **Bug Lifecycle**: [workflow/bug-lifecycle.md](workflow/bug-lifecycle.md) -- states, transitions, triage process
- **Support Cases**: [workflow/support-cases.md](workflow/support-cases.md) -- customer case workflow, diagnostics, escalation
