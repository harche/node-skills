# sosreport Analysis

sosreport (from the `sos` package) is a system-level diagnostic collection tool used for deep OS-level investigation and Red Hat support cases.

## Sub-references

- `sosreport/structure.md` -- directory layout, key files for node team
- `sosreport/analysis.md` -- triage checklist, OOM detection, disk/network issues

## What is sosreport

`sos report` (formerly `sosreport`) collects comprehensive system state:
- Hardware and kernel info
- Systemd service status and logs
- Network configuration and state
- Storage and filesystem details
- Container runtime state
- SELinux and security configuration
- Package and RPM info

It is more detailed than must-gather at the OS level. must-gather captures Kubernetes/OpenShift cluster state; sosreport captures the underlying RHCOS system state.

## When to Use sosreport

- Red Hat support cases (support engineers request it)
- Kernel-level issues (OOM kills, hardware errors, driver problems)
- OS-level network issues (bonding, NIC configuration)
- Storage/filesystem corruption or performance
- Boot failures or systemd ordering issues
- Issues that are not visible from the Kubernetes API layer
- Complement to must-gather for node-specific deep dives

## Collecting on RHCOS

RHCOS nodes do not have SSH access by default. Use `oc debug node/` to access the host.

### Method 1: Via oc debug (Preferred)

```bash
# Get a debug shell
oc debug node/<node>
chroot /host

# Run sos report
sos report --batch --tmp-dir /var/tmp

# The report will be saved as /var/tmp/sosreport-<hostname>-<date>.tar.xz
```

### Method 2: Toolbox Container

```bash
oc debug node/<node>
chroot /host
toolbox

# Inside toolbox (has more tools available)
sos report --batch
```

### Method 3: Specific Plugins Only

```bash
# Collect only relevant plugins (faster, smaller)
sos report --batch --only-plugins=crio,podman,networking,systemd,kernel,logs

# List available plugins
sos report --list-plugins
```

### Retrieving the Report

```bash
# From the debug pod (before exiting)
# Note the path from sos output, e.g. /var/tmp/sosreport-node1-2024-01-15.tar.xz

# Option 1: Copy from node via oc
oc debug node/<node> -- cat /host/var/tmp/sosreport-*.tar.xz > sosreport.tar.xz

# Option 2: Use a persistent pod
oc run sos-copy --image=registry.access.redhat.com/ubi9/ubi-minimal --overrides='
{
  "spec": {
    "nodeName": "<node>",
    "containers": [{
      "name": "sos-copy",
      "image": "registry.access.redhat.com/ubi9/ubi-minimal",
      "command": ["sleep", "3600"],
      "volumeMounts": [{"name": "host", "mountPath": "/host"}]
    }],
    "volumes": [{"name": "host", "hostPath": {"path": "/"}}]
  }
}'
oc cp sos-copy:/host/var/tmp/sosreport-*.tar.xz ./sosreport.tar.xz
oc delete pod sos-copy
```

## Quick Triage After Collection

```bash
# Extract
tar xf sosreport-*.tar.xz
cd sosreport-*/

# System overview
cat date
cat hostname
cat uname
cat uptime
cat free

# Check for OOM kills
grep -i oom sos_logs/sos.log
grep -i 'out of memory' var/log/messages
grep -i 'oom' sos_commands/kernel/dmesg

# Failed services
cat sos_commands/systemd/systemctl_list-units_--failed_--all

# Disk space
cat df

# Memory
cat free
cat proc/meminfo
```

## Relationship to Other Tools

| Tool | Scope | Use Case |
|------|-------|----------|
| `must-gather` | Cluster (k8s resources, operator logs) | Cluster-wide triage, support cases |
| `sosreport` | Single node (OS, kernel, hardware) | Deep node-level diagnostics |
| `oc debug node/` | Single node (live) | Interactive investigation |
| `journalctl` | Single node (service logs) | Real-time log analysis |
| Prometheus | Cluster (metrics) | Trends, resource usage, alerting |
