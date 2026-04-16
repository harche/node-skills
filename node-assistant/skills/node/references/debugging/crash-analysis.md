# Crash Dump Analysis

Analyzing crashes from node components: kubelet (Go), CRI-O (Go), crun (C), and conmonrs (Rust).

## Sub-references

- `crash/coredump.md` -- core dump collection and analysis with coredumpctl and gdb
- `crash/panic-traces.md` -- reading Go/Rust/C panic and crash traces

## When to Use

- Kubelet or CRI-O crashes (segfaults, panics, deadlocks)
- crun crashes during container operations
- conmonrs crashes (container monitor)
- Any node component process that terminates unexpectedly

## Where to Find Crash Data on RHCOS

```bash
oc debug node/<node>
chroot /host

# systemd-coredump stores core dumps
coredumpctl list

# Journal entries around crash time
journalctl -u kubelet -p err --since "1 hour ago"
journalctl -u crio -p err --since "1 hour ago"

# Check if core dumps are enabled
cat /proc/sys/kernel/core_pattern
# On RHCOS, typically: |/usr/lib/systemd/systemd-coredump %P %u %g %s %t %c %h
```

## Crash Types by Component

| Component | Language | Crash Type | Where to Look |
|-----------|----------|-----------|---------------|
| kubelet | Go | panic, deadlock | journalctl -u kubelet (panic trace in logs) |
| CRI-O | Go | panic, deadlock | journalctl -u crio |
| crun | C | segfault, signal | coredumpctl, dmesg |
| conmonrs | Rust | panic, segfault | coredumpctl, journalctl |

## Quick Investigation Flow

1. **Identify the crash**:
   ```bash
   # Check if any core dumps exist
   coredumpctl list --since "24 hours ago"

   # Check service status
   systemctl status kubelet crio

   # Check journal for crash entries
   journalctl -p emerg..err --since "24 hours ago" | grep -i -E 'panic|segfault|signal|abort|fatal'
   ```

2. **Get crash details**:
   ```bash
   # For a core dump
   coredumpctl info <PID-or-match>

   # For a Go panic (in logs)
   journalctl -u <service> --no-pager | grep -A 100 'goroutine.*\[running\]' | head -120
   ```

3. **Determine root cause**: see `crash/coredump.md` for core analysis or `crash/panic-traces.md` for trace interpretation.

4. **Correlate with changes**: check if the crash started after a cluster upgrade, MachineConfig change, or workload change.

## Preserving Crash Data

Core dumps can be large and may be rotated. Preserve before they are lost:

```bash
# List available dumps
coredumpctl list

# Export a core dump
coredumpctl dump <PID> -o /var/tmp/core-<component>-<date>.dump

# Copy off the node
# (from outside, using oc)
oc debug node/<node> -- cat /host/var/tmp/core-*.dump > core.dump
```

## Reporting Crashes

When filing a bug or support case for a crash:
1. Include the full panic trace or core dump info
2. Include the component version (`kubelet --version`, `crio --version`, `crun --version`)
3. Include the RHCOS version (`cat /etc/os-release`)
4. Include the cluster version (`oc get clusterversion`)
5. Note when the crash started (first occurrence in logs)
6. Note frequency (one-time, intermittent, every time)
7. Note what workload/operation triggers it (if known)
