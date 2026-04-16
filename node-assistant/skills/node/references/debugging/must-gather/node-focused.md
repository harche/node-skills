# Node-Focused must-gather Analysis

Extracting and analyzing node-specific data from a must-gather collection.

## Node Status and Conditions

### Node YAML

```bash
# Full node definition
cat cluster-scoped-resources/core/nodes/<node-name>.yaml

# With omc
omc describe node <node-name>
```

### Key Fields to Check

**Conditions** -- the most immediate indicator of node health:

```bash
# Extract conditions for all nodes
for f in cluster-scoped-resources/core/nodes/*.yaml; do
  echo "=== $(basename $f .yaml) ==="
  grep -A 4 'type: Ready' "$f"
  grep -A 4 'type: MemoryPressure' "$f"
  grep -A 4 'type: DiskPressure' "$f"
  grep -A 4 'type: PIDPressure' "$f"
done
```

**Annotations** -- contain MachineConfig state:

```bash
grep 'machineconfiguration.openshift.io' cluster-scoped-resources/core/nodes/<node>.yaml
```

Key annotations:
- `machineconfiguration.openshift.io/currentConfig` -- currently applied MC
- `machineconfiguration.openshift.io/desiredConfig` -- target MC
- `machineconfiguration.openshift.io/state` -- Done, Working, Degraded
- `machineconfiguration.openshift.io/reason` -- reason if Degraded

If `currentConfig != desiredConfig`, the node is mid-update or stuck.

**Taints** -- may explain scheduling issues:

```bash
grep -A 10 'taints:' cluster-scoped-resources/core/nodes/<node>.yaml
```

**Allocatable vs Capacity**:

```bash
# Side by side for a node
grep -A 6 'allocatable:' cluster-scoped-resources/core/nodes/<node>.yaml
grep -A 6 'capacity:' cluster-scoped-resources/core/nodes/<node>.yaml
```

## Kubelet Logs Within must-gather

Default must-gather may or may not include kubelet journal logs depending on the version and collection method.

### If Host Service Logs Are Present

```bash
# Check if kubelet logs were collected
find . -path "*kubelet*" -name "*.log" -o -path "*kubelet*" -name "journal*" 2>/dev/null

# Common locations
ls host_service_logs/kubelet/ 2>/dev/null
ls */host_service_logs/ 2>/dev/null
```

### Collecting Kubelet Logs Separately

If the must-gather does not include kubelet logs, collect them from a live cluster:

```bash
# Stream kubelet logs from a node
oc adm node-logs <node> -u kubelet --since "2h" > kubelet-<node>.log

# All journal logs
oc adm node-logs <node> --since "2h" > journal-<node>.log
```

### Analyzing Kubelet Logs

```bash
# Error summary
grep -i error kubelet.log | sed 's/[0-9]\{1,\}/N/g' | sort | uniq -c | sort -rn | head -20

# PLEG issues
grep -i pleg kubelet.log

# Node status update failures
grep -i 'node status update' kubelet.log

# Volume issues
grep -i -E 'volume|mount|attach|csi' kubelet.log | tail -20

# Certificate issues
grep -i -E 'certificate|cert|tls' kubelet.log | tail -20
```

## CRI-O Logs Within must-gather

```bash
# Check for CRI-O logs
find . -path "*crio*" -name "*.log" 2>/dev/null

# Collect separately if missing
oc adm node-logs <node> -u crio --since "2h" > crio-<node>.log
```

### Analyzing CRI-O Logs

```bash
# Container creation failures
grep -i -E 'error.*creat|fail.*container' crio.log | tail -20

# Image pull issues
grep -i -E 'pull|image.*error' crio.log | tail -20

# Runtime (crun) errors
grep -i -E 'crun|oci.*error|runtime.*error' crio.log | tail -20
```

## Machine and MachineSet Info

### Machine Objects

```bash
# All machines
ls cluster-scoped-resources/machine.openshift.io/machines/openshift-machine-api/

# Specific machine
cat cluster-scoped-resources/machine.openshift.io/machines/openshift-machine-api/<machine>.yaml

# With omc
omc get machines -n openshift-machine-api
omc describe machine <machine> -n openshift-machine-api
```

Key Machine fields:
- `spec.providerSpec` -- cloud provider configuration (instance type, zone, etc.)
- `status.phase` -- Running, Provisioning, Failed, Deleting
- `status.nodeRef` -- link to the Kubernetes Node object
- `status.errorReason` / `status.errorMessage` -- failure info

### MachineSets

