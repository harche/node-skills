# Building conmon-rs

## Prerequisites

### Rust Toolchain

Install Rust via rustup:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Verify installation
rustc --version
cargo --version
```

Check the required Rust version in `rust-toolchain.toml` or `Cargo.toml`:

```bash
cat rust-toolchain.toml
```

### System Dependencies (Fedora/RHEL)

```bash
sudo dnf install -y \
  gcc \
  make \
  pkg-config \
  protobuf-compiler \
  protobuf-devel \
  libseccomp-devel \
  capnproto \
  git
```

### System Dependencies (Ubuntu/Debian)

```bash
sudo apt-get install -y \
  gcc \
  make \
  pkg-config \
  protobuf-compiler \
  libprotobuf-dev \
  libseccomp-dev \
  capnproto \
  git
```

## Clone and Build

```bash
git clone https://github.com/containers/conmon-rs.git
cd conmon-rs
```

### Release Build

```bash
cargo build --release
```

Output binary: `target/release/conmonrs`

### Debug Build

```bash
cargo build
```

Output binary: `target/debug/conmonrs`

### Build with Specific Features

```bash
# Build with all features
cargo build --release --all-features

# Build without default features
cargo build --release --no-default-features
```

## Cross-Compile for Linux (amd64)

### From macOS

```bash
# Add the target
rustup target add x86_64-unknown-linux-gnu

# Install cross-compilation linker (via Homebrew)
brew install SergioBenitez/osxct/x86_64-unknown-linux-gnu

# Build
cargo build --release --target x86_64-unknown-linux-gnu
```

Output: `target/x86_64-unknown-linux-gnu/release/conmonrs`

### Using cross (Recommended)

`cross` provides containerized cross-compilation environments:

```bash
# Install cross
cargo install cross

# Build for linux/amd64
cross build --release --target x86_64-unknown-linux-gnu

# Build for linux/arm64
cross build --release --target aarch64-unknown-linux-gnu
```

### Using a Container

```bash
podman run --rm -v $(pwd):/src:Z -w /src \
  registry.fedoraproject.org/fedora:latest \
  bash -c "
    dnf install -y gcc make pkg-config protobuf-compiler protobuf-devel \
      libseccomp-devel capnproto git curl && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    source ~/.cargo/env && \
    cargo build --release
  "
```

## Testing

### Run All Tests

```bash
cargo test
```

### Run Tests with Output

```bash
cargo test -- --nocapture
```

### Run Specific Tests

```bash
cargo test test_name
cargo test --lib     # Library tests only
cargo test --doc     # Doc tests only
```

### Run Tests with Logging

```bash
RUST_LOG=debug cargo test -- --nocapture
```

### Integration Tests

Some integration tests require root and a running CRI-O or container runtime:

```bash
sudo -E cargo test --test integration
```

## Linting and Formatting

```bash
# Format code
cargo fmt

# Check formatting (CI style)
cargo fmt -- --check

# Run clippy linter
cargo clippy -- -D warnings

# Run clippy with all features
cargo clippy --all-features -- -D warnings
```

## Build Output

| Build Type | Output Path |
|------------|-------------|
| Debug | `target/debug/conmonrs` |
| Release | `target/release/conmonrs` |
| Cross (linux/amd64) | `target/x86_64-unknown-linux-gnu/release/conmonrs` |
| Cross (linux/arm64) | `target/aarch64-unknown-linux-gnu/release/conmonrs` |

## Deploying Custom conmon-rs to RHCOS

```bash
# Copy to node
NODE=<node-name>
scp target/release/conmonrs core@${NODE}:/tmp/conmonrs

# Replace on node
ssh core@${NODE}
sudo cp /tmp/conmonrs /usr/libexec/crio/conmonrs
sudo chmod 755 /usr/libexec/crio/conmonrs

# Restart CRI-O to pick up the new binary
sudo systemctl restart crio

# Verify conmon-rs is being used
sudo crictl info | jq '.config.containerd'
```

## Repository Layout

```
conmon-rs/
  Cargo.toml              # Workspace manifest
  conmon-rs/
    Cargo.toml             # Main crate
    src/
      main.rs              # Entry point
      container/           # Container monitoring logic
      attach/              # Container attach handling
      child_reaper/        # Process reaping
      init/                # Initialization
  pkg/
    client/                # Go client library (used by CRI-O)
  proto/
    conmon.proto           # gRPC service definition
  .cargo/
    config.toml            # Cargo configuration
```

## Common Build Issues

### `protoc: command not found`

```bash
sudo dnf install protobuf-compiler    # Fedora/RHEL
sudo apt install protobuf-compiler    # Ubuntu/Debian
```

### `capnp: command not found`

```bash
sudo dnf install capnproto            # Fedora/RHEL
sudo apt install capnproto            # Ubuntu/Debian
```

### Rust version mismatch

```bash
rustup update
rustup install $(cat rust-toolchain.toml | grep channel | cut -d'"' -f2)
```

### Linker errors during cross-compilation

Use `cross` instead of native cross-compilation:

```bash
cargo install cross
cross build --release --target x86_64-unknown-linux-gnu
```

### Out-of-memory during build

Limit parallelism:

```bash
cargo build --release -j 2
```

## Tips

- Use `cargo build --release` for deployment; debug builds are significantly slower at runtime
- The `conmonrs` binary is relatively small (~5-10MB) compared to the Go-based conmon
- When debugging, set `RUST_LOG=debug` or `RUST_LOG=trace` for verbose logging
- conmon-rs communicates with CRI-O over a gRPC socket; the protocol is defined in `proto/conmon.proto`
