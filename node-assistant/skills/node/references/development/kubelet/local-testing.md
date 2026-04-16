# Kubelet Local Testing

## Unit Tests

### Run All Kubelet Unit Tests

```bash
cd ~/go/src/github.com/openshift/kubernetes
make test WHAT=./pkg/kubelet/...
```

This runs all tests under `pkg/kubelet/` recursively.

### Run Tests for a Specific Package

```bash
# Container manager tests
make test WHAT=./pkg/kubelet/cm/...

# Eviction manager tests
make test WHAT=./pkg/kubelet/eviction/...

# Stats provider tests
make test WHAT=./pkg/kubelet/stats/...

# Node status tests
make test WHAT=./pkg/kubelet/nodestatus/...

# Pod workers tests
make test WHAT=./pkg/kubelet/pod_workers_test.go

# CRI API tests
make test WHAT=./pkg/kubelet/cri/...
```

### Run a Specific Test by Name

Use `-run` with a regex pattern matching the test function name:

```bash
make test WHAT=./pkg/kubelet/... GOFLAGS="-run TestSyncPod"
```

Multiple patterns:

```bash
make test WHAT=./pkg/kubelet/... GOFLAGS="-run 'TestSyncPod|TestEviction'"
```

### Verbose Output

```bash
make test WHAT=./pkg/kubelet/... GOFLAGS="-v -run TestSyncPod"
```

### Run with Race Detector

```bash
make test WHAT=./pkg/kubelet/... GOFLAGS="-race"
```

Note: race detection significantly increases test time and memory usage.

### Run Tests with Count (Repeat)

Useful for catching flaky tests:

```bash
make test WHAT=./pkg/kubelet/... GOFLAGS="-count=10 -run TestSyncPod"
```

### Using `go test` Directly

For faster iteration, you can bypass the Makefile:

```bash
go test ./pkg/kubelet/... -v -run TestSyncPod
go test ./pkg/kubelet/cm/... -v -count=1
```

## Important Test Packages

| Package | What It Tests |
|---------|---------------|
| `pkg/kubelet/` | Core kubelet sync loop, pod lifecycle |
| `pkg/kubelet/cm/` | Container manager, cgroup management, device plugins, cpumanager, memorymanager, topologymanager |
| `pkg/kubelet/cm/cpumanager/` | CPU pinning policies |
| `pkg/kubelet/cm/memorymanager/` | NUMA memory allocation |
| `pkg/kubelet/cm/topologymanager/` | NUMA topology alignment |
| `pkg/kubelet/cm/devicemanager/` | Device plugin framework |
| `pkg/kubelet/stats/` | Stats collection (cAdvisor, CRI) |
| `pkg/kubelet/eviction/` | Eviction manager, thresholds |
| `pkg/kubelet/nodestatus/` | Node status reporting |
| `pkg/kubelet/kuberuntime/` | CRI runtime integration |
| `pkg/kubelet/lifecycle/` | Admission handlers, preemption |
| `pkg/kubelet/volumemanager/` | Volume attach/mount |
| `pkg/kubelet/pleg/` | Pod lifecycle event generator |
| `pkg/kubelet/userns/` | User namespace mapping |
| `pkg/kubelet/config/` | Pod source configuration |
| `staging/src/k8s.io/kubelet/` | Kubelet API types and client |

## Integration Tests

Integration tests live under `test/integration/` and test kubelet behavior against a real API server (started in-process).

```bash
# Run node-related integration tests
make test-integration WHAT=./test/integration/node/...

# Run specific integration test
make test-integration WHAT=./test/integration/node/... GOFLAGS="-run TestNodeStatus"
```

Integration tests are slower than unit tests; they spin up etcd and kube-apiserver.

## Node E2E Tests

Node e2e tests exercise the kubelet end-to-end. These run against a real node with a running kubelet and CRI-O.

```bash
# From the kubernetes root
make test-e2e-node FOCUS="\\[NodeConformance\\]"
```

These tests are typically run in CI via Prow. For local execution, you need a running node with CRI-O.

### Running Node E2E Locally

```bash
# Build the test binary
make WHAT=test/e2e_node/e2e_node.test

# Run against a local node (requires root)
sudo ./_output/bin/e2e_node.test \
  --container-runtime-endpoint=unix:///var/run/crio/crio.sock \
  --ginkgo.focus="\\[NodeConformance\\]" \
  --ginkgo.skip="\\[Flaky\\]" \
  --node-name=$(hostname)
```

## Adding New Tests

### Unit Test

1. Create or modify a `_test.go` file in the appropriate package.

2. Follow existing patterns in the package. Example:

```go
func TestMyFeature(t *testing.T) {
    // Setup
    kubelet := newTestKubelet(t)
    defer kubelet.cleanup()

    // Test logic
    result, err := kubelet.kubelet.SomeMethod()
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }

    // Assertions
    if result != expected {
        t.Errorf("expected %v, got %v", expected, result)
    }
}
```

3. For table-driven tests (preferred style):

```go
func TestMyFeatureVariants(t *testing.T) {
    tests := []struct {
        name     string
        input    string
        expected string
    }{
        {
            name:     "basic case",
            input:    "foo",
            expected: "bar",
        },
        {
            name:     "edge case",
            input:    "",
            expected: "",
        },
    }

    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            result := myFunction(tc.input)
            if result != tc.expected {
                t.Errorf("expected %q, got %q", tc.expected, result)
            }
        })
    }
}
```

4. Run your new test:

```bash
go test ./pkg/kubelet/your-package/... -v -run TestMyFeature -count=1
```

### Integration Test

1. Add a test file under `test/integration/node/`.
2. Use the integration test framework to start an API server.
3. Follow patterns from existing integration tests (e.g., `test/integration/node/lifecycle_test.go`).

## Test Utilities

Key test helpers in the kubelet codebase:

- `pkg/kubelet/kubelet_test.go` -- `newTestKubelet()` for creating test kubelet instances
- `pkg/kubelet/kuberuntime/testing/` -- fake CRI runtime for testing
- `pkg/kubelet/cm/testing/` -- fake container manager
- `staging/src/k8s.io/client-go/kubernetes/fake` -- fake Kubernetes client

## CI Test Jobs

Kubelet-related Prow jobs in `openshift/release`:

- `pull-ci-openshift-kubernetes-master-unit` -- unit tests
- `pull-ci-openshift-kubernetes-master-e2e-node` -- node e2e tests
- `periodic-ci-openshift-kubernetes-master-e2e-aws` -- full e2e on AWS

Check job status at https://prow.ci.openshift.org/
