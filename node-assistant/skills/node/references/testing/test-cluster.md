# Setting Up Test Clusters for Node Testing

## Cluster Creation

For cluster provisioning (installing a new OpenShift cluster), see [Cluster Provisioning](../deployment/cluster-provisioning.md). This document covers preparing an existing cluster for node-specific testing.

## Preparing a Cluster for Node Testing

### Verify Cluster Health

Before running tests, confirm the cluster is in a good state:

```bash
# Check all nodes are Ready
oc get nodes

# Check all cluster operators are Available
oc get co

# Check MachineConfigPools are updated and not degraded
oc get mcp

# Verify no unexpected pods are failing
oc get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
```

### Verify Node Configuration

```bash
# Check kubelet version
oc get nodes -o wide

# Check CRI-O version
oc debug node/<node-name> -- chroot /host crio --version

# Check current MachineConfig applied to workers
oc get mcp worker -o jsonpath='{.status.configuration.name}'

# Check node labels
oc get nodes --show-labels
```

## Installing Test Dependencies

### openshift-tests Binary

```bash
# Option 1: Build from source
git clone https://github.com/openshift/origin.git
cd origin && make WHAT=cmd/openshift-tests

# Option 2: Extract from release payload
oc adm release extract --tools <release-image>

# Option 3: Use the tests image directly
podman run --rm -v ~/.kube:/root/.kube:z \
  registry.ci.openshift.org/ocp/4.16:tests \
  openshift-tests run openshift/conformance/parallel
```

### Kubernetes Test Binaries

```bash
# For node e2e tests
cd $GOPATH/src/k8s.io/kubernetes
make WHAT=test/e2e/e2e.test
make WHAT=test/e2e_node/e2e_node.test

# Ginkgo runner
go install github.com/onsi/ginkgo/v2/ginkgo@latest
```

### Debug Tools on Nodes

```bash
# SSH to node (RHCOS)
oc debug node/<node-name>
chroot /host

# Install debug tools on the node (ephemeral)
oc debug node/<node-name> -- chroot /host bash -c "rpm-ostree usroverlay && dnf install -y strace perf"

# Or use toolbox
oc debug node/<node-name> -- chroot /host toolbox
```

## Labeling Nodes for Test Targeting

### Custom Labels for Test Isolation

```bash
# Label a specific worker for test targeting
oc label node <node-name> node-role.kubernetes.io/test-target=

# Label for specific feature testing
oc label node <node-name> feature-test=topology-manager
oc label node <node-name> feature-test=device-plugin

# Remove label when done
oc label node <node-name> feature-test-
```

### Using Labels in Tests

When running e2e tests, node labels can be used to target specific nodes:

```bash
# Run tests only on labeled nodes
./openshift-tests run openshift/conformance/parallel \
  --dry-run | grep '\[sig-node\]' | \
  ./openshift-tests run -f - \
  --node-selector="feature-test=topology-manager"
```

For node e2e tests, use `--node-name` to target a specific node:

```bash
make test-e2e-node \
  REMOTE=true \
  HOSTS=<labeled-node-ip> \
  FOCUS='\[NodeConformance\]'
```

### Dedicated Test Worker Pool

For disruptive testing, create a separate MachineConfigPool:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfigPool
metadata:
  name: test-workers
spec:
  machineConfigSelector:
    matchExpressions:
      - key: machineconfiguration.openshift.io/role
        operator: In
        values: [worker, test-workers]
  nodeSelector:
    matchLabels:
      node-role.kubernetes.io/test-workers: ""
```

```bash
# Label a node into the test pool
oc label node <node-name> node-role.kubernetes.io/test-workers=

# Wait for the pool to pick up the node
oc get mcp test-workers -w
```

## Applying Test Configurations

### Custom KubeletConfig

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: test-kubelet-config
spec:
  machineConfigPoolSelector:
    matchLabels:
      pools.operator.machineconfiguration.openshift.io/test-workers: ""
  kubeletConfig:
    topologyManagerPolicy: "single-numa-node"
    cpuManagerPolicy: "static"
    reservedSystemCPUs: "0-1"
    memoryManagerPolicy: "Static"
    evictionHard:
      memory.available: "100Mi"
      nodefs.available: "10%"
```

### Custom CRI-O Config

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: ContainerRuntimeConfig
metadata:
  name: test-crio-config
spec:
  machineConfigPoolSelector:
    matchLabels:
      pools.operator.machineconfiguration.openshift.io/test-workers: ""
  containerRuntimeConfig:
    logSizeMax: "10Mi"
    logLevel: "debug"
    pidsLimit: 4096
```

## Cleaning Up After Tests

### Remove Test Workloads

```bash
# Delete test namespaces (openshift-tests creates e2e-* namespaces)
oc get ns | grep '^e2e-' | awk '{print $1}' | xargs oc delete ns

# Delete any remaining test pods
oc delete pods -A -l test=true
```

### Remove Test Labels and Pools

```bash
# Remove test labels from nodes
oc label node <node-name> feature-test-
oc label node <node-name> node-role.kubernetes.io/test-target-
oc label node <node-name> node-role.kubernetes.io/test-workers-

# Delete test MachineConfigPool
oc delete mcp test-workers

# Delete test KubeletConfig and ContainerRuntimeConfig
oc delete kubeletconfig test-kubelet-config
oc delete containerruntimeconfig test-crio-config
```

### Revert Node State

```bash
# Wait for MCP to finish rolling out after config removal
oc get mcp worker -w

# Verify nodes are back to baseline
oc get nodes
oc get mcp
```

### Full Cluster Cleanup

If the cluster is heavily modified and cleanup is impractical, consider destroying and reprovisioning:

```bash
openshift-install destroy cluster --dir=<install-dir>
```
