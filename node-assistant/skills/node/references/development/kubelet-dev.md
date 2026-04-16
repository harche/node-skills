# Kubelet Development for OpenShift

## Repository

The OpenShift kubelet lives in the `openshift/kubernetes` fork:

```
git clone https://github.com/openshift/kubernetes.git
cd kubernetes
```

This is a full fork of `kubernetes/kubernetes` upstream. OpenShift carries patches on top of upstream in the `UPSTREAM` directory and via `carry` commits.

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `master` | Tracks upstream `main`; rebased periodically |
| `release-4.X` | Corresponds to OCP 4.X release; cherry-picks only |

For active development, work against `master` unless backporting a fix.

To find the current OCP release branch:

```bash
git branch -r | grep 'release-4\.' | sort -V | tail -5
```

## Repository Layout (kubelet-relevant)

```
cmd/kubelet/              # kubelet binary entrypoint
pkg/kubelet/              # core kubelet logic
pkg/kubelet/cm/           # container manager (cgroups, device plugins)
pkg/kubelet/stats/        # stats provider
pkg/kubelet/eviction/     # eviction manager
pkg/kubelet/nodestatus/   # node status reporting
staging/src/k8s.io/kubelet/  # kubelet API types
openshift-hack/           # OpenShift-specific build scripts
```

## Build System

The kubelet uses standard Go and Makefile-based builds:

- **Local build**: `make WHAT=cmd/kubelet`
- **Cross-compile**: `GOOS=linux GOARCH=amd64 make WHAT=cmd/kubelet`
- **Regenerate code**: `make update`
- **Verify generated code**: `make verify`

Build output lands in `_output/bin/` (native) or `_output/bin/linux/amd64/` (cross-compiled).

## Quick Start

Clone and create a worktree per the [standard setup](../SETUP.md). To build and test:

```bash
make WHAT=cmd/kubelet                # Build kubelet
make test WHAT=./pkg/kubelet/...     # Run unit tests
```

## OpenShift-Specific Considerations

- OpenShift carries patches in `UPSTREAM/` with `UPSTREAM: <type>` commit prefixes
- `UPSTREAM: <carry>:` = OpenShift-specific carry patch (not intended for upstream)
- `UPSTREAM: <merge>:` = merge commit from upstream rebase
- `UPSTREAM: 12345:` = upstream PR cherry-pick
- The kubelet runs as a systemd service managed by the MCO on RHCOS nodes
- Kubelet configuration is rendered via MachineConfig (see MCO docs)
- The kubelet binary is part of the `hyperkube` image in OCP

## CI and Image Builds

- CI builds use `openshift/builder` images
- The kubelet is built as part of the `ose-hyperkube` image
- PR CI runs via Prow jobs defined in `openshift/release`

## Sub-References

- **[Building the kubelet](kubelet/building.md)** -- prerequisites, build commands, cross-compilation, container image builds
- **[Running a custom kubelet](kubelet/running.md)** -- deploying to a test cluster, key flags, feature gates
- **[Local testing](kubelet/local-testing.md)** -- unit tests, integration tests, adding new tests
