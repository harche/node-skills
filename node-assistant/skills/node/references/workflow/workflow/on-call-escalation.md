# Escalation Procedures

## Severity Levels and Response Times

| Severity | Customer Impact | Initial Response | Ongoing Updates | Resolution Target |
|----------|----------------|------------------|-----------------|-------------------|
| 1 - Urgent | Production down, no workaround | 1 hour | Continuous / hourly | ASAP, all hands |
| 2 - High | Major impact, degraded with workaround | 4 hours | Every business day | Within current sprint |
| 3 - Normal | Moderate impact, functional workaround | 1 business day | Weekly | Planned release |
| 4 - Low | Minor issue, informational | 2 business days | As needed | Best effort |

### Severity Assessment Guidelines

When a new escalation arrives, assess severity based on:

- **Blast radius**: How many nodes / clusters / customers are affected?
- **Data risk**: Is there any risk of data loss or corruption?
- **Workaround**: Does a workaround exist, and is it acceptable long-term?
- **Trend**: Is the issue getting worse (e.g., more nodes failing over time)?
- **Release impact**: Does this block an upcoming release?

If in doubt, treat it as one level higher than you think.

## Internal Escalation Path

### Level 1: Within the Team

**When**: You need help investigating, or you're stuck on a problem.

**How**:
- Post in `#team-node` with a summary and ask for help.
- Tag specific people who have expertise in the relevant area.
- For urgent issues, use `@here` in `#team-node`.

**Examples**:
- You don't know the kubelet area well enough.
- You need a second opinion on root cause.
- You're handling multiple incidents simultaneously.

### Level 2: Team Lead

**When**: The issue needs coordination beyond what you can do as on-call.

**How**:
- Message the team lead directly (Slack DM or PagerDuty).
- Provide: issue summary, current status, what you've tried, what you need.

**Examples**:
- Cross-team dependency is blocking progress.
- Need to pull in additional engineers.
- Customer is unhappy with response time.
- Decision needed on whether to do an emergency z-stream.

### Level 3: Manager

**When**: The issue has organizational or business impact beyond the team.

**How**:
- Team lead escalates to manager.
- In extreme urgency, the on-call engineer can escalate directly.

**Examples**:
- Multiple Sev 1 issues simultaneously.
- Need resources from other teams.
- Issue involves a strategic customer.
- Potential PR / communications issue.

### Level 4: Director / VP

**When**: Business-critical situation requiring executive attention.

**How**:
- Manager escalates through the management chain.

**Examples**:
- Widespread outage affecting many customers.
- Security incident with active exploitation.
- Issue that could affect a major release timeline.

## External Escalation Flow

### Standard Flow

```
Customer
  |
  v
Support Case (Red Hat Customer Portal)
  |
  v
CEE (Customer Experience & Engagement)
  |
  v  (CEE creates/links Jira issue)
Node Team On-Call Engineer
  |
  v  (if needed)
Team Lead --> Manager --> Director
```

### Expedited Flow (Sev 1)

```
Customer --> Support Case --> Case Manager assigned
                                    |
                                    v
                    CEE + Engineering (bridge call)
                                    |
                                    v
                    Real-time troubleshooting
```

### CEE Interaction

- CEE is the customer-facing contact. All customer communication goes
  through CEE unless they explicitly arrange a direct call.
- Provide CEE with clear, actionable information they can relay.
- Avoid jargon that isn't helpful to the customer.
- If CEE asks for a bridge call, prepare: have logs analyzed, hypotheses
  ready, and know what additional data you need.

## Bridge Call Procedures

### When Bridge Calls Happen

- Sev 1 escalations (almost always).
- Sev 2 escalations where the customer requests it.
- Multi-day Sev 2 issues where progress has stalled.

### Preparing for a Bridge Call

1. **Review the issue end-to-end**:
   ```bash
   ./scripts/jira.sh issue-deep-dive OCPNODE-1234
   ```

2. **Have your analysis ready**:
   - What do you know for certain?
   - What are your hypotheses?
   - What data do you still need?
   - What is the timeline for a fix?

3. **Know the customer's environment**: Platform, version, scale, workloads.

4. **Have commands ready**: If you'll need the customer to run diagnostic
   commands, prepare them in advance.

### During the Call

- **Introduce yourself** and your role.
- **State the current understanding** clearly.
- **Be honest** about what you don't know. "We're investigating" is fine.
- **Ask specific questions**: Don't ask "tell me everything." Ask "can you
  confirm if the node was rebooted at 14:30 UTC?"
- **Take notes**: Document action items and who owns them.
- **Set expectations**: When will the next update be? What are the next steps?

### After the Call

1. Update the Jira issue with:
   - Call summary.
   - Findings.
   - Action items and owners.
   - Next steps and timeline.
2. Follow through on your action items promptly.
3. Schedule the next check-in if needed.

## Cross-Team Escalation

### When You Need Another Team

Common scenarios where node issues involve other teams:

| Situation | Team to Engage | Slack Channel |
|-----------|---------------|---------------|
| Kernel bug (cgroup, overlayfs, scheduling) | Kernel / RHEL team | `#forum-kernel` |
| Network issue on nodes | SDN / OVN team | `#forum-sdn` |
| Storage issue on nodes | Storage team | `#forum-storage` |
| Installer / bootstrap failure | Installer team | `#forum-installer` |
| API server unreachable from nodes | API / etcd team | `#forum-apiserver` |
| Image registry pull failures | Image Registry team | `#forum-imageregistry` |
| Release / build issues | TRT | `#forum-ocp-crt` |

### How to Engage Another Team

1. **File a bug in their project** or **comment on the existing bug** with
   a clear request.
2. **Post in their Slack channel** with:
   - Brief summary of the issue.
   - Why you believe their component is involved.
   - Link to the Jira issue.
   - Severity and urgency.
3. **Tag their on-call** if they have one and the issue is urgent.
4. **Follow up** if you don't get a response within the SLA window.

## Post-Incident Review

### When to Do a Post-Incident Review

- Any Sev 1 incident.
- Sev 2 incidents that lasted more than 2 days.
- Incidents that revealed systemic issues.
- Any incident the team lead deems worth reviewing.

### Post-Incident Review Format

1. **Timeline**: What happened, when, in chronological order.
2. **Impact**: What was affected and for how long.
3. **Root Cause**: The underlying technical cause.
4. **Detection**: How was the issue detected? Could we have detected it
   sooner?
5. **Response**: What went well? What could be improved?
6. **Action Items**: Concrete steps to prevent recurrence.
   - Each action item has an owner and a target date.
   - Action items become Jira tasks in OCPNODE.

### Blameless Culture

Post-incident reviews are blameless. The goal is to improve systems and
processes, not to assign blame. Focus on:
- What information was missing?
- What tools or automation could help?
- What monitoring gaps exist?
- What documentation should be updated?

### Documenting the Review

- Create a Jira issue of type Task with label `postmortem`.
- Attach the timeline and findings.
- Link to the original incident bug.
- Track action items as sub-tasks.
- Share the review summary in `#team-node` for team awareness.
