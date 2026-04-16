# Building CRI-O

## Prerequisites

### Required Packages (Fedora/RHEL)

```bash
sudo dnf install -y \
  golang \
  make \
  git \
  gcc \
  pkg-config \
  glib2-devel \
  libseccomp-devel \
  gpgme-devel \
  device-mapper-devel \
  libassuan-devel \
  containers-common \
  btrfs-progs-devel
```

### Required Packages (Ubuntu/Debian)

```bash
sudo apt-get install -y \
  golang \
  make \
  git \
  gcc \
  pkg-config \
  libglib2.0-dev \
  libseccomp-dev \
  libgpgme-dev \
  libdevmapper-dev \
  libassuan-dev \
  libbtrfs-dev
```

## Clone and Setup

See the [standard setup](../../SETUP.md) for cloning and worktree creation.

## Build Commands

### Build All (Binaries + Docs)

```bash
make
```

### Build Binaries Only

```bash
make binaries
```

Produces:
- `bin/crio` -- the CRI-O daemon
- `bin/pinns` -- pin namespaces helper binary

### Build with Debug Symbols

```bash
make binaries GO_BUILDFLAGS="-gcflags='all=-N -l'"
```

### Build crio Only (Skip pinns)

```bash
go build -o bin/crio ./cmd/crio
```

## Cross-Compile for RHCOS (linux/amd64)

When building on macOS or a non-amd64 system:

```bash
GOOS=linux GOARCH=amd64 CGO_ENABLED=1 \
  CC=x86_64-linux-gnu-gcc \
  make binaries
```

Note: Cross-compiling CRI-O with CGO requires a cross-compilation toolchain because CRI-O uses CGO for seccomp and other system libraries. For simplicity, build in a Linux container:

```bash
podman run --rm -v $(pwd):/src:Z -w /src \
  registry.fedoraproject.org/fedora:latest \
  bash -c "dnf install -y golang make gcc pkg-config libseccomp-devel gpgme-devel glib2-devel device-mapper-devel && make binaries"
```

## RPM Building

CRI-O RPMs for RHCOS are built via the OSBS/Brew pipeline. For local RPM builds:

```bash
# Install rpm-build tools
sudo dnf install -y rpm-build rpmdevtools

# Build SRPM and RPM
make rpm
```

Or use the spec file directly:

```bash
rpmbuild -ba contrib/crio.spec
```

## Container Image Build

### Build Container Image

```bash
podman build -t quay.io/<your-user>/cri-o:custom -f Dockerfile .
```

### Using the CI Dockerfile

```bash
podman build -t quay.io/<your-user>/cri-o:custom -f Dockerfile.ci .
```

### Push to Registry

```bash
podman push quay.io/<your-user>/cri-o:custom
```

## Deploying Custom CRI-O to a Cluster

### Method 1: Replace Binary on Node

```bash
# Build for linux/amd64 (in a container if needed)
podman run --rm -v $(pwd):/src:Z -w /src \
  registry.fedoraproject.org/fedora:latest \
  bash -c "dnf install -y golang make gcc pkg-config libseccomp-devel gpgme-devel glib2-devel device-mapper-devel && make binaries"

# Copy to node
NODE=<node-name>
scp bin/crio core@${NODE}:/tmp/

# Replace on node
ssh core@${NODE}
sudo systemctl stop crio
sudo cp /tmp/crio /usr/bin/crio
sudo systemctl start crio

# Verify
sudo crio version
sudo crictl info
```

### Method 2: Via MachineConfig

For persistent deployment, create a MachineConfig that replaces the binary. See `deployment/debug-binary.md` for the full workflow.

## Build Output

| Artifact | Path |
|----------|------|
| CRI-O binary | `bin/crio` |
| pinns binary | `bin/pinns` |
| Man pages | `docs/crio*.8` |
| Completions | `completions/` |

## Common Build Errors

### Missing libseccomp

```
pkg-config --cflags -- libseccomp: Package libseccomp was not found
```

Fix: `sudo dnf install libseccomp-devel`

### Missing gpgme

```
gpgme.h: No such file or directory
```

Fix: `sudo dnf install gpgme-devel`

### Go version mismatch

```
go: go.mod requires go >= X.Y
```

Install the required Go version.

### Vendor directory issues

```bash
go mod vendor
go mod tidy
```

## Tips

- For fastest iteration on CRI-O changes, build just the `crio` binary with `go build -o bin/crio ./cmd/crio`
- Use the containerized build approach when cross-compiling to avoid toolchain issues
- The `make clean` target removes all build artifacts
- Use `make help` to see all available make targets
