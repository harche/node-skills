# Node-Level Debugging

General approach for debugging node-level issues in OpenShift clusters. Follow the progression: logs, metrics, events, then deep dive.

## Sub-references

- `node/kubelet-debug.md` -- kubelet troubleshooting, common failures, log analysis
- `node/crio-debug.md` -- CRI-O troubleshooting, crictl usage, runtime errors
- `node/systemd-debug.md` -- systemd service debugging on RHCOS
- `node/network-debug.md` -- node networking, CNI, namespace inspection

## Debugging Approach

Start broad, narrow down:

1. **Cluster view** -- node conditions, events, pod scheduling failures
2. **Node view** -- systemd service status, resource pressure, kernel messages
3. **Component view** -- kubelet/CRI-O logs, specific error patterns
4. **Deep dive** -- metrics, traces, core dumps

## Initial Triage

Get the node state from the API:

```bash
oc get nodes -o wide
oc describe node <node>
```

Key fields in `oc describe node`:
- `Conditions` -- Ready, MemoryPressure, DiskPressure, PIDPressure, NetworkUnavailable
- `Allocatable` vs `Capacity` -- resource headroom
- `Non-terminated Pods` -- scheduling density
- `Events` -- recent node-level events

## Getting a Debug Shell

```bash
oc debug node/<node>
chroot /host
```

This drops you into a privileged pod on the node with host filesystem at `/host`. After `chroot /host`, you have full access to systemd, journalctl, crictl, and host binaries.

For persistent access (e.g., running long captures):

```bash
oc debug node/<node> -- sleep 3600 &
```

## Key Systemd Services

The node runs several critical services managed by systemd:

| Service | Purpose |
|---------|---------|
| `kubelet.service` | Pod lifecycle, node registration, volume management |
| `crio.service` | Container runtime (OCI), image management |
| `machine-config-daemon.service` | MachineConfig application, OS updates |
| `NetworkManager.service` | Network configuration |
| `ovs-vswitchd.service` | OVN-Kubernetes OVS datapath |
| `openvswitch.service` | Open vSwitch base service |

Check all service states quickly:

```bash
systemctl list-units --type=service --state=failed
systemctl list-units --type=service --state=running | grep -E 'kubelet|crio|machine-config|NetworkManager|ovs'
```

## Log Collection Priority

When investigating a node issue, collect logs in this order:

1. **kubelet logs** -- almost always relevant; covers pod lifecycle, node status reporting
2. **CRI-O logs** -- container creation/deletion failures, image pulls
3. **dmesg / kernel logs** -- OOM kills, hardware errors, filesystem issues
4. **systemd journal** -- boot failures, service dependency issues
5. **audit logs** -- SELinux denials, security policy violations

Quick log collection:

```bash
# kubelet logs, last hour
journalctl -u kubelet --since "1 hour ago" --no-pager

# CRI-O logs, last hour
journalctl -u crio --since "1 hour ago" --no-pager

# Kernel messages
dmesg -T | tail -100

# SELinux denials
ausearch -m avc -ts recent
```

## Node Conditions Quick Reference

| Condition | Healthy Value | Common Causes When Unhealthy |
|-----------|--------------|------------------------------|
| Ready | True | kubelet crash, runtime down, network plugin failure |
| MemoryPressure | False | memory leak in pods, insufficient node memory |
| DiskPressure | False | container logs filling disk, image storage full |
| PIDPressure | False | fork bombs, runaway container processes |
| NetworkUnavailable | False | CNI plugin crash, OVN-Kubernetes failure |

## Event Correlation

Node events can be correlated with pod events and cluster events to build a timeline:

```bash
# Node events sorted by time
oc get events --field-selector involvedObject.kind=Node,involvedObject.name=<node> --sort-by='.lastTimestamp'

# All events on the cluster sorted by time
oc get events -A --sort-by='.lastTimestamp' | tail -50
```

## Resource Pressure Checks

On the node (via `oc debug node/<node>`):

```bash
# Memory
free -h
cat /proc/meminfo | grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree'

# CPU
uptime
top -bn1 | head -20

# Disk
df -h
df -i  # inode usage

# PIDs
ps aux | wc -l
cat /proc/sys/kernel/pid_max
```

## Common Escalation Patterns

- **Node NotReady** -- see `node/kubelet-debug.md` (kubelet health, certificates, runtime)
- **Pods stuck in ContainerCreating** -- see `node/crio-debug.md` (runtime errors, network namespace)
- **Node boot failures** -- see `node/systemd-debug.md` (service ordering, MCD issues)
- **Pod networking broken** -- see `node/network-debug.md` (CNI, OVN, iptables)
- **Metrics-based investigation** -- see `prometheus.md` (Prometheus/Thanos queries)
- **Post-incident analysis** -- see `must-gather.md` (diagnostic dump analysis)
- **Crash investigation** -- see `crash-analysis.md` (core dumps, panic traces)