```bash
cat cluster-scoped-resources/machine.openshift.io/machinesets/openshift-machine-api/<machineset>.yaml

# With omc
omc get machinesets -n openshift-machine-api
```

### Correlating Machine to Node

```bash
# Find which machine backs a node
grep -r 'nodeRef' cluster-scoped-resources/machine.openshift.io/machines/openshift-machine-api/ | \
  grep <node-name>

# Or find all machine-to-node mappings
for f in cluster-scoped-resources/machine.openshift.io/machines/openshift-machine-api/*.yaml; do
  machine=$(basename $f .yaml)
  node=$(grep -A 1 'nodeRef:' "$f" | grep 'name:' | awk '{print $2}')
  phase=$(grep 'phase:' "$f" | tail -1 | awk '{print $2}')
  echo "$machine -> $node ($phase)"
done
```

## MachineConfig and MachineConfigPool State

### MachineConfigPool

```bash
# MCP status
cat cluster-scoped-resources/machineconfiguration.openshift.io/machineconfigpools/worker.yaml

# Key status fields
omc get mcp
omc describe mcp worker
```

Important MCP status fields:
- `status.machineCount` -- total nodes in pool
- `status.readyMachineCount` -- nodes with desired config applied
- `status.updatedMachineCount` -- nodes updated to latest rendered config
- `status.unavailableMachineCount` -- nodes being updated
- `status.degradedMachineCount` -- nodes that failed update
- `status.conditions` -- Updated, Updating, Degraded, NodeDegraded

### MachineConfig

```bash
# List all MachineConfigs
ls cluster-scoped-resources/machineconfiguration.openshift.io/machineconfigs/

# Rendered config (the effective config for a pool)
cat cluster-scoped-resources/machineconfiguration.openshift.io/machineconfigs/rendered-worker-*.yaml

# Compare two rendered configs
diff <(cat cluster-scoped-resources/machineconfiguration.openshift.io/machineconfigs/rendered-worker-old.yaml) \
     <(cat cluster-scoped-resources/machineconfiguration.openshift.io/machineconfigs/rendered-worker-new.yaml)
```

### MCD (Machine Config Daemon) Logs

```bash
# Find MCD pods
ls namespaces/openshift-machine-config-operator/core/pods/ | grep machine-config-daemon

# Read MCD log for a specific node's daemon pod
cat namespaces/openshift-machine-config-operator/core/pods/machine-config-daemon-<hash>/machine-config-daemon.log | tail -50

# Look for update/error messages
grep -i -E 'error|fail|drain|reboot|update|apply' \
  namespaces/openshift-machine-config-operator/core/pods/machine-config-daemon-*/machine-config-daemon.log
```

## Node Resource Allocation and Usage

### Pods on a Node

```bash
# Find all pods scheduled to a specific node
omc get pods -A -o wide | grep <node-name>

# Or manually -- find pods with matching nodeName
grep -rl "nodeName: <node-name>" namespaces/*/core/pods/*/
```

### Resource Requests and Limits

```bash
# Summarize resource allocation on a node
omc describe node <node> | grep -A 50 'Allocated resources:'

# Or manually sum requests
omc get pods -A -o json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for pod in data.get('items', []):
    node = pod.get('spec', {}).get('nodeName', '')
    if node == '<node-name>':
        name = pod['metadata']['name']
        for c in pod['spec'].get('containers', []):
            req = c.get('resources', {}).get('requests', {})
            print(f\"{name}/{c['name']}: cpu={req.get('cpu','?')} mem={req.get('memory','?')}\")
"
```

### Node Images

```bash
# Images present on a node (from node YAML)
grep -A 100 'images:' cluster-scoped-resources/core/nodes/<node>.yaml | head -100
```

## Common Node Investigation Workflows

### Node Stuck in NotReady

1. Check node conditions in YAML
2. Check MachineConfig annotations (stuck update?)
3. Check MCD logs for the node's daemon pod
4. Check events for node-related warnings
5. If kubelet logs are available, check for heartbeat failures

### Node Stuck in SchedulingDisabled

1. Check if node is cordoned: look for `unschedulable: true` in node spec
2. Check if MCD cordoned it for an update: look at MCD logs
3. Check if operator cordoned it: check events

### Degraded MachineConfigPool

1. Identify which node(s) are degraded from MCP status
2. Check the degraded node's MC annotations (`state: Degraded`, `reason:`)
3. Read the MCD log for that node's daemon pod
4. Common causes: failed file write, failed service restart, drain timeout
