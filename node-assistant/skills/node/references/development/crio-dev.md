# CRI-O Development for OpenShift

## Repositories

| Repo | Purpose |
|------|---------|
| `github.com/cri-o/cri-o` | Upstream CRI-O |
| `github.com/openshift/cri-o` | OpenShift downstream fork |

For OpenShift-specific work, use the downstream fork. For upstream features and bug fixes, work against the upstream repo first and backport.

```bash
# Upstream
git clone https://github.com/cri-o/cri-o.git

# Downstream (OpenShift)
git clone https://github.com/openshift/cri-o.git
```

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Upstream development |
| `release-1.X` | Upstream stable releases |
| `release-4.X` | OpenShift downstream (tracks upstream release-1.X) |

OCP 4.18 uses CRI-O 1.31.x, OCP 4.17 uses CRI-O 1.30.x, etc. The minor version mapping is: CRI-O 1.(OCP_minor + 13).

## Build System

### Quick Build

```bash
make
```

### Build Binaries Only

```bash
make binaries
```

This produces `bin/crio` and `bin/pinns`.

### Build with Specific Tags

```bash
make GO_BUILDTAGS="containers_image_openpgp"
```

## Key Dependencies

| Dependency | Purpose |
|------------|---------|
| `containers/image` | Image pulling and management |
| `containers/storage` | Container filesystem storage |
| `conmon` / `conmon-rs` | Container monitor process |
| `crun` / `runc` | OCI runtime |
| `containers/common` | Shared container tooling config |
| `CNI plugins` / `Multus` | Network setup |

## Configuration

CRI-O configuration on RHCOS nodes:

| Path | Purpose |
|------|---------|
| `/etc/crio/crio.conf` | Main configuration file |
| `/etc/crio/crio.conf.d/` | Drop-in configuration directory |
| `/etc/containers/registries.conf` | Image registry configuration |
| `/etc/containers/storage.conf` | Storage driver configuration |
| `/etc/containers/policy.json` | Image signature policy |

On OpenShift, CRI-O configuration is managed by the MCO via `ContainerRuntimeConfig` CRs and MachineConfigs.

## Repository Layout

```
cmd/crio/             # crio binary entrypoint
server/               # CRI gRPC server implementation
internal/             # Internal packages
  config/             # Configuration parsing
  factory/            # Container/sandbox creation
  lib/                # Core container runtime library
  storage/            # Image and container storage
pkg/                  # Public packages
  annotations/        # OCI/CRI annotation handling
  config/             # Public configuration types
  sandbox/            # Sandbox (pod) management
test/                 # Integration tests
contrib/              # Systemd units, packaging
```

## Quick Start

Clone and create a worktree per the [standard setup](../SETUP.md). To build and test (Linux only — CRI-O does not build natively on macOS):

```bash
make binaries
make testunit
sudo make testintegration  # requires root and runc/crun
```

## Sub-References

- **[Building CRI-O](crio/building.md)** -- prerequisites, build commands, cross-compilation, RPM and container image builds
- **[CRI-O Configuration](crio/configuration.md)** -- config file structure, drop-in dirs, runtime/storage/network config
- **[CRI-O Testing](crio/testing.md)** -- unit tests, integration tests, CRI conformance, CI setup
