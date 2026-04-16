# MCO (Machine Config Operator) Development

## Repository

```bash
git clone https://github.com/openshift/machine-config-operator.git
cd machine-config-operator
```

## MCO Components

The MCO consists of several components that manage node configuration:

| Component | Binary | Description |
|-----------|--------|-------------|
| **machine-config-operator** | `machine-config-operator` | Top-level operator; manages other components |
| **machine-config-controller** | `machine-config-controller` | Renders MachineConfigs, manages MachineConfigPools |
| **machine-config-daemon** (MCD) | `machine-config-daemon` | Runs on every node; applies configuration, manages updates |
| **machine-config-server** (MCS) | `machine-config-server` | Serves Ignition configs to joining nodes |

## Key CRDs

| CRD | Purpose |
|-----|---------|
| `MachineConfig` | Declares desired machine configuration (files, systemd units, kernel args, etc.) |
| `MachineConfigPool` | Groups nodes and associates rendered MachineConfigs |
| `ControllerConfig` | Internal; cluster-level configuration for the MCO |
| `KubeletConfig` | User-facing; applies custom KubeletConfiguration to a pool |
| `ContainerRuntimeConfig` | User-facing; applies custom CRI-O configuration to a pool |

## Build System

### Build Everything

```bash
make
```

### Build Individual Components

```bash
make daemon          # MCD only
make controller      # machine-config-controller only
make operator        # machine-config-operator only
make server          # machine-config-server only
```

### Build Container Images

```bash
make image           # Build all images
```

### Quick Start

Clone and create a worktree per the [standard setup](../SETUP.md). To build and test:

```bash
make              # Build all binaries
make test         # Run unit tests
make daemon       # Build MCD only for fast iteration
```

## Repository Layout

```
cmd/                          # Binary entrypoints
  machine-config-operator/
  machine-config-controller/
  machine-config-daemon/
  machine-config-server/
pkg/
  controller/                 # MachineConfig rendering, pool management
  daemon/                     # MCD logic (apply configs, update OS, reboot)
  server/                     # MCS Ignition serving
  operator/                   # Operator lifecycle
  apis/machineconfiguration/  # CRD types and generated code
  helpers/                    # Shared utilities
templates/                    # Default MachineConfig templates
install/                      # CRD manifests, RBAC
test/                         # E2E tests
manifests/                    # Operator manifests for OLM
```

## Testing

### Unit Tests

```bash
make test
```

### E2E Tests

```bash
# Requires a running OCP cluster with KUBECONFIG set
make test-e2e
```

### Run Specific Unit Tests

```bash
go test ./pkg/daemon/... -v -run TestUpdate
go test ./pkg/controller/... -v -run TestRender
```

## Workflow: Typical MCD Change

1. Edit code in `pkg/daemon/`
2. Build: `make daemon`
3. Run unit tests: `go test ./pkg/daemon/... -v`
4. Deploy to cluster for testing (see `mco/building.md`)
5. Run e2e tests against the cluster

## Sub-References

- **[Building the MCO](mco/building.md)** -- prerequisites, full build, component build, container images, deploying custom builds
- **[MCO Architecture](mco/architecture.md)** -- component interaction, rendering pipeline, update flow, Ignition, OS updates and layering
- **[MCO Testing](mco/testing.md)** -- unit tests, e2e tests, CI job structure, test environment setup
