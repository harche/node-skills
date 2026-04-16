# E2E Testing for Node Components

## Overview

End-to-end testing validates node component behavior in a running OpenShift cluster. The Node team works with three main e2e test surfaces:

1. **Kubernetes node e2e tests** -- focused kubelet/runtime tests that run against individual nodes
2. **Kubernetes conformance tests** -- the standard K8s conformance suite, including node-specific subsets
3. **OpenShift e2e tests** -- the `openshift-tests` binary from `openshift/origin`, covering OpenShift-specific functionality and conformance

## OpenShift E2E Test Framework

OpenShift e2e tests are built on top of the Kubernetes e2e framework (`k8s.io/kubernetes/test/e2e/framework`). Key additions:

- **Disruption monitoring** -- tracks API availability and workload disruption during tests
- **Invariant checks** -- background monitors that fail the suite if platform invariants are violated (e.g., node goes NotReady unexpectedly)
- **Alert validation** -- checks that no unexpected alerts fire during the test run
- **Lease-based test isolation** -- prevents conflicting tests from running simultaneously

The framework uses Ginkgo v2 as the test runner and Gomega for assertions.

## Node-Specific E2E Test Suites

Tests relevant to the Node team are primarily tagged with:

- `[sig-node]` -- kubelet, pod lifecycle, resource management, device plugins, topology manager
- `[sig-node] [Feature:NodeAllocatable]` -- node resource reservation
- `[sig-node] [Feature:PodLifecycleSleepAction]` -- graceful shutdown behaviors
- `[NodeConformance]` -- subset required for node conformance certification
- `[NodeFeature:*]` -- feature-specific node tests (e.g., `[NodeFeature:SidecarContainers]`)

MCO-related tests are typically under:
- `[sig-node] Machine Config` -- MCO operator behavior
- `[sig-node] MachineConfigPool` -- pool update and rollback

CRI-O-related tests surface through:
- `[sig-node]` tests exercising container runtime behavior (image pull, container lifecycle)
- Container runtime interface validation via `critest`

## Running E2E Tests Against a Cluster

### Prerequisites

- A running OpenShift cluster with `KUBECONFIG` exported
- The appropriate test binary built or downloaded
- Cluster admin privileges

### Quick Start with openshift-tests

```bash
# Clone and build
git clone https://github.com/openshift/origin.git
cd origin
make WHAT=cmd/openshift-tests

# Run node-specific tests
./openshift-tests run openshift/conformance/parallel \
  --dry-run | grep '\[sig-node\]' | \
  ./openshift-tests run -f -

# Run a single test by name
./openshift-tests run-test "test name here"
```

### Quick Start with Kubernetes Node E2E

```bash
# From a kubernetes checkout
make test-e2e-node FOCUS='\[sig-node\]' \
  REMOTE=true \
  HOSTS=<node-ip> \
  SSH_KEY=<path-to-key>
```

## Test Organization

```
test/
  e2e/             # Kubernetes e2e tests
    node/           # Node-specific e2e tests (kubelet, lifecycle)
  e2e_node/         # Node e2e tests that run on the node itself
  conformance/      # Conformance test definitions
```

In the `openshift/origin` repo:
```
test/
  extended/         # OpenShift-extended e2e tests
    node/           # Node-specific extensions
    machines/       # Machine and MachineConfig tests
```

## Choosing the Right Test Suite

| Scenario | Suite |
|---|---|
| Validating kubelet behavior changes | Kubernetes node e2e (`test/e2e_node`) |
| Verifying OpenShift node conformance | `openshift-tests run openshift/conformance/parallel` filtered to `[sig-node]` |
| Checking MCO changes | MCO e2e tests or `openshift-tests` with MCO focus |
| Certifying a node implementation | Kubernetes conformance + node conformance |
| Pre-merge CI validation | Prow presubmit jobs (see ci-jobs.md) |

## Test Timeouts and Stability

- Default Ginkgo test timeout: 45 minutes for most suites
- Node e2e default per-test timeout: 5 minutes (configurable via `--test-timeout`)
- Tests tagged `[Slow]` are excluded from parallel runs by default
- Tests tagged `[Disruptive]` modify cluster state and run serially
- Tests tagged `[Flaky]` are skipped in CI by default

## JUnit and Artifacts

All test suites produce JUnit XML reports. For `openshift-tests`:

```bash
# Results written to current directory by default
./openshift-tests run openshift/conformance/parallel \
  -o junit/results.xml
```

For CI jobs, JUnit and artifacts are uploaded to GCS and visible in Prow job results.

## Environment Variables

Common environment variables affecting node e2e behavior:

| Variable | Purpose |
|---|---|
| `KUBECONFIG` | Path to cluster kubeconfig |
| `TEST_PROVIDER` | Cloud provider for test setup (`aws`, `gcp`, `azure`, `none`) |
| `KUBE_SSH_KEY` | SSH key path for node access during node e2e |
| `KUBE_SSH_USER` | SSH user for node access (default: `core` on RHCOS) |

## Sub-References

- [Node E2E Tests](e2e/node-e2e.md) -- Kubernetes node e2e test details, running, and authoring
- [Conformance Tests](e2e/conformance.md) -- Kubernetes conformance and node conformance suites
- [OpenShift Tests](e2e/openshift-tests.md) -- The `openshift-tests` binary, suites, and disruption framework
