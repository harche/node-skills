# Kubernetes Conformance Tests

## What Conformance Means

Kubernetes conformance tests define the minimum set of behaviors a distribution must implement to call itself "Kubernetes." Passing the conformance suite is required for CNCF Certified Kubernetes status. For the Node team, conformance matters because:

- OpenShift must pass the full conformance suite every release
- Node conformance is a specific subset testing kubelet behavior independent of the cluster
- Any change to kubelet, CRI-O, or node configuration must not regress conformance

Conformance tests are tagged `[Conformance]` in the Kubernetes e2e test suite. They must be:
- Non-vendor-specific -- no cloud provider dependencies
- Stable -- no `[Flaky]` or `[Alpha]` tests
- Portable -- pass on any conformant K8s implementation

## Running the Full Conformance Suite

### From Kubernetes Source

```bash
cd $GOPATH/src/k8s.io/kubernetes

# Build the e2e test binary
make WHAT=test/e2e/e2e.test

# Run conformance tests against a cluster
export KUBECONFIG=/path/to/kubeconfig

./e2e.test \
  --ginkgo.focus='\[Conformance\]' \
  --ginkgo.skip='\[Disruptive\]|\[Serial\]' \
  --provider=skeleton \
  --report-dir=/tmp/conformance-results \
  --num-nodes=2
```

### Serial Conformance Tests

Some conformance tests are tagged `[Serial]` and must run separately:

```bash
./e2e.test \
  --ginkgo.focus='\[Conformance\].*\[Serial\]' \
  --provider=skeleton \
  --report-dir=/tmp/conformance-serial-results \
  --num-nodes=2
```

### Via openshift-tests

```bash
# Run K8s conformance via openshift-tests
./openshift-tests run kubernetes/conformance \
  --provider aws \
  -o /tmp/conformance-junit.xml
```

## Node Conformance Subset

The node conformance suite (`[NodeConformance]`) tests kubelet behavior independently. These tests run directly on the node rather than from an external test driver.

### What It Covers

- Pod lifecycle basics (create, delete, restart)
- Container probe behavior (liveness, readiness)
- Pod status reporting
- Resource limit enforcement
- Volume mounts (emptyDir, configMap, secret, downwardAPI)
- Security context enforcement
- Node status and conditions reporting
- DNS resolution from pods
- Logging (container stdout/stderr)

### Running Node Conformance

```bash
# From kubernetes source
make test-e2e-node FOCUS='\[NodeConformance\]'

# Against a remote node
make test-e2e-node \
  FOCUS='\[NodeConformance\]' \
  REMOTE=true \
  HOSTS=10.0.1.50 \
  SSH_KEY=~/.ssh/id_rsa \
  SSH_USER=core
```

### Using the Node Conformance Container Image

Kubernetes publishes a node conformance image that can run the suite without building from source:

```bash
# Pull the conformance image matching your cluster version
docker pull registry.k8s.io/node-test:v1.29.0

# Run against a node
docker run --rm \
  -v /:/rootfs:ro \
  -v /var/run/dbus:/var/run/dbus \
  --net=host \
  --privileged \
  registry.k8s.io/node-test:v1.29.0 \
  --focus='\[NodeConformance\]'
```

## Sonobuoy as an Alternative Runner

Sonobuoy wraps the Kubernetes conformance suite with easier execution and result collection. Useful for ad-hoc validation without building test binaries.

### Installation

```bash
# Download sonobuoy
wget https://github.com/vmware-tanzu/sonobuoy/releases/download/v0.57.2/sonobuoy_0.57.2_linux_amd64.tar.gz
tar xzf sonobuoy_0.57.2_linux_amd64.tar.gz
sudo mv sonobuoy /usr/local/bin/
```

### Running Conformance

```bash
# Run the full conformance suite
sonobuoy run --mode=certified-conformance --wait

# Run only non-disruptive conformance
sonobuoy run --mode=non-disruptive-conformance --wait

# Check status
sonobuoy status

# Retrieve results
results=$(sonobuoy retrieve)
sonobuoy results $results
sonobuoy results $results --mode=detailed | jq 'select(.status=="failed")'

# Clean up
sonobuoy delete --wait
```

### Node-Specific Run

```bash
# Run only node conformance via sonobuoy
sonobuoy run \
  --e2e-focus='\[NodeConformance\]' \
  --e2e-skip='\[Disruptive\]' \
  --wait
```

## CNCF Certification Requirements

To achieve CNCF Certified Kubernetes status (which OpenShift maintains each release):

1. **Pass the conformance suite** -- all `[Conformance]` tests must pass
2. **Use a supported Kubernetes version** -- within the CNCF support window
3. **Submit results** -- PR to `cncf/k8s-conformance` with:
   - `e2e.log` -- full test output
   - `junit_01.xml` -- JUnit results
   - `PRODUCT.yaml` -- product metadata
4. **No modifications to conformance behavior** -- the tests must run unmodified

### OpenShift Conformance Tracking

OpenShift tracks conformance status via:
- **Periodic CI jobs** -- nightly conformance runs per platform and version
- **Release blocking** -- conformance failures block GA releases
- **Conformance dashboard** -- visible in TestGrid under `redhat-openshift-*-conformance`

### When Conformance Tests Fail

If a node change causes conformance regression:

1. Check if the test itself was recently modified upstream (may be a test bug)
2. Verify the failure reproduces locally, not just in CI
3. Identify whether the behavior change is intentional or a bug
4. If intentional, upstream discussion is required -- conformance tests cannot be skipped
5. File a Bugzilla/Jira with `Conformance` label for tracking

## Adding Tests to Conformance

Promoting a test to `[Conformance]` requires upstream review. The test must:
- Be stable (no flakes in CI for several weeks)
- Test portable behavior (no cloud-specific logic)
- Not be `[Disruptive]` unless absolutely necessary (and then also `[Serial]`)
- Have a clear specification reference in the test description
- Be approved by SIG Architecture conformance reviewers
