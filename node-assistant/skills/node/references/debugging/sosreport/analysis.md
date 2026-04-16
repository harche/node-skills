# Analyzing sosreport

Techniques for extracting actionable information from a sosreport collection.

## Quick Triage Checklist

Run through these in order to get an initial picture of the node's state at collection time.

### 1. System Overview

```bash
cat date                              # When was this collected?
cat hostname                          # Which node?
cat uname                             # Kernel version
cat uptime                            # How long has the node been up?
cat free                              # Memory summary
cat sos_commands/filesys/df_-h        # Disk usage
```

### 2. Failed Services

```bash
cat sos_commands/systemd/systemctl_list-units_--failed_--all
```

If kubelet or crio are failed, check their journals immediately:
```bash
cat sos_commands/kubernetes/journalctl_--no-pager_--unit_kubelet | tail -100
cat sos_commands/crio/journalctl_--no-pager_--unit_crio | tail -100
```

### 3. Kernel Messages (dmesg)

```bash
# Look for critical issues
grep -i -E 'oom|panic|error|fail|warn|bug|call trace' sos_commands/kernel/dmesg | tail -30
```

### 4. Container State

```bash
cat sos_commands/crio/crictl_ps_-a | head -30
cat sos_commands/crio/crictl_pods | head -30
```

### 5. SELinux Denials

```bash
grep 'avc:' var/log/audit/audit.log | tail -10
```

## Looking for OOM Kills

OOM (Out Of Memory) kills are one of the most common node-level issues.

### In dmesg / Kernel Log

```bash
# Check kernel ring buffer
grep -i 'oom' sos_commands/kernel/dmesg
grep -i 'out of memory' sos_commands/kernel/dmesg

# Full OOM kill details (process name, memory stats)
grep -A 20 'Out of memory' sos_commands/kernel/dmesg
grep -A 20 'oom-kill' sos_commands/kernel/dmesg
```

### In System Log

```bash
grep -i 'oom' var/log/messages
grep -i 'killed process' var/log/messages
```

### OOM Kill Analysis

When you find an OOM kill, look for:
- **Which process was killed**: the process name and PID in the OOM message
- **Total memory at the time**: `MemTotal`, `MemFree`, `MemAvailable` in the OOM dump
- **Which cgroup triggered it**: cgroup path indicates the container/pod
- **Score**: `oom_score_adj` shows the OOM priority

```bash
# Check memory state at collection
cat proc/meminfo | grep -E 'MemTotal|MemAvailable|MemFree|SwapTotal|SwapFree|Committed_AS'

# Check cgroup memory limits
find sys/fs/cgroup -name 'memory.max' -exec sh -c 'echo "$1: $(cat $1)"' _ {} \; 2>/dev/null | head -20
```

## Disk Pressure Indicators

```bash
# Filesystem usage
cat sos_commands/filesys/df_-h

# Inode usage (can exhaust even with disk space available)
cat sos_commands/filesys/df_-i 2>/dev/null || grep -i inode sos_commands/filesys/*

# Container storage specifically
grep '/var/lib/containers' sos_commands/filesys/df_-h

# Block device I/O stats
cat sos_commands/block/lsblk

# Check for filesystem errors
grep -i -E 'ext4.*error|xfs.*error|filesystem.*error|I/O error' sos_commands/kernel/dmesg
grep -i -E 'read-only' sos_commands/kernel/dmesg
```

### Image and Container Storage

```bash
# Container images on disk
cat sos_commands/crio/crictl_images

# Storage configuration
cat etc/containers/storage.conf

# Overlay mount count (excessive = problem)
grep overlay sos_commands/filesys/mount* | wc -l
```

## Network Issues

### Interface Errors and Drops

```bash
# Interface statistics
cat sos_commands/networking/ip_-s_link

# Look for errors and drops
grep -i -E 'errors|dropped' sos_commands/networking/ip_-s_link

# ethtool per-interface error counters
for f in sos_commands/networking/ethtool_-S_*; do
  echo "=== $(basename $f) ==="
  grep -i -E 'err|drop|miss|crc|collision' "$f"
done
```

### Connectivity

```bash
# Routing table
cat sos_commands/networking/ip_route

# DNS config
cat etc/resolv.conf

# Listening ports
cat sos_commands/networking/ss_-tlnp

# NetworkManager state
cat sos_commands/networking/nmcli_device_status
cat sos_commands/networking/nmcli_connection_show
```

### OVS / OVN State

```bash
# OVS bridge configuration
cat sos_commands/ovn_central/ovs-vsctl_show 2>/dev/null
cat sos_commands/openvswitch/ovs-vsctl_show 2>/dev/null

# OVN southbound (if collected)
cat sos_commands/ovn_central/ovn-sbctl_show 2>/dev/null
```

## Comparing with must-gather Data

sosreport and must-gather complement each other. Cross-reference:

| Finding in sosreport | Check in must-gather |
|---------------------|---------------------|
| OOM kill on a process | Pod events, container restart count |
| Failed systemd service | Operator logs, MCD logs |
| Disk full on `/var/lib/containers` | Node conditions (DiskPressure) |
| Network errors on NIC | OVN-Kubernetes pod logs, node events |
| SELinux denial | MCD logs (if MC-related), pod events |
| Kubelet crash in journal | Node conditions, events |

### Timeline Correlation

```bash
# Get sosreport collection time
cat date

# Cross-reference with must-gather events around that time
grep -r "$(cat date | cut -d' ' -f1-3)" /path/to/must-gather/namespaces/*/core/events.yaml
```

## Performance Analysis

### CPU

```bash
# CPU info
cat proc/cpuinfo | grep 'model name' | head -1
cat proc/cpuinfo | grep processor | wc -l  # CPU count

# Load average
cat uptime

# CPU-related kernel parameters
grep -E 'cpu|sched' sos_commands/kernel/sysctl_-a | head -20
```

### Memory Details

```bash
# Full memory breakdown
cat proc/meminfo

# Slab usage (kernel memory)
cat proc/slabinfo | sort -k 3 -n -r | head -20

# Memory fragmentation
cat proc/buddyinfo

# Huge pages
grep -i huge proc/meminfo
```

### Process Analysis

```bash
# Top processes at collection time (if ps output is collected)
cat sos_commands/process/ps_auxwww | sort -k 4 -n -r | head -20  # by memory
cat sos_commands/process/ps_auxwww | sort -k 3 -n -r | head -20  # by CPU

# Process count
cat sos_commands/process/ps_auxwww | wc -l
```

## Common Patterns

### "Node went NotReady and recovered"

1. Check dmesg for OOM/hardware/kernel issues
2. Check kubelet journal for PLEG or heartbeat failures
3. Check CRI-O journal for runtime errors
4. Check disk/memory pressure at the time
5. Check network errors (lost connectivity to API server?)

### "Node keeps rebooting"

1. Check `uptime` -- how long since last boot?
2. Check `sos_commands/systemd/journalctl_--no-pager_--boot` for boot issues
3. Check dmesg for kernel panics or hardware errors
4. Check `sos_commands/systemd/systemd-analyze_blame` for boot timing
5. Check if MCD is triggering reboots (MC updates)

### "Containers failing on this node but not others"

1. Check CRI-O logs and crictl output
2. Check disk space (especially `/var/lib/containers`)
3. Check SELinux denials
4. Check kernel parameters vs other nodes (sysctl differences)
5. Check for corrupted container storage
