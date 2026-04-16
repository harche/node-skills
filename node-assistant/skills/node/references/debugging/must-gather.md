# must-gather Analysis

must-gather is OpenShift's diagnostic data collection tool. It captures cluster state, logs, and configuration into a local directory for offline analysis and support case attachment.

## Sub-references

- `must-gather/structure.md` -- directory layout, where to find specific data
- `must-gather/analysis.md` -- triage patterns, omc tool, timeline reconstruction
- `must-gather/node-focused.md` -- node-specific data extraction and analysis

## What is must-gather

`oc adm must-gather` runs a privileged pod on the cluster that collects:
- Cluster resource definitions (nodes, pods, services, operators, etc.)
- Component logs (kubelet, CRI-O, operator pods)
- Events
- Cluster operator status
- MachineConfig/MachineConfigPool state
- Audit logs (optional)
- Prometheus metrics data (optional)

The output is a local tarball/directory that can be analyzed offline or attached to a support case.

## Running must-gather

### Default Collection

```bash
# Standard must-gather (all cluster data)
oc adm must-gather

# Specify output directory
oc adm must-gather --dest-dir=/tmp/must-gather-$(date +%Y%m%d)
```

### With Specific Images

Different images collect different data:

```bash
# Default OpenShift must-gather
oc adm must-gather --image=quay.io/openshift/origin-must-gather:latest

# Network diagnostics (OVN-K specific)
oc adm must-gather --image=quay.io/openshift/origin-must-gather --image=quay.io/openshift/origin-network-must-gather

# Storage diagnostics
oc adm must-gather --image=quay.io/openshift/origin-must-gather --image=quay.io/openshift/ocs-must-gather

# Multiple images at once
oc adm must-gather \
  --image=quay.io/openshift/origin-must-gather \
  --image=quay.io/openshift/origin-network-must-gather
```

### Scoped Collection

```bash
# Only collect for specific namespaces
oc adm must-gather -- /usr/bin/gather_namespaces <namespace1> <namespace2>

# Only audit logs
oc adm must-gather -- /usr/bin/gather_audit_logs

# Time-bounded (since a specific time)
oc adm must-gather --since=2h

# Specific node
oc adm must-gather --node-name=<node>
```

### Handling Collection Issues

```bash
# Increase timeout (default 10 minutes)
oc adm must-gather --timeout=30m

# Run on a specific node (when scheduling is constrained)
oc adm must-gather --node-name=<node>

# If cluster is severely degraded, collect what you can manually:
oc get nodes -o yaml > nodes.yaml
oc get events -A --sort-by='.lastTimestamp' > events.txt
oc get co > clusteroperators.txt
oc adm node-logs <node> -u kubelet --since "1h" > kubelet.log
```

## Quick Triage Checklist

After obtaining a must-gather, check these first:

1. **Cluster operators** -- `cat cluster-scoped-resources/config.openshift.io/clusteroperators.yaml`
2. **Node status** -- `cat cluster-scoped-resources/core/nodes/`
3. **Events** -- look in namespace-scoped `events.yaml` files
4. **MachineConfigPool** -- `cat cluster-scoped-resources/machineconfiguration.openshift.io/machineconfigpools/`
5. **Pod status** -- check for non-Running pods across key namespaces

## omc (OpenShift Must-gather Client)

`omc` is a CLI tool that lets you run `oc`-like commands against a must-gather directory as if it were a live cluster.

```bash
# Install
go install github.com/gmeghnag/omc@latest

# Point to a must-gather
omc use /path/to/must-gather/

# Then use familiar commands
omc get nodes
omc get pods -A
omc get events -A --sort-by='.lastTimestamp'
omc describe node <node>
omc get mcp
omc logs <pod> -n <namespace>
```

## When to Use must-gather

- Post-incident analysis (cluster is now stable)
- Filing support cases (Red Hat requires must-gather)
- Comparing cluster state before/after changes
- Investigating intermittent issues (collect periodically)
- Collaborative debugging (share must-gather with teammates)

## Relationship to Other Debug Tools

| Tool | When | Live/Offline |
|------|------|-------------|
| `oc debug node/` | Active investigation on a live node | Live |
| `must-gather` | Capture state for offline analysis | Offline |
| `sosreport` | Deep OS-level diagnostics | Offline |
| Prometheus | Metrics-based investigation | Live |
