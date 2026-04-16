# MCO Testing

## Unit Tests

### Run All Unit Tests

```bash
cd ~/go/src/github.com/openshift/machine-config-operator
make test
```

### Run Tests for a Specific Package

```bash
go test ./pkg/daemon/... -v
go test ./pkg/controller/... -v
go test ./pkg/operator/... -v
go test ./pkg/server/... -v
```

### Run a Specific Test

```bash
go test ./pkg/daemon/... -v -run TestReconcilable
go test ./pkg/controller/render/... -v -run TestRenderMachineConfig
```

### Run with Race Detector

```bash
go test ./pkg/daemon/... -race
```

### Run with Count (Detect Flakes)

```bash
go test ./pkg/daemon/... -v -run TestUpdate -count=5
```

## E2E Tests

### Prerequisites

- A running OCP cluster
- `KUBECONFIG` set to a valid kubeconfig with cluster-admin
- Sufficient cluster resources (e2e tests create MachineConfigs that trigger node reboots)

### Run All E2E Tests

```bash
make test-e2e
```

### Run Specific E2E Tests

```bash
# Run a single test by name
make test-e2e TESTS="-run TestMCDToken"

# Run tests matching a pattern
make test-e2e TESTS="-run TestKubelet"
```

### E2E Test with Verbose Output

```bash
make test-e2e TESTS="-v -run TestMCDToken"
```

### Common E2E Test Suites

The e2e tests live in `test/e2e/`:

| Test File | Tests |
|-----------|-------|
| `mcd_test.go` | MCD apply, rollback, drift detection |
| `pool_test.go` | MachineConfigPool operations |
| `kubeletconfig_test.go` | KubeletConfig CR handling |
| `containerruntimeconfig_test.go` | ContainerRuntimeConfig CR |
| `osimageurl_test.go` | OS image pinning |
| `layering_test.go` | On-cluster layering |
| `upgrade_test.go` | Upgrade scenarios |

## CI Job Structure

MCO CI runs via Prow. Key jobs in `openshift/release`:

### Pre-submit (PR) Jobs

| Job | What It Does |
|-----|-------------|
| `pull-ci-openshift-machine-config-operator-master-unit` | Unit tests |
| `pull-ci-openshift-machine-config-operator-master-e2e-aws` | E2E on AWS |
| `pull-ci-openshift-machine-config-operator-master-e2e-aws-ovn` | E2E with OVN networking |
| `pull-ci-openshift-machine-config-operator-master-verify` | Linting, vet, generated code checks |

### Periodic Jobs

| Job | What It Does |
|-----|-------------|
| `periodic-ci-openshift-machine-config-operator-master-e2e-aws` | Nightly e2e |
| `periodic-ci-openshift-machine-config-operator-master-e2e-upgrade` | Upgrade testing |

View job results at https://prow.ci.openshift.org/?repo=openshift%2Fmachine-config-operator

## Test Environment Setup

### For Unit Tests

No special environment needed beyond Go and the repo:

```bash
git clone https://github.com/openshift/machine-config-operator.git
cd machine-config-operator
make test
```

### For E2E Tests

1. **Provision a cluster**: Use `openshift-install` or cluster-bot to get a test cluster.

```bash
# Via cluster-bot in Slack
# Message @cluster-bot: launch 4.18
```

2. **Set KUBECONFIG**:

```bash
export KUBECONFIG=/path/to/kubeconfig
```

3. **Verify cluster access**:

```bash
oc get nodes
oc get mcp
oc get mc
```

4. **Run e2e tests**:

```bash
make test-e2e
```

### Resource Requirements for E2E

- E2E tests create and delete MachineConfigs, triggering node reboots
- Tests may take 30-60 minutes to complete depending on cluster size
- A minimum 3-node cluster (1 master + 2 workers) is recommended
- Some tests require multiple workers to test pool rollouts

## Writing New Tests

### Unit Test Pattern

```go
func TestMyNewFeature(t *testing.T) {
    tests := []struct {
        name     string
        input    *mcfgv1.MachineConfig
        expected bool
    }{
        {
            name:     "basic case",
            input:    helpers.NewMachineConfig("test-mc", nil, "", nil),
            expected: true,
        },
    }

    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            result := myFunction(tc.input)
            assert.Equal(t, tc.expected, result)
        })
    }
}
```

### E2E Test Pattern

```go
func TestMyE2EFeature(t *testing.T) {
    cs := framework.NewClientSet("")

    // Create a MachineConfig
    mc := &mcfgv1.MachineConfig{
        ObjectMeta: metav1.ObjectMeta{
            Name: "99-worker-test",
            Labels: map[string]string{
                "machineconfiguration.openshift.io/role": "worker",
            },
        },
        Spec: mcfgv1.MachineConfigSpec{
            Config: runtime.RawExtension{
                Raw: helpers.MarshalOrDie(ctrlcommon.NewIgnConfig()),
            },
        },
    }

    _, err := cs.MachineConfigs().Create(context.TODO(), mc, metav1.CreateOptions{})
    require.NoError(t, err)
    t.Cleanup(func() {
        cs.MachineConfigs().Delete(context.TODO(), mc.Name, metav1.DeleteOptions{})
    })

    // Wait for pool to finish updating
    err = helpers.WaitForPoolComplete(t, cs, "worker", mc.Name)
    require.NoError(t, err)

    // Verify on node
    // ...
}
```

## Debugging Test Failures

### Unit Test Failures

```bash
# Verbose output with full test logs
go test ./pkg/daemon/... -v -run TestFailing -count=1 2>&1 | tee test.log
```

### E2E Test Failures

```bash
# Check MCP status
oc get mcp -o yaml

# Check MCD logs on failing node
oc logs -n openshift-machine-config-operator -l k8s-app=machine-config-daemon --tail=100

# Check node conditions
oc get nodes -o wide
oc describe node <node-name>

# Gather must-gather for deeper analysis
oc adm must-gather --dest-dir=/tmp/must-gather
```
