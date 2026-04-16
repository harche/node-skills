# Building the Kubelet (OpenShift)

## Prerequisites

| Dependency | Notes |
|------------|-------|
| Go | Must match version in `go.mod` |
| make | GNU Make |
| Docker or Podman | For container image builds |
| git | For cloning and patch management |

Install Go:

```bash
sudo dnf install golang   # Fedora/RHEL
# or use gimme / goenv for version management
```

## Clone and Setup

See the [standard setup](../../SETUP.md) for cloning and worktree creation.

## Local Build

Build the kubelet binary for your host platform:

```bash
make WHAT=cmd/kubelet
```

Output: `_output/bin/kubelet`

Build with verbose output:

```bash
make WHAT=cmd/kubelet KUBE_VERBOSE=5
```

Build with debug symbols (useful for dlv):

```bash
DBG=1 make WHAT=cmd/kubelet
```

## Cross-Compile for Linux (amd64)

Required when building on macOS or for deploying to RHCOS nodes:

```bash
GOOS=linux GOARCH=amd64 make WHAT=cmd/kubelet
```

Output: `_output/bin/linux/amd64/kubelet`

For arm64 (e.g., aarch64 nodes):

```bash
GOOS=linux GOARCH=arm64 make WHAT=cmd/kubelet
```

Output: `_output/bin/linux/arm64/kubelet`

## Build All Kubernetes Binaries

```bash
make
```

Or build specific binaries:

```bash
make WHAT="cmd/kubelet cmd/kubectl cmd/kube-apiserver"
```

## Regenerate Generated Code

After modifying API types or other generated sources:

```bash
make update
```

This runs all code generators (deepcopy, defaulting, conversion, openapi, etc.). Verify nothing is stale:

```bash
make verify
```

## Container Image Build

The kubelet ships inside the `ose-hyperkube` image. To build a custom image:

```bash
# Build the binary for linux/amd64
GOOS=linux GOARCH=amd64 make WHAT=cmd/kubelet

# Build image using OpenShift Dockerfiles
podman build -f openshift-hack/images/hyperkube/Dockerfile \
  -t quay.io/<your-user>/ose-hyperkube:custom .
```

Push to a registry accessible by your cluster:

```bash
podman push quay.io/<your-user>/ose-hyperkube:custom
```

## Build Output Locations

| Build Type | Output Path |
|------------|-------------|
| Native | `_output/bin/kubelet` |
| Linux amd64 | `_output/bin/linux/amd64/kubelet` |
| Linux arm64 | `_output/bin/linux/arm64/kubelet` |
| All binaries | `_output/bin/` or `_output/bin/<os>/<arch>/` |

## Common Build Errors and Fixes

### `go: module lookup disabled by GOPROXY=off`

The build environment may require a proxy. Set:

```bash
export GOPROXY=https://proxy.golang.org,direct
```

### Go version mismatch

```
go: go.mod requires go >= 1.22.0 (running go 1.21.x)
```

Install the correct Go version as specified in `go.mod`.

### Out-of-memory during build

Kubernetes is a large project. Limit parallelism:

```bash
make WHAT=cmd/kubelet GOFLAGS="-p 2"
```

### Stale generated code

```
make verify
# If failures:
make update
git diff  # review generated changes
```

### Permission errors on _output

```bash
rm -rf _output
make WHAT=cmd/kubelet
```

## Tips

- Use `ccache` or keep `_output/` warm across builds -- Go caching helps significantly
- For rapid iteration, build only the kubelet (`WHAT=cmd/kubelet`) rather than all binaries
- The Go build cache at `~/.cache/go-build` speeds up rebuilds; do not clear it unnecessarily
- Use `go build -race cmd/kubelet` during local testing to catch race conditions (not for deployment)
