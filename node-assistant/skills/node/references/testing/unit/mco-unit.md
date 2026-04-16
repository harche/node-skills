# MCO Unit Tests

## Overview

Machine Config Operator (MCO) unit tests live in the `openshift/machine-config-operator` repository. They validate controller logic, daemon behavior, config rendering, and server endpoints without requiring a running cluster.

## Running All MCO Unit Tests

```bash
cd $GOPATH/src/github.com/openshift/machine-config-operator

# Run all unit tests
make test

# Using go test directly
go test ./pkg/...

# Verbose
go test -v ./pkg/...
```

## Key Test Packages

| Package | What It Tests |
|---|---|
| `pkg/controller/node` | Node controller logic: cordoning, draining, config application tracking |
| `pkg/controller/render` | MachineConfig rendering: merging multiple MachineConfig objects into a rendered config |
| `pkg/controller/container-runtime-config` | CRI-O runtime config generation from ContainerRuntimeConfig CR |
| `pkg/controller/kubelet-config` | KubeletConfig CR processing and validation |
| `pkg/controller/template` | Template controller for generating platform-specific MachineConfigs |
| `pkg/daemon` | Machine config daemon: config diff, update logic, OS operations |
| `pkg/daemon/pivot` | OS pivot/rebase operations |
| `pkg/server` | MCS (Machine Config Server) serving ignition configs |
| `pkg/helpers` | Shared utility functions |
| `pkg/upgrademonitor` | Upgrade status tracking and reporting |

## Running Specific Tests

```bash
# Run tests in a specific package
go test -v ./pkg/controller/render/...

# Run a specific test by name
go test -v -run TestRenderMachineConfig ./pkg/controller/render/...

# Run a specific subtest
go test -v -run 'TestRenderMachineConfig/merge_kernel_arguments' ./pkg/controller/render/...

# Run daemon tests only
go test -v ./pkg/daemon/...

# Run server tests
go test -v ./pkg/server/...
```

## Test Patterns in MCO

### Controller Tests

MCO controller tests use `controller-runtime` fake clients to simulate Kubernetes API interactions:

```go
func TestNodeController(t *testing.T) {
    client := fake.NewClientBuilder().
        WithObjects(node, mcp, mc).
        Build()
    
    reconciler := &NodeReconciler{Client: client}
    result, err := reconciler.Reconcile(ctx, ctrl.Request{...})
    // assert expected state changes
}
```

### Render Tests

Render tests validate that multiple MachineConfig objects merge correctly:

```go
func TestRenderMachineConfig(t *testing.T) {
    configs := []*mcfgv1.MachineConfig{baseMC, overlayMC}
    rendered, err := renderMachineConfig(configs)
    // verify merged ignition config, kernel args, fips, etc.
}
```

### Daemon Tests

Daemon tests validate the on-node update logic -- computing config diffs, determining if a reboot is needed, and executing updates:

```go
func TestUpdate(t *testing.T) {
    d := &Daemon{
        // mock OS, file system, systemd interactions
    }
    err := d.update(oldConfig, newConfig)
    // verify expected file writes, service restarts, reboot decisions
}
```

### MCS (Machine Config Server) Tests

Server tests validate that the correct Ignition config is served based on node pool membership:

```go
func TestServeIgnition(t *testing.T) {
    // Configure server with pool configs
    // HTTP request for a specific pool
    // Validate Ignition JSON response
}
```

## Test Fixtures

MCO tests use fixture files for complex configurations:

```
pkg/controller/render/testdata/
  *.yaml          # MachineConfig YAML fixtures
  *.ign           # Ignition config fixtures

pkg/daemon/testdata/
  *.conf          # CRI-O config fixtures
  *.json          # Ignition config fixtures
```

## Mocks and Fakes

| Component | Mock/Fake | Location |
|---|---|---|
| Kubernetes API | `controller-runtime` fake client | `sigs.k8s.io/controller-runtime/pkg/client/fake` |
| OS operations | `FakeOS` interface | `pkg/daemon/osutil_test.go` |
| systemd | Mock D-Bus connection | `pkg/daemon/daemon_test.go` |
| rpm-ostree | Fake rpm-ostree client | `pkg/daemon/rpmostree_test.go` |
| File system | In-memory file system or temp dirs | Test-local |

## Coverage

```bash
# Coverage for all packages
go test -coverprofile=mco-coverage.out ./pkg/...
go tool cover -html=mco-coverage.out -o mco-coverage.html

# Coverage for a specific controller
go test -coverprofile=render-coverage.out ./pkg/controller/render/...
go tool cover -func=render-coverage.out
```

## Common Test Failures

| Failure Pattern | Likely Cause |
|---|---|
| `failed to create fake client` | Test fixture object missing required fields (apiVersion, kind) |
| `unexpected diff in rendered config` | MachineConfig merge logic changed, update expected output |
| `reboot required mismatch` | Daemon update classification logic changed |
| `ignition validation failed` | Ignition spec version incompatibility in fixtures |

## CI Job

MCO unit tests run as a presubmit job:
- **Job**: `pull-ci-openshift-machine-config-operator-master-unit`
- **Config**: `ci-operator/config/openshift/machine-config-operator/`

The job must pass before an MCO PR can merge.
