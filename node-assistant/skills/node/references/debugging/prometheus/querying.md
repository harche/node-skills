# Querying Prometheus via promtool

`promtool` is the official Prometheus CLI for running PromQL queries against remote endpoints.

## Install

```bash
go install github.com/prometheus/prometheus/cmd/promtool@latest
```

Ensure `$GOPATH/bin` (typically `~/go/bin`) is in your `$PATH`.

## Prerequisites

All queries require:
- An HTTP config file (`http.yml`) with authentication -- see `cluster-access.md`
- The Prometheus/Thanos endpoint URL

For these examples, assume:
```bash
export PROM_HOST="https://$(oc get route -n openshift-monitoring thanos-querier -o jsonpath='{.spec.host}')"
export HTTP_CONFIG="http.yml"
```

## Instant Query

Returns the current value of a PromQL expression.

```bash
promtool query instant --http.config.file=$HTTP_CONFIG "$PROM_HOST" '<promql>'
```

Examples:

```bash
# All kubelet targets up/down
promtool query instant --http.config.file=$HTTP_CONFIG "$PROM_HOST" 'up{job="kubelet"}'

# Node CPU usage (5m average)
promtool query instant --http.config.file=$HTTP_CONFIG "$PROM_HOST" \
  '100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'

# Running pods per node
promtool query instant --http.config.file=$HTTP_CONFIG "$PROM_HOST" \
  'kubelet_running_pods'

# Currently firing alerts
promtool query instant --http.config.file=$HTTP_CONFIG "$PROM_HOST" \
  'ALERTS{alertstate="firing"}'
```

## Range Query

Returns values over a time range, sampled at a given step interval.

```bash
promtool query range \
  --http.config.file=$HTTP_CONFIG \
  --start=<rfc3339-or-unix> \
  --end=<rfc3339-or-unix> \
  --step=<duration> \
  "$PROM_HOST" '<promql>'
```

Examples:

```bash
# CPU usage over the last 6 hours, sampled every 5 minutes
promtool query range \
  --http.config.file=$HTTP_CONFIG \
  --start=$(date -u -v-6H +%Y-%m-%dT%H:%M:%SZ) \
  --end=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --step=5m \
  "$PROM_HOST" \
  '100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'

# Memory available over the last 24 hours
promtool query range \
  --http.config.file=$HTTP_CONFIG \
  --start=$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ) \
  --end=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --step=15m \
  "$PROM_HOST" \
  'node_memory_MemAvailable_bytes'

# PLEG relist duration (p99) over 12 hours
promtool query range \
  --http.config.file=$HTTP_CONFIG \
  --start=$(date -u -v-12H +%Y-%m-%dT%H:%M:%SZ) \
  --end=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --step=5m \
  "$PROM_HOST" \
  'histogram_quantile(0.99, rate(kubelet_pleg_relist_duration_seconds_bucket[5m]))'
```

Time format notes:
- RFC 3339: `2024-01-15T14:00:00Z`
- Unix timestamp: `1705323600`
- On Linux, use `date -u -d "-6 hours"` instead of `-v-6H` (macOS)

## Series Query

Lists time series matching a label selector. Useful for discovering what metrics exist.

```bash
promtool query series \
  --http.config.file=$HTTP_CONFIG \
  --match='<series-selector>' \
  "$PROM_HOST"
```

Examples:

```bash
# All kubelet metrics
promtool query series \
  --http.config.file=$HTTP_CONFIG \
  --match='{job="kubelet"}' \
  "$PROM_HOST"

# All metrics for a specific node
promtool query series \
  --http.config.file=$HTTP_CONFIG \
  --match='{instance="<node-name>"}' \
  "$PROM_HOST"

# All metrics with "pleg" in the name
promtool query series \
  --http.config.file=$HTTP_CONFIG \
  --match='{__name__=~".*pleg.*"}' \
  "$PROM_HOST"

# All CRI-O metrics
promtool query series \
  --http.config.file=$HTTP_CONFIG \
  --match='{__name__=~"crio_.*"}' \
  "$PROM_HOST"
```

## Labels Query

Lists unique label values for a given label name.

```bash
promtool query labels \
  --http.config.file=$HTTP_CONFIG \
  "$PROM_HOST" '<label-name>'
```

Examples:

```bash
# List all node instances
promtool query labels --http.config.file=$HTTP_CONFIG "$PROM_HOST" instance

# List all jobs (scraped targets)
promtool query labels --http.config.file=$HTTP_CONFIG "$PROM_HOST" job

# List all metric names (caution: large output)
promtool query labels --http.config.file=$HTTP_CONFIG "$PROM_HOST" __name__

# List all namespaces present in metrics
promtool query labels --http.config.file=$HTTP_CONFIG "$PROM_HOST" namespace
```

## Analyze (TSDB)

Analyze metric cardinality. Useful for understanding which metrics produce the most time series.

```bash
promtool query analyze \
  --http.config.file=$HTTP_CONFIG \
  "$PROM_HOST"
```

This returns top metrics by cardinality. Useful when investigating monitoring performance or storage pressure.

## Output and Formatting

promtool outputs text by default. For machine-readable output, pipe through formatting tools:

```bash
# Pretty-print with column alignment
promtool query instant --http.config.file=$HTTP_CONFIG "$PROM_HOST" 'up{job="kubelet"}' | column -t

# Extract just values (awk)
promtool query instant --http.config.file=$HTTP_CONFIG "$PROM_HOST" 'up{job="kubelet"}' | awk '{print $NF}'

# Count results
promtool query instant --http.config.file=$HTTP_CONFIG "$PROM_HOST" 'up{job="kubelet"}' | wc -l
```

## PromQL Quick Reference

Common operators and functions used in node debugging:

| Pattern | Purpose |
|---------|---------|
| `rate(counter[5m])` | Per-second rate of a counter over 5m |
| `increase(counter[1h])` | Total increase of a counter over 1h |
| `histogram_quantile(0.99, rate(hist_bucket[5m]))` | p99 of a histogram |
| `avg by(instance)(metric)` | Average grouped by node |
| `sum by(instance)(metric)` | Sum grouped by node |
| `topk(5, metric)` | Top 5 values |
| `bottomk(5, metric)` | Bottom 5 values |
| `metric > threshold` | Filter values above threshold |
| `absent(metric)` | Returns 1 if metric is missing (useful for alerting) |
| `changes(metric[1h])` | Number of value changes in 1h |
| `resets(counter[1h])` | Number of counter resets in 1h (indicates restarts) |
