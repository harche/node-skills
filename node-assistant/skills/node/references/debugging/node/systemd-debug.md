# Systemd Debugging on RHCOS

RHCOS (Red Hat Enterprise Linux CoreOS) is an immutable, container-optimized OS managed by the Machine Config Operator. All node services run under systemd.

## Getting a Shell

```bash
oc debug node/<node>
chroot /host
```

## Service Status

```bash
# Check a specific service
systemctl status kubelet
systemctl status crio

# Detailed service properties
systemctl show kubelet --property=ActiveState,SubState,MainPID,ExecMainStartTimestamp,NRestarts,Result

# Is a service active/enabled?
systemctl is-active kubelet
systemctl is-enabled kubelet
```

## Listing Services

```bash
# All failed units
systemctl list-units --failed

# All running services
systemctl list-units --type=service --state=running

# All services (any state)
systemctl list-units --type=service --all

# Timers (periodic tasks)
systemctl list-timers --all
```

## Journal (Logs)

### Basic Queries

```bash
# Logs for a specific service
journalctl -u kubelet --no-pager

# Last hour
journalctl -u crio --since "1 hour ago" --no-pager

# Time range
journalctl -u kubelet --since "2024-01-15 14:00:00" --until "2024-01-15 14:30:00" --no-pager

# Follow live
journalctl -u kubelet -f

# Errors and above
journalctl -u kubelet -p err --no-pager

# Current boot only
journalctl -u kubelet -b --no-pager
```

### System-Wide Journal

```bash
# Current boot, all services
journalctl -b --no-pager | tail -200

# Kernel messages (like dmesg but timestamped)
journalctl -k --no-pager

# Previous boot (if available)
journalctl -b -1 --no-pager

# List boots
journalctl --list-boots

# Disk usage of journal
journalctl --disk-usage
```

### Filtering

```bash
# By priority: emerg(0), alert(1), crit(2), err(3), warning(4), notice(5), info(6), debug(7)
journalctl -p err --no-pager | tail -100

# By PID
journalctl _PID=<pid> --no-pager

# By executable
journalctl _EXE=/usr/bin/kubelet --no-pager

# Multiple units
journalctl -u kubelet -u crio --since "30 min ago" --no-pager

# Output as JSON (for parsing)
journalctl -u kubelet -o json --since "10 min ago" --no-pager
```

## Boot Analysis

```bash
# Time taken by each service during boot
systemd-analyze blame

# Critical path (longest chain)
systemd-analyze critical-chain

# Critical chain for a specific service
systemd-analyze critical-chain kubelet.service

# Boot time summary
systemd-analyze time

# Plot boot sequence (generates SVG)
systemd-analyze plot > /tmp/boot-plot.svg
```

## Service Dependencies

```bash
# What does kubelet depend on?
systemctl list-dependencies kubelet

# What depends on kubelet? (reverse)
systemctl list-dependencies kubelet --reverse

# Full dependency tree
systemctl list-dependencies kubelet --all
```

## Service Configuration

```bash
# View the unit file
systemctl cat kubelet

# View overrides/drop-ins
systemctl show kubelet --property=FragmentPath,DropInPaths

# List drop-in files
ls /etc/systemd/system/kubelet.service.d/
```

## RHCOS Services Relevant to Node Team

### Core Node Services

| Service | Purpose |
|---------|---------|
| `kubelet.service` | Kubernetes node agent |
| `crio.service` | Container runtime |
| `machine-config-daemon.service` | Applies MachineConfig changes |
| `node-valid-hostname.service` | Ensures valid hostname before kubelet starts |

### Networking

| Service | Purpose |
|---------|---------|
| `NetworkManager.service` | Network configuration |
| `openvswitch.service` | OVS base service |
| `ovs-vswitchd.service` | OVS forwarding daemon |
| `ovsdb-server.service` | OVS database |
| `ovs-configuration.service` | OVS bridge setup |
| `NetworkManager-wait-online.service` | Blocks until network is up |

### Storage and Filesystems

| Service | Purpose |
|---------|---------|
| `var-lib-containers.mount` | Container storage mount |
| `iscsid.service` | iSCSI initiator (if using iSCSI storage) |
| `multipathd.service` | Multipath I/O |

### System

| Service | Purpose |
|---------|---------|
| `chronyd.service` | NTP time sync |
| `auditd.service` | Kernel audit framework |
| `sshd.service` | SSH (if enabled) |
| `rpm-ostreed.service` | OS update management |
| `zincati.service` | Auto-update agent (FCOS, not RHCOS) |

## Common Debugging Scenarios

### Service Won't Start

```bash
# Check status and recent logs
systemctl status <service>
journalctl -u <service> -b --no-pager | tail -50

# Check dependencies -- is a required service down?
systemctl list-dependencies <service>

# Check if something is masking the service
systemctl is-enabled <service>
ls -la /etc/systemd/system/<service>  # masked = symlink to /dev/null
```

### Service Keeps Restarting

```bash
# Check restart count
systemctl show <service> --property=NRestarts

# Check restart policy
systemctl show <service> --property=Restart,RestartSec,StartLimitBurst,StartLimitIntervalSec

# Watch restarts in real time
journalctl -u <service> -f
```

### Boot Hangs or Slow Boot

```bash
# Identify slow services
systemd-analyze blame | head -20

# Check critical chain
systemd-analyze critical-chain

# Check for stuck "starting" units
systemctl list-units --state=activating

# Check for ordering cycles
systemd-analyze verify /etc/systemd/system/*.service 2>&1 | grep -i cycle
```

### MachineConfig Daemon Issues

The MCD applies OS-level configuration changes. When it fails, the node can be stuck in a degraded MachineConfigPool.

```bash
# MCD status
systemctl status machine-config-daemon

# MCD logs
journalctl -u machine-config-daemon --since "1 hour ago" --no-pager

# Current applied config
cat /etc/machine-config-daemon/currentconfig

# Desired config
cat /etc/machine-config-daemon/desiredconfig

# Check MCP status from cluster side
oc get mcp
oc describe mcp worker
```

## Systemd Transient Units

Debug pods (`oc debug node/`) create transient systemd scopes. To see them:

```bash
systemctl list-units --type=scope | grep crio
```
