# Prometheus Metrics for Node Debugging

Querying Prometheus/Thanos for node-level metrics using `promtool`. Prometheus is the primary metrics store in OpenShift clusters, with Thanos Querier providing a unified query interface across replicas.

## Sub-references

- `prometheus/cluster-access.md` -- setting up authentication and connectivity to Thanos/Prometheus
- `prometheus/querying.md` -- promtool query syntax, instant/range/series/labels
- `prometheus/node-metrics.md` -- key metrics for node debugging, PromQL patterns, alert rules

## Overview

The query workflow:
1. Set up access to Thanos Querier (OpenShift) or Prometheus (upstream k8s)
2. Create an HTTP config file with authentication credentials
3. Use `promtool` to run PromQL queries against the endpoint
4. Analyze results for node health, resource pressure, component behavior

## promtool

`promtool` is the official Prometheus CLI tool. It supports querying remote Prometheus-compatible endpoints with authentication.

Install:

```bash
go install github.com/prometheus/prometheus/cmd/promtool@latest
```

## OpenShift Setup (Quick Start)

OpenShift exposes Thanos Querier via a route in `openshift-monitoring`.

```bash
# 1. Get the Thanos route
THANOS_HOST=$(oc get route -n openshift-monitoring thanos-querier -o jsonpath='{.spec.host}')

# 2. Create a service account and token
oc create sa prometheus-reader -n openshift-monitoring
oc adm policy add-cluster-role-to-user cluster-monitoring-view -z prometheus-reader -n openshift-monitoring
TOKEN=$(oc create token prometheus-reader -n openshift-monitoring --duration=24h)

# 3. Create http config file
cat > http.yml <<EOF
authorization:
  type: Bearer
  credentials: "${TOKEN}"
EOF

# 4. Query
promtool query instant --http.config.file=http.yml "https://${THANOS_HOST}" 'up{job="kubelet"}'
```

See `prometheus/cluster-access.md` for detailed setup instructions.

## Kubernetes Setup (Quick Start)

```bash
# 1. Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090 &

# 2. Create http config (TLS skip for localhost)
cat > http.yml <<EOF
tls_config:
  insecure_skip_verify: true
EOF

# 3. Query
promtool query instant --http.config.file=http.yml "http://localhost:9090" 'up{job="kubelet"}'
```

## Key Queries for Node Debugging

Quick reference of the most useful queries (full list in `prometheus/node-metrics.md`):

### Node Health

```bash
# Kubelet up/down
promtool query instant --http.config.file=http.yml "https://${THANOS_HOST}" 'up{job="kubelet"}'

# Node readiness
promtool query instant --http.config.file=http.yml "https://${THANOS_HOST}" 'kube_node_status_condition{condition="Ready",status="true"}'
```

### Resource Pressure

```bash
# CPU usage per node (5m average)
promtool query instant --http.config.file=http.yml "https://${THANOS_HOST}" \
  '100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'

# Memory available per node
promtool query instant --http.config.file=http.yml "https://${THANOS_HOST}" \
  'node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100'

# Disk available on node filesystem
promtool query instant --http.config.file=http.yml "https://${THANOS_HOST}" \
  'node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100'
```

### Kubelet Health

```bash
# PLEG relist duration (high values indicate problems)
promtool query instant --http.config.file=http.yml "https://${THANOS_HOST}" \
  'histogram_quantile(0.99, rate(kubelet_pleg_relist_duration_seconds_bucket[5m]))'

# Pod start latency
promtool query instant --http.config.file=http.yml "https://${THANOS_HOST}" \
  'histogram_quantile(0.99, rate(kubelet_pod_start_duration_seconds_bucket[5m]))'
```

## Query Types

| Type | Use Case | Example |
|------|----------|---------|
| `instant` | Current value of a metric | CPU usage right now |
| `range` | Values over a time window | CPU trend over 24h |
| `series` | List matching time series | Find all kubelet metrics |
| `labels` | List label values | List all node names |

See `prometheus/querying.md` for full syntax and examples.

## When to Use Prometheus vs Other Tools

| Scenario | Tool |
|----------|------|
| Is the node under resource pressure? | Prometheus (node_exporter metrics) |
| Why did kubelet crash? | journalctl / must-gather logs |
| Trending resource usage over time | Prometheus range queries |
| What containers are using the most CPU? | Prometheus (container_cpu_*) |
| Detailed container lifecycle events | kubelet/CRI-O logs |
| Alerting rule investigation | Prometheus (ALERTS metric, alert rules) |
