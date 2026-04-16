# Kubernetes Rebase for OpenShift

The Kubernetes rebase is the process of updating openshift/kubernetes from one Kubernetes minor version to the next. This is one of the most complex and critical tasks in the OCP release cycle.

## Repository Structure

**openshift/kubernetes** is a fork of **kubernetes/kubernetes**. It maintains:

- An `master` branch tracking the current OCP development version
- `release-4.X` branches for each supported OCP release
- Hundreds of downstream carry patches on top of upstream code

The fork structure means every upstream change is available, and OpenShift-specific modifications are layered on top as additional commits.

## Carry Patches

Carry patches are downstream-only commits in openshift/kubernetes that do not exist in upstream kubernetes/kubernetes. They implement OpenShift-specific behavior.

### Carry Patch Convention

Carry patches use a prefix convention in their commit message:

```
UPSTREAM: <carry>: description of the change
```

Examples:
```
UPSTREAM: <carry>: Add OpenShift-specific feature gate overrides
UPSTREAM: <carry>: Enable CRI-O as default runtime
UPSTREAM: <carry>: Add kubelet certificate bootstrap for OpenShift
```

Other commit prefixes in openshift/kubernetes:

```
UPSTREAM: 12345: Cherry-pick of upstream PR #12345
UPSTREAM: <drop>: Temporary patch, should not survive the next rebase
```

- `<carry>` — permanent downstream patch, reapply on every rebase
- `<drop>` — temporary patch, discard during the next rebase
- `12345` — cherry-pick of a specific upstream PR (will be in the next upstream release, so it auto-resolves)

### Managing Carry Patches

Before starting a rebase, audit the carry patches:

```bash
# List all carry patches on the current branch
git log --oneline upstream/master..openshift/master | grep "UPSTREAM: <carry>"
```

For each carry patch, determine:

1. **Still needed?** — has upstream merged equivalent functionality?
2. **Still applies cleanly?** — will it conflict with upstream changes?
3. **Needs updating?** — does the carry patch need modification for the new upstream version?

## Rebase Process: Step by Step

### Step 1: Set Up the Environment

```bash
git clone git@github.com:openshift/kubernetes.git
cd kubernetes
git remote add upstream git@github.com:kubernetes/kubernetes.git
git fetch upstream
git fetch origin
```

### Step 2: Create the Rebase Branch

Start from the upstream tag for the new Kubernetes version:

```bash
# Example: rebasing to Kubernetes 1.31.0
git checkout -b rebase-1.31 v1.31.0
```

### Step 3: Identify Carry Patches to Apply

Generate the list of carry patches from the current branch:

```bash
git log --oneline --reverse origin/master -- | grep "UPSTREAM: <carry>" > carry-patches.txt
git log --oneline --reverse origin/master -- | grep "UPSTREAM: <drop>" > drop-patches.txt
```

Review `drop-patches.txt` — these should be discarded. Review `carry-patches.txt` — these need to be reapplied.

Also identify upstream cherry-picks that are now in the new version:

```bash
git log --oneline --reverse origin/master -- | grep -E "UPSTREAM: [0-9]+" > cherry-picks.txt
```

These can usually be dropped since they are included in the new upstream tag.

### Step 4: Apply Carry Patches

Apply each carry patch to the rebase branch:

```bash
# Apply carry patches one by one
git cherry-pick -x <carry-patch-sha>
```

Or apply them in bulk (riskier but faster):

```bash
# Generate a list of SHAs for carry patches
git log --reverse --format="%H" origin/master | ... > carry-shas.txt

# Cherry-pick all
git cherry-pick -x $(cat carry-shas.txt)
```

The cherry-pick will stop on conflicts. This is where the real work begins.

### Step 5: Resolve Conflicts

For each conflict:

1. Understand what the carry patch does
2. Understand what upstream changed
3. Combine both intents — keep the upstream change AND the carry patch behavior
4. Test that the resolution compiles: `make build`

Common conflict areas for the Node team:

