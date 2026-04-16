# GKE (Google Kubernetes Engine)

Create and manage production-grade upstream Kubernetes clusters on Google Cloud.

## Prerequisites

- `gcloud` CLI installed and authenticated: `gcloud auth login`
- Project access to `openshift-gce-devel`
- `kubectl` installed

## Default Environment

```
Project:  openshift-gce-devel
Region:   us-central1
```

## Create a Cluster

```bash
gcloud container clusters create my-cluster \
  --project=openshift-gce-devel \
  --region=us-central1 \
  --num-nodes=3
```

## Get Credentials

```bash
gcloud container clusters get-credentials my-cluster \
  --project=openshift-gce-devel \
  --region=us-central1
```

This configures `kubectl` to point at the cluster.

## List Clusters

```bash
gcloud container clusters list --project=openshift-gce-devel
```

## Machine Types

```bash
# Small (dev/test)
--machine-type=e2-medium

# Standard
--machine-type=e2-standard-4

# High-memory
--machine-type=e2-highmem-4
```

Example:

```bash
gcloud container clusters create dev-cluster \
  --project=openshift-gce-devel \
  --region=us-central1 \
  --machine-type=e2-standard-4 \
  --num-nodes=3
```

## Specific Kubernetes Version

```bash
# List available versions
gcloud container get-server-config \
  --project=openshift-gce-devel \
  --region=us-central1 \
  --format="yaml(validMasterVersions)"

# Create with specific version
gcloud container clusters create my-cluster \
  --project=openshift-gce-devel \
  --region=us-central1 \
  --cluster-version=1.31.1-gke.1678000
```

## Zonal vs Regional

```bash
# Zonal cluster (single zone, cheaper)
gcloud container clusters create my-cluster \
  --project=openshift-gce-devel \
  --zone=us-central1-a \
  --num-nodes=3

# Regional cluster (HA across zones, default)
# --num-nodes is PER ZONE, so 1 = 3 total across 3 zones
gcloud container clusters create my-cluster \
  --project=openshift-gce-devel \
  --region=us-central1 \
  --num-nodes=1
```

## Node Pools

```bash
# Add a node pool
gcloud container node-pools create extra-pool \
  --cluster=my-cluster \
  --project=openshift-gce-devel \
  --region=us-central1 \
  --machine-type=e2-standard-8 \
  --num-nodes=2

# List node pools
gcloud container node-pools list \
  --cluster=my-cluster \
  --project=openshift-gce-devel \
  --region=us-central1

# Resize a node pool
gcloud container clusters resize my-cluster \
  --node-pool=default-pool \
  --num-nodes=5 \
  --project=openshift-gce-devel \
  --region=us-central1

# Delete a node pool
gcloud container node-pools delete extra-pool \
  --cluster=my-cluster \
  --project=openshift-gce-devel \
  --region=us-central1
```

## GPU Nodes

```bash
# Create cluster with GPU node pool
gcloud container clusters create gpu-cluster \
  --project=openshift-gce-devel \
  --zone=us-central1-f \
  --num-nodes=1

gcloud container node-pools create gpu-pool \
  --cluster=gpu-cluster \
  --project=openshift-gce-devel \
  --zone=us-central1-f \
  --machine-type=a2-highgpu-1g \
  --accelerator=type=nvidia-tesla-a100,count=1 \
  --num-nodes=1

# Install NVIDIA GPU drivers
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded-latest.yaml
```

GPU nodes are only available in specific zones and are expensive.

## Delete a Cluster

```bash
gcloud container clusters delete my-cluster \
  --project=openshift-gce-devel \
  --region=us-central1
```

Use `--quiet` to skip the confirmation prompt in scripts.

## Cost Awareness

- Regional clusters cost more (3x the nodes of zonal for the same `--num-nodes` value)
- GPU nodes (A100) cost hundreds of dollars per day
- Always delete clusters when done
- Use `gcloud container clusters list --project=openshift-gce-devel` periodically to check for forgotten clusters
