# OpenShift E2E Tests (`openshift-tests`)

## Overview

`openshift-tests` is the primary e2e test binary for OpenShift. It is built from the `openshift/origin` repository and contains both upstream Kubernetes e2e tests (vendored) and OpenShift-specific test suites.

## Building the Binary

```bash
git clone https://github.com/openshift/origin.git
cd origin
make WHAT=cmd/openshift-tests

# Binary is at ./openshift-tests
# Or use the image: registry.ci.openshift.org/ocp/4.16:tests
```

For a specific OCP version, check out the corresponding `release-4.x` branch:

```bash
git checkout release-4.16
make WHAT=cmd/openshift-tests
```

## Test Suites

### Core Suites

```bash
# List available suites
./openshift-tests run --help

# Parallel conformance (most common)
./openshift-tests run openshift/conformance/parallel

# Serial conformance (tests requiring exclusive cluster access)
./openshift-tests run openshift/conformance/serial

# Minimal parallel (smaller, faster subset)
./openshift-tests run openshift/conformance/parallel/minimal

# Upstream Kubernetes conformance
./openshift-tests run kubernetes/conformance
```

### Running a Suite

```bash
export KUBECONFIG=/path/to/kubeconfig

# Full parallel conformance
./openshift-tests run openshift/conformance/parallel \
  --provider aws \
  --max-parallel-tests 30 \
  -o /tmp/e2e-results.txt \
  --junit-dir /tmp/junit

# With timeout
./openshift-tests run openshift/conformance/parallel \
  --provider aws \
  --timeout 4h
```

### Running Specific Tests

```bash
# Run a single test by exact name
./openshift-tests run-test \
  "[sig-node] Pods should be submitted and removed [NodeConformance] [Conformance]"

# Dry-run to list tests, then filter and run
./openshift-tests run openshift/conformance/parallel \
  --dry-run | grep '\[sig-node\]' > /tmp/node-tests.txt
./openshift-tests run -f /tmp/node-tests.txt

# Run all tests matching a pattern
./openshift-tests run openshift/conformance/parallel \
  --dry-run | grep -i 'eviction' | \
  ./openshift-tests run -f -
```

### Node-Specific Test Filtering

```bash
# All sig-node tests
./openshift-tests run openshift/conformance/parallel \
  --dry-run | grep '\[sig-node\]' | \
  ./openshift-tests run -f -

# MCO-related tests
./openshift-tests run openshift/conformance/parallel \
  --dry-run | grep -i 'machine.config' | \
  ./openshift-tests run -f -

# Node lifecycle tests
./openshift-tests run openshift/conformance/parallel \
  --dry-run | grep -i 'node.*lifecycle\|graceful.*shutdown\|drain' | \
  ./openshift-tests run -f -
```

## Test Output and JUnit Reports

### Console Output

`openshift-tests` streams results to stdout. The `-o` flag captures full output:

```
started: (1/500) "[sig-node] Pods should be submitted..."
passed: (1/500) "[sig-node] Pods should be submitted..." 12s
started: (2/500) "[sig-node] Container Runtime..."
...
```

Final summary:

```
Failing tests:
  "[sig-node] some test that failed"

pass: 495  fail: 3  skip: 2

error: 3 fail, 2 skip, 495 pass, 500 total
```

### JUnit Reports

```bash
# Write JUnit to a directory
./openshift-tests run openshift/conformance/parallel \
  --junit-dir /tmp/junit

# Multiple XML files are created:
# /tmp/junit/junit_e2e_TIMESTAMP.xml
# /tmp/junit/junit_e2e_TIMESTAMP_monitor.xml  (invariant/monitor results)
```

Parse JUnit results:

```bash
# List failures from JUnit
xmllint --xpath '//testcase[failure]/@name' /tmp/junit/junit_e2e_*.xml

# Count failures
xmllint --xpath 'count(//testcase[failure])' /tmp/junit/junit_e2e_*.xml
```

## The Disruption Monitoring Framework

`openshift-tests` runs background monitors during test execution that track platform health. These produce separate JUnit results.

### What Monitors Track

- **API availability** -- kube-apiserver, openshift-apiserver, oauth-apiserver reachability
- **Ingress availability** -- routes remain accessible during tests
- **Node stability** -- nodes stay Ready, no unexpected reboots
- **Alert monitoring** -- no critical/warning alerts fire unexpectedly
- **Pod invariants** -- static pods remain running, no unexpected restarts

### Monitor Results

Monitor failures appear as separate test cases in JUnit:

```
"[invariant] alert/KubePodNotReady should not be firing"
"[invariant] node/workers should remain ready"
"[invariant] disruption/service-load-balancer connection/new should be available throughout the test"
```

### Interpreting Monitor Failures

Monitor failures often indicate real regressions that individual tests may not catch. Common node-related monitor failures:

| Monitor Failure | What to Check |
|---|---|
| `node/workers should remain ready` | kubelet crashes, OOM, kernel panic, MCO rollout |
| `alert/KubePodNotReady` | pod scheduling issues, runtime failures, resource pressure |
| `alert/KubeletDown` | kubelet process health, certificate issues |
| `alert/SystemMemoryExceedsReservation` | system-reserved settings, memory leaks |
| `disruption/...` during upgrade | drain behavior, pod disruption budgets |

## Provider Configuration

The `--provider` flag configures cloud-specific test behavior:

```bash
# AWS
./openshift-tests run openshift/conformance/parallel --provider aws

# GCP
./openshift-tests run openshift/conformance/parallel --provider gcp

# Azure
./openshift-tests run openshift/conformance/parallel --provider azure

# Bare metal / unknown
./openshift-tests run openshift/conformance/parallel --provider skeleton

# vSphere
./openshift-tests run openshift/conformance/parallel --provider vsphere
```

## Common Node-Related Test Failures

### Kubelet Failures

| Test Pattern | Likely Cause | Investigation |
|---|---|---|
| `Pods should be submitted and removed` | kubelet not starting pods | `journalctl -u kubelet`, check node conditions |
| `should have their auto-restart back-off timer reset` | restart policy regression | Check kubelet restart backoff logic |
| `should cap back-off at MaxContainerBackOff` | backoff cap changed | Verify `MaxContainerBackOff` kubelet config |
| `Probing container should be restarted with a exec liveness probe` | probe execution timing | Check CRI-O exec latency |

### MCO Failures

| Test Pattern | Likely Cause | Investigation |
|---|---|---|
| `Machine Config Pools should update` | MCO rollout stuck | `oc get mcp`, check MCO pod logs |
| `MachineConfig should apply` | rendered config not applied | Check `machine-config-daemon` logs on node |

### CRI-O Failures

| Test Pattern | Likely Cause | Investigation |
|---|---|---|
| `should pull images` | CRI-O image pull issue | `crictl images`, `journalctl -u crio` |
| `Container Runtime should support exec` | exec pathway broken | Check CRI-O exec handler, seccomp profiles |

## Environment Variables

| Variable | Purpose |
|---|---|
| `KUBECONFIG` | Cluster access |
| `TEST_PROVIDER` | Override `--provider` |
| `TEST_SUITE` | Override default suite |
| `OPENSHIFT_TESTS_DISABLE_MONITOR` | Comma-separated monitors to disable |
