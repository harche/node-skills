# Key Prometheus Metrics for Node Debugging

Metrics relevant to node health, kubelet behavior, container runtime, and resource pressure.

For all examples, assume:
```bash
export PROM_HOST="https://$(oc get route -n openshift-monitoring thanos-querier -o jsonpath='{.spec.host}')"
export HTTP_CONFIG="http.yml"
alias pq='promtool query instant --http.config.file=$HTTP_CONFIG "$PROM_HOST"'
alias pqr='promtool query range --http.config.file=$HTTP_CONFIG'
```

## Kubelet Metrics

Scraped from the kubelet metrics endpoint (port 10250).

### Pod Lifecycle

| Metric | Type | Description |
|--------|------|-------------|
| `kubelet_running_pods` | gauge | Number of running pods |
| `kubelet_running_containers` | gauge | Running containers by type (init, regular, ephemeral) |
| `kubelet_pod_start_duration_seconds_bucket` | histogram | Time from pod creation to running |
| `kubelet_pod_worker_duration_seconds_bucket` | histogram | Time kubelet spends syncing a pod |
| `kubelet_desired_pods` | gauge | Pods the kubelet is supposed to be running |
| `kubelet_active_pods` | gauge | Pods currently active |

```bash
# Pods per node
pq 'kubelet_running_pods'

# Pod start latency (p99)
pq 'histogram_quantile(0.99, rate(kubelet_pod_start_duration_seconds_bucket[5m]))'

# Pod start latency (p99) for a specific node
pq 'histogram_quantile(0.99, rate(kubelet_pod_start_duration_seconds_bucket{instance="<node>"}[5m]))'
```

### PLEG (Pod Lifecycle Event Generator)

| Metric | Type | Description |
|--------|------|-------------|
| `kubelet_pleg_relist_duration_seconds_bucket` | histogram | Time for PLEG to relist all pods |
| `kubelet_pleg_relist_interval_seconds_bucket` | histogram | Interval between relists |
| `kubelet_pleg_last_seen_seconds` | gauge | Last time PLEG was active (Unix timestamp) |
| `kubelet_pleg_discard_events` | counter | Events discarded due to too many |

```bash
# PLEG relist duration (p99) -- should be < 1s, alarm > 3s
pq 'histogram_quantile(0.99, rate(kubelet_pleg_relist_duration_seconds_bucket[5m]))'

# PLEG health -- seconds since last relist (high = unhealthy)
pq 'time() - kubelet_pleg_last_seen_seconds'

# Trend PLEG duration over 6h
pqr --start=$(date -u -v-6H +%Y-%m-%dT%H:%M:%SZ) --end=$(date -u +%Y-%m-%dT%H:%M:%SZ) --step=5m \
  "$PROM_HOST" 'histogram_quantile(0.99, rate(kubelet_pleg_relist_duration_seconds_bucket[5m]))'
```

### Volume Operations

| Metric | Type | Description |
|--------|------|-------------|
| `kubelet_volume_stats_available_bytes` | gauge | Available bytes per PVC |
| `kubelet_volume_stats_capacity_bytes` | gauge | Total capacity per PVC |
| `kubelet_volume_stats_used_bytes` | gauge | Used bytes per PVC |
| `kubelet_volume_stats_inodes_free` | gauge | Free inodes per PVC |
| `volume_manager_total_volumes` | gauge | Volumes by state (desired, actual) |
| `storage_operation_duration_seconds_bucket` | histogram | Storage operation latency |

```bash
# PVC usage percentage
pq '100 * kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 80'

# Volumes with low inode availability
pq 'kubelet_volume_stats_inodes_free < 10000'

# Slow storage operations
pq 'histogram_quantile(0.99, rate(storage_operation_duration_seconds_bucket[5m])) > 5'
```

### Node Identity

| Metric | Type | Description |
|--------|------|-------------|
| `kubelet_node_name` | gauge | Maps kubelet instance to node name |
| `kubelet_node_config_error` | gauge | 1 if kubelet has a config error |

```bash
# Check kubelet config errors
pq 'kubelet_node_config_error == 1'
```

## Container Runtime Metrics

Scraped from cAdvisor (embedded in kubelet) and CRI-O.

### CPU

| Metric | Type | Description |
|--------|------|-------------|
| `container_cpu_usage_seconds_total` | counter | Cumulative CPU time consumed |
| `container_cpu_cfs_throttled_seconds_total` | counter | Time throttled by CFS |
| `container_cpu_cfs_throttled_periods_total` | counter | CFS periods throttled |
| `container_cpu_cfs_periods_total` | counter | Total CFS periods |

```bash
# Top 10 CPU-consuming containers
pq 'topk(10, rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m]))'

# CPU throttling percentage by container
pq 'rate(container_cpu_cfs_throttled_periods_total[5m]) / rate(container_cpu_cfs_periods_total[5m]) * 100 > 50'

# CPU usage by node (sum of all containers)
pq 'sum by(node)(rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m]))'
```

### Memory

| Metric | Type | Description |
|--------|------|-------------|
| `container_memory_working_set_bytes` | gauge | Current working set (used for OOM decisions) |
| `container_memory_rss` | gauge | RSS memory |
| `container_memory_usage_bytes` | gauge | Total memory usage (includes cache) |
| `container_memory_cache` | gauge | Page cache usage |
| `container_oom_events_total` | counter | OOM kill events |

