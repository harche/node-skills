# Support Case Workflow

## Overview

When a customer opens a Red Hat support case that involves node-level
components (kubelet, CRI-O, MCO, node networking, etc.), it may be routed
to the Node team for engineering investigation.

## How Cases Reach the Node Team

1. **Customer** opens a support case on the Red Hat Customer Portal.
2. **CEE (Customer Experience & Engagement)** triages the case.
3. If CEE determines the issue is in a node component, they:
   - Create a Jira bug in OCPNODE (or link to an existing one).
   - Tag it with `escalation` and/or `customer` labels.
   - Set priority based on case severity.
4. The **on-call engineer** or **triage lead** picks it up.

## Responding to Support Escalations

### Initial Response

1. **Read the Jira issue thoroughly**:
   ```bash
   ./scripts/jira.sh issue-deep-dive OCPNODE-1234
   ```

2. **Understand the customer environment**: OCP version, platform (AWS, bare
   metal, vSphere, etc.), cluster size, workload type.

3. **Check for known issues**: Search Jira and the Knowledge Base for similar
   reports.
   ```bash
   ./scripts/jira.sh search 'project = OCPNODE AND type = Bug AND text ~ "crio timeout" AND resolution = Unresolved'
   ```

4. **Comment on the Jira issue** with your initial assessment and any
   questions for the customer (CEE relays to the customer).

### Gathering Diagnostic Data

#### must-gather

The standard diagnostic collection for OpenShift clusters:

```bash
oc adm must-gather
```

For node-specific data, use targeted must-gather:
```bash
# General node diagnostics
oc adm must-gather --image=quay.io/openshift/must-gather

# MCO-specific
oc adm must-gather --image=quay.io/openshift/must-gather -- /usr/bin/gather_mco
```

must-gather collects:
- Node status and conditions
- Kubelet logs
- CRI-O logs
- MCO daemon logs
- MachineConfig and MachineConfigPool status
- Pod and container status across nodes

#### sosreport

For deeper host-level diagnostics when must-gather is insufficient:

```bash
# On the affected node (via debug pod)
oc debug node/<node-name>
chroot /host
sosreport --batch --all-logs
```

sosreport collects:
- Full system logs (journald)
- Kernel parameters and dmesg
- Network configuration
- Filesystem and disk state
- SELinux context
- cgroup hierarchy

#### Targeted Log Collection

When you know what to look for:

```bash
# Kubelet logs from a specific node
oc adm node-logs <node-name> -u kubelet

# CRI-O logs
oc adm node-logs <node-name> -u crio

# MCO daemon logs
oc logs -n openshift-machine-config-operator pod/machine-config-daemon-xxxxx

# Kernel logs
oc adm node-logs <node-name> --path=journal -u kernel
```

## Linking Support Cases to Jira Bugs

### Creating a Bug from a Case

If no existing bug matches:
1. Create a new OCPNODE bug with the customer's reproduction steps.
2. Add the `escalation` label.
3. Link the support case URL:
   ```bash
   ./scripts/jira.sh link OCPNODE-1234 https://access.redhat.com/support/cases/#/case/03123456
   ```
4. Set priority to match the case severity.

### Linking to Existing Bugs

If an existing bug matches:
1. Add a comment noting the customer case.
2. Link the case:
   ```bash
   ./scripts/jira.sh link OCPNODE-5678 https://access.redhat.com/support/cases/#/case/03123456
   ```
3. Consider raising priority if multiple customers are affected.

## Red Hat Knowledge Base

### Searching for Existing Solutions

Before deep investigation, check if a Knowledge Base article or solution
already exists:

- Search at https://access.redhat.com/search/
- Filter by product (OpenShift Container Platform) and version.
- Check the "Known Issues" section of the release notes.

### Writing Knowledge Base Articles

If you solve a novel issue that may recur:
1. Draft a solution article with symptoms, root cause, and resolution.
2. Submit through the internal Knowledge Base authoring process.
3. Link the article to the Jira bug.

## Escalation Process

### Severity Levels and SLAs

| Severity | Definition | Initial Response | Update Frequency |
|----------|-----------|------------------|-----------------|
| 1 (Urgent) | Production down, no workaround | 1 hour | Continuous |
| 2 (High) | Major impact, workaround exists | 4 hours | Daily |
| 3 (Normal) | Moderate impact | 1 business day | Weekly |
| 4 (Low) | Minor issue, informational | 2 business days | As needed |

### Internal Escalation Path

1. **Engineer** investigates and provides updates.
2. **Team Lead**: Escalate if you're blocked or need more resources.
3. **Manager**: Escalate if cross-team coordination is needed.
4. **Director / VP**: For business-critical situations.

### When to Escalate Internally

- You're stuck and need help from another team (kernel, networking, storage).
- The fix requires a z-stream errata and needs release engineering.
- Multiple customers are affected (pattern recognition).
- The SLA is at risk.

### External Escalation Flow

```
Customer --> Support Case --> CEE Triage --> Engineering (Node Team)
                                  |
                                  v
                          Case Manager (if Sev 1/2)
                                  |
                                  v
                          Bridge call (if needed)
```

### Bridge Calls

For Severity 1 escalations, a bridge call may be set up:
- **Attendees**: Customer, CEE, Engineering (you), potentially management.
- **Purpose**: Real-time troubleshooting and status updates.
- **Prep**: Have the must-gather analyzed, relevant logs pulled, and a
  working theory before the call.
- **Follow-up**: Document findings and next steps in the Jira issue
  immediately after the call.

## Communication Guidelines

- All technical findings go in the **Jira issue** (not just Slack/email).
- CEE is the customer-facing contact. Don't contact the customer directly
  unless CEE arranges it.
- Update the Jira issue at least as often as the SLA requires.
- If you hand off to another engineer, document your findings and current
  status in the issue before handing off.

## Post-Resolution

1. Ensure the bug has the correct fix version and target release.
2. If a z-stream errata is needed, work with release engineering.
3. Confirm with CEE that the customer can verify the fix.
4. Consider writing a Knowledge Base article if the issue is likely to recur.
5. Close the bug through the normal lifecycle once verified.
