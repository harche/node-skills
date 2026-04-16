# Building the Kueue Operator

## Prerequisites

| Dependency | Notes |
|------------|-------|
| Go | Must match version in `go.mod` |
| make | GNU Make |
| Docker or Podman | For container image builds |
| operator-sdk | For OLM bundle generation |
| controller-gen | Auto-installed via Makefile |
| kustomize | Auto-installed via Makefile |
| git | For cloning |

### Install operator-sdk

```bash
# Download operator-sdk binary
export OPERATOR_SDK_VERSION=v1.34.0
curl -LO https://github.com/operator-framework/operator-sdk/releases/download/${OPERATOR_SDK_VERSION}/operator-sdk_linux_amd64
chmod +x operator-sdk_linux_amd64
sudo mv operator-sdk_linux_amd64 /usr/local/bin/operator-sdk

# Verify
operator-sdk version
```

## Clone and Setup

See the [standard setup](../../SETUP.md) for cloning and worktree creation.

## Build Steps

### Build the Operator Binary

```bash
make build
```

Output: `bin/manager`

### Build with go directly (for faster iteration)

```bash
go build -o bin/manager cmd/manager/main.go
```

### Cross-Compile for Linux

```bash
GOOS=linux GOARCH=amd64 make build
```

## Code Generation

### Generate DeepCopy Methods

After modifying API types in `api/v1alpha1/`:

```bash
make generate
```

### Generate CRD Manifests

```bash
make manifests
```

### Verify Generated Code Is Up to Date

```bash
make verify
```

## Container Image Build

### Build Image

```bash
make docker-build IMG=quay.io/<your-user>/kueue-operator:custom
```

### Build with Podman

```bash
make docker-build IMG=quay.io/<your-user>/kueue-operator:custom CONTAINER_TOOL=podman
```

### Push Image

```bash
make docker-push IMG=quay.io/<your-user>/kueue-operator:custom
```

Or with Podman:

```bash
make docker-push IMG=quay.io/<your-user>/kueue-operator:custom CONTAINER_TOOL=podman
```

## Deploy to Cluster

### Install CRDs

```bash
make install
```

### Deploy the Operator

```bash
# Using a custom image
make deploy IMG=quay.io/<your-user>/kueue-operator:custom
```

This creates the operator namespace, RBAC, deployment, and all required resources.

### Verify Deployment

```bash
# Check operator pod
oc get pods -n openshift-kueue-operator

# Check operator logs
oc logs -n openshift-kueue-operator deployment/kueue-operator-controller-manager -f

# Check CRDs are installed
oc get crd | grep kueue
```

### Create a Kueue Instance

```bash
oc apply -f config/samples/kueue_v1alpha1_kueue.yaml
```

### Verify Kueue Is Running

```bash
# Check Kueue controller
oc get pods -n kueue-system

# Check Kueue CRDs
oc get clusterqueues
oc get localqueues --all-namespaces
oc get resourceflavors
```

### Undeploy

```bash
make undeploy
```

### Uninstall CRDs

```bash
make uninstall
```

## OLM Bundle

### Generate OLM Bundle

```bash
make bundle IMG=quay.io/<your-user>/kueue-operator:custom
```

### Build Bundle Image

```bash
make bundle-build BUNDLE_IMG=quay.io/<your-user>/kueue-operator-bundle:custom
```

### Push Bundle Image

```bash
make bundle-push BUNDLE_IMG=quay.io/<your-user>/kueue-operator-bundle:custom
```

### Deploy via OLM

```bash
operator-sdk run bundle quay.io/<your-user>/kueue-operator-bundle:custom
```

## Run Locally (Without Deploying)

For development, run the operator process locally against a remote cluster:

```bash
export KUBECONFIG=/path/to/kubeconfig

# Install CRDs first
make install

# Run the operator locally
make run
```

This runs the operator as a local process with the controller connecting to the cluster specified by KUBECONFIG.

## Common Build Issues

### `controller-gen: command not found`

The Makefile auto-downloads controller-gen. If it fails:

```bash
go install sigs.k8s.io/controller-tools/cmd/controller-gen@latest
```

### `kustomize: command not found`

```bash
go install sigs.k8s.io/kustomize/kustomize/v5@latest
```

### Image build fails with permission errors

```bash
# Use podman with rootless
make docker-build IMG=quay.io/<your-user>/kueue-operator:custom CONTAINER_TOOL=podman
```

### Module download failures

```bash
export GOPROXY=https://proxy.golang.org,direct
go mod download
```
