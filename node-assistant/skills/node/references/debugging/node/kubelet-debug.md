# Kubelet Debugging

Kubelet is the primary node agent. It registers the node, manages pod lifecycle, reports node status, and handles volume operations.

## Getting a Shell

```bash
oc debug node/<node>
chroot /host
```

## Kubelet Logs

```bash
# Recent logs
journalctl -u kubelet --since "1 hour ago" --no-pager

# Follow live
journalctl -u kubelet -f

# Logs around a specific time
journalctl -u kubelet --since "2024-01-15 14:00:00" --until "2024-01-15 14:30:00"

# Filter by priority (err and above)
journalctl -u kubelet -p err --no-pager

# Grep for specific pod
journalctl -u kubelet --no-pager | grep <pod-name>
```

## Kubelet Log Verbosity

Kubelet uses klog verbosity levels. The default in OpenShift is `--v=2`.

| Level | Content |
|-------|---------|
| `--v=0` | Errors only |
| `--v=2` | Default -- steady-state info, warnings |
| `--v=4` | Detailed -- useful for most debugging |
| `--v=6` | API request/response bodies |
| `--v=8` | Full content dumps |

To increase verbosity at runtime without restart, modify the kubelet's KubeletConfiguration via MachineConfig or use the dynamic log level endpoint (if enabled):

```bash
# Check current verbosity
curl -sk https://localhost:10250/configz | python3 -m json.tool | grep -i log
```

For persistent changes, create a KubeletConfig CR:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: debug-verbosity
spec:
  machineConfigPoolSelector:
    matchLabels:
      pools.operator.machineconfiguration.openshift.io/worker: ""
  kubeletConfig:
    logging:
      verbosity: 4
```

**Warning**: verbosity >= 6 generates massive log volume. Use only for targeted debugging and revert promptly.

## Kubelet Service Status

```bash
systemctl status kubelet
systemctl is-active kubelet
systemctl show kubelet --property=ActiveState,SubState,MainPID,ExecMainStartTimestamp
```

## Common Issues

### Node NotReady

Checklist:

1. **kubelet running?**
   ```bash
   systemctl is-active kubelet
   journalctl -u kubelet --since "5 min ago" -p err --no-pager
   ```

2. **Container runtime healthy?**
   ```bash
   systemctl is-active crio
   crictl info
   ```

3. **Certificates valid?**
   ```bash
   # Check kubelet client cert
   openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates
   # Check kubelet serving cert
   openssl x509 -in /var/lib/kubelet/pki/kubelet-server-current.pem -noout -dates
   ```

4. **Network connectivity to API server?**
   ```bash
   # Check API server endpoint
   curl -sk https://<api-server>:6443/healthz
   ```

5. **Node conditions?**
   ```bash
   oc get node <node> -o jsonpath='{range .status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.message}{"\n"}{end}'
   ```

### Pod Eviction

Kubelet evicts pods when node resources cross eviction thresholds.

Default soft eviction thresholds:
- `memory.available` < 100Mi
- `nodefs.available` < 10%
- `nodefs.inodesFree` < 5%
- `imagefs.available` < 15%

Check current thresholds:

```bash
curl -sk https://localhost:10250/configz | python3 -m json.tool | grep -A 10 eviction
```

Check actual resource state:

```bash
free -h
df -h /var/lib/containers  # imagefs
df -h /var              # nodefs
df -i /var              # inodes
```

### Volume Mount Failures

Symptoms: pods stuck in `ContainerCreating` with volume-related events.

```bash
# Check kubelet volume manager logs
journalctl -u kubelet --no-pager | grep -i -E 'volume|mount|attach|csi'

# Check CSI driver pods
oc get pods -n openshift-cluster-csi-drivers

# List mounted volumes
mount | grep kubernetes
findmnt -t ext4,xfs | grep kubelet
```

### Image Pull Errors

```bash
# Check kubelet image pull logs
journalctl -u kubelet --no-pager | grep -i -E 'pull|image|registry'

# Check CRI-O for image pull details
journalctl -u crio --no-pager | grep -i -E 'pull|image'

# Verify registry connectivity from node
curl -sk https://<registry>/v2/
```

### PLEG Issues (Pod Lifecycle Event Generator)

PLEG is responsible for detecting container state changes. When PLEG is unhealthy, the node goes NotReady.

Symptoms in kubelet logs:
```
PLEG is not healthy: pleg was last seen active 3m0s ago; threshold is 3m0s
```

Common causes:
- CRI-O unresponsive or slow
- High container churn (many pods starting/stopping)
- Disk I/O saturation (slow container state reads)
- Large number of pods on node

Investigate:

```bash
# Check PLEG relist duration
journalctl -u kubelet --no-pager | grep -i pleg

# Check CRI-O responsiveness
time crictl ps
time crictl pods

# Check disk I/O
iostat -xz 1 5
```

### CGroup Errors

```bash
# Check cgroup version
stat -fc %T /sys/fs/cgroup  # "cgroup2fs" = v2, "tmpfs" = v1

# Check kubelet cgroup driver config
cat /etc/kubernetes/kubelet.conf | grep -i cgroup

# Look for cgroup errors
journalctl -u kubelet --no-pager | grep -i -E 'cgroup|oom|memory.max'
dmesg -T | grep -i -E 'cgroup|oom'
```

## Health and Metrics Endpoints

```bash
# Healthz (unauth, port 10248)
curl -s http://localhost:10248/healthz

# Metrics (requires auth, port 10250)
curl -sk https://localhost:10250/metrics --header "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" | head -50

# From outside the node via oc
oc get --raw /api/v1/nodes/<node>/proxy/metrics | head -50
```

## Node Conditions Reference

| Condition | Meaning | Kubelet Check |
|-----------|---------|---------------|
| Ready | kubelet healthy, can accept pods | kubelet running + runtime healthy + network plugin ready |
| MemoryPressure | `memory.available` below eviction threshold | `free -h` |
| DiskPressure | `nodefs.available` or `imagefs.available` below threshold | `df -h` |
| PIDPressure | available PIDs below threshold | `ps aux | wc -l` |
| NetworkUnavailable | network plugin not configured | CNI plugin status |

## Kubelet Configuration

```bash
# Active kubelet config
cat /etc/kubernetes/kubelet.conf

# Kubelet flags (systemd drop-in)
cat /etc/systemd/system/kubelet.service.d/*.conf

# Runtime kubelet config (from API)
curl -sk https://localhost:10250/configz | python3 -m json.tool
```