```bash
# Top memory consumers
pq 'topk(10, container_memory_working_set_bytes{container!="POD",container!=""})'

# Containers near their memory limit (>90%)
pq 'container_memory_working_set_bytes{container!="POD",container!=""} / container_spec_memory_limit_bytes{container!="POD",container!=""} * 100 > 90'

# OOM events
pq 'increase(container_oom_events_total[1h]) > 0'
```

### Filesystem

| Metric | Type | Description |
|--------|------|-------------|
| `container_fs_usage_bytes` | gauge | Filesystem usage per container |
| `container_fs_limit_bytes` | gauge | Filesystem limit per container |
| `container_fs_reads_total` | counter | Filesystem read operations |
| `container_fs_writes_total` | counter | Filesystem write operations |

```bash
# Containers using the most filesystem space
pq 'topk(10, container_fs_usage_bytes{container!="POD",container!=""})'
```

## Node-Level Metrics (node-exporter)

Scraped from node-exporter running as a DaemonSet.

### CPU

```bash
# CPU usage per node (percentage, 5m average)
pq '100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'

# CPU usage by mode per node
pq 'rate(node_cpu_seconds_total{instance="<node>"}[5m])'

# System CPU vs User CPU
pq 'avg by(instance)(rate(node_cpu_seconds_total{mode="system"}[5m])) * 100'
```

### Memory

```bash
# Available memory percentage
pq 'node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100'

# Nodes with < 10% available memory
pq 'node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100 < 10'

# Total vs Available
pq '{__name__=~"node_memory_MemTotal_bytes|node_memory_MemAvailable_bytes"}'
```

### Disk

```bash
# Root filesystem usage percentage
pq '100 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100)'

# Container storage usage (/var/lib/containers)
pq '100 - (node_filesystem_avail_bytes{mountpoint=~".*/var/lib/containers.*"} / node_filesystem_size_bytes{mountpoint=~".*/var/lib/containers.*"} * 100)'

# Disk I/O utilization
pq 'rate(node_disk_io_time_seconds_total[5m]) * 100'

# Disk read/write throughput
pq 'rate(node_disk_read_bytes_total[5m])'
pq 'rate(node_disk_written_bytes_total[5m])'
```

### Network

```bash
# Network throughput per interface
pq 'rate(node_network_receive_bytes_total{device!="lo"}[5m])'
pq 'rate(node_network_transmit_bytes_total{device!="lo"}[5m])'

# Network errors
pq 'rate(node_network_receive_errs_total[5m]) > 0'
pq 'rate(node_network_transmit_errs_total[5m]) > 0'

# Dropped packets
pq 'rate(node_network_receive_drop_total[5m]) > 0'
```

## CRI-O Metrics

CRI-O exposes metrics on port 9537 (if enabled).

| Metric | Type | Description |
|--------|------|-------------|
| `crio_operations_total` | counter | Operations by type |
| `crio_operations_latency_seconds` | summary | Operation latency |
| `crio_image_pulls_successes_total` | counter | Successful image pulls |
| `crio_image_pulls_failures_total` | counter | Failed image pulls |
| `crio_containers_oom_total` | counter | Container OOM events |
| `crio_containers_oom_count_total` | counter | Cumulative OOM count |

```bash
# CRI-O operation rates
pq 'rate(crio_operations_total[5m])'

# Image pull failures
pq 'increase(crio_image_pulls_failures_total[1h]) > 0'

# CRI-O OOM kills
pq 'increase(crio_containers_oom_total[1h]) > 0'
```

## Common PromQL Patterns for Node Investigations

### "Which nodes are unhealthy?"

```bash
pq 'kube_node_status_condition{condition="Ready",status="true"} == 0'
pq 'kube_node_status_condition{condition="MemoryPressure",status="true"} == 1'
pq 'kube_node_status_condition{condition="DiskPressure",status="true"} == 1'
pq 'kube_node_status_condition{condition="PIDPressure",status="true"} == 1'
```

### "Was there a kubelet restart?"

```bash
pq 'resets(kubelet_running_pods[1h]) > 0'
pq 'changes(kubelet_node_name[1h]) > 0'
```

### "Is the cluster overcommitted?"

```bash
# CPU requests vs allocatable
pq 'sum by(node)(kube_pod_container_resource_requests{resource="cpu"}) / on(node) kube_node_status_allocatable{resource="cpu"} * 100'

# Memory requests vs allocatable
pq 'sum by(node)(kube_pod_container_resource_requests{resource="memory"}) / on(node) kube_node_status_allocatable{resource="memory"} * 100'
```

## Alert Rules Relevant to Node Team

Key built-in alerts to be aware of:

| Alert | Condition |
|-------|-----------|
| `KubeletDown` | Kubelet target unreachable |
| `KubeletTooManyPods` | Node running > 110 pods (default limit) |
| `KubeletPlegDurationHigh` | PLEG relist > 10s for 5m |
| `KubeletNodeNotReady` | Node NotReady for > 15m |
| `NodeFilesystemSpaceFillingUp` | Disk usage trending to full within 24h |
| `NodeFilesystemAlmostOutOfSpace` | Disk usage > 95% |
| `NodeMemoryMajorPagesFaults` | High major page faults |
| `NodeNetworkReceiveErrs` | Network receive errors increasing |
| `NodeClockSkewDetected` | Clock drift > 0.05s |

```bash
# Check currently firing node-related alerts
pq 'ALERTS{alertstate="firing",alertname=~".*Node.*|.*Kubelet.*"}'
```
