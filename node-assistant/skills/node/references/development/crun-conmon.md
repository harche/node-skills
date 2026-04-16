# crun and conmon-rs Development

## Overview

crun and conmon-rs are low-level container runtime components used by CRI-O on OpenShift nodes.

| Component | Language | Purpose |
|-----------|----------|---------|
| **crun** | C | OCI runtime; creates and runs containers (replacement for runc) |
| **conmon-rs** | Rust | Container monitor; manages container lifecycle, I/O, logging |

## crun

### Repository

```bash
git clone https://github.com/containers/crun.git
cd crun
```

### What crun Does

crun is the default OCI container runtime on OpenShift (replaced runc starting in OCP 4.12). It is called by CRI-O to:

- Create container processes with appropriate namespaces, cgroups, and security contexts
- Set up the container filesystem (rootfs, mounts, pivotroot)
- Apply resource limits (cgroups v1/v2)
- Apply security policies (seccomp, SELinux, AppArmor, capabilities)
- Handle container lifecycle (create, start, kill, delete)

### Key Advantages Over runc

- Written in C (smaller, faster startup than Go-based runc)
- Native cgroup v2 support
- Lower memory footprint
- Supports additional features: user namespaces, WASM, etc.

### Quick Start

Clone and create a worktree per the [standard setup](../../SETUP.md). To build:

```bash
./autogen.sh
./configure
make
sudo make install
```

## conmon-rs

### Repository

```bash
git clone https://github.com/containers/conmon-rs.git
cd conmon-rs
```

### What conmon-rs Does

conmon-rs (conmon rewritten in Rust) is the container monitor process. CRI-O spawns one conmon-rs instance per container. It:

- Holds the container's terminal/stdio and forwards logs
- Monitors the container process and reports exit status to CRI-O
- Handles container attach and exec
- Survives CRI-O restarts (so containers keep running if CRI-O is restarted)

### conmon-rs vs conmon

conmon-rs replaced the original C-based `conmon` starting in OCP 4.14:

| Feature | conmon (C) | conmon-rs (Rust) |
|---------|-----------|-----------------|
| Language | C | Rust |
| IPC | Pipe-based | gRPC (protobuf) |
| Memory safety | Manual | Rust guarantees |
| Logging | Basic | Structured, async |
| Maintenance | Legacy | Active development |

### Quick Start

Clone and create a worktree per the [standard setup](../../SETUP.md). To build:

```bash
cargo build --release
```

Binary output: `target/release/conmonrs`

## Deployment on RHCOS

On OpenShift nodes, these binaries live at:

| Binary | Path |
|--------|------|
| crun | `/usr/bin/crun` |
| conmonrs | `/usr/libexec/crio/conmonrs` |
| conmon (legacy) | `/usr/bin/conmon` |

To deploy custom builds, see `deployment/debug-binary.md`.

## Sub-References

- **[Building crun](crun-conmon/crun-building.md)** -- prerequisites, build from source, cross-compile, testing
- **[Building conmon-rs](crun-conmon/conmonrs-building.md)** -- Rust toolchain setup, build, cross-compile, testing
