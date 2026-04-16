# Unit Testing for Node Components

## Overview

Each node component (kubelet, MCO, CRI-O) has its own unit test infrastructure. Unit tests are the first line of defense and run fastest in CI. All node PRs should include or update relevant unit tests.

## Per-Component Unit Test Patterns

### Kubelet

Kubelet unit tests live in the upstream Kubernetes repository under `pkg/kubelet/...`. They use the standard Go testing package with testify assertions in some areas.

```bash
# Run all kubelet unit tests
cd $GOPATH/src/k8s.io/kubernetes
make test WHAT=./pkg/kubelet/...

# Run a specific test
go test -run TestSyncPod ./pkg/kubelet/...
```

Key test packages: `kubelet`, `cm` (container manager), `stats`, `eviction`, `images`, `lifecycle`, `cri`, `kuberuntime`.

See [Kubelet Unit Tests](unit/kubelet-unit.md) for detailed coverage.

### Machine Config Operator (MCO)

MCO unit tests live in the `openshift/machine-config-operator` repository. They use Go testing with controller-runtime fake clients for Kubernetes API interaction.

```bash
cd $GOPATH/src/github.com/openshift/machine-config-operator
make test
```

Key test packages: `pkg/controller/node`, `pkg/controller/render`, `pkg/daemon`, `pkg/server`.

See [MCO Unit Tests](unit/mco-unit.md) for detailed coverage.

### CRI-O

CRI-O unit tests live in the `cri-o/cri-o` repository. They use Go testing plus BATS (Bash Automated Testing System) for CLI and integration testing.

```bash
cd $GOPATH/src/github.com/cri-o/cri-o
make testunit
```

CRI-O also has a CRI validation suite (`critest`) and local integration tests via `make localintegration`.

See [CRI-O Unit Tests](unit/crio-unit.md) for detailed coverage.

## Common Patterns Across Components

### Test Organization

All components follow Go conventions:
- Test files are `*_test.go` alongside the code they test
- Table-driven tests are the preferred pattern
- Mocks/fakes are in `testing/` or `fake/` subdirectories

### Running Tests with Verbosity

```bash
# Verbose output (shows individual test names)
go test -v ./pkg/kubelet/...

# Short mode (skip long-running tests)
go test -short ./pkg/kubelet/...

# With race detection
go test -race ./pkg/kubelet/...
```

### Test Coverage

```bash
# Generate coverage report
go test -coverprofile=coverage.out ./pkg/kubelet/...

# View coverage in browser
go tool cover -html=coverage.out

# Coverage summary
go tool cover -func=coverage.out | tail -1
```

### Debugging Test Failures

```bash
# Run a single failing test with verbose output
go test -v -run TestMyFailingTest ./pkg/kubelet/cm/...

# Run with count=1 to disable test caching
go test -count=1 -v -run TestMyFailingTest ./pkg/kubelet/cm/...

# Run with timeout (default 10m)
go test -timeout 30m ./pkg/kubelet/...
```

## CI Integration

Unit tests run as presubmit jobs in Prow for all node components:
- **Kubelet**: `pull-kubernetes-unit` (runs all K8s unit tests including kubelet)
- **MCO**: `pull-ci-openshift-machine-config-operator-master-unit` 
- **CRI-O**: `pull-ci-cri-o-cri-o-main-test`

Failures in these jobs block PR merges.

## Sub-References

- [Kubelet Unit Tests](unit/kubelet-unit.md) -- test packages, mocks, and coverage details
- [MCO Unit Tests](unit/mco-unit.md) -- controller tests, daemon tests, rendering tests
- [CRI-O Unit Tests](unit/crio-unit.md) -- unit tests, critest, BATS tests
