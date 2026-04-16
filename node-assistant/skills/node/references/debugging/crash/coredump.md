# Core Dump Analysis

Working with core dumps from node component crashes on RHCOS using `coredumpctl` and `gdb`.

## coredumpctl Basics

RHCOS uses `systemd-coredump` to capture and store core dumps. The `coredumpctl` command manages them.

### Listing Core Dumps

```bash
oc debug node/<node>
chroot /host

# List all core dumps
coredumpctl list

# List recent dumps (last 24h)
coredumpctl list --since "24 hours ago"

# Filter by executable
coredumpctl list /usr/bin/kubelet
coredumpctl list /usr/bin/crio
coredumpctl list /usr/bin/crun
coredumpctl list /usr/bin/conmonrs

# Filter by PID
coredumpctl list <PID>
```

Output columns: `TIME`, `PID`, `UID`, `GID`, `SIG`, `COREFILE`, `EXE`.

Key signals:
- `SIGSEGV (11)` -- segmentation fault (memory access violation)
- `SIGABRT (6)` -- abort (Go panic, assertion failure)
- `SIGBUS (7)` -- bus error (misaligned access)
- `SIGFPE (8)` -- floating point exception
- `SIGKILL (9)` -- killed (OOM killer)

### Core Dump Info

```bash
# Detailed info about the most recent dump
coredumpctl info

# Info for a specific PID
coredumpctl info <PID>

# Info for a specific executable
coredumpctl info /usr/bin/crun
```

This shows:
- Signal that caused the crash
- Executable path and arguments
- Hostname, timestamp
- Cgroup (which container/pod, if applicable)
- Stack trace (if symbolized)
- Core dump storage path

### Exporting Core Dumps

```bash
# Export to a file
coredumpctl dump <PID> -o /var/tmp/core.<component>.<PID>

# Export the most recent dump for an executable
coredumpctl dump /usr/bin/crun -o /var/tmp/core.crun

# Check the size before exporting
coredumpctl info <PID> | grep 'Disk Size'
```

## Interactive Debugging with gdb

```bash
# Open gdb with the core dump
coredumpctl gdb <PID>

# Or load manually
gdb /usr/bin/<component> /var/tmp/core.<PID>
```

### Essential gdb Commands

```
# Stack trace of the crashing thread
bt

# Full stack trace with arguments
bt full

# Stack trace of all threads
thread apply all bt

# Switch to a specific thread
thread <N>

# Examine a specific frame
frame <N>

# Print a variable
print <variable>

# Show registers
info registers

# Show signal info
info signal

# Show memory mappings
info proc mappings

# Quit
quit
```

### Quick gdb Session for a Crash

```bash
coredumpctl gdb <PID> --batch -ex 'thread apply all bt' -ex 'quit'
```

This prints all thread backtraces without entering interactive mode.

## Go Stack Traces from Core Dumps

Kubelet and CRI-O are Go programs. Go panics print a stack trace to stderr (captured in journalctl), but core dumps can also be analyzed.

### Extracting Go Stack Traces

For Go programs, the stack trace is often more useful from the journal than from gdb:

```bash
# Go panic traces appear in the service journal
journalctl -u kubelet --no-pager | grep -A 100 'goroutine.*\[running\]'
journalctl -u crio --no-pager | grep -A 100 'goroutine.*\[running\]'
```

If you only have the core dump (no journal):

```bash
# Use Delve (Go debugger) if available
dlv core /usr/bin/kubelet /var/tmp/core.kubelet

# Inside Delve
goroutines     # List all goroutines
goroutine <N>  # Switch to goroutine N
bt             # Stack trace of current goroutine
```

### Using gdb with Go Binaries

gdb can work with Go core dumps but may need Go runtime support:

```bash
# Load Go runtime support in gdb
(gdb) source /usr/share/go/src/runtime/runtime-gdb.py

# List goroutines
(gdb) info goroutines

# Switch to a goroutine
(gdb) goroutine <N> bt
```

Note: OpenShift binaries are typically stripped. See "Symbolizing Stripped Binaries" below.

## Rust Stack Traces (conmonrs)

conmonrs is written in Rust. Core dumps from Rust programs can be analyzed with gdb.

```bash
coredumpctl gdb /usr/bin/conmonrs

# In gdb
bt
thread apply all bt
```

Rust backtraces may include demangled symbols if debug info is available. If the binary is stripped:

```bash
# Check if symbols are present
file /usr/bin/conmonrs
# "stripped" = no debug symbols

# Get a backtrace anyway (addresses will be shown)
coredumpctl gdb /usr/bin/conmonrs --batch -ex 'bt' -ex 'quit'
```

The `RUST_BACKTRACE=1` environment variable only affects runtime panics, not core dump analysis.

## C Crash Traces (crun)

crun is a C program. Core dumps are straightforward with gdb:

```bash
coredumpctl gdb /usr/bin/crun

# Stack trace
(gdb) bt
(gdb) bt full

# Check signal
(gdb) info signal

# If it was a SIGSEGV, check what memory was accessed
(gdb) print $_siginfo._sifields._sigfault.si_addr
```

Common crun crash patterns:
- NULL pointer dereference in container setup
- Stack buffer overflow in argument parsing
- Use-after-free in cgroup operations

## Symbolizing Stripped Binaries

OpenShift ships stripped binaries (no debug symbols). To get useful backtraces:

### Method 1: debuginfo packages

```bash
# On RHCOS, install debuginfo (if available)
rpm -qa | grep <component>
# Then find the matching debuginfo RPM

# debuginfo is installed to /usr/lib/debug/
# gdb will pick it up automatically
```

### Method 2: Build with Debug Symbols

Build the component from source with debug symbols:

```bash
# For Go programs
go build -gcflags="all=-N -l" -o kubelet ./cmd/kubelet

# For C programs (crun)
meson setup builddir -Dbuildtype=debug
ninja -C builddir

# For Rust programs (conmonrs)
cargo build  # debug build includes symbols by default
```

### Method 3: addr2line

If you have the unstripped binary or separate debug symbols:

```bash
# Convert addresses from backtrace to source locations
addr2line -e /path/to/unstripped/binary 0x<address>

# For multiple addresses
addr2line -e /path/to/unstripped/binary -f 0x<addr1> 0x<addr2> 0x<addr3>
```

## Sending Core Dumps to Engineering

For support cases and bug reports:

```bash
# Export the core dump
coredumpctl dump <PID> -o /var/tmp/core.<component>.<PID>

# Compress it (core dumps can be large)
xz -9 /var/tmp/core.<component>.<PID>

# Include metadata
coredumpctl info <PID> > /var/tmp/core.<component>.<PID>.info

# Include component version
<component> --version > /var/tmp/core.<component>.version 2>&1

# Include OS version
cat /etc/os-release > /var/tmp/os-release.txt
```

Attach all files to the Jira ticket or support case. Include the RPM version:

```bash
rpm -qa | grep -E 'kubelet|cri-o|crun|conmon'
```

## Core Dump Configuration

### Check Current Settings

```bash
# Core pattern (how cores are captured)
cat /proc/sys/kernel/core_pattern

# Storage location for systemd-coredump
cat /etc/systemd/coredump.conf

# Storage usage
coredumpctl list | wc -l
du -sh /var/lib/systemd/coredump/
```

### Adjusting Storage Limits

If core dumps are being rotated too quickly:

```bash
# Check current limits
cat /etc/systemd/coredump.conf
# ProcessSizeMax, ExternalSizeMax, MaxUse, KeepFree
```

Note: On RHCOS, modify via MachineConfig, not directly, as changes will not persist across reboots.
