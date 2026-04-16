# CRI-O Debugging

CRI-O is the container runtime on OpenShift nodes. It implements the Kubernetes CRI (Container Runtime Interface) and manages container lifecycle, image pulls, and container storage.

## CRI-O Logs

```bash
# Recent logs
journalctl -u crio --since "1 hour ago" --no-pager

# Follow live
journalctl -u crio -f

# Errors only
journalctl -u crio -p err --no-pager

# Grep for specific container/pod
journalctl -u crio --no-pager | grep <container-id-or-pod-name>
```

## CRI-O Log Levels

CRI-O supports these log levels: `trace`, `debug`, `info`, `warn`, `error`, `fatal`.

Default in OpenShift: `info`.

### Change Log Level at Runtime (No Restart)

```bash
# Increase to debug
crio-status config set log_level debug

# Or via the UNIX socket directly
curl --unix-socket /var/run/crio/crio.sock -X POST "http://localhost/config?log_level=debug"

# Verify
crio-status config get log_level
```

### Change Persistently

Edit `/etc/crio/crio.conf` or drop a file in `/etc/crio/crio.conf.d/`:

```ini
[crio.runtime]
log_level = "debug"
```

Then restart: `systemctl restart crio`

**Warning**: `debug` level is very verbose. Use for targeted investigations and revert.

## CRI-O Service Status

```bash
systemctl status crio
systemctl is-active crio
systemctl show crio --property=ActiveState,SubState,MainPID,ExecMainStartTimestamp
```

## crictl Commands

`crictl` is the CRI client tool for interacting with CRI-O directly.

### Pods

```bash
# List all pods
crictl pods

# List pods with filters
crictl pods --state ready
crictl pods --name <pod-name>
crictl pods --namespace <namespace>

# Inspect pod sandbox
crictl inspectp <pod-id>
```

### Containers

```bash
# List all containers
crictl ps -a

# List running containers
crictl ps

# Inspect container
crictl inspect <container-id>

# Container logs
crictl logs <container-id>
crictl logs --tail 100 <container-id>
crictl logs --since "2024-01-15T14:00:00Z" <container-id>

# Container stats
crictl stats
crictl stats <container-id>

# Execute in container
crictl exec -it <container-id> /bin/sh
```

### Images

```bash
# List images
crictl images
crictl images --digests

# Image info
crictl inspecti <image-id-or-name>

# Pull image (for testing)
crictl pull <image-ref>
```

### Runtime Info

```bash
# CRI-O runtime info (version, storage, config)
crictl info

# CRI-O version
crictl version
```

## Common Issues

### Container Startup Failures

Symptoms: pod stuck in `ContainerCreating` or `CrashLoopBackOff`.

```bash
# Find the container
crictl ps -a --name <container-name>

# Inspect for exit code and reason
crictl inspect <container-id> | grep -A 5 '"state"'

# Check container logs
crictl logs <container-id>

# Check CRI-O logs for the container
journalctl -u crio --no-pager | grep <container-id>
```

Common causes:
- Entrypoint/command not found in image
- Missing mount points or volumes
- Security context issues (SELinux, seccomp, capabilities)
- Resource limits too restrictive (OOM on startup)

### Image Pull Errors

```bash
# Check CRI-O pull logs
journalctl -u crio --no-pager | grep -i -E 'pull|image|auth|tls|registry'

# Test pull directly
crictl pull <image-ref>

# Check registries config
cat /etc/containers/registries.conf
cat /etc/containers/registries.conf.d/*.conf

# Check pull secrets
ls /var/lib/kubelet/config.json
cat /var/lib/kubelet/config.json | python3 -m json.tool
```

Common causes:
- Registry unreachable (network/firewall)
- Auth failure (expired or missing pull secret)
- TLS errors (missing CA, expired cert)
- Image not found (wrong tag, deleted)
- Disk space (no room to store image layers)

### Storage Issues

CRI-O uses overlay storage by default on RHCOS.

```bash
# Check container storage usage
df -h /var/lib/containers

# Check overlay mount count
mount | grep overlay | wc -l

# Check for storage corruption
ls -la /var/lib/containers/storage/

# CRI-O storage info
crictl info | python3 -m json.tool | grep -A 10 store

# Clean unused images (careful in production)
crictl rmi --prune
```

Quota issues with overlay:
- XFS project quotas on `/var/lib/containers`
- Check with: `xfs_quota -x -c 'report -h' /var/lib/containers`

### Network Namespace Failures

```bash
# Check network namespace for a pod
crictl inspectp <pod-id> | grep -i netns

# Verify namespace exists
ls -la /var/run/netns/

# Check CNI plugin logs
journalctl -u crio --no-pager | grep -i -E 'cni|network|netns'

# Check CNI config
ls /etc/cni/net.d/
cat /etc/cni/net.d/*.conflist
```

### Runtime (crun) Errors

OpenShift uses `crun` as the OCI runtime (replaced `runc`).

```bash
# Check which runtime CRI-O is using
crictl info | python3 -m json.tool | grep -i runtime

# Check crun version
crun --version

# Look for crun errors in CRI-O logs
journalctl -u crio --no-pager | grep -i -E 'crun|runtime|oci'

# Run crun directly for debugging (advanced)
crun --version
crun list
crun state <container-id>
```

Common crun errors:
- Seccomp profile issues
- Cgroup configuration errors
- Namespace creation failures
- Resource limit enforcement failures

### Conmon / Conmonrs Issues

Conmon (or conmonrs, the Rust rewrite) is the container monitor process. Each container has a conmon process that holds the container's stdio and monitors exit.

```bash
# Check conmon processes
ps aux | grep conmon

# Check if using conmonrs
ls -la /usr/bin/conmon*

# Conmon logs for a specific container
# Conmon logs go to the container log file
ls /var/log/pods/<namespace>_<pod>_<uid>/<container>/

# Check for orphaned conmon processes
ps aux | grep conmon | grep -v grep | wc -l
crictl ps | wc -l  # should roughly match
```

## CRI-O Metrics

CRI-O exposes Prometheus metrics on its metrics endpoint.

```bash
# Check if metrics are enabled
cat /etc/crio/crio.conf | grep -A 5 metrics

# Fetch metrics (default port 9537)
curl -s http://localhost:9537/metrics | head -50

# Key metrics
curl -s http://localhost:9537/metrics | grep -E '^crio_'
```

Key CRI-O metrics:
- `crio_operations_total` -- operation counts by type
- `crio_operations_latency_seconds` -- operation latency
- `crio_image_pulls_successes_total` / `crio_image_pulls_failures_total`
- `crio_containers_oom_total` -- OOM kills
- `crio_containers_oom_count_total` -- cumulative OOM count

## CRI-O Configuration

```bash
# Main config
cat /etc/crio/crio.conf

# Drop-in configs (override main)
ls /etc/crio/crio.conf.d/
cat /etc/crio/crio.conf.d/*.conf

# Effective config (merged)
crio config
```

Key configuration areas:
- `[crio.runtime]` -- runtime path, default runtime, log level
- `[crio.image]` -- pause image, registries
- `[crio.network]` -- CNI plugin paths
- `[crio.metrics]` -- metrics endpoint config
