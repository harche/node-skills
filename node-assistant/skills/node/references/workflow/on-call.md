# On-Call Playbook

## Overview

The Node team maintains an on-call rotation to handle CI breakages, customer
escalations, and production issues affecting node components. The on-call
engineer is the first responder for anything urgent that can't wait for
normal sprint work.

## Rotation

- **Rotation length**: 1 week (Monday to Monday).
- **Coverage**: Business hours for your timezone; after-hours only for
  Severity 1 escalations.
- **Tool**: PagerDuty or team-managed rotation schedule (check with team lead
  for current setup).
- **Handoff**: Monday morning. Outgoing on-call writes a summary; incoming
  on-call reviews it.

## On-Call Responsibilities

### Primary Duties

1. **Monitor CI health**: Watch for node-related CI job failures that affect
   the broader OpenShift CI system.
2. **Triage incoming bugs**: Review new OCPNODE bugs that arrive outside the
   weekly triage meeting.
3. **Handle escalations**: Respond to customer escalations routed to the
   Node team.
4. **Unblock the team**: If a team member is blocked by CI or infra, help
   investigate.

### What On-Call Is NOT

- On-call does not mean you stop all sprint work. Handle interrupts, then
  return to sprint items.
- On-call does not mean you fix every issue yourself. Triage, investigate,
  and route to the right person.
- On-call does not mean you're available 24/7 (unless Sev 1).

## Daily On-Call Routine

### Morning Check

1. **Check Slack channels** for overnight activity:
   - `#forum-node`
   - `#team-node`
   - `#forum-ocp-crt` (CI issues)

2. **Review new bugs**:
   ```bash
   ./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND status = New AND created >= -1d ORDER BY priority DESC'
   ```

3. **Check escalations**:
   ```bash
   ./scripts/jira.sh search 'project = OCPNODE AND labels = escalation AND resolution = Unresolved AND updated >= -1d ORDER BY priority DESC'
   ```

4. **Check CI dashboards**: Review Prow for node-related job health.

### Throughout the Day

- Respond to Slack pings in node channels.
- Monitor PagerDuty for alerts.
- Update Jira on any in-progress escalations.

### End of Day

- Post a brief summary in `#team-node` if there were notable incidents.
- Ensure any Sev 1/2 issues have a clear status and next steps documented.

## Communication Channels

| Channel | Purpose |
|---------|---------|
| `#team-node` | Internal team discussion |
| `#forum-node` | Cross-team node questions |
| `#forum-ocp-crt` | CI/release tooling issues |
| `#forum-qe` | QE coordination |
| PagerDuty | Sev 1 escalation alerts |
| Email: node-team@redhat.com | Team distribution list |

## When to Page / Escalate

| Situation | Action |
|-----------|--------|
| CI completely broken for node repos | Post in `#forum-ocp-crt`, investigate |
| Customer Sev 1 escalation | Respond immediately, consider bridge call |
| Customer Sev 2 escalation | Acknowledge within 4 hours |
| Node component crash in CI | Investigate, file bug if new |
| Security vulnerability (CVE) | Escalate to team lead immediately |
| Unsure if it's your problem | Triage and route; don't sit on it |

## Detail References

- **Runbook**: [workflow/on-call-runbook.md](workflow/on-call-runbook.md) -- monitoring, common alerts, first-response actions
- **Escalation Procedures**: [workflow/on-call-escalation.md](workflow/on-call-escalation.md) -- severity levels, escalation paths, bridge calls
