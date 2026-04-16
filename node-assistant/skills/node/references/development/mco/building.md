# Building the MCO

## Prerequisites

| Dependency | Notes |
|------------|-------|
| Go | Must match version in `go.mod` |
| make | GNU Make |
| Docker or Podman | For container image builds |
| git | For cloning |

## Clone and Setup

See the [standard setup](../../SETUP.md) for cloning and worktree creation.

## Full Build

Build all MCO binaries:

```bash
make
```

Output binaries land in `_output/linux/amd64/` (or the platform-appropriate directory).

## Component Builds

Build only the component you are working on:

```bash
make daemon          # machine-config-daemon (MCD)
make controller      # machine-config-controller
make operator        # machine-config-operator
make server          # machine-config-server
```

For rapid MCD iteration:

```bash
# Direct go build for fastest feedback
go build -o _output/linux/amd64/machine-config-daemon ./cmd/machine-config-daemon
```

## Cross-Compilation

For building on macOS targeting RHCOS nodes:

```bash
GOOS=linux GOARCH=amd64 go build -o _output/linux/amd64/machine-config-daemon ./cmd/machine-config-daemon
```

## Container Image Builds

### Build All Images

```bash
make image
```

### Build Specific Component Image

```bash
# Build MCD image
podman build -f Dockerfile.rhel7 -t quay.io/<your-user>/machine-config-daemon:custom .
podman push quay.io/<your-user>/machine-config-daemon:custom
```

### Using a Custom Registry

```bash
export IMAGE_REPO=quay.io/<your-user>
make image
```

## Deploying Custom MCO to a Cluster

### Method 1: Replace MCD Binary on Node

For testing MCD changes quickly:

```bash
# Build for linux/amd64
GOOS=linux GOARCH=amd64 make daemon

# Copy to node
NODE=<node-name>
scp _output/linux/amd64/machine-config-daemon core@${NODE}:/tmp/

# Replace on node
ssh core@${NODE}
sudo cp /tmp/machine-config-daemon /usr/bin/machine-config-daemon
sudo systemctl restart machine-config-daemon
```

### Method 2: Custom Image via Deployment Patch

For testing controller or operator changes:

```bash
# Build and push custom image
podman build -f Dockerfile.rhel7 -t quay.io/<your-user>/machine-config-operator:custom .
podman push quay.io/<your-user>/machine-config-operator:custom

# Patch the deployment to use your image
oc -n openshift-machine-config-operator set image \
  deployment/machine-config-operator \
  machine-config-operator=quay.io/<your-user>/machine-config-operator:custom
```

### Method 3: Full Custom MCO Deployment

For comprehensive testing with all custom components:

```bash
# Set environment variables
export REGISTRY=quay.io/<your-user>
export TAG=custom

# Build and push all images
make image
make push

# Apply custom images to cluster
oc -n openshift-machine-config-operator set image \
  daemonset/machine-config-daemon \
  machine-config-daemon=${REGISTRY}/machine-config-daemon:${TAG}

oc -n openshift-machine-config-operator set image \
  deployment/machine-config-controller \
  machine-config-controller=${REGISTRY}/machine-config-controller:${TAG}
```

### Preventing Operator from Reverting Your Changes

The CVO will revert manual image overrides. To prevent this during development:

```bash
# Scale down the CVO (development clusters only!)
oc scale deployment cluster-version-operator -n openshift-cluster-version --replicas=0
```

Remember to scale it back up when done:

```bash
oc scale deployment cluster-version-operator -n openshift-cluster-version --replicas=1
```

## Regenerating Code

After modifying CRD types:

```bash
make update
make verify
```

## Common Build Issues

### Module download failures

```bash
export GOPROXY=https://proxy.golang.org,direct
go mod download
```

### Stale vendor directory

```bash
go mod vendor
go mod tidy
```

### Image build failures on SELinux systems

```bash
podman build --security-opt label=disable -f Dockerfile.rhel7 .
```
