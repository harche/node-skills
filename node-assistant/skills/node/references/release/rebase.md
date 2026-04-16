# Upstream Rebase Process

Rebasing brings a new upstream version of a component into OpenShift. For the Node team, the major rebases are Kubernetes (kubelet, kube-proxy) and CRI-O. These happen once per OCP minor release cycle.

## What Is a Rebase?

A rebase replaces the upstream base of a downstream fork with a newer upstream version while preserving downstream (OpenShift-specific) patches. For example:

- openshift/kubernetes based on Kubernetes 1.30 -> rebased to Kubernetes 1.31
- openshift/cri-o based on CRI-O 1.30 -> rebased to CRI-O 1.31

This is fundamentally different from a cherry-pick. A cherry-pick brings one fix to an older branch. A rebase replaces the entire upstream foundation.

## Components That Get Rebased

### Kubernetes (openshift/kubernetes)

The largest and most complex rebase. openshift/kubernetes is a fork of kubernetes/kubernetes with hundreds of carry patches for OpenShift integration. Node team components affected:

- **kubelet** — pod lifecycle, container runtime interface, resource management
- **kube-proxy** — network proxy (though OpenShift primarily uses OVN-Kubernetes)
- **kubectl** — CLI tooling
- **API machinery** — shared libraries used across many components

The Kubernetes rebase aligns with a new Kubernetes minor release and happens at the start of each OCP development cycle.

### CRI-O (openshift/cri-o)

CRI-O versions track Kubernetes minor versions (CRI-O 1.31 pairs with Kubernetes 1.31). The CRI-O rebase brings in:

- New CRI (Container Runtime Interface) API support
- Runtime improvements and bug fixes
- New container features (annotations, security profiles, etc.)
- Updated dependencies (conmon, containers/image, containers/storage)

### Other Node-Adjacent Rebases

- **conmon-rs** — container monitor, updated alongside CRI-O
- **crun / runc** — OCI runtimes, updated as needed
- **containers/image, containers/storage** — container libraries used by CRI-O

## High-Level Rebase Process

Regardless of the component, the rebase process follows this pattern:

1. **Upstream releases a new version** (e.g., Kubernetes 1.31.0, CRI-O 1.31.0)
2. **Create a new branch** from the upstream tag
3. **Apply downstream carry patches** on top of the upstream code
4. **Resolve conflicts** between carry patches and upstream changes
5. **Update dependencies** (go.mod, vendor/)
6. **Run tests** — unit, integration, e2e
7. **Submit PR** for review
8. **Post-rebase cleanup** — update CI configurations, verify feature gates, fix test failures

## Rebase Timeline

Rebases happen early in the OCP development cycle:

| Phase | Timeline | Activity |
|-------|----------|----------|
| Upstream release | Kubernetes releases ~3x/year | Upstream tag is available |
| Rebase starts | Within days of upstream release | Branch creation, carry patch application |
| Conflict resolution | 1-3 weeks | The bulk of the work |
| Testing and stabilization | 1-2 weeks | CI green, e2e passing |
| Merge | Before feature freeze | Rebase lands on master |

The Kubernetes rebase is on the critical path for every OCP release. Delays in the rebase delay the entire release.

## Rebase Ownership

- **Kubernetes rebase**: coordinated by the Kubernetes rebase team (includes Node team members); the Node team owns kubelet and node-specific carry patches
- **CRI-O rebase**: owned by the Node/Runtime team; typically done by 1-2 engineers
- **Runtime/library rebases**: owned by the engineer most familiar with the component

## Key Challenges

### Carry Patch Conflicts

The most time-consuming part of any rebase is resolving conflicts between downstream carry patches and upstream changes. Upstream may have:

- Refactored code that carry patches modify
- Removed APIs that carry patches depend on
- Changed behavior that carry patches assume

### Dependency Skew

After a rebase, dependency versions may conflict between the rebased component and other OpenShift components that have not been rebased yet. Go module replace directives and staging repos help manage this.

### Feature Gate Alignment

New upstream feature gates must be evaluated:

- Which gates are alpha, beta, GA in the new version?
- Which gates does OpenShift need to override?
- Do any new gates affect node behavior?

### API Changes

New or changed APIs must be reviewed for OpenShift compatibility:

- New kubelet configuration fields
- Changed CRI API semantics
- Deprecated features slated for removal

## Further Reading

- [Kubernetes Rebase](release/rebase-kubernetes.md) — detailed Kubernetes rebase process, carry patches, and conflict resolution
- [CRI-O Rebase](release/rebase-crio.md) — CRI-O rebase process and coordination with upstream
