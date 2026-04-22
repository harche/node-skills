# Node Team Jira Reference

Red Hat Jira: `redhat.atlassian.net`. The `jira.sh` script at `${CLAUDE_PLUGIN_ROOT}/scripts/jira.sh` wraps the REST API.

## Scripts

| Command | What it does |
|---|---|
| `jira.sh get <KEY>` | Full issue details |
| `jira.sh search '<JQL>' [limit]` | Search with JQL |
| `jira.sh comments <KEY>` | List comments |
| `jira.sh issue-deep-dive <KEY>` | Issue + comments + linked issues |
| `jira.sh bug-overview <team>` | Untriaged, unassigned, blockers, new bugs |
| `jira.sh my-bugs-data <team>` | My assigned bugs |
| `jira.sh my-board-data <team>` | My sprint board items |
| `jira.sh my-standup-data <team>` | My standup prep (board + bugs + comments) |
| `jira.sh sprint-dashboard <team>` | Sprint issues by status, workload, blockers |
| `jira.sh standup-data <team>` | Team standup (dashboard + recent updates) |
| `jira.sh epic-progress <KEY>` | Epic children + completion stats |
| `jira.sh release-data <team> [ver]` | Release readiness (blockers, bugs, epics) |
| `jira.sh pickup-data <team>` | Unassigned items to pick up |
| `jira.sh planning-data <team>` | Sprint planning (carryovers + backlog + bugs) |
| `jira.sh carryover-report <team>` | Not-done items from previous sprint |
| `jira.sh team-activity <team>` | Per-member sprint items |
| `jira.sh transitions <KEY>` | Available status transitions |
| `jira.sh transition <ID> <KEY>` | Perform a transition |
| `jira.sh comment "<text>" <KEY>` | Add a comment |
| `jira.sh link <KEY> <URL> <title>` | Add a remote link |

Team values: `core`, `green`, `blue`, `dra`, `kueue`, `all`

## Projects

| Project | Tracks |
|---|---|
| OCPNODE | Node team epics, stories, tasks, spikes |
| OCPBUGS | Cross-team bugs (filter by Node components) |
| RHOCPPRIO | Red Hat OpenShift Priority List (escalations) |
| OCPKUEUE | Kueue-specific work |
| OCPSTRAT | Strategy/feature tracking |

## Components We Own

Defined in saved filter "Node Components":

Node, Node / CRI-O, Node / Kubelet, Node / CPU manager, Node / Memory manager, Node / Topology manager, Node / Numa aware Scheduling, Node / Device Manager, Node / Pod resource API, Node / Node Problem Detector, Node / Kueue, Node / Instaslice-operator

## Boards & Sprints

| ID | Board | Type |
|---|---|---|
| 7845 | Node board | scrum |
| 4383 | Node-Epics | kanban |
| 9874 | Node QE | scrum |

Sprint naming: `OCP Node Core Sprint N`, `OCP Node Devices Sprint N`, `OCP Kueue Sprint N`, `CNF Compute Sprint N`

Team queue: `aos-node@redhat.com`

## Sub-teams

| Team | Filter |
|---|---|
| Core | `filter = "Node Core Team"` (`membersOf(OpenShift-Node-Team)`) |
| Green | `filter = "Node Green Team"` |
| Blue | `filter = "Node Blue Team"` |

## Saved Filters

Use in JQL via `filter = "Name"`:

| Name | ID | Scope |
|---|---|---|
| Node Components | 91645 | Component list |
| Node Bugs | 83963 | Node component bugs in OCPBUGS/RHOCPPRIO/OCPNODE |
| Node Green Team | 89708 | Green team assignees |
| Node Blue Team | 64253 | Blue team assignees |
| Node Core Team | 66331 | Core team members |
| Node Epics | 96318 | OCPNODE epics |
| Node CR bugs | 94401 | Component regression bugs |

## Custom Field IDs

Use field names in JQL, IDs for REST API calls:

| ID | Name |
|---|---|
| `customfield_10014` | Epic Link |
| `customfield_10011` | Epic Name |
| `customfield_10020` | Sprint |
| `customfield_10028` | Story Points |
| `customfield_10001` | Team |
| `customfield_10022` | Target start |
| `customfield_10023` | Target end |
| `customfield_10855` | Target Version |
| `customfield_10840` | Severity |
| `customfield_10847` | Release Blocker |
| `customfield_10877` | Bugzilla Bug |
| `customfield_10875` | Git Pull Request |
| `customfield_10978` | SFDC Cases Counter |
| `customfield_10979` | SFDC Cases Links |
| `customfield_12313441` | SFDC Cases (legacy) |

## Workflow Statuses

Bug lifecycle: NEW → To Do → ASSIGNED → POST → Modified → ON_QA → Verified → CLOSED/Done

Feature/epic: New → Planning → To Do → In Progress → Code Review → Review → Dev Complete → Done/Closed

## Key Field Meanings

| Field Value | Meaning |
|---|---|
| Priority: Undefined | Untriaged — needs prioritization |
| Release Blocker: Proposed | Someone thinks this blocks the release |
| Release Blocker: Approved | Confirmed release blocker |
| Customer Impact: Customer Escalated | Customer-reported or escalated |
| SFDC Cases Counter (not empty) | Has linked support cases |
| Special Handling: contract-priority | Contractual obligation |

## Bug Triage Definitions

Base all queries on `filter = "Node Bugs"` and append:

| Category | JQL Clause |
|---|---|
| Untriaged | `priority = Undefined OR "Release Blocker" = Proposed OR assignee in ("aos-node@redhat.com")` |
| Blocker? | `"Release Blocker" = Proposed OR priority = Blocker AND "Release Blocker" is EMPTY` |
| Blocker+ | `"Release Blocker" = Approved OR priority = Blocker` |
| Customer Issues | `"Customer Impact" = "Customer Escalated" OR "SFDC Cases Counter" is not EMPTY` |
| Escalations | `project = "Red Hat OpenShift Priority List" OR "Customer Impact" = "Customer Escalated" OR labels in (shift_telco5g)` |
| CVE | `labels in (SecurityTracking) OR issuetype in (Vulnerability, Weakness)` |
| CR | `labels = component-regression` |

## Gotchas

- Epic children: use `"Epic Link" = EPIC-KEY` in JQL (not `parentEpic`).
- `issueFunction` (e.g. `issueFunction in commented("by currentUser()")`) does **not exist** on Jira Cloud. Workaround: `watcher = currentUser() AND comment ~ "keyword"`.
- Always confirm with the user before any write operation (create, edit, comment, transition).
