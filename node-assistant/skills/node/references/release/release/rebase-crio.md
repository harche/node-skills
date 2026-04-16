# CRI-O Rebase

The CRI-O rebase updates openshift/cri-o to a new upstream CRI-O minor version. CRI-O versions track Kubernetes minor versions (CRI-O 1.31 pairs with Kubernetes 1.31), so the CRI-O rebase happens alongside the Kubernetes rebase each OCP release cycle.

## Repository Structure

CRI-O has a two-repo workflow for OpenShift:

- **cri-o/cri-o** — the upstream CRI-O repository. Node team members are upstream maintainers and contribute directly.
- **openshift/cri-o** — the downstream fork with OpenShift-specific patches and CI configuration.

Unlike openshift/kubernetes (which has hundreds of carry patches), openshift/cri-o has relatively few downstream patches because the Node team pushes most changes upstream first.

## CRI-O Version Alignment

| OCP Version | Kubernetes Version | CRI-O Version |
|-------------|-------------------|---------------|
| 4.17 | 1.30 | 1.30.x |
| 4.18 | 1.31 | 1.31.x |
| 4.19 | 1.32 | 1.32.x |

CRI-O minor versions are released shortly after the corresponding Kubernetes release, since CRI-O depends on the CRI API defined in Kubernetes.

## Downstream Patches in openshift/cri-o

Downstream patches in openshift/cri-o are fewer than in openshift/kubernetes but still exist:

- **Build system changes** — OpenShift-specific build flags, RPM spec modifications
- **Default configuration** — production defaults for OpenShift (e.g., seccomp profiles, runtime paths)
- **CI integration** — OpenShift CI job definitions, test configuration
- **Feature gate alignment** — ensuring CRI-O features match OpenShift's enablement decisions

These patches follow a similar convention to openshift/kubernetes but are less formalized. Review the commit history on the openshift/cri-o branch to identify downstream-only changes.

## Rebase Process

### Step 1: Verify Upstream Release

Confirm the upstream CRI-O release is available:

```bash
# Check for the release tag
git ls-remote --tags https://github.com/cri-o/cri-o.git | grep v1.31
```

CRI-O typically releases within a few weeks of the Kubernetes release. You can start the rebase with an RC tag if the final release is not yet available.

### Step 2: Set Up the Working Environment

```bash
git clone git@github.com:openshift/cri-o.git
cd cri-o
git remote add upstream git@github.com:cri-o/cri-o.git
git fetch upstream
git fetch origin
```

### Step 3: Identify Downstream Patches

```bash
# Compare the current openshift branch with its upstream base
git log --oneline upstream/release-1.30..origin/master
```

Categorize each commit:

- **Keep** — downstream patches that are still needed
- **Drop** — patches that were merged upstream or are no longer relevant
- **Update** — patches that need modification for the new version

### Step 4: Create the Rebase Branch

```bash
# Start from the upstream release tag
git checkout -b rebase-1.31 v1.31.0

# Apply downstream patches
git cherry-pick -x <downstream-patch-sha>
# Repeat for each patch
```

### Step 5: Resolve Conflicts

CRI-O rebases are simpler than Kubernetes because:

- Fewer downstream patches means fewer conflicts
- Node team members are upstream maintainers, so they know the upstream changes well
- CRI-O has a smaller codebase than Kubernetes

Common conflict areas:

- **internal/config/** — CRI-O server configuration defaults
- **server/** — CRI API implementation changes
- **pkg/config/** — configuration parsing and validation
- **Makefile, Dockerfile** — build system changes

### Step 6: Update Dependencies

```bash
go mod tidy
go mod vendor
make vendor
```

CRI-O's key dependencies:

- **containers/image** — container image handling
- **containers/storage** — container filesystem storage
- **containers/common** — shared container libraries
- **conmon / conmon-rs** — container monitoring process
- **opencontainers/runc** or **containers/crun** — OCI runtime

Check if any of these dependencies have breaking changes in the new version.

### Step 7: Build and Test

```bash
# Build CRI-O
make binaries

# Run unit tests
make testunit

# Run integration tests (requires a Linux environment with podman/runc)
make testintegration
```

### Step 8: Verify Configuration Compatibility

CRI-O configuration changes between versions can affect OpenShift node behavior. Check for:

- **New configuration options** — review the upstream changelog for new `crio.conf` fields
- **Changed defaults** — upstream may change default values that OpenShift relies on
- **Deprecated options** — options removed in the new version that MCO may still set
- **New CLI flags** — the CRI-O systemd unit may need updates

Verify that the MCO-generated CRI-O configuration is compatible:

```bash
# Check the CRI-O config template in MCO
# File: openshift/machine-config-operator/templates/common/...
# Ensure all config fields are valid for the new CRI-O version
```

### Step 9: Submit the Rebase PR

PR conventions for CRI-O rebase:

- Title: `Rebase to CRI-O 1.31.0`
- Body: summary of upstream changes relevant to OpenShift, list of downstream patches kept/dropped/updated
- Reviewers: Node/Runtime team members

### Step 10: Post-Rebase Coordination

After the CRI-O rebase merges:

1. **Update MCO** — if CRI-O configuration changed, update the MCO templates in openshift/machine-config-operator
2. **Update CI** — adjust CI job configurations for the new CRI-O version
3. **Coordinate with Kubernetes rebase** — CRI-O and kubelet must be compatible; ensure both rebases land close together
4. **Test upgrades** — verify that upgrading from old CRI-O to new CRI-O works correctly (container continuity, no pod restarts)

## Key Configuration Changes Between Versions

Things to watch for in each rebase:

### Runtime Configuration

- Default OCI runtime (crun vs runc)
- Seccomp profile defaults
- AppArmor / SELinux configuration
- Namespace configuration (user namespaces, PID namespace sharing)

### Storage Configuration

- Storage driver changes (overlay options)
- Image store configuration
- Container filesystem options

### Networking

- CNI plugin path and configuration directory
- Network namespace handling

### Monitoring and Logging

- Metrics endpoint changes
- Log format and verbosity defaults
- Tracing integration

## Testing After Rebase

### Local Testing

```bash
# Start CRI-O with a test configuration
sudo crio --config test/testdata/crio.conf

# Use crictl to test basic operations
crictl version
crictl pull registry.access.redhat.com/ubi9/ubi:latest
crictl runp test/testdata/sandbox_config.json
```

### CI Testing

The following CI jobs exercise CRI-O on OpenShift:

- e2e tests that create/destroy pods (every e2e job tests CRI-O implicitly)
- CRI-O specific tests in `openshift/cri-o` CI
- Node conformance tests (`[sig-node]` tests)
- Container runtime tests (critest conformance suite)

### Upgrade Testing

Critical for CRI-O rebases:

- Upgrade from previous OCP version (old CRI-O) to new OCP version (new CRI-O)
- Verify running containers survive the CRI-O restart during upgrade
- Verify container logs are preserved
- Verify exec/attach still works on containers created by the old version

## Coordinating with Upstream CRI-O Maintainers

The Node team has members who are CRI-O upstream maintainers. This gives advantages:

- **Early visibility** into upcoming changes
- **Influence over defaults** that affect OpenShift
- **Direct communication** for coordinating release timing
- **Ability to push fixes upstream first** rather than carrying downstream patches

When encountering issues during the rebase:

1. Check if upstream is aware of the issue
2. File an upstream issue or PR if it is an upstream bug
3. Carry a temporary downstream patch only if the upstream fix will take too long
4. Mark temporary patches clearly so they are dropped in the next rebase