- **pkg/kubelet/** — kubelet configuration, pod lifecycle, container runtime integration
- **pkg/kubelet/cm/** — cgroup manager, resource management
- **pkg/kubelet/cri/** — CRI client code, runtime service
- **pkg/kubelet/config/** — kubelet configuration parsing
- **staging/src/k8s.io/kubelet/** — kubelet API types
- **cmd/kubelet/** — kubelet binary, flag parsing
- **vendor/** — vendored dependencies (resolve after all patches applied)

### Step 6: Update Dependencies

After all carry patches are applied:

```bash
# Update go.mod and vendor
go mod tidy
go mod vendor

# Update OpenShift-specific dependencies
# (staging repos, library-go, api, client-go forks)
```

Dependency updates often require coordinating with other teams who own the forked libraries (openshift/api, openshift/library-go, openshift/client-go).

### Step 7: Update Generated Code

Kubernetes uses extensive code generation:

```bash
# Run all code generators
make generated_files
# Or more specifically:
hack/update-codegen.sh
hack/update-openapi-gen.sh
```

Verify generated code is correct:

```bash
hack/verify-codegen.sh
```

### Step 8: Build and Test

```bash
# Build all binaries
make build

# Run unit tests
make test

# Run integration tests (subset relevant to node)
make test-integration WHAT=./pkg/kubelet/...

# Run node e2e tests locally if possible
```

### Step 9: Submit the Rebase PR

The rebase PR is a large PR. It typically:

- Contains hundreds of commits (all the upstream changes + reapplied carry patches)
- Touches thousands of files
- Requires review from multiple teams

PR conventions:

- Title: `UPSTREAM: <carry>: Rebase to Kubernetes 1.31`
- Body: list of carry patches applied, dropped, and modified
- Reviewers: kubernetes rebase team, node team leads, API team

### Step 10: Post-Rebase Tasks

After the rebase PR merges:

1. **Update CI configurations** — new test suites, changed test names, updated conformance lists
2. **Verify feature gates** — check that OpenShift feature gate overrides are correct for the new version
3. **Update component dependencies** — other repos (MCO, cluster-version-operator) may need updates to work with the new kubelet
4. **Monitor CI** — watch for test failures caused by the rebase over the following days
5. **Update documentation** — if kubelet configuration options changed

## Common Conflict Areas for Node Team

### Kubelet Configuration

OpenShift overrides several kubelet defaults. When upstream changes the configuration structure, carry patches that set defaults will conflict.

Files: `pkg/kubelet/apis/config/`, `cmd/kubelet/app/options/`

### CRI Integration

OpenShift uses CRI-O exclusively. Carry patches that set CRI-O as the default or adjust CRI behavior often conflict with upstream CRI changes.

Files: `pkg/kubelet/cri/`, `pkg/kubelet/kuberuntime/`

### Certificate Management

OpenShift has custom certificate bootstrap logic for kubelet. Upstream may change the certificate rotation or authentication code.

Files: `pkg/kubelet/certificate/`, `cmd/kubelet/app/server.go`

### Feature Gates

OpenShift overrides many feature gate defaults. New upstream feature gates need to be evaluated and potentially overridden.

Files: `pkg/features/`, `staging/src/k8s.io/apiserver/pkg/features/`

### Node Status and Lifecycle

Carry patches for node status reporting, shutdown behavior, and lifecycle hooks frequently conflict.

Files: `pkg/kubelet/nodestatus/`, `pkg/kubelet/nodelifecycle/`

## Tips for Successful Rebases

- **Start early** — do not wait for the final upstream release; start with RC tags
- **Rebase incrementally** — if the diff is massive, consider rebasing to intermediate upstream commits
- **Keep carry patches minimal** — every carry patch is a future conflict; push changes upstream when possible
- **Document carry patch rationale** — future rebases depend on understanding why each carry patch exists
- **Coordinate with other teams** — API, networking, and storage teams have their own carry patches that may interact with yours
- **Test continuously** — do not accumulate patches without building; catch conflicts early
