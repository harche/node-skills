# MCO Architecture Reference

## Component Overview

```
┌─────────────────────────────────────────────┐
│         machine-config-operator             │
│  (manages lifecycle of other components)    │
└──────┬──────────────────┬───────────────────┘
       │                  │
       ▼                  ▼
┌──────────────┐   ┌──────────────────┐
│  machine-    │   │  machine-config- │
│  config-     │   │  server (MCS)    │
│  controller  │   │                  │
│  (MCC)       │   │  Serves Ignition │
│              │   │  to bootstrapping│
│  Renders MC, │   │  nodes           │
│  manages MCP │   └──────────────────┘
└──────┬───────┘
       │ renders
       ▼
┌──────────────────────────────────┐
│  MachineConfigPool (MCP)         │
│  ├─ rendered-master-xxxxx        │
│  └─ rendered-worker-xxxxx        │
└──────┬───────────────────────────┘
       │ applied by
       ▼
┌──────────────────────────────────┐
│  machine-config-daemon (MCD)     │
│  (DaemonSet on every node)       │
│                                  │
│  Applies configs, manages OS     │
│  updates, triggers reboots       │
└──────────────────────────────────┘
```

## Machine Config Controller (MCC)

The MCC watches MachineConfig and MachineConfigPool resources and performs rendering.

### Rendering Pipeline

1. **Collect**: Gathers all MachineConfig objects whose labels match a MachineConfigPool's `machineConfigSelector`.
2. **Sort**: Orders MachineConfigs by name (lexicographic). This is why naming conventions matter (e.g., `00-worker`, `01-worker-custom`).
3. **Merge**: Merges all configs into a single rendered MachineConfig:
   - Files: later configs override earlier ones (by path)
   - Systemd units: merged by unit name, later configs win
   - Kernel arguments: accumulated (union)
   - Extensions: accumulated (union)
   - FIPS: any config enabling FIPS wins
4. **Output**: Creates a `rendered-<pool>-<hash>` MachineConfig.

### Key Controllers in MCC

| Controller | Watches | Creates/Updates |
|-----------|---------|-----------------|
| `render` | MachineConfig, MachineConfigPool | rendered-* MachineConfigs |
| `kubelet-config` | KubeletConfig | MachineConfig with kubelet.conf |
| `container-runtime-config` | ContainerRuntimeConfig | MachineConfig with crio.conf |
| `node` | Node | Updates MCP status based on node state |

## Machine Config Daemon (MCD)

The MCD runs as a DaemonSet on every node. It is responsible for:

1. **Comparing** the current node config (`currentConfig` annotation) against the desired config (`desiredConfig` annotation on the node).
2. **Applying** the desired config if it differs from current.
3. **Draining** the node before applying changes (via the Kubernetes drain API).
4. **Rebooting** the node after applying changes (when necessary).

### MCD Update Flow

```
1. MCC sets desiredConfig annotation on node
2. MCD detects desiredConfig != currentConfig
3. MCD sets node as SchedulingDisabled (cordon)
4. MCD drains the node
5. MCD applies the new config:
   a. Writes files to disk
   b. Enables/disables systemd units
   c. Updates kernel arguments (rpm-ostree kargs)
   d. Updates OS extensions (rpm-ostree install/uninstall)
   e. Updates OS image (if layered/image-based)
6. MCD reboots the node (if required)
7. After reboot, MCD sets currentConfig = desiredConfig
8. MCD uncordons the node
```

### When Reboot Is Required

The MCD triggers a reboot when:
- Files in `/etc` or `/usr` are changed
- Systemd units are added/removed/modified
- Kernel arguments change
- OS extensions change
- The OS image changes

The MCD does NOT reboot when:
- Only SSH keys are updated
- Only node annotations change

## MachineConfigPool Update Flow

When a new rendered config is created:

```
1. MCP status changes to "Updating"
2. MCC sets maxUnavailable (default 1) nodes' desiredConfig
3. Each MCD applies the config and reboots
4. As nodes complete, MCC advances the next batch
5. When all nodes in the pool are updated, MCP status = "Updated"
```

### MCP Status Conditions

| Condition | Meaning |
|-----------|---------|
| `Updated` | All nodes in pool match the rendered config |
| `Updating` | Rollout in progress |
| `Degraded` | One or more nodes failed to apply config |
| `RenderDegraded` | Failed to render a new MachineConfig |
| `NodeDegraded` | Specific node failed |

## Ignition Configs

MachineConfigs use a subset of the Ignition v3.x specification:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-worker-custom
  labels:
    machineconfiguration.openshift.io/role: worker
spec:
  config:
    ignition:
      version: 3.4.0
    storage:
      files:
        - path: /etc/my-config
          mode: 0644
          contents:
            source: data:text/plain;charset=utf-8;base64,<base64-content>
    systemd:
      units:
        - name: my-service.service
          enabled: true
          contents: |
            [Unit]
            Description=My Custom Service
            [Service]
            ExecStart=/usr/bin/my-binary
            [Install]
            WantedBy=multi-user.target
  kernelArguments:
    - nosmt
  extensions:
    - usbguard
```

### Machine Config Server (MCS)

The MCS serves Ignition configs over HTTPS to nodes during bootstrap. It listens on port 22623 and serves configs based on the requesting node's role (determined by client certificate).

## OS Updates and Layering

### Traditional Mode (rpm-ostree)

In the traditional model, nodes run a base RHCOS image managed by rpm-ostree:

- `rpm-ostree status` shows the current deployment
- OS updates are applied by the MCD via `rpm-ostree upgrade`
- Extensions are installed via `rpm-ostree install`
- Kernel arguments are managed via `rpm-ostree kargs`

### On-Cluster Layering (OCP 4.13+)

On-cluster layering allows building custom OS images:

1. Users create a `MachineOSConfig` specifying a base image and custom content (Containerfile).
2. The MCO builds a new OS image on-cluster using the `MachineOSBuild` process.
3. The resulting image is pushed to the internal or external registry.
4. The MCD pulls and applies the new layered image via `rpm-ostree rebase`.

Key resources:
- `MachineOSConfig` -- defines the custom layering configuration
- `MachineOSBuild` -- represents a build of a custom OS image

### Image-Based Updates

With image-based updates, the node OS is defined entirely by a container image reference. The MCD uses `rpm-ostree rebase` or `bootc switch` to apply the new image.

## Configuration Drift Detection

The MCD periodically checks for configuration drift:
- Compares files on disk to the rendered MachineConfig
- Reports drift via node annotations and MCP conditions
- Can force-reapply on drift (depends on configuration)
