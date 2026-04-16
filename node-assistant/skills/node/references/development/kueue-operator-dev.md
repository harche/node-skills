# OpenShift Kueue Operator Development

## Repositories

| Repo | Purpose |
|------|---------|
| `github.com/openshift/kueue-operator` | OpenShift Kueue operator (manages Kueue on OCP) |
| `github.com/kubernetes-sigs/kueue` | Upstream Kueue project |

The OpenShift Kueue operator manages the lifecycle of Kueue on an OpenShift cluster. It deploys, configures, and upgrades the upstream Kueue components.

```bash
# Clone the operator
git clone https://github.com/openshift/kueue-operator.git
cd kueue-operator
```

## What is Kueue

Kueue is a Kubernetes-native job queueing system that provides:

- **Job admission control**: controls when jobs are allowed to start based on available resources
- **Resource quota management**: manages resource allocation across namespaces and tenants
- **Fair sharing**: distributes cluster resources fairly among workloads
- **Priority and preemption**: supports workload prioritization

## Key CRDs

| CRD | Purpose |
|-----|---------|
| `Kueue` | Operator CR; defines the desired Kueue deployment configuration |
| `ClusterQueue` | Cluster-scoped; defines resource quotas and admission policies |
| `LocalQueue` | Namespace-scoped; connects workloads to a ClusterQueue |
| `ResourceFlavor` | Defines a set of node labels/taints that represent a type of resource |
| `Workload` | Internal representation of a job's resource requirements |
| `WorkloadPriorityClass` | Defines priority levels for workloads |
| `AdmissionCheck` | Custom admission gates for workloads |

## Operator Architecture

```
┌────────────────────────────────┐
│  kueue-operator                │
│  (Deployment in openshift-     │
│   kueue-operator namespace)    │
│                                │
│  Watches: Kueue CR             │
│  Manages: Kueue controller     │
│           deployment           │
└──────────┬─────────────────────┘
           │ deploys/manages
           ▼
┌────────────────────────────────┐
│  kueue-controller-manager      │
│  (Deployment in kueue-system)  │
│                                │
│  Watches: ClusterQueue,        │
│    LocalQueue, ResourceFlavor, │
│    Workload, Jobs, etc.        │
│                                │
│  Manages: Job admission,       │
│    resource quotas, scheduling │
└────────────────────────────────┘
```

## Build System

### Build the Operator Binary

```bash
make build
```

### Build Container Image

```bash
make docker-build IMG=quay.io/<your-user>/kueue-operator:custom
```

### Push Container Image

```bash
make docker-push IMG=quay.io/<your-user>/kueue-operator:custom
```

### Generate Manifests and Code

```bash
make generate       # Generate deepcopy, etc.
make manifests      # Generate CRD manifests, RBAC, webhook configs
```

## Operator SDK

The Kueue operator is built with the Operator SDK framework:

- Controller runtime for reconciliation loops
- CRD generation via controller-gen
- OLM (Operator Lifecycle Manager) bundle generation

## Repository Layout

```
cmd/
  manager/                # Operator entrypoint
api/
  v1alpha1/               # Kueue CR API types
controllers/
  kueue_controller.go     # Main reconciliation logic
config/
  crd/                    # CRD manifests
  rbac/                   # RBAC manifests
  manager/                # Operator deployment manifests
  samples/                # Example Kueue CRs
bundle/                   # OLM bundle
hack/                     # Build and development scripts
test/
  e2e/                    # E2E tests
```

## Quick Start

Clone and create a worktree per the [standard setup](../SETUP.md). To build and test:

```bash
make build
make test
make docker-build IMG=quay.io/<your-user>/kueue-operator:custom
```

## Deploying to a Cluster

### Install CRDs

```bash
make install
```

### Run Locally (Against a Remote Cluster)

```bash
export KUBECONFIG=/path/to/kubeconfig
make run
```

### Deploy to Cluster

```bash
make deploy IMG=quay.io/<your-user>/kueue-operator:custom
```

### Undeploy

```bash
make undeploy
```

## Working with Upstream Kueue

When changes are needed in the upstream Kueue project:

1. Fork and clone `kubernetes-sigs/kueue`
2. Make changes and test upstream
3. Submit a PR to upstream
4. Update the operator to consume the new upstream version

```bash
# Clone upstream
git clone https://github.com/kubernetes-sigs/kueue.git
cd kueue

# Build upstream
make build

# Test upstream
make test
make test-e2e
```

## Sub-References

- **[Building the Kueue Operator](kueue/building.md)** -- prerequisites, build steps, image build, cluster deployment
- **[Testing the Kueue Operator](kueue/testing.md)** -- unit tests, e2e tests, envtest setup, CI jobs
