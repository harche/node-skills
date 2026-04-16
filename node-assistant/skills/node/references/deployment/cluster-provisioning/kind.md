# kind (Kubernetes in Docker)

Create local Kubernetes clusters using Docker containers as nodes. Fast, lightweight, and free.

## Prerequisites

- Docker running locally
- `kind` CLI: `brew install kind` or `go install sigs.k8s.io/kind@latest`
- `kubectl`: `brew install kubectl`

## Basic Usage

```bash
# Create default cluster (single control-plane node)
kind create cluster --name dev

# Create with specific Kubernetes version
kind create cluster --name dev --image kindest/node:v1.31.0

# List clusters
kind get clusters

# Get kubeconfig
kind get kubeconfig --name dev

# Set kubectl context
kubectl cluster-info --context kind-dev

# Delete cluster
kind delete cluster --name dev

# Delete all clusters
kind delete clusters --all
```

## Multi-Node Cluster

Create a config file and pass it with `--config`:

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
```

```bash
kind create cluster --name multi --config kind-config.yaml
```

### HA Control Plane (3 control-plane + 3 workers)

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: control-plane
- role: control-plane
- role: worker
- role: worker
- role: worker
```

## Custom Kubernetes Version

Find available node images at https://github.com/kubernetes-sigs/kind/releases.

```bash
kind create cluster --image kindest/node:v1.31.0
kind create cluster --image kindest/node:v1.30.0
kind create cluster --image kindest/node:v1.29.0
```

## Port Mappings

Expose services on the host:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000
    protocol: TCP
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
```

## Ingress Setup

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
```

Then install nginx ingress controller:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

## Local Registry

```bash
# Create a registry container
docker run -d --restart=always -p 5001:5000 --network bridge --name kind-registry registry:2

# Create cluster connected to it
kind create cluster --name dev --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5001"]
    endpoint = ["http://kind-registry:5001"]
EOF

# Connect registry to kind network
docker network connect kind kind-registry

# Use it
docker tag my-app:latest localhost:5001/my-app:latest
docker push localhost:5001/my-app:latest
kubectl run my-app --image=localhost:5001/my-app:latest
```

## Loading Images

Load local Docker images directly into the cluster without a registry:

```bash
# Load from Docker daemon
kind load docker-image my-app:latest --name dev

# Load from a tar archive
kind load image-archive my-app.tar --name dev
```

## Delete

```bash
kind delete cluster --name dev
```

## Limitations

kind is not suitable for Node team work that requires:

- **Real node OS**: kind nodes are Docker containers, not VMs. There is no RHCOS, no immutable rootfs.
- **systemd**: kind nodes do not run a full systemd init. Service management behaves differently.
- **CRI-O**: kind uses containerd as the container runtime, not CRI-O.
- **MCO/MachineConfig**: No Machine Config Operator, no MachineConfigPool.
- **GPU**: No GPU passthrough support.

Use kind for testing Kubernetes API interactions, controllers, and operators. Use OpenShift on GCP for anything that needs real RHCOS nodes.
