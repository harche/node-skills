# CRI-O Configuration Reference

## Configuration File Locations

| Path | Purpose |
|------|---------|
| `/etc/crio/crio.conf` | Main configuration file |
| `/etc/crio/crio.conf.d/*.conf` | Drop-in overrides (alphabetical order) |
| `/usr/share/containers/containers.conf` | System-wide containers defaults |
| `/etc/containers/containers.conf` | Admin containers overrides |

Drop-in files in `/etc/crio/crio.conf.d/` override values from the main config. Files are processed in alphabetical order; later files override earlier ones.

On OpenShift, MCO manages CRI-O configuration. Do not edit config files directly on RHCOS nodes -- they will be overwritten.

## Main Config File Structure

The CRI-O config uses TOML format with these top-level sections:

```toml
[crio]
# General CRI-O settings

[crio.api]
# gRPC API settings

[crio.runtime]
# Container runtime settings

[crio.image]
# Image management settings

[crio.network]
# Network settings

[crio.metrics]
# Prometheus metrics settings

[crio.tracing]
# OpenTelemetry tracing settings

[crio.stats]
# Stats collection settings

[crio.nri]
# Node Resource Interface settings
```

## Generate Default Config

```bash
crio config --default > /etc/crio/crio.conf
```

## Runtime Configuration

### `[crio.runtime]`

```toml
[crio.runtime]
# Default OCI runtime
default_runtime = "crun"

# Runtime table entries
[crio.runtime.runtimes.crun]
runtime_path = "/usr/bin/crun"
runtime_type = "oci"
monitor_path = "/usr/libexec/crio/conmonrs"
monitor_env = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"]

[crio.runtime.runtimes.runc]
runtime_path = "/usr/bin/runc"
runtime_type = "oci"
monitor_path = "/usr/libexec/crio/conmonrs"

# Container process limits
pids_limit = 4096
log_size_max = -1

# Conmon (legacy container monitor)
conmon = "/usr/bin/conmon"

# Conmon-rs (new container monitor, default in OCP 4.14+)
# Set via runtime table monitor_path

# Cgroup manager
cgroup_manager = "systemd"

# SELinux
selinux = true

# Seccomp
seccomp_profile = "/usr/share/containers/seccomp.json"

# Apparmor
apparmor_profile = ""

# Default ulimits
default_ulimits = [
  "nofile=65536:65536",
]

# Namespaces
namespaces_dir = "/var/run"

# Infra (pause) container image
infra_ctr_cpuset = ""

# Runtime hooks
hooks_dir = ["/usr/share/containers/oci/hooks.d", "/etc/containers/oci/hooks.d"]

# Timezone
timezone = ""

# Devices
additional_devices = ["/dev/fuse"]

# Workloads (for resource management)
[crio.runtime.workloads]
```

### Runtime Selection

CRI-O supports multiple OCI runtimes. Pods select a runtime via the `RuntimeClass`:

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: crun
handler: crun
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  runtimeClassName: crun
  containers:
  - name: test
    image: registry.access.redhat.com/ubi9/ubi-minimal
```

### Kata Containers Runtime (if installed)

```toml
[crio.runtime.runtimes.kata]
runtime_path = "/usr/bin/containerd-shim-kata-v2"
runtime_type = "vm"
privileged_without_host_devices = true
```

## Storage Configuration

### `[crio.storage]` (inherits from containers/storage)

Primary storage configuration lives in `/etc/containers/storage.conf`:

```toml
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"

[storage.options]
size = ""
override_kernel_check = "true"

[storage.options.overlay]
mountopt = "nodev,metacopy=on"
```

On RHCOS, the default storage driver is `overlay` backed by `/var/lib/containers/storage`.

## Network Configuration

### `[crio.network]`

```toml
[crio.network]
# CNI configuration directory
network_dir = "/etc/cni/net.d/"

# CNI plugin binaries
plugin_dirs = ["/opt/cni/bin/", "/usr/libexec/cni/"]
```

On OpenShift, networking is managed by the cluster network operator (CNO) via Multus and OVN-Kubernetes (or OpenShift SDN). CRI-O delegates to CNI plugins configured by the CNO.

## Image Configuration

### `[crio.image]`

```toml
[crio.image]
# Default transport
default_transport = "docker://"

# Pause image
pause_image = "quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:..."
pause_image_auth_file = "/var/lib/kubelet/config.json"
pause_command = "/usr/bin/pod"

# Image pull settings
global_auth_file = "/var/lib/kubelet/config.json"

# Signature verification
image_volumes = "mkdir"
insecure_registries = []

# Big image handling
big_files_temporary_dir = ""
```

### Registry Configuration

Registry mirrors and settings are in `/etc/containers/registries.conf`:

```toml
# /etc/containers/registries.conf
unqualified-search-registries = ["registry.access.redhat.com", "docker.io"]

[[registry]]
prefix = "docker.io"
location = "docker.io"

[[registry.mirror]]
location = "my-mirror.example.com"
```

On OpenShift, configure registries via `ImageContentSourcePolicy` or `ImageDigestMirrorSet` CRs (not by editing the file directly).

## Metrics Configuration

### `[crio.metrics]`

```toml
[crio.metrics]
enable_metrics = true
metrics_port = 9537
metrics_socket = ""
metrics_cert = ""
metrics_key = ""
```

CRI-O exposes Prometheus metrics at `http://localhost:9537/metrics`.

## Drop-In Configuration on OpenShift

MCO creates drop-in files in `/etc/crio/crio.conf.d/`:

| File | Source |
|------|--------|
| `00-default` | Base RHCOS defaults |
| `01-ctrcfg-*` | From `ContainerRuntimeConfig` CR |
| `10-*` | Various MCO-managed overrides |

### ContainerRuntimeConfig CR

Apply CRI-O configuration changes via the MCO:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: ContainerRuntimeConfig
metadata:
  name: custom-crio
spec:
  machineConfigPoolSelector:
    matchLabels:
      pools.operator.machineconfiguration.openshift.io/worker: ""
  containerRuntimeConfig:
    pidsLimit: 8192
    logSizeMax: "52428800"
    overlaySize: "50G"
    defaultRuntime: "crun"
```

This generates a MachineConfig with a drop-in file that MCO applies to all matching nodes.

## Inspecting Runtime Configuration

On a running node:

```bash
# View effective configuration
sudo crio config

# View status via crictl
sudo crictl info

# Check CRI-O version and build info
sudo crio version

# View CRI-O logs
journalctl -u crio -f
```
