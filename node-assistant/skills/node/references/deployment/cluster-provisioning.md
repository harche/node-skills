# Test Cluster Provisioning

Provision Kubernetes and OpenShift clusters for development and testing. Three options are available, each suited to different needs.

## Cluster Types

| Type | Tool | Where | Time | Cost | Use Case |
|------|------|-------|------|------|----------|
| **kind** | `kind` | Local (Docker) | Seconds | Free | Unit tests, quick API experiments, CI |
| **GKE** | `gcloud` | Google Cloud | 5-10 min | $$  | Upstream Kubernetes on real infrastructure |
| **OpenShift** | `ocp-install.sh` | Google Cloud | 30-45 min | $$$  | Full OCP with operators, MCO, RHCOS nodes |

## When to Use Which

### kind -- Fast local cluster

Use when you need a Kubernetes API to test against and do not need real nodes, RHCOS, systemd, or CRI-O. kind uses containerd, not CRI-O, and nodes are Docker containers, not VMs. There is no systemd or real OS.

Good for: controller development, operator logic tests, webhook testing, quick experiments.

Not for: anything that requires RHCOS, CRI-O, real node behavior, GPU, or MCO.

### GKE -- Managed upstream Kubernetes

Use when you need real infrastructure with upstream Kubernetes. Nodes are real VMs with a real OS, but it is not OpenShift and does not have CRI-O (uses containerd).

Good for: testing against real node behavior, testing things that need real kubelet, testing across Kubernetes versions.

Not for: anything OpenShift-specific (operators, MachineConfig, routes, RHCOS).

### OpenShift on GCP -- Full OCP

Use when you need the full OpenShift stack with RHCOS nodes, CRI-O, MCO, operators, and the complete platform. This is what you need for Node team work most of the time.

Good for: CRI-O testing, MCO testing, debug binary deployment, layered images, GPU workloads, feature validation.

Caveat: takes 30-45 min to create and costs real money. GPU clusters are expensive. Always destroy when done.

## Sub-References

- **kind**: [cluster-provisioning/kind.md](cluster-provisioning/kind.md) -- Multi-node configs, ingress, local registry, port mappings
- **GKE**: [cluster-provisioning/gke.md](cluster-provisioning/gke.md) -- Machine types, node pools, GPU nodes, autoscaling
- **OpenShift**: [cluster-provisioning/openshift.md](cluster-provisioning/openshift.md) -- Cluster types (regular, SNO, GPU, SNO-CPU), install/destroy lifecycle, debugging failures

## Quick Start

### kind

```bash
kind create cluster --name dev
kubectl cluster-info --context kind-dev
# done in seconds

kind delete cluster --name dev
```

### GKE

```bash
gcloud container clusters create my-cluster \
  --project=openshift-gce-devel \
  --region=us-central1 \
  --num-nodes=3

gcloud container clusters get-credentials my-cluster \
  --project=openshift-gce-devel \
  --region=us-central1

# when done
gcloud container clusters delete my-cluster \
  --project=openshift-gce-devel \
  --region=us-central1
```

### OpenShift

```bash
# Download installer
./scripts/ocp-install.sh download 4.18.6

# Create cluster
./scripts/ocp-install.sh create 4.18.6 regular

# Set kubeconfig
eval $(./scripts/ocp-install.sh kubeconfig 4.18.6 cluster1)

# Verify
oc get nodes
oc get co

# When done -- ALWAYS destroy to avoid cost
./scripts/ocp-install.sh destroy 4.18.6 cluster1
```

## Cost Awareness

- **kind**: Free. Local Docker containers.
- **GKE**: Cloud cost. Standard instances are moderate. GPU instances (A100) are expensive.
- **OpenShift on GCP**: Cloud cost. `regular` is moderate (6 VMs). `gpu` and `sno` use A100 GPU instances and are expensive. Always destroy when done.

GPU instances in particular can cost hundreds of dollars per day. Set a reminder to destroy the cluster if you step away.
