# CRI-O Unit Tests

## Overview

CRI-O testing spans multiple layers: Go unit tests, CRI validation (`critest`), BATS integration tests for CLI behavior, and local integration tests. Tests live in the `cri-o/cri-o` repository.

## Unit Tests

### Running All Unit Tests

```bash
cd $GOPATH/src/github.com/cri-o/cri-o

# Run all unit tests
make testunit

# Using go test directly
go test ./...

# Verbose
go test -v ./...
```

### Key Test Packages

| Package | What It Tests |
|---|---|
| `server/` | CRI gRPC server endpoints (RunPodSandbox, CreateContainer, etc.) |
| `server/cri/v1/` | CRI v1 API implementation |
| `pkg/config/` | CRI-O configuration parsing and validation |
| `pkg/container/` | Container lifecycle management |
| `pkg/sandbox/` | Pod sandbox management |
| `pkg/storage/` | Image and container storage operations |
| `internal/runtimehandler/` | Runtime handler selection (runc, crun, kata) |
| `internal/config/cgmgr/` | Cgroup manager (systemd, cgroupfs) |
| `internal/config/nsmgr/` | Namespace manager |
| `utils/` | Shared utility functions |
| `pkg/annotations/` | Annotation parsing and validation |

### Running Specific Tests

```bash
# Run tests in a specific package
go test -v ./server/...

# Run a single test
go test -v -run TestRunPodSandbox ./server/...

# Run tests matching a pattern
go test -v -run 'TestConfig.*' ./pkg/config/...

# With race detection
go test -race ./server/...
```

## critest -- CRI Validation Suite

`critest` validates a CRI implementation against the CRI specification. It tests the gRPC API contract that kubelet depends on.

### Installation

```bash
# Install critest
go install github.com/kubernetes-sigs/cri-tools/cmd/critest@latest

# Or build from source
git clone https://github.com/kubernetes-sigs/cri-tools.git
cd cri-tools
make critest
```

### Running Against CRI-O

```bash
# Start CRI-O (or use an existing instance)
sudo crio &

# Run CRI validation
sudo critest \
  --runtime-endpoint unix:///var/run/crio/crio.sock \
  --image-endpoint unix:///var/run/crio/crio.sock

# Run specific test suites
sudo critest \
  --runtime-endpoint unix:///var/run/crio/crio.sock \
  --ginkgo.focus="PodSandbox"

# Run image service tests only
sudo critest \
  --runtime-endpoint unix:///var/run/crio/crio.sock \
  --ginkgo.focus="ImageService"
```

### What critest Validates

- **PodSandbox lifecycle** -- create, status, stop, remove, list
- **Container lifecycle** -- create, start, stop, remove, status, list
- **Image operations** -- pull, list, remove, status
- **Exec/Attach** -- exec sync, exec, attach
- **Port forwarding** -- port-forward to containers
- **Logging** -- container log retrieval
- **Networking** -- pod network namespace configuration

## BATS Tests

CRI-O uses BATS (Bash Automated Testing System) for CLI and integration testing. These tests exercise `crio`, `crio-status`, and related tools.

### Running BATS Tests

```bash
cd $GOPATH/src/github.com/cri-o/cri-o

# Run all BATS tests
make localintegration

# Run specific BATS test files
bats test/crio.bats
bats test/config.bats
bats test/image.bats
```

### Key BATS Test Files

| File | What It Tests |
|---|---|
| `test/crio.bats` | Core CRI-O daemon lifecycle |
| `test/config.bats` | Configuration file parsing and defaults |
| `test/image.bats` | Image pull, list, remove |
| `test/network.bats` | CNI network configuration |
| `test/seccomp.bats` | Seccomp profile application |
| `test/apparmor.bats` | AppArmor profile handling |
| `test/cgroups.bats` | Cgroup management |
| `test/checkpoint.bats` | Container checkpoint/restore |
| `test/crio-status.bats` | `crio status` subcommand |
| `test/policy.bats` | Image signature policy |
| `test/restore.bats` | State restore after restart |

### BATS Test Structure

```bash
# Example BATS test
@test "crio should start with default config" {
    start_crio
    run crictl info
    [ "$status" -eq 0 ]
    [[ "$output" == *"runtimeType"* ]]
    stop_crio
}
```

### BATS Helpers

BATS tests use helper functions from `test/helpers.bash`:
- `start_crio` / `stop_crio` -- manage CRI-O daemon lifecycle
- `crictl` -- wrapper for CRI CLI
- `pod_config` / `container_config` -- generate JSON configs
- `wait_until_reachable` -- poll until CRI-O socket is ready

## Test Infrastructure

### Build Dependencies

```bash
# Install test dependencies
make vendor
make testunit-bin   # Build test binaries

# BATS dependencies
sudo dnf install -y bats  # or brew install bats-core on macOS
```

### Running Tests in a Container

```bash
# Build test container
make test-image

# Run unit tests in container
podman run --rm crio-test make testunit

# Run integration tests in container (needs privileges)
podman run --rm --privileged crio-test make localintegration
```

### Test Fixtures

```
test/testdata/
  container_config.json     # Default container config
  sandbox_config.json       # Default pod sandbox config
  container_redis.json      # Redis container config
  policy.json               # Image signature policy
  *.conf                    # CRI-O config fixtures
```

## Coverage

```bash
# Unit test coverage
go test -coverprofile=crio-coverage.out ./...
go tool cover -html=crio-coverage.out -o crio-coverage.html

# Coverage for a specific package
go test -coverprofile=server-coverage.out ./server/...
go tool cover -func=server-coverage.out
```

## CI Jobs

CRI-O tests run as presubmit jobs:
- **Unit tests**: `pull-ci-cri-o-cri-o-main-test`
- **Integration tests**: `pull-ci-cri-o-cri-o-main-integration`
- **critest validation**: runs as part of integration job

These jobs must pass before a CRI-O PR can merge.
