# Kubernetes Node E2E Tests

## What They Test

Node e2e tests (`test/e2e_node/`) validate kubelet functionality by running tests directly against a node. Unlike cluster-level e2e tests, these execute on the node itself and interact with the local kubelet process. Key areas:

- **Pod lifecycle** -- creation, running, termination, restart policies, graceful shutdown
- **Container runtime integration** -- image pulling, container creation, exec, logs, port forwarding
- **Resource management** -- CPU/memory requests and limits, eviction behavior, QoS classes
- **cgroup enforcement** -- cgroup v1/v2 resource limits, pod-level cgroups, systemd slice structure
- **Device plugins** -- device allocation, plugin lifecycle, topology hints
- **Topology manager** -- NUMA-aware resource alignment policies
- **Node allocatable** -- system-reserved, kube-reserved, eviction thresholds
- **Node status** -- conditions, capacity, allocatable reporting
- **Volume management** -- local volumes, projected volumes, CSI node operations
- **Probe behavior** -- liveness, readiness, startup probes
- **Security contexts** -- SELinux, seccomp, AppArmor, user namespace support
- **Swap support** -- swap-enabled node behavior (feature-gated)

## Running Node E2E Tests

### From Kubernetes Source

```bash
cd $GOPATH/src/k8s.io/kubernetes

# Run all node e2e tests locally
make test-e2e-node

# Run with a specific focus
make test-e2e-node FOCUS='\[NodeConformance\]'

# Run against a remote node
make test-e2e-node \
  REMOTE=true \
  HOSTS=10.0.1.50 \
  SSH_KEY=~/.ssh/id_rsa \
  SSH_USER=core
```

### Using Ginkgo Directly

```bash
cd test/e2e_node

# Build and run
ginkgo -v -focus='\[sig-node\]' -skip='\[Flaky\]|\[Serial\]' \
  --timeout=2h \
  -- \
  --kubelet-flags="--cgroup-driver=systemd" \
  --report-dir=/tmp/node-e2e-results
```

## Key Test Focus Areas

### By SIG Label

| Label | Scope |
|---|---|
| `[sig-node]` | All node SIG tests |
| `[NodeConformance]` | Required for node conformance certification |
| `[NodeFeature:SidecarContainers]` | Sidecar container behavior |
| `[NodeFeature:PodLifecycleSleepAction]` | Sleep action on pre-stop |
| `[NodeFeature:UserNamespacesSupport]` | User namespace isolation |

### By Functional Area

```bash
# Eviction tests
make test-e2e-node FOCUS='eviction'

# Cgroup tests
make test-e2e-node FOCUS='cgroup'

# Device plugin tests
make test-e2e-node FOCUS='Device.Plugin'

# Topology manager tests
make test-e2e-node FOCUS='TopologyManager'

# Probe tests
make test-e2e-node FOCUS='Probing'
```

## Running Against Remote Nodes

Node e2e tests support running against remote machines via SSH. This is the standard mode for CI.

```bash
make test-e2e-node \
  REMOTE=true \
  HOSTS="10.0.1.50 10.0.1.51" \
  SSH_KEY=~/.ssh/id_rsa \
  SSH_USER=core \
  FOCUS='\[NodeConformance\]' \
  SKIP='\[Flaky\]' \
  PARALLELISM=8 \
  TIMEOUT=2h
```

For OpenShift/RHCOS nodes, the SSH user is `core` and you need the SSH key used during cluster installation.

Multiple hosts can be specified space-separated. Tests will be distributed across nodes.

## Common Flags

| Flag | Purpose | Example |
|---|---|---|
| `FOCUS` | Ginkgo focus regex | `FOCUS='\[NodeConformance\]'` |
| `SKIP` | Ginkgo skip regex | `SKIP='\[Flaky\]\|\[Serial\]'` |
| `REMOTE` | Run against remote node(s) | `REMOTE=true` |
| `HOSTS` | Remote node IP(s) | `HOSTS=10.0.1.50` |
| `SSH_KEY` | SSH private key path | `SSH_KEY=~/.ssh/id_rsa` |
| `SSH_USER` | SSH username | `SSH_USER=core` |
| `PARALLELISM` | Number of parallel Ginkgo nodes | `PARALLELISM=8` |
| `TIMEOUT` | Overall test timeout | `TIMEOUT=2h` |
| `REPORT_DIR` | JUnit output directory | `REPORT_DIR=/tmp/results` |
| `KUBELET_FLAGS` | Extra kubelet flags for local runs | `KUBELET_FLAGS="--v=4"` |
| `CONTAINER_RUNTIME_ENDPOINT` | CRI socket path | Defaults to `/var/run/crio/crio.sock` on RHCOS |

## Interpreting Results

### JUnit Output

Results are written to the `REPORT_DIR` as JUnit XML. Each test case includes:

- Test name with full Ginkgo path
- Duration
- Pass/fail/skip status
- Failure message and stack trace on failure

### Common Failure Patterns

| Pattern | Likely Cause |
|---|---|
| `context deadline exceeded` | Test timed out -- kubelet may be slow or unresponsive |
| `pod not in expected phase` | Pod scheduling or runtime issue |
| `failed to pull image` | Network or registry problem on the node |
| `cgroup path not found` | cgroup driver mismatch or cgroup v1/v2 incompatibility |
| `device plugin not registered` | Device plugin binary not present or crashed |
| `connection refused` on kubelet port | kubelet not running or crashed during test |

### Debugging Failures

```bash
# Check kubelet logs on the node
journalctl -u kubelet --since "1 hour ago" | tail -200

# Check CRI-O logs
journalctl -u crio --since "1 hour ago" | tail -200

# Check node conditions
kubectl get node <node-name> -o jsonpath='{.status.conditions}' | jq .
```

## Adding New Node E2E Tests

### File Organization

Tests live in `test/e2e_node/`. Create a new file or add to an existing one based on functional area:

```
test/e2e_node/
  container_lifecycle_test.go
  eviction_test.go
  device_plugin_test.go
  topology_manager_test.go
  resource_metrics_test.go
  ...
```

### Test Structure

```go
package e2enode

import (
    "context"
    "github.com/onsi/ginkgo/v2"
    "github.com/onsi/gomega"
    "k8s.io/kubernetes/test/e2e/framework"
    e2epod "k8s.io/kubernetes/test/e2e/framework/pod"
)

var _ = SIGDescribe("My Feature", func() {
    f := framework.NewDefaultFramework("my-feature")

    ginkgo.It("should do the expected thing [NodeConformance]", func(ctx context.Context) {
        pod := e2epod.MakePod(f.Namespace.Name, nil, nil, false, "sleep 300")
        pod = e2epod.NewPodClient(f).CreateSync(ctx, pod)
        gomega.Expect(pod.Status.Phase).To(gomega.Equal(v1.PodRunning))
    })
})
```

### Labeling Conventions

- Add `[NodeConformance]` if the test validates required kubelet behavior
- Add `[NodeFeature:FeatureName]` for feature-gated functionality
- Add `[Serial]` if the test cannot run in parallel with others
- Add `[Disruptive]` if the test modifies node state (e.g., restarts kubelet)
- Add `[Slow]` if the test takes more than a few minutes
