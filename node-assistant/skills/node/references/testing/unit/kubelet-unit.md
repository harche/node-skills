# Kubelet Unit Tests

## Overview

Kubelet unit tests live in the upstream Kubernetes repository under `pkg/kubelet/` and its subpackages. They validate individual kubelet subsystem logic without requiring a running kubelet or cluster.

## Running All Kubelet Unit Tests

```bash
cd $GOPATH/src/k8s.io/kubernetes

# Using make (recommended -- handles build flags)
make test WHAT=./pkg/kubelet/...

# Using go test directly
go test ./pkg/kubelet/...

# Verbose output
make test WHAT=./pkg/kubelet/... GOFLAGS="-v"
```

## Key Test Packages

| Package | What It Tests |
|---|---|
| `pkg/kubelet` | Core kubelet sync loop, pod workers, pod status management |
| `pkg/kubelet/cm` | Container manager, cgroup configuration, QoS cgroup hierarchy |
| `pkg/kubelet/cm/cpumanager` | CPU pinning policies (static, none), CPU topology |
| `pkg/kubelet/cm/memorymanager` | Memory manager policies, NUMA allocation |
| `pkg/kubelet/cm/topologymanager` | Topology hints, alignment policies (best-effort, restricted, single-numa-node) |
| `pkg/kubelet/cm/devicemanager` | Device plugin registration, allocation, checkpoint |
| `pkg/kubelet/stats` | Stats provider, cAdvisor stats, CRI stats |
| `pkg/kubelet/eviction` | Eviction manager, thresholds, signal ordering |
| `pkg/kubelet/images` | Image GC, pull serialization, back-off |
| `pkg/kubelet/lifecycle` | Admission handlers, preemption, predicate checks |
| `pkg/kubelet/kuberuntime` | CRI runtime integration, container/sandbox management |
| `pkg/kubelet/cri/remote` | CRI client, remote runtime service |
| `pkg/kubelet/status` | Pod status manager, condition reporting |
| `pkg/kubelet/volumemanager` | Volume attach/detach/mount reconciliation |
| `pkg/kubelet/config` | Pod config sources (API, file, HTTP) |
| `pkg/kubelet/prober` | Liveness, readiness, startup probe logic |
| `pkg/kubelet/nodestatus` | Node status reporting, capacity, conditions |
| `pkg/kubelet/pleg` | Pod lifecycle event generator (generic, event-driven) |

## Running Specific Tests

```bash
# Run a specific test by name
go test -run TestSyncPod ./pkg/kubelet/...

# Run tests in a specific package
go test -v ./pkg/kubelet/eviction/...

# Run tests matching a pattern in a specific package
go test -v -run TestEviction ./pkg/kubelet/eviction/...

# Run a specific subtest (table-driven)
go test -v -run 'TestSyncPod/pod_with_init_containers' ./pkg/kubelet/...
```

## Test Fixtures and Mocks

### Fake CRI Runtime

The kubelet tests use a fake CRI runtime (`pkg/kubelet/cri/remote/fake/`) that simulates container runtime behavior:

```go
import fakeremote "k8s.io/kubernetes/pkg/kubelet/cri/remote/fake"

fakeRuntime, err := fakeremote.NewFakeRemoteRuntime()
```

### Fake Kubelet Dependencies

```go
// pkg/kubelet/kubelet_test.go provides test setup
func newTestKubelet(t *testing.T, ...) *TestKubelet {
    // Sets up fake runtime, fake clock, fake pod manager, etc.
}
```

### Common Mocks

| Mock | Location | Purpose |
|---|---|---|
| `FakeRuntime` | `pkg/kubelet/container/testing/fake_runtime.go` | Simulates container runtime |
| `FakePodManager` | `pkg/kubelet/pod/testing/fake_pod_manager.go` | Pod tracking |
| `FakeClock` | `k8s.io/utils/clock/testing` | Time-dependent logic |
| `FakeRecorder` | `k8s.io/client-go/tools/record` | Event recording |
| `FakeOS` | `pkg/kubelet/container/testing/os.go` | OS-level operations |
| `FakeStatsProvider` | `pkg/kubelet/stats/testing/` | Stats collection |

### cadvisor Mocks

```go
import cadvisortest "github.com/google/cadvisor/utils/sysfs/testing"
```

## Coverage

```bash
# Generate coverage for all kubelet packages
make test WHAT=./pkg/kubelet/... GOFLAGS="-cover"

# Detailed coverage output
go test -coverprofile=kubelet-coverage.out ./pkg/kubelet/...
go tool cover -html=kubelet-coverage.out -o kubelet-coverage.html

# Coverage for a specific subsystem
go test -coverprofile=eviction-coverage.out ./pkg/kubelet/eviction/...
go tool cover -func=eviction-coverage.out
```

## Race Detection

```bash
# Run with Go race detector (slower but catches data races)
make test WHAT=./pkg/kubelet/... GOFLAGS="-race"
```

Race detection is enabled by default in CI. If a test passes locally but fails in CI with a race condition, run with `-race` locally to reproduce.

## Common Test Patterns

### Table-Driven Tests

Most kubelet tests use the table-driven pattern:

```go
func TestEvictionThresholds(t *testing.T) {
    tests := []struct {
        name       string
        thresholds []evictionapi.Threshold
        stats      *statsapi.Summary
        expectEviction bool
    }{
        {
            name: "memory pressure triggers eviction",
            // ...
        },
        {
            name: "no pressure, no eviction",
            // ...
        },
    }
    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            // test logic
        })
    }
}
```

### Testing with Feature Gates

```go
func TestFeatureGatedBehavior(t *testing.T) {
    featuregatetesting.SetFeatureGateDuringTest(t, utilfeature.DefaultFeatureGate,
        features.SidecarContainers, true)
    // test code that depends on SidecarContainers gate
}
```

## Debugging Slow or Flaky Tests

```bash
# Run test with timeout
go test -timeout 5m -v -run TestSlowTest ./pkg/kubelet/...

# Disable test caching
go test -count=1 -v -run TestFlakyTest ./pkg/kubelet/...

# Run a test multiple times to reproduce flakes
go test -count=10 -v -run TestFlakyTest ./pkg/kubelet/...

# CPU/memory profiling for slow tests
go test -cpuprofile=cpu.prof -memprofile=mem.prof ./pkg/kubelet/cm/...
go tool pprof cpu.prof
```
