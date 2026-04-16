# OpenShift on GCP

Create and manage OpenShift Container Platform clusters on Google Cloud using the `ocp-install.sh` script.

## Script Location

```bash
./scripts/ocp-install.sh <command>
```

## Commands

### Download Installer

```bash
./scripts/ocp-install.sh download <version>
```

Downloads `openshift-install` from CI release artifacts. Binary is saved to `~/clusters/<major.minor>/<version>/openshift-install`.

### Create a Cluster

```bash
./scripts/ocp-install.sh create <version> <type> [cluster-name]
```

If cluster-name is omitted, one is auto-generated as `$USER<type-prefix><random>`.

The script:
1. Reads pull secret from the OS secret store (`OCP_PULL_SECRET`) -- macOS Keychain or Linux secret-tool
2. Generates `install-config.yaml` from built-in templates
3. Shows a summary and asks for confirmation
4. Runs `openshift-install create cluster`
5. Prints the KUBECONFIG path on success

### List Clusters

```bash
./scripts/ocp-install.sh list [version]
```

Shows all clusters with version, status (ACTIVE/DESTROYED/CONFIG/EMPTY), and path.

### Get Kubeconfig

```bash
eval $(./scripts/ocp-install.sh kubeconfig <version> <cluster-dir>)
```

### Destroy a Cluster

```bash
./scripts/ocp-install.sh destroy <version> <cluster-dir>
```

Asks for confirmation before destroying.

### Debug a Failed Installation

```bash
./scripts/ocp-install.sh debug <version> <cluster-dir>
```

Runs a full diagnostic:
1. **Local log analysis** -- parses `.openshift_install.log` for errors, fatals, and failure patterns (bootstrap failure, timeouts, quota issues, SSH auth, resource conflicts)
2. **Log bundle inventory** -- lists available `log-bundle-*.tar.gz` files with extract instructions
3. **GCP diagnostics** (requires `gcloud`) -- compute instances, serial console output, Cloud Logging errors, firewall rules, orphaned disks

## Cluster Types

### regular -- 3 control-plane + 3 workers

Standard GCP instances. The default for most testing. Uses `us-central1` region.

```bash
./scripts/ocp-install.sh create 4.18.6 regular
```

### sno -- Single Node OpenShift with GPU

Single control-plane node with GPU (a2-highgpu-2g). Zone: `us-central1-f`. Zero workers -- the single node runs both control plane and workloads.

```bash
./scripts/ocp-install.sh create 4.18.6 sno
```

### gpu -- 3 control-plane + 3 GPU workers

Standard control plane with GPU workers (a2-highgpu-1g). Zone: `us-central1-f` for workers.

```bash
./scripts/ocp-install.sh create 4.18.6 gpu
```

### sno-cpu -- Single Node OpenShift, CPU only

Single node with `cpuPartitioningMode: AllNodes`. No GPU. For testing CPU partitioning features.

```bash
./scripts/ocp-install.sh create 4.18.6 sno-cpu
```

## Workflow Example

```bash
# 1. Download the installer
./scripts/ocp-install.sh download 4.18.6

# 2. Create a regular cluster
./scripts/ocp-install.sh create 4.18.6 regular

# 3. List clusters to find the cluster directory
./scripts/ocp-install.sh list

# 4. Set kubeconfig
eval $(./scripts/ocp-install.sh kubeconfig 4.18.6 cluster1)

# 5. Verify
oc get nodes
oc get co

# 6. Destroy when done
./scripts/ocp-install.sh destroy 4.18.6 cluster1
```

## Environment

| Setting | Value |
|---------|-------|
| GCP Project | `openshift-gce-devel` |
| Region | `us-central1` |
| GPU Zone | `us-central1-f` |
| Base Domain | `gcp.devcluster.openshift.com` |
| Data Directory | `~/clusters/<major.minor>/<version>/cluster<N>/` |
| Pull Secret | OS secret store (`OCP_PULL_SECRET`), falls back to `~/clusters/pull-secret-gcp.txt` |
| SSH Key | `~/.ssh/id_rsa.pub` |

### Pull Secret Setup (One-Time)

macOS (Keychain):

```bash
security add-generic-password -a "$USER" -s "OCP_PULL_SECRET" \
  -w "$(cat pull-secret.json | python3 -c \
  "import sys,json; print(json.dumps(json.load(sys.stdin), separators=(',',':')))")"
```

Linux (secret-tool):

```bash
cat pull-secret.json | python3 -c \
  "import sys,json; print(json.dumps(json.load(sys.stdin), separators=(',',':')))" | \
  secret-tool store --label="OCP Pull Secret" service ocp-install username "$USER" key OCP_PULL_SECRET
```

## Debugging Install Failures

```bash
./scripts/ocp-install.sh debug 4.18.6 cluster1
```

Common failure patterns:

| Pattern | Meaning | Fix |
|---------|---------|-----|
| Bootstrap failed to complete | Bootstrap host could not create temp control plane | Check serial console, SSH key, ignition |
| context deadline exceeded | Cluster API connection timed out | Check firewall rules, DNS |
| quota | GCP quota exceeded | Request quota increase or use fewer/smaller instances |
| resourceInUseByAnotherResource | Stale GCP resources from prior install | Destroy old cluster first, or manually clean up resources |
| unable to authenticate | SSH key mismatch | Verify `~/.ssh/id_rsa.pub` matches what was baked into the cluster |

## Cost

- **regular**: 6 VMs (3 master + 3 worker), moderate cost
- **sno**: 1 VM with GPU (a2-highgpu-2g), expensive
- **gpu**: 6 VMs (3 standard + 3 GPU), most expensive
- **sno-cpu**: 1 VM, cheapest option

GPU instances (a2-highgpu) cost hundreds of dollars per day. Always destroy when done. Set a reminder if you step away.

Cluster creation takes 30-45 minutes. The `install-config.yaml` is consumed during install; a `.backup` copy is saved.
