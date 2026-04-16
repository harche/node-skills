# Running a Custom Kubelet on OpenShift

## Option 1: Deploy to a Test Cluster Node

The most common workflow is replacing the kubelet binary on a running RHCOS node.

### Steps

1. Build the kubelet for linux/amd64:

```bash
cd ~/go/src/github.com/openshift/kubernetes
GOOS=linux GOARCH=amd64 make WHAT=cmd/kubelet
```

2. Copy to the target node:

```bash
NODE=<node-name>
oc debug node/${NODE} -- chroot /host crictl info  # verify access

scp _output/bin/linux/amd64/kubelet core@${NODE}:/tmp/kubelet
```

3. SSH to the node and replace the binary:

```bash
ssh core@${NODE}
sudo cp /tmp/kubelet /usr/bin/kubelet
sudo systemctl restart kubelet
```

4. Verify the kubelet is running with your build:

```bash
sudo /usr/bin/kubelet --version
sudo systemctl status kubelet
journalctl -u kubelet -f
```

For a more automated approach, see the `deployment/debug-binary.md` reference for using the debug binary deployment skill.

### Rollback

To restore the original kubelet, reprovision the node or let MCO reconcile:

```bash
# Force MCO to re-render the node
oc debug node/${NODE} -- chroot /host rpm-ostree rollback
# or simply delete the node and let the MachineSet recreate it
```

## Option 2: Running Kubelet Locally (Development)

Running the kubelet locally against a remote API server is possible but limited (no CRI-O, no cgroups v2 setup, no RHCOS filesystem). Useful for testing kubelet startup logic.

```bash
./kubelet \
  --kubeconfig=/path/to/kubeconfig \
  --config=/path/to/kubelet-config.yaml \
  --container-runtime-endpoint=unix:///var/run/crio/crio.sock \
  --node-ip=<node-ip> \
  --v=4
```

This requires a valid kubeconfig with kubelet bootstrap credentials.

## Key Kubelet Flags

| Flag | Description |
|------|-------------|
| `--config` | Path to KubeletConfiguration YAML file |
| `--kubeconfig` | Path to kubeconfig for API server auth |
| `--container-runtime-endpoint` | CRI socket path (default: `unix:///var/run/crio/crio.sock` on OCP) |
| `--node-ip` | Override auto-detected node IP |
| `--hostname-override` | Override hostname |
| `--v` | Log verbosity (0-10; 4 is common for debugging) |
| `--feature-gates` | Enable/disable feature gates (comma-separated key=bool) |
| `--cgroup-driver` | `systemd` (default on OCP) or `cgroupfs` |
| `--pod-infra-container-image` | Pause container image |
| `--root-dir` | Kubelet root directory (default `/var/lib/kubelet`) |

## KubeletConfiguration File

On OCP, the kubelet config is managed by the MCO and rendered at `/etc/kubernetes/kubelet.conf` on the node. To inspect:

```bash
oc debug node/${NODE} -- chroot /host cat /etc/kubernetes/kubelet.conf
```

Key fields in the KubeletConfiguration:

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
featureGates:
  FeatureGateName: true
maxPods: 250
podPidsLimit: 4096
systemReserved:
  cpu: 500m
  memory: 1Gi
kubeReserved:
  cpu: 500m
  memory: 1Gi
evictionHard:
  memory.available: 100Mi
  nodefs.available: 10%
  imagefs.available: 15%
```

## Feature Gates Relevant to Node Team

Common feature gates the node team works with (check release notes for current status):

| Feature Gate | Stage | Description |
|-------------|-------|-------------|
| `UserNamespacesSupport` | Beta | User namespace support for pods |
| `ProcMountType` | Beta | Custom /proc mount types |
| `InPlacePodVerticalScaling` | Alpha | Resize pod resources without restart |
| `SidecarContainers` | GA (1.29+) | Native init container restart policy |
| `KubeletCgroupDriverFromCRI` | Beta | Get cgroup driver from CRI |
| `MemoryQoS` | Alpha | Memory QoS with cgroup v2 |
| `CPUManagerPolicyAlphaOptions` | Alpha | Additional CPU manager policies |
| `TopologyManagerPolicyAlphaOptions` | Alpha | Additional topology manager policies |
| `DynamicResourceAllocation` | Alpha/Beta | DRA for device plugins |
| `SELinuxMount` | Beta | SELinux relabeling for volumes |
| `RecursiveReadOnlyMounts` | Alpha | Recursive read-only bind mounts |
| `SwapBehavior` | Beta | Swap support for nodes |

Enable a feature gate on a node via KubeletConfig CR:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: custom-feature-gates
spec:
  machineConfigPoolSelector:
    matchLabels:
      pools.operator.machineconfiguration.openshift.io/worker: ""
  kubeletConfig:
    featureGates:
      UserNamespacesSupport: true
```

## Debugging the Kubelet

```bash
# View kubelet logs on a node
oc debug node/${NODE} -- chroot /host journalctl -u kubelet --no-pager -n 200

# Increase verbosity temporarily
# Edit /etc/kubernetes/kubelet-workaround (if present) or use systemd override
ssh core@${NODE}
sudo mkdir -p /etc/systemd/system/kubelet.service.d
sudo tee /etc/systemd/system/kubelet.service.d/10-verbose.conf <<EOF
[Service]
Environment="KUBELET_LOG_LEVEL=4"
EOF
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Check kubelet health
curl -sk https://localhost:10250/healthz
```
