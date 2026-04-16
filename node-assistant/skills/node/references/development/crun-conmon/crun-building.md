# Building crun

## Prerequisites

### Required Packages (Fedora/RHEL)

```bash
sudo dnf install -y \
  autoconf automake libtool \
  gcc \
  make \
  python3 \
  libcap-devel \
  libseccomp-devel \
  yajl-devel \
  systemd-devel \
  go-md2man \
  git
```

### Required Packages (Ubuntu/Debian)

```bash
sudo apt-get install -y \
  autoconf automake libtool \
  gcc \
  make \
  python3 \
  libcap-dev \
  libseccomp-dev \
  libyajl-dev \
  libsystemd-dev \
  go-md2man \
  git
```

### Optional Dependencies

| Library | Purpose | Flag to Disable |
|---------|---------|-----------------|
| libcap | Linux capabilities | `--disable-caps` |
| libseccomp | Seccomp filtering | `--disable-seccomp` |
| libyajl | JSON parsing | `--disable-yajl` (uses embedded parser) |
| libsystemd | Systemd cgroup driver | `--disable-systemd` |

## Clone and Build

```bash
git clone https://github.com/containers/crun.git
cd crun

# Generate configure script
./autogen.sh

# Configure (default options are suitable for RHCOS)
./configure

# Build
make
```

Output binary: `crun`

### Build with Specific Options

```bash
./configure \
  --prefix=/usr \
  --enable-shared=no \
  --enable-static=yes

make
```

### Static Build

For a fully static binary (useful for deploying to RHCOS without dependency worries):

```bash
./configure --enable-static
make LDFLAGS="-static"
```

Note: Fully static builds with glibc are not recommended. Use musl libc for true static builds or rely on dynamically linked builds matching RHCOS library versions.

## Cross-Compile for RHCOS

### Using a Container (Recommended)

Build inside a Fedora or UBI container matching the target environment:

```bash
podman run --rm -v $(pwd):/src:Z -w /src \
  registry.fedoraproject.org/fedora:latest \
  bash -c "
    dnf install -y autoconf automake libtool gcc make python3 \
      libcap-devel libseccomp-devel yajl-devel systemd-devel go-md2man git && \
    ./autogen.sh && \
    ./configure && \
    make
  "
```

### Native Cross-Compilation (aarch64 target from x86_64)

```bash
sudo dnf install -y gcc-aarch64-linux-gnu \
  libseccomp-devel.aarch64 libcap-devel.aarch64 yajl-devel.aarch64

./autogen.sh
./configure --host=aarch64-linux-gnu
make
```

## Build Targets

| Target | Description |
|--------|-------------|
| `make` | Build crun binary |
| `make check` | Run test suite |
| `make install` | Install to prefix (default `/usr/local`) |
| `make clean` | Remove build artifacts |
| `make distclean` | Remove build artifacts and configure output |

## Testing

### Run All Tests

```bash
make check
```

### Run Specific Tests

The test suite uses `bats` and OCI runtime conformance tests:

```bash
# Install bats if needed
sudo dnf install -y bats

# Run tests
cd tests
sudo bats test_start.bats
sudo bats test_create.bats
sudo bats test_exec.bats
```

### OCI Runtime Conformance

```bash
# Install runtime-tools
go install github.com/openshift/runtime-tools/cmd/oci-runtime-tool@latest

# Run conformance tests
sudo RUNTIME=/path/to/crun oci-runtime-tool validate
```

## Deploying Custom crun to RHCOS

```bash
# Copy to node
NODE=<node-name>
scp crun core@${NODE}:/tmp/crun

# Replace on node
ssh core@${NODE}
sudo cp /tmp/crun /usr/bin/crun
sudo chmod 755 /usr/bin/crun

# Restart CRI-O to pick up the new binary
sudo systemctl restart crio

# Verify
sudo crun --version
sudo crictl info
```

## Build Configuration Reference

Key `./configure` options:

| Option | Description |
|--------|-------------|
| `--prefix=PREFIX` | Install prefix (default `/usr/local`) |
| `--disable-seccomp` | Build without seccomp support |
| `--disable-caps` | Build without capabilities support |
| `--disable-systemd` | Build without systemd cgroup driver |
| `--disable-yajl` | Use embedded JSON parser instead of libyajl |
| `--enable-static` | Enable static linking |
| `--with-python-bindings` | Build Python bindings |

## Common Build Issues

### `autoreconf: command not found`

```bash
sudo dnf install autoconf automake libtool
```

### `configure: error: libseccomp is required`

```bash
sudo dnf install libseccomp-devel
```

### `yajl/yajl_tree.h: No such file or directory`

```bash
sudo dnf install yajl-devel
# Or disable yajl: ./configure --disable-yajl
```

### Tests fail with permission errors

Most crun tests require root privileges:

```bash
sudo make check
```
