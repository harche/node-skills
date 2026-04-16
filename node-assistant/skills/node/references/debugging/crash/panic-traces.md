# Panic Trace Analysis

Reading and interpreting panic traces and crash backtraces from node components.

## Go Panic Traces (Kubelet, CRI-O)

Go panics produce a structured stack trace written to stderr, which systemd captures in the journal.

### Finding Panic Traces

```bash
oc debug node/<node>
chroot /host

# Kubelet panics
journalctl -u kubelet --no-pager | grep -B 5 -A 100 'goroutine.*\[running\]' | head -150

# CRI-O panics
journalctl -u crio --no-pager | grep -B 5 -A 100 'goroutine.*\[running\]' | head -150

# Any Go panic in recent logs
journalctl --since "24 hours ago" --no-pager | grep -B 5 -A 100 'goroutine.*\[running\]' | head -150
```

### Go Panic Trace Format

```
goroutine 1 [running]:
runtime/debug.Stack()
	/usr/lib/golang/src/runtime/debug/stack.go:24 +0x5e
main.handler()
	/build/cmd/kubelet/app/server.go:421 +0x1a3
net/http.HandlerFunc.ServeHTTP(...)
	/usr/lib/golang/src/net/http/server.go:2136 +0x29
```

Reading this:
- **goroutine N [state]**: goroutine number and its state when the trace was taken
- **function name**: fully qualified function (package.Function)
- **file:line**: source location
- **+0xNN**: offset from function start (useful for matching to exact instruction)

### Goroutine States

| State | Meaning |
|-------|---------|
| `[running]` | Actively executing (this goroutine caused the panic) |
| `[runnable]` | Ready to run, waiting for a CPU |
| `[sleep]` | Blocked in `time.Sleep` or similar |
| `[chan receive]` | Blocked reading from a channel |
| `[chan send]` | Blocked writing to a channel |
| `[select]` | Blocked in a `select` statement |
| `[IO wait]` | Blocked on I/O (network, file) |
| `[sync.Mutex.Lock]` | Waiting to acquire a mutex |
| `[sync.RWMutex.RLock]` | Waiting for a read lock |
| `[semacquire]` | Waiting on a semaphore (sync.WaitGroup, etc.) |
| `[GC sweep wait]` | Garbage collector |
| `[syscall]` | In a system call |

### Deadlock Detection

Go runtime detects deadlocks and prints "fatal error: all goroutines are asleep - deadlock!"

```bash
journalctl -u kubelet --no-pager | grep -B 5 -A 200 'all goroutines are asleep'
```

Signs of deadlock in traces:
- Multiple goroutines in `[sync.Mutex.Lock]` or `[sync.RWMutex.RLock]`
- Goroutines waiting on channels where no sender/receiver exists
- Circular lock dependencies

### Common Go Panic Types

**nil pointer dereference**:
```
runtime error: invalid memory address or nil pointer dereference
```
The top of the stack shows where the nil access occurred. Check the variable being dereferenced.

**slice bounds out of range**:
```
runtime error: index out of range [5] with length 3
```
An array/slice access with an invalid index.

**concurrent map writes**:
```
fatal error: concurrent map writes
```
Multiple goroutines writing to the same map without synchronization. The trace shows which goroutines are involved.

**send on closed channel**:
```
panic: send on closed channel
```
A goroutine tried to send on a channel that was already closed.

**stack overflow**:
```
runtime: goroutine stack exceeds 1000000000-byte limit
```
Infinite recursion or extremely deep call stacks.

### Goroutine Dump (Without Panic)

To capture all goroutine stacks from a running process (for debugging hangs, not crashes):

```bash
# Send SIGQUIT to a Go process to dump goroutines (and kill it)
kill -QUIT $(pidof kubelet)
# Check journal for the dump
journalctl -u kubelet --no-pager | tail -500

# Or use the debug endpoint (kubelet)
curl -sk https://localhost:10250/debug/pprof/goroutine?debug=2 \
  --header "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
```

## Rust Panic Traces (conmonrs)

Rust panics produce a backtrace if `RUST_BACKTRACE=1` is set. On RHCOS, this may or may not be set by default.

### Finding Rust Panics

```bash
journalctl --no-pager | grep -B 5 -A 50 "thread.*panicked"
journalctl --no-pager | grep -B 5 -A 50 "RUST_BACKTRACE"
```

### Rust Panic Trace Format

