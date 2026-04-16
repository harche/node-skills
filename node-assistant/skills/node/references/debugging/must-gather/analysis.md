# Analyzing must-gather Data

Patterns and techniques for extracting actionable information from a must-gather collection.

## Quick Triage (First 5 Minutes)

Run these checks immediately to identify the scope of the problem:

### 1. Cluster Operator Status

```bash
# Check for degraded/unavailable operators
cat cluster-scoped-resources/config.openshift.io/clusteroperators.yaml | \
  grep -B 2 -A 5 'type: Degraded' | grep -E 'name:|status:|message:'

# Or with omc
omc get co
```

### 2. Node Conditions

```bash
# Quick node status
for f in cluster-scoped-resources/core/nodes/*.yaml; do
  name=$(grep 'name:' "$f" | head -1 | awk '{print $2}')
  ready=$(grep -A 2 'type: Ready' "$f" | grep 'status:' | awk '{print $2}')
  echo "$name: Ready=$ready"
done

# Or with omc
omc get nodes
```

### 3. Events (Warnings)

```bash
# All warning events
find . -name "events.yaml" -exec grep -B 1 -A 8 'type: Warning' {} \; | head -100

# Open event-filter.html in a browser for a sortable view
open event-filter.html  # macOS
```

### 4. Non-Running Pods

```bash
# Find pods not in Running/Succeeded state
omc get pods -A --field-selector='status.phase!=Running,status.phase!=Succeeded'

# Or manually
find . -path "*/pods/*/status" -exec grep -l 'phase: Pending\|phase: Failed\|phase: Unknown' {} \;
```

### 5. MachineConfigPool State

```bash
cat cluster-scoped-resources/machineconfiguration.openshift.io/machineconfigpools/*.yaml | \
  grep -E 'name:|degradedMachineCount:|unavailableMachineCount:|readyMachineCount:'

# Or with omc
omc get mcp
```

## Finding Error Patterns in Logs

### Across All Collected Logs

```bash
# Find error/fatal messages in all logs
find . -name "*.log" -exec grep -l -i -E 'error|fatal|panic' {} \;

# Aggregate error types
find . -name "*.log" -exec grep -i 'error' {} \; | \
  sed 's/[0-9]\{1,\}/N/g' | sort | uniq -c | sort -rn | head -20
```

### In Specific Component Logs

```bash
# Machine Config Daemon errors
cat namespaces/openshift-machine-config-operator/core/pods/machine-config-daemon-*/machine-config-daemon.log | \
  grep -i error | tail -20

# OVN-Kubernetes errors
find namespaces/openshift-ovn-kubernetes/ -name "*.log" -exec grep -i error {} \; | tail -30

# Monitoring stack errors
find namespaces/openshift-monitoring/ -name "*.log" -exec grep -i error {} \; | tail -30
```

## Comparing Node States

When one node is unhealthy but others are fine, compare them:

```bash
# Compare node YAML side by side
diff <(cat cluster-scoped-resources/core/nodes/healthy-node.yaml) \
     <(cat cluster-scoped-resources/core/nodes/unhealthy-node.yaml)

# Compare conditions
for f in cluster-scoped-resources/core/nodes/*.yaml; do
  echo "=== $(basename $f .yaml) ==="
  grep -A 3 'type: Ready' "$f"
  grep -A 3 'type: MemoryPressure' "$f"
  grep -A 3 'type: DiskPressure' "$f"
done

# Compare labels/annotations (e.g., MachineConfig annotations)
for f in cluster-scoped-resources/core/nodes/*.yaml; do
  echo "=== $(basename $f .yaml) ==="
  grep 'machineconfiguration.openshift.io' "$f"
done
```

## Timeline Reconstruction

Build a chronological view of what happened:

### From Events

```bash
# Extract and sort all events by timestamp
find . -name "events.yaml" -exec python3 -c "
import yaml, sys
for f in sys.argv[1:]:
    with open(f) as fh:
        docs = yaml.safe_load_all(fh)
        for doc in docs:
            if doc and 'items' in doc:
                for item in doc['items']:
                    ts = item.get('lastTimestamp') or item.get('firstTimestamp', 'unknown')
                    ns = item.get('metadata', {}).get('namespace', '-')
                    reason = item.get('reason', '-')
                    msg = item.get('message', '-')[:120]
                    print(f'{ts} [{ns}] {reason}: {msg}')
" {} + | sort
```

### From Logs

```bash
# Interleave kubelet and CRI-O logs by timestamp (if available)
# Useful for correlating container lifecycle events
sort -t ' ' -k 1,2 kubelet.log crio.log | grep -i -E 'error|warn|fail'
```

## Resource Usage Analysis

### Node Allocatable vs Capacity

```bash
for f in cluster-scoped-resources/core/nodes/*.yaml; do
  echo "=== $(basename $f .yaml) ==="
  echo "Capacity:"
  grep -A 5 'capacity:' "$f" | head -6
  echo "Allocatable:"
  grep -A 5 'allocatable:' "$f" | head -6
  echo ""
done
```

### Pod Resource Requests/Limits on a Node

```bash
# Find all pods scheduled to a specific node
omc describe node <node> | grep -A 100 'Non-terminated Pods'
```

## Using omc (OpenShift Must-gather Client)

omc lets you query must-gather data with familiar `oc` syntax.

### Setup

```bash
# Install
go install github.com/gmeghnag/omc@latest

# Point to must-gather directory
omc use /path/to/must-gather/quay-io-openshift-origin-must-gather-sha256-xxx/
```

### Common omc Commands

```bash
# Cluster overview
omc get clusterversion
omc get co
omc get nodes
omc get mcp

# Node investigation
omc describe node <node>
omc get pods -A --field-selector spec.nodeName=<node>

# Events
omc get events -A --sort-by='.lastTimestamp' | tail -50

# Pod logs
omc logs <pod> -n <namespace>
omc logs <pod> -n <namespace> -c <container> --previous

# Resource details
omc get machines -n openshift-machine-api
omc describe machine <machine> -n openshift-machine-api
omc get machineconfig
omc describe mcp worker
```

## Common Analysis Patterns

### "Why did this node go NotReady?"

1. Check node conditions: `omc describe node <node>` -- look at Conditions section
2. Check events: `omc get events -A --sort-by='.lastTimestamp' | grep <node>`
3. Check MCD state: was a MachineConfig being applied?
4. Check kubelet logs (if captured): look for heartbeat failures
5. Check MachineConfigPool: was a rollout in progress?

### "Why was this pod evicted?"

1. Check pod events: `omc describe pod <pod> -n <ns>`
2. Check node conditions at the time (DiskPressure, MemoryPressure)
3. Check eviction events: `grep -r 'Evicted' namespaces/<ns>/core/events.yaml`
4. Check node resource state from node YAML

### "Why is the MachineConfigPool degraded?"

1. Check MCP status: `omc get mcp` / `omc describe mcp <pool>`
2. Check which nodes are degraded: look for `degradedMachineCount`
3. Check MCD logs on degraded nodes
4. Compare desired vs current MachineConfig on degraded nodes
5. Check for MachineConfig render errors
