# Kueue Operator Testing

## Unit Tests

### Run All Unit Tests

```bash
cd ~/go/src/github.com/openshift/kueue-operator
make test
```

This runs unit tests using `go test` with the envtest framework for controller tests.

### Run Specific Tests

```bash
go test ./controllers/... -v -run TestKueueReconciler
go test ./api/... -v
```

### Run with Race Detector

```bash
go test ./... -race
```

### Run with Verbose Output

```bash
make test TESTARGS="-v"
```

## envtest Setup

The Kueue operator uses `envtest` from controller-runtime for testing controllers without a full cluster. envtest runs a local API server and etcd.

### How envtest Works

1. Downloads and runs a local `kube-apiserver` and `etcd`
2. Installs CRDs into the local API server
3. Runs controller reconciliation loops against the local API server
4. Tests verify the controller creates/updates expected resources

### envtest Binaries

The Makefile automatically downloads envtest binaries. To do it manually:

```bash
# Setup envtest
go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest

# Download binaries for a specific K8s version
setup-envtest use 1.29.x

# List available versions
setup-envtest list

# Get the path to envtest assets
setup-envtest use 1.29.x -p path
```

### Writing Controller Tests with envtest

```go
var _ = Describe("Kueue Controller", func() {
    Context("When reconciling a Kueue resource", func() {
        It("should create the Kueue controller manager deployment", func() {
            // Create a Kueue CR
            kueue := &kueuev1alpha1.Kueue{
                ObjectMeta: metav1.ObjectMeta{
                    Name:      "test-kueue",
                    Namespace: "default",
                },
                Spec: kueuev1alpha1.KueueSpec{
                    // spec fields
                },
            }
            Expect(k8sClient.Create(ctx, kueue)).Should(Succeed())

            // Verify the controller creates the expected deployment
            Eventually(func() bool {
                dep := &appsv1.Deployment{}
                err := k8sClient.Get(ctx, types.NamespacedName{
                    Name:      "kueue-controller-manager",
                    Namespace: "kueue-system",
                }, dep)
                return err == nil
            }, timeout, interval).Should(BeTrue())
        })
    })
})
```

### Test Suite Setup

```go
var (
    k8sClient  client.Client
    testEnv    *envtest.Environment
    ctx        context.Context
    cancel     context.CancelFunc
)

var _ = BeforeSuite(func() {
    testEnv = &envtest.Environment{
        CRDDirectoryPaths:     []string{filepath.Join("..", "config", "crd", "bases")},
        ErrorIfCRDPathMissing: true,
    }

    cfg, err := testEnv.Start()
    Expect(err).NotTo(HaveOccurred())

    // Setup scheme, client, controller manager...
})

var _ = AfterSuite(func() {
    cancel()
    Expect(testEnv.Stop()).To(Succeed())
})
```

## E2E Tests

### Prerequisites

- A running OCP cluster
- `KUBECONFIG` set to a cluster-admin kubeconfig
- The operator image built and accessible

### Run E2E Tests

```bash
make test-e2e
```

### Run Specific E2E Tests

```bash
make test-e2e TESTARGS="-v -run TestKueueDeployment"
```

### E2E Test Structure

E2E tests in `test/e2e/` verify:

1. Operator deploys successfully
2. Kueue CR triggers Kueue controller deployment
3. ClusterQueue, LocalQueue, and ResourceFlavor CRDs are functional
4. Workload admission works end-to-end
5. Operator handles updates and upgrades

### Example E2E Test Flow

```go
func TestKueueE2E(t *testing.T) {
    // 1. Deploy the operator
    // 2. Create a Kueue CR
    kueue := &kueuev1alpha1.Kueue{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "kueue",
            Namespace: operatorNamespace,
        },
    }
    _, err := kueueClient.Create(context.TODO(), kueue, metav1.CreateOptions{})
    require.NoError(t, err)

    // 3. Wait for Kueue controller to be ready
    waitForDeploymentReady(t, "kueue-system", "kueue-controller-manager")

    // 4. Create a ClusterQueue
    cq := &kueuev1beta1.ClusterQueue{
        ObjectMeta: metav1.ObjectMeta{Name: "test-cq"},
        Spec: kueuev1beta1.ClusterQueueSpec{
            ResourceGroups: []kueuev1beta1.ResourceGroup{{
                CoveredResources: []corev1.ResourceName{"cpu", "memory"},
                Flavors: []kueuev1beta1.FlavorQuotas{{
                    Name: "default-flavor",
                    Resources: []kueuev1beta1.ResourceQuota{
                        {Name: "cpu", NominalQuota: resource.MustParse("4")},
                        {Name: "memory", NominalQuota: resource.MustParse("8Gi")},
                    },
                }},
            }},
        },
    }

    // 5. Create a LocalQueue and submit a job
    // 6. Verify the job is admitted and runs
    // 7. Cleanup
}
```

## CI Jobs

### Pre-submit (PR) Jobs

| Job | What It Does |
|-----|-------------|
| `pull-ci-openshift-kueue-operator-master-unit` | Unit tests |
| `pull-ci-openshift-kueue-operator-master-e2e` | E2E tests on OCP |
| `pull-ci-openshift-kueue-operator-master-verify` | Linting, vet, generated code |
| `pull-ci-openshift-kueue-operator-master-images` | Image build verification |

### Periodic Jobs

| Job | What It Does |
|-----|-------------|
| `periodic-ci-openshift-kueue-operator-master-e2e` | Nightly e2e |

View results at https://prow.ci.openshift.org/?repo=openshift%2Fkueue-operator

### CI Configuration

CI jobs are defined in the `openshift/release` repo under:

```
ci-operator/config/openshift/kueue-operator/
ci-operator/jobs/openshift/kueue-operator/
```

## Linting and Static Analysis

```bash
# Run go vet
go vet ./...

# Run golangci-lint (if configured)
golangci-lint run

# Verify generated code is up to date
make verify
```

## Debugging Test Failures

### Unit Test Failures

```bash
# Verbose output
go test ./controllers/... -v -run TestFailing -count=1 2>&1 | tee test.log

# With envtest debug logging
KUBEBUILDER_ASSETS=$(setup-envtest use 1.29.x -p path) \
  go test ./controllers/... -v -run TestFailing
```

### E2E Test Failures

```bash
# Check operator logs
oc logs -n openshift-kueue-operator deployment/kueue-operator-controller-manager --tail=200

# Check Kueue controller logs
oc logs -n kueue-system deployment/kueue-controller-manager --tail=200

# Check Kueue CR status
oc get kueue -o yaml

# Check events
oc get events -n openshift-kueue-operator --sort-by='.lastTimestamp'
oc get events -n kueue-system --sort-by='.lastTimestamp'

# Gather must-gather
oc adm must-gather --dest-dir=/tmp/must-gather
```