```
thread 'main' panicked at 'called `Result::unwrap()` on an `Err` value: Os { code: 2, kind: NotFound, message: "No such file or directory" }', src/main.rs:45:10
stack backtrace:
   0: std::panicking::begin_panic_handler
   1: core::panicking::panic_fmt
   2: core::result::unwrap_failed
   3: conmonrs::container::Container::setup
             at ./src/container.rs:123
   4: conmonrs::main
             at ./src/main.rs:45
```

Reading this:
- **thread 'X' panicked at 'message'**: the panic message and source location
- **stack backtrace**: frames numbered from 0 (newest) upward
- Frames with `at ./src/...` are application code; others are standard library

### Common Rust Panic Patterns

**unwrap() on Err/None**:
```
called `Result::unwrap()` on an `Err` value: ...
called `Option::unwrap()` on a `None` value
```
The program expected a value but got an error/None. Check the source location.

**index out of bounds**:
```
index out of bounds: the len is 3 but the index is 5
```

**assertion failure**:
```
assertion failed: condition
```

### Backtrace Interpretation

If the binary is stripped, you get addresses instead of function names:

```
   3: 0x55a1b2c3d4e5
   4: 0x55a1b2c3d4f6
```

Use `addr2line` with an unstripped binary to resolve these (see `crash/coredump.md`).

## C Crash Traces (crun)

crun is a C program. Crashes typically come from signals (SIGSEGV, SIGABRT).

### Finding crun Crashes

```bash
# In dmesg
dmesg -T | grep crun

# In kernel log
journalctl -k --no-pager | grep crun

# In CRI-O logs (crun is invoked by CRI-O)
journalctl -u crio --no-pager | grep -i -E 'crun.*error|crun.*fail|crun.*signal|exit status'

# Core dumps
coredumpctl list /usr/bin/crun
```

### Signal-Based Crashes

Kernel messages for segfaults look like:

```
crun[12345]: segfault at 0000000000000000 ip 00007f1234567890 sp 00007ffd12345678 error 4 in libc-2.34.so[7f1234500000+1c0000]
```

Reading this:
- `segfault at <addr>` -- the address that was accessed (0 = null pointer)
- `ip <addr>` -- instruction pointer (where in the code)
- `sp <addr>` -- stack pointer
- `error N` -- page fault error code (4 = read from user-space address)
- `in <library>[<base>+<size>]` -- which shared library or binary

### Common crun Crash Patterns

**Null pointer dereference during container setup**:
- crun accesses container config data that is null
- Look at the cgroup path and container ID in CRI-O logs

**Signal in cgroup operations**:
- cgroup v2 migration issues
- Kernel version incompatibilities
- Check `cat /proc/filesystems | grep cgroup` and `stat -fc %T /sys/fs/cgroup`

**Crash during seccomp filter setup**:
- Invalid seccomp profile
- Missing syscall in profile
- Check the pod's security context

## Relating Panics to Code Changes

When a crash starts after an upgrade or code change:

1. **Identify the component version**:
   ```bash
   rpm -qa | grep -E 'kubelet|cri-o|crun|conmon'
   # Or from the binary
   kubelet --version
   crio --version
   crun --version
   ```

2. **Find the source location from the trace**: file and line number from the panic/backtrace.

3. **Check the changelog/commits**: look at what changed between the last working version and the current version at that source location.

4. **Check known issues**:
   - Kubernetes issues: github.com/kubernetes/kubernetes
   - CRI-O issues: github.com/cri-o/cri-o
   - crun issues: github.com/containers/crun
   - conmonrs issues: github.com/containers/conmon-rs

5. **Reproduce**: if possible, reproduce the crash in a test cluster with the same workload.

## Common Patterns Across All Languages

### Crash Only Under Load

- Race condition or concurrency bug
- Memory pressure (OOM adjacent)
- File descriptor exhaustion
- Check system limits: `ulimit -a`, `cat /proc/sys/fs/file-max`

### Crash During Upgrade/Rollback

- Binary/config version mismatch
- On-disk state format change
- Check if MachineConfig was partially applied

### Intermittent Crash

- Race condition (timing-dependent)
- External dependency failure (network, storage)
- Resource exhaustion at peak
- Collect multiple crash traces and compare stack traces for consistency

### Crash Immediately on Start

- Configuration error
- Missing dependency (library, file, socket)
- Certificate expiration
- Check `systemctl status <service>` and `journalctl -u <service> -b` for startup errors
