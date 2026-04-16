# On-Call Runbook

## Monitoring Dashboards

### CI Dashboards

| Dashboard | URL | What to Watch |
|-----------|-----|---------------|
| Prow | https://prow.ci.openshift.org | Job pass/fail rates for node repos |
| TestGrid | https://testgrid.k8s.io/redhat | Trend of test results over time |
| CI Search | https://search.ci.openshift.org | Search across all job logs |
| Sippy | https://sippy.dptools.openshift.org | Release health and test pass rates |

### Cluster Monitoring

For live clusters under investigation:

| Dashboard | How to Access |
|-----------|--------------|
| Prometheus | `oc port-forward -n openshift-monitoring prometheus-k8s-0 9090` |
| Grafana (if deployed) | `oc port-forward -n openshift-monitoring grafana-xxxxx 3000` |
| Alert Manager | `oc port-forward -n openshift-monitoring alertmanager-main-0 9093` |

### Key Metrics to Watch

- **Node readiness**: `kube_node_status_condition{condition="Ready"}` -- any
  node going NotReady is an immediate concern.
- **Kubelet restart rate**: `process_start_time_seconds{job="kubelet"}` --
  frequent restarts indicate a crash loop.
- **CRI-O health**: `container_runtime_crio_operations_total` -- track
  operation latency and error rates.
- **MCO state**: `mco_degraded_machine_count` -- non-zero means MCO has
  degraded nodes.
- **Pod startup latency**: `kubelet_pod_start_duration_seconds` -- regression
  here affects all workloads.

## Common Alerts and First-Response Actions

### KubeletDown

**Meaning**: Kubelet on a node has stopped responding.

**First response**:
1. Check if the node is reachable: `oc get node <name>`.
2. Check kubelet status: `oc debug node/<name> -- chroot /host systemctl status kubelet`.
3. Check kubelet logs: `oc adm node-logs <name> -u kubelet --since=-30m`.
4. Check for OOM or resource exhaustion: `oc adm node-logs <name> -u kernel | grep -i oom`.

**Common causes**: OOM kill, disk pressure, kernel panic, bad MachineConfig
update.

### MCODegraded

**Meaning**: Machine Config Operator cannot apply configuration to one or
more nodes.

**First response**:
1. Check MachineConfigPool status: `oc get mcp`.
2. Check MCO daemon pods: `oc get pods -n openshift-machine-config-operator`.
3. Check daemon logs on the degraded node:
   `oc logs -n openshift-machine-config-operator -l k8s-app=machine-config-daemon --field-selector spec.nodeName=<name>`.
4. Look for failed systemd units on the node.

**Common causes**: Invalid MachineConfig, disk full, conflict between
MachineConfigs, node unreachable.

### CrioOperationTimeout

**Meaning**: CRI-O operation (pull, create, start, stop) timed out.

**First response**:
1. Check CRI-O logs: `oc adm node-logs <name> -u crio --since=-30m`.
2. Check for storage issues: `oc debug node/<name> -- df -h /var/lib/containers`.
3. Check for network issues (image pull timeout): review CRI-O pull logs.
4. Check conmon processes: `oc debug node/<name> -- chroot /host ps aux | grep conmon`.

**Common causes**: Storage full, slow image registry, kernel bug affecting
overlayfs, stuck container processes.

### NodeNotReady

**Meaning**: Node status has transitioned to NotReady.

**First response**:
1. Check node conditions: `oc describe node <name>` -- look at Conditions.
2. Check kubelet: is it running?
3. Check system resources: disk, memory, pid pressure.
4. Check recent MachineConfig changes that might have triggered a reboot.

**Common causes**: Kubelet crash, network partition, disk pressure (especially
`/var`), certificate expiry.

### NodeClockNotSynchronising

**Meaning**: NTP is not working on the node.

**First response**:
1. Check chronyd status: `oc debug node/<name> -- chroot /host systemctl status chronyd`.
2. Verify NTP sources: `oc debug node/<name> -- chroot /host chronyc sources`.
3. Check if the node can reach NTP servers (network/firewall issue).

**Common causes**: Firewall blocking NTP, misconfigured chrony, upstream NTP
server down.

## CI Breakage Triage

### Identifying Node-Related CI Failures

1. Check Prow for recent failures in node-owned repos:
   - `openshift/machine-config-operator`
   - `openshift/kubernetes` (node-related jobs)
   - `openshift/cri-o`

2. Check if failures are widespread or limited to one repo/job:
   - If widespread: likely infra issue. Check `#forum-ocp-crt`.
   - If limited to node repos: likely a code or config regression.

3. Look at the failure timeline -- did it start after a specific merge?

### Common CI Breakage Patterns

**Image build failure**: A dependency changed or a Dockerfile broke.
- Check the `images` job output.
- Look for go build errors or missing packages.

**E2E cluster provisioning failure**: Not your problem (usually).
- Check if other repos also fail provisioning.
- Post in `#forum-ocp-crt`.

**E2E test failure in node tests**: Likely a real regression.
- Check which test(s) failed.
- Look at the PR merge history for the repo.
- Reproduce locally if possible.

**Vendor/dependency failure**: A dependency update broke the build.
- Check recent go.mod / vendor changes.
- May need to pin or update the dependency.

### Taking Action on CI Breakage

1. **File a bug** if the breakage is new and not already tracked.
2. **Post in `#forum-ocp-crt`** if you need TRT (Technical Release Team) help.
3. **Consider a revert** if a specific PR clearly caused the break and the
   fix isn't obvious.
4. **Use `/override`** on blocked PRs if the failure is known-infrastructure
   and unrelated to PR content (admin only).

## Customer Escalation Handling

When an escalation arrives during on-call:

1. **Acknowledge quickly**: Comment on the Jira issue that you're looking at
   it.
   ```bash
   ./scripts/jira.sh get OCPNODE-1234
   ```

2. **Assess severity**: Match to SLA response times.

3. **Gather data**: Request must-gather and sosreport if not already attached.

4. **Investigate**: Use the diagnostic approaches from the support-cases
   reference.

5. **Update regularly**: Per SLA update frequency requirements.

6. **Escalate if needed**: Don't sit on a problem you can't solve. Reach out
   to other team members or other teams.

## Handoff Process

At the end of your on-call rotation:

### Outgoing On-Call

1. Write a handoff summary covering:
   - Active escalations and their status.
   - CI issues that are ongoing.
   - Any in-progress investigations.
   - Anything the incoming on-call should watch for.

2. Post the summary in `#team-node`.

3. Update all Jira issues with current status.

### Incoming On-Call

1. Read the handoff summary.
2. Review active escalations:
   ```bash
   ./scripts/jira.sh search 'project = OCPNODE AND labels = escalation AND resolution = Unresolved ORDER BY priority DESC'
   ```
3. Check CI dashboard for current health.
4. Confirm PagerDuty rotation has switched to you.

## When to Page vs Handle Yourself

### Handle Yourself

- CI flake that resolves on retest.
- New bug that can wait for triage meeting.
- Sev 3/4 escalation with clear next steps.
- Questions in Slack that you can answer.

### Page / Escalate

- Sev 1 escalation (customer production down).
- Security vulnerability with active exploit.
- CI completely blocked for a node repo with no obvious fix.
- Issue in a component you don't know well enough to investigate.
- You're overloaded with concurrent incidents.

Use PagerDuty to page the team lead or a specific SME. In Slack, use
`@here` in `#team-node` for urgent but not page-worthy items.
