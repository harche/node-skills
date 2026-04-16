# sosreport Directory Structure

After extracting a sosreport tarball, the contents are organized by subsystem and plugin.

## Top-Level Layout

```
sosreport-<hostname>-<date>/
  date                    # Collection timestamp
  hostname                # Node hostname
  uname                   # Kernel version
  uptime                  # System uptime
  free                    # Memory summary
  df                      # Disk usage
  installed-rpms          # All installed packages
  sos_logs/               # sos collection metadata
    sos.log               # Collection log (errors during collection noted here)
  sos_commands/           # Output of diagnostic commands, by plugin
  proc/                   # /proc filesystem snapshot
  etc/                    # /etc filesystem snapshot
  var/log/                # Log files
  run/                    # /run filesystem snapshot
  sys/                    # /sys filesystem snapshot (partial)
```

## Key Directories for Node Team

### Container Runtime Data

```
sos_commands/crio/
  crictl_images                      # Images on node
  crictl_info                        # CRI-O runtime info
  crictl_pods                        # Pod sandboxes
  crictl_ps_-a                       # All containers (running + stopped)
  crictl_stats                       # Container resource usage
  crictl_version                     # CRI-O version
  journalctl_--no-pager_--unit_crio  # CRI-O journal logs

sos_commands/podman/                 # If podman is available
  podman_info
  podman_images
  podman_ps_--all_--external

etc/crio/
  crio.conf                          # CRI-O main config
  crio.conf.d/                       # Drop-in configs

etc/containers/
  registries.conf                    # Registry configuration
  storage.conf                       # Container storage config
  policy.json                        # Image signature policy
```

### Kernel and System Data

```
sos_commands/kernel/
  dmesg                              # Kernel ring buffer
  dmesg_--facility_kern              # Kernel-only messages
  lsmod                              # Loaded kernel modules
  sysctl_-a                          # All kernel parameters
  uname_-a                           # Kernel version

proc/
  meminfo                            # Detailed memory info
  cpuinfo                            # CPU info
  cmdline                            # Kernel boot parameters
  vmstat                             # Virtual memory stats
  slabinfo                           # Slab allocator stats
  buddyinfo                          # Memory fragmentation
  interrupts                         # Interrupt counters
  mounts                             # Mounted filesystems
  cgroups                            # Cgroup controllers

sos_commands/systemd/
  systemctl_list-units_--all         # All systemd units
  systemctl_list-units_--failed_--all  # Failed units
  systemd-analyze_blame              # Boot timing
  systemd-analyze_critical-chain     # Boot critical path
  journalctl_--no-pager_--boot       # Full boot journal

var/log/
  messages                           # System log (syslog)
  audit/audit.log                    # SELinux/audit log
```

### Network Data

```
sos_commands/networking/
  ip_addr                            # All IP addresses
  ip_route                           # Routing table
  ip_link                            # Link status
  ip_neigh                           # ARP/neighbor table
  ip_-s_link                         # Interface statistics
  ss_-tlnp                           # TCP listening sockets
  ss_-ulnp                           # UDP listening sockets
  ss_-s                              # Socket statistics summary
  iptables_-t_nat_-nvL               # NAT rules
  iptables_-nvL                      # Filter rules
  nmcli_connection_show              # NetworkManager connections
  nmcli_device_status                # NM device status
  ethtool_<interface>                # Per-interface details

sos_commands/ovn_central/            # If OVN is present
  ovs-vsctl_show
  ovn-sbctl_show
  ovn-nbctl_show

etc/NetworkManager/                  # NM configuration
etc/sysconfig/network-scripts/       # Legacy network config
etc/resolv.conf                      # DNS configuration
```

### Storage Data

```
sos_commands/block/
  lsblk                              # Block device list
  lsblk_-f                           # Filesystems on block devices
  blkid                              # Block device attributes

sos_commands/filesys/
  df_-h                              # Human-readable disk usage
  df_-i                              # Inode usage
  mount                              # Current mounts
  findmnt                            # Mount tree

sos_commands/devicemapper/           # DM/LVM info
  dmsetup_table
  dmsetup_status
  lvs
  vgs
  pvs

sos_commands/multipath/              # If multipath is configured
  multipath_-ll
```

### Kubelet Data

```
sos_commands/kubernetes/
  journalctl_--no-pager_--unit_kubelet  # Kubelet logs

etc/kubernetes/
  kubelet.conf                       # Kubelet config (if present)
  manifests/                         # Static pod manifests

var/lib/kubelet/
  config.json                        # Image pull secrets
  kubeadm-flags.env                  # Kubelet flags (kubeadm clusters)
```

### Security

```
sos_commands/selinux/
  sestatus                           # SELinux status
  semanage_boolean_-l                # SELinux booleans
  ausearch_-m_avc_-ts_recent         # Recent AVC denials

var/log/audit/
  audit.log                          # Full audit log
```

## Quick Navigation Commands

```bash
# Find all files mentioning a keyword
grep -rl "keyword" .

# Check OOM kills
grep -i "oom" sos_commands/kernel/dmesg
grep -i "out of memory" var/log/messages

# Check for failed services
cat sos_commands/systemd/systemctl_list-units_--failed_--all

# Check container state
cat sos_commands/crio/crictl_ps_-a

# Check disk pressure
cat sos_commands/filesys/df_-h

# Check memory pressure
cat proc/meminfo | grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree'

# Check network errors
cat sos_commands/networking/ip_-s_link | grep -i -E 'error|drop'
```
