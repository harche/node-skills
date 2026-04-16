# CRI-O Testing

## Unit Tests

### Run All Unit Tests

```bash
cd ~/go/src/github.com/cri-o/cri-o   # or openshift/cri-o
make testunit
```

### Run Unit Tests for a Specific Package

```bash
go test ./internal/config/... -v
go test ./server/... -v
go test ./pkg/annotations/... -v
go test ./internal/factory/container/... -v
```

### Run a Specific Unit Test

```bash
go test ./server/... -v -run TestGetContainerInfo
go test ./internal/config/... -v -run TestConfigValidation
```

### Run with Race Detector

```bash
go test ./server/... -race
```

### Run with Count (Flake Detection)

```bash
go test ./server/... -v -run TestSomeTest -count=10
```

## Integration Tests

Integration tests exercise CRI-O end-to-end with a running instance and a container runtime.

### Prerequisites

- Root access (required for namespaces, cgroups)
- An OCI runtime installed: `crun` or `runc`
- CNI plugins installed in `/opt/cni/bin/`
- `conmon` or `conmon-rs` installed

### Run All Integration Tests

```bash
sudo make testintegration
```

### Run Specific Integration Tests

```bash
sudo make testintegration TESTFLAGS="-run TestCrio"
```

### Integration Test Framework

Integration tests use `bats` (Bash Automated Testing System) located in `test/`:

```bash
# Run a specific bats test file
sudo bats test/crio.bats
sudo bats test/pod.bats
sudo bats test/image.bats
sudo bats test/ctr.bats
```

### Key Integration Test Files

| File | Tests |
|------|-------|
| `test/crio.bats` | CRI-O daemon lifecycle, configuration |
| `test/pod.bats` | Pod sandbox creation, deletion, listing |
| `test/ctr.bats` | Container creation, exec, lifecycle |
| `test/image.bats` | Image pull, list, remove |
| `test/network.bats` | CNI network setup |
| `test/seccomp.bats` | Seccomp profile application |
| `test/apparmor.bats` | AppArmor profile application |
| `test/selinux.bats` | SELinux labeling |
| `test/userns.bats` | User namespace tests |
| `test/checkpoint.bats` | Container checkpoint/restore |

## CRI Conformance Tests (critest)

`critest` validates CRI-O against the CRI specification.

### Install critest

```bash
go install github.com/kubernetes-sigs/cri-tools/cmd/critest@latest
```

### Run CRI Conformance

```bash
# Start CRI-O
sudo crio &

# Run critest against CRI-O
sudo critest \
  --runtime-endpoint unix:///var/run/crio/crio.sock \
  --image-endpoint unix:///var/run/crio/crio.sock
```

### Run Specific CRI Conformance Tests

```bash
sudo critest \
  --runtime-endpoint unix:///var/run/crio/crio.sock \
  --ginkgo.focus="runtime should support"
```

## CI Setup

### Prow CI Jobs

CRI-O CI runs via Prow and GitHub Actions.

#### Upstream (cri-o/cri-o)

- GitHub Actions workflows in `.github/workflows/`
- Integration tests run on Fedora and Ubuntu
- CRI conformance tests
- Linting and static analysis

#### Downstream (openshift/cri-o)

| Job | What It Does |
|-----|-------------|
| `pull-ci-openshift-cri-o-master-unit` | Unit tests |
| `pull-ci-openshift-cri-o-master-integration` | Integration tests |
| `pull-ci-openshift-cri-o-master-e2e-aws` | E2E on OCP/AWS |
| `pull-ci-openshift-cri-o-master-verify` | Linting, vet, verify |

### Running CI Locally with `act` (GitHub Actions)

For upstream CRI-O:

```bash
# Install act
go install github.com/nektos/act@latest

# Run a specific workflow
act -W .github/workflows/test.yml
```

## Test Environment Setup

### Fedora/RHEL Development Machine

```bash
# Install dependencies
sudo dnf install -y \
  golang make gcc git \
  bats \
  containers-common \
  crun runc \
  conmon \
  cri-tools \
  libseccomp-devel gpgme-devel glib2-devel device-mapper-devel \
  containernetworking-plugins

# Clone and build
git clone https://github.com/cri-o/cri-o.git
cd cri-o
make binaries

# Run tests
make testunit
sudo make testintegration
```

### Container-Based Test Environment

```bash
# Build the test image
podman build -f test/Dockerfile -t crio-test .

# Run tests in container
podman run --privileged --rm -v $(pwd):/src:Z crio-test make testunit
```

## Writing New Tests

### Unit Test

Add test functions in `_test.go` files adjacent to the code being tested:

```go
func TestMyNewFeature(t *testing.T) {
    t.Parallel()

    tests := []struct {
        name     string
        input    string
        expected string
        wantErr  bool
    }{
        {
            name:     "valid input",
            input:    "foo",
            expected: "bar",
        },
        {
            name:    "invalid input",
            input:   "",
            wantErr: true,
        },
    }

    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            t.Parallel()
            result, err := myFunction(tc.input)
            if tc.wantErr {
                require.Error(t, err)
                return
            }
            require.NoError(t, err)
            assert.Equal(t, tc.expected, result)
        })
    }
}
```

### Integration Test (bats)

Add tests to existing bats files or create a new one in `test/`:

```bash
@test "my new feature works" {
    start_crio

    # Create a pod
    pod_id=$(crictl runp test/testdata/sandbox_config.json)

    # Create a container
    ctr_id=$(crictl create "$pod_id" test/testdata/container_config.json test/testdata/sandbox_config.json)

    # Start and verify
    crictl start "$ctr_id"
    crictl inspect "$ctr_id" | jq -e '.status.state == "CONTAINER_RUNNING"'

    # Cleanup
    crictl stop "$ctr_id"
    crictl rm "$ctr_id"
    crictl stopp "$pod_id"
    crictl rmp "$pod_id"
}
```

## Debugging Test Failures

```bash
# Run single unit test with verbose output
go test ./server/... -v -run TestFailing -count=1 2>&1 | tee test.log

# Run integration test with debug output
sudo CRIO_LOG_LEVEL=debug bats test/pod.bats

# Check CRI-O logs during integration tests
# Tests store logs in test/testout/
ls test/testout/
cat test/testout/crio.log
```
