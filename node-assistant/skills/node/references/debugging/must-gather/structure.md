# must-gather Directory Structure

Understanding the must-gather layout is essential for efficient offline debugging. The structure mirrors Kubernetes API resource organization.

## Top-Level Layout

```
must-gather.local.<id>/
  quay-io-openshift-origin-must-gather-sha256-<hash>/
    cluster-scoped-resources/
    namespaces/
    event-filter.html
    timestamp
```

The actual data is one level below the top directory, under the image-specific folder.

## cluster-scoped-resources/

Contains all cluster-scoped Kubernetes and OpenShift resources.

```
cluster-scoped-resources/
  config.openshift.io/
    clusteroperators.yaml        # Cluster operator status
    clusterversions.yaml         # Cluster version and upgrade history
    infrastructures.yaml         # Cloud provider, platform info
    schedulers.yaml              # Scheduler configuration
  core/
    nodes/                       # One YAML per node
      <node-name>.yaml
    persistentvolumes/           # PVs
    namespaces/                  # Namespace definitions
  machineconfiguration.openshift.io/
    machineconfigpools/          # MCP definitions and status
      master.yaml
      worker.yaml
    machineconfigs/              # Individual MachineConfigs
  machine.openshift.io/
    machines/                    # Machine objects
    machinesets/                 # MachineSet objects
  storage.k8s.io/
    storageclasses/              # StorageClass definitions
    csinodes/                    # CSI node info
  rbac.authorization.k8s.io/
    clusterroles/
    clusterrolebindings/
```

## namespaces/

Contains namespace-scoped resources and pod logs, organized by namespace.

```
namespaces/
  openshift-machine-config-operator/
    core/
      pods/
        machine-config-daemon-<hash>/
          machine-config-daemon.log          # Current log
          machine-config-daemon.log.prev     # Previous log (if restarted)
      configmaps/
      services/
      events.yaml                            # Namespace events
    apps/
      deployments/
      replicasets/
      daemonsets/
  openshift-kube-apiserver/
  openshift-kube-controller-manager/
  openshift-kube-scheduler/
  openshift-etcd/
  openshift-monitoring/
  openshift-ovn-kubernetes/
  openshift-sdn/
  openshift-dns/
  openshift-ingress/
  openshift-cluster-node-tuning-operator/
  ...
```

## Node-Specific Data

Node information is spread across several locations:

### Node Resource Definitions

```
cluster-scoped-resources/core/nodes/<node-name>.yaml
```

Contains: status, conditions, allocatable/capacity, addresses, labels, annotations, taints.

### Kubelet Logs

```
# If collected (not always present in default must-gather)
namespaces/openshift-kube-apiserver/...  # API server interactions
# Node logs are typically under:
<must-gather-root>/host_service_logs/kubelet/
# Or accessed via:
oc adm node-logs --path=journal (collected separately)
```

Note: Default must-gather may not include full kubelet/CRI-O journal logs. For those, use `oc adm node-logs` during live collection or `--image` with a node-specific collector.

### Machine Objects

```
cluster-scoped-resources/machine.openshift.io/machines/openshift-machine-api/<machine-name>.yaml
```

Contains: provider spec, status, node reference, error messages.

### MachineConfig

```
cluster-scoped-resources/machineconfiguration.openshift.io/machineconfigs/<mc-name>.yaml
cluster-scoped-resources/machineconfiguration.openshift.io/machineconfigpools/<mcp-name>.yaml
```

## Event Logs

Events are captured per-namespace:

```
namespaces/<namespace>/core/events.yaml
```

The `event-filter.html` at the top level provides a browser-viewable, filterable summary of all events.

### Finding Events Quickly

```bash
# All events across namespaces
find . -name "events.yaml" -exec grep -l "Warning" {} \;

# Node events
grep -r "involvedObject:" cluster-scoped-resources/core/nodes/ | grep -i event

# Pod events in a specific namespace
cat namespaces/<namespace>/core/events.yaml | grep -A 5 "reason: Failed"
```

## Audit Logs

If collected (via `gather_audit_logs`), audit logs are under:

```
audit_logs/
  kube-apiserver/
    <node>/audit.log
  openshift-apiserver/
    <node>/audit.log
  oauth-apiserver/
    <node>/audit.log
```

Audit logs are large. Filter by user, resource, or verb:

```bash
# Find kubelet-related audit entries
grep '"kubelet"' audit_logs/kube-apiserver/*/audit.log | head -20

# Find node status updates
grep '"nodes/status"' audit_logs/kube-apiserver/*/audit.log | head -20
```

## Container Logs

Container logs for pods in collected namespaces:

```
namespaces/<namespace>/core/pods/<pod-name>/<container-name>.log
namespaces/<namespace>/core/pods/<pod-name>/<container-name>.log.prev
```

The `.prev` file contains logs from the previous container instance (if the container restarted).

## Navigating Efficiently

```bash
# Find all files related to a specific node
find . -type f | xargs grep -l "<node-name>" 2>/dev/null

# Find all non-Running pods
grep -r '"phase":' namespaces/*/core/pods/*/status.yaml | grep -v Running

# Find all error events
grep -r 'type: Warning' namespaces/*/core/events.yaml | head -30

# Find all container restarts
grep -r 'restartCount:' namespaces/*/core/pods/ | grep -v 'restartCount: 0'
```
