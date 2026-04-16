# Setting Up Prometheus Access

How to authenticate and connect to Prometheus/Thanos for metric queries using `promtool`.

## OpenShift: Thanos Querier

OpenShift clusters run Thanos Querier in the `openshift-monitoring` namespace, exposed via a route.

### Step 1: Get the Thanos Route

```bash
THANOS_HOST=$(oc get route -n openshift-monitoring thanos-querier -o jsonpath='{.spec.host}')
echo "Thanos endpoint: https://${THANOS_HOST}"
```

### Step 2: Create a Service Account and Token

```bash
# Create SA
oc create sa prometheus-reader -n openshift-monitoring

# Grant cluster-monitoring-view role (read-only access to all metrics)
oc adm policy add-cluster-role-to-user cluster-monitoring-view -z prometheus-reader -n openshift-monitoring

# Create a token (24h duration)
TOKEN=$(oc create token prometheus-reader -n openshift-monitoring --duration=24h)

# Verify token works
curl -sk -H "Authorization: Bearer ${TOKEN}" "https://${THANOS_HOST}/api/v1/query?query=up" | head -c 200
```

### Step 3: Create HTTP Config File

promtool uses an HTTP config file for authentication and TLS settings.

```bash
cat > http.yml <<EOF
authorization:
  type: Bearer
  credentials: "${TOKEN}"
EOF
```

Or if you need to reference a token file:

```bash
cat > http.yml <<EOF
authorization:
  type: Bearer
  credentials_file: /path/to/token-file
EOF
```

### Step 4: Verify Access

```bash
promtool query instant --http.config.file=http.yml "https://${THANOS_HOST}" 'up{job="kubelet"}'
```

### Token Refresh

Tokens created via `oc create token` expire. For long-running sessions:

```bash
# Refresh token
TOKEN=$(oc create token prometheus-reader -n openshift-monitoring --duration=24h)

# Update http.yml
cat > http.yml <<EOF
authorization:
  type: Bearer
  credentials: "${TOKEN}"
EOF
```

### Using an Existing User Token

If you already have cluster access, you can use your own token:

```bash
TOKEN=$(oc whoami -t)
cat > http.yml <<EOF
authorization:
  type: Bearer
  credentials: "${TOKEN}"
EOF
```

Note: this token expires when your session expires.

## Kubernetes: Port-Forward

For upstream Kubernetes clusters or when the Thanos route is unavailable.

### Step 1: Find the Prometheus Service

```bash
kubectl get svc -n monitoring
# Typically: prometheus-k8s, prometheus-operated, or similar

kubectl get svc -n openshift-monitoring
# On OpenShift: prometheus-k8s
```

### Step 2: Port-Forward

```bash
# Upstream Kubernetes
kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090 &

# OpenShift (direct to Prometheus, bypassing Thanos)
oc port-forward -n openshift-monitoring svc/prometheus-k8s 9090:9090 &
```

### Step 3: Create HTTP Config

For localhost port-forward, TLS may not be needed or needs to be skipped:

```bash
# If Prometheus is serving plain HTTP
cat > http.yml <<EOF
tls_config:
  insecure_skip_verify: true
EOF
```

If Prometheus requires authentication via port-forward:

```bash
TOKEN=$(oc create token prometheus-k8s -n openshift-monitoring --duration=1h)
cat > http.yml <<EOF
authorization:
  type: Bearer
  credentials: "${TOKEN}"
tls_config:
  insecure_skip_verify: true
EOF
```

### Step 4: Query

```bash
promtool query instant --http.config.file=http.yml "http://localhost:9090" 'up'
```

## Troubleshooting Access

### "unauthorized" or 403

```bash
# Verify SA exists
oc get sa prometheus-reader -n openshift-monitoring

# Verify role binding
oc get clusterrolebinding | grep prometheus-reader

# Re-create if missing
oc adm policy add-cluster-role-to-user cluster-monitoring-view -z prometheus-reader -n openshift-monitoring

# Get a fresh token
TOKEN=$(oc create token prometheus-reader -n openshift-monitoring --duration=24h)
```

### "connection refused" or timeout

```bash
# Check Thanos route exists
oc get route -n openshift-monitoring thanos-querier

# Check Thanos pods are running
oc get pods -n openshift-monitoring | grep thanos

# Check if monitoring stack is healthy
oc get co monitoring

# Try direct port-forward as fallback
oc port-forward -n openshift-monitoring svc/thanos-querier 9091:9091 &
```

### "certificate signed by unknown authority"

```bash
# Add CA to http.yml
cat > http.yml <<EOF
authorization:
  type: Bearer
  credentials: "${TOKEN}"
tls_config:
  ca_file: /path/to/ca.crt
EOF

# Or extract the serving CA from the cluster
oc get cm -n openshift-monitoring serving-certs-ca-bundle -o jsonpath='{.data.service-ca\.crt}' > ca.crt
```

## http.yml Reference

Full structure of the HTTP config file used by promtool:

```yaml
# Bearer token auth (most common for OpenShift)
authorization:
  type: Bearer
  credentials: "<token>"
  # Or reference a file:
  # credentials_file: /path/to/token

# Basic auth (less common)
# basic_auth:
#   username: "user"
#   password: "pass"

# TLS configuration
tls_config:
  # Skip certificate verification (dev/test only)
  insecure_skip_verify: false
  # Custom CA
  ca_file: /path/to/ca.crt
  # Client certificates (mutual TLS)
  # cert_file: /path/to/client.crt
  # key_file: /path/to/client.key
```
