# Prow Job Configuration

## Config Repository

All OpenShift CI job configuration lives in the `openshift/release` repository:

```
https://github.com/openshift/release
```

## Directory Structure

```
openshift/release/
  ci-operator/
    config/
      openshift/
        kubernetes/                    # Kubelet/K8s jobs
          openshift-kubernetes-master.yaml
          openshift-kubernetes-release-4.16.yaml
        machine-config-operator/       # MCO jobs
          openshift-machine-config-operator-master.yaml
        origin/                        # openshift-tests jobs
          openshift-origin-master.yaml
      cri-o/
        cri-o/                         # CRI-O jobs
          cri-o-cri-o-main.yaml
    jobs/                              # Generated Prow job YAML (do not edit directly)
    step-registry/                     # Reusable test steps, chains, workflows
      openshift/
        e2e/
          test/                        # e2e test step definitions
        install/                       # Cluster install steps
```

## ci-operator Concepts

`ci-operator` is the test orchestrator that Prow jobs invoke. It handles image building, cluster provisioning, and test execution.

### Key Concepts

| Concept | Description |
|---|---|
| **Config** | YAML in `ci-operator/config/` defining images, tests, and promotion |
| **Step** | A single container execution (a test command, a setup script) |
| **Chain** | Ordered sequence of steps |
| **Workflow** | A complete test pattern: pre (setup) + test (execution) + post (teardown) |
| **Step Registry** | Reusable library of steps/chains/workflows in `step-registry/` |

### Config File Structure

```yaml
# ci-operator/config/openshift/machine-config-operator/openshift-machine-config-operator-master.yaml
base_images:
  os:
    name: ubi
    namespace: ocp
    tag: "9"
build_root:
  image_stream_tag:
    name: release
    namespace: openshift
    tag: golang-1.21
images:
  - from: os
    to: machine-config-operator
tests:
  - as: unit
    commands: make test
    container:
      from: src
  - as: e2e-aws
    steps:
      cluster_profile: aws
      workflow: openshift-e2e-aws
  - as: e2e-aws-ovn
    steps:
      cluster_profile: aws
      workflow: openshift-e2e-aws-ovn
```

### Test Definitions

Tests can be defined in two ways:

**Container tests** (unit tests, linting):
```yaml
tests:
  - as: unit
    commands: make test
    container:
      from: src
      memory_backed_volume:
        size: 4Gi
```

**Multi-stage tests** (e2e, requiring a cluster):
```yaml
tests:
  - as: e2e-aws
    steps:
      cluster_profile: aws
      workflow: openshift-e2e-aws
      test:
        - as: test
          cli: latest
          commands: |
            openshift-tests run openshift/conformance/parallel \
              --provider aws \
              --junit-dir ${ARTIFACT_DIR}/junit
          from: tests
          resources:
            requests:
              cpu: "1"
              memory: 2Gi
```

## Multi-Stage Test Workflows

### Workflow Structure

```
workflow: openshift-e2e-aws
  pre:
    - ipi-install-hosted       # Provision cluster
    - openshift-e2e-test-pre   # Pre-test setup
  test:
    - openshift-e2e-test       # Run tests
  post:
    - openshift-e2e-test-post  # Collect artifacts
    - ipi-deprovision          # Tear down cluster
```

### Step Registry Location

```
ci-operator/step-registry/
  openshift/
    e2e/
      test/
        openshift-e2e-test-ref.yaml       # Step definition
        openshift-e2e-test-commands.sh     # Script to run
    install/
      install/
        openshift-install-install-chain.yaml  # Install chain
```

### Step Definition Example

```yaml
# openshift-e2e-test-ref.yaml
ref:
  as: openshift-e2e-test
  from: tests
  commands: openshift-e2e-test-commands.sh
  resources:
    requests:
      cpu: "3"
      memory: 600Mi
  documentation: Runs the OpenShift e2e test suite
```

## Node Team Job Examples

### Adding a New Unit Test Job

```yaml
# In ci-operator/config/openshift/machine-config-operator/openshift-machine-config-operator-master.yaml
tests:
  - as: unit
    commands: make test
    container:
      from: src
```

### Adding a New E2E Job

```yaml
tests:
  - as: e2e-aws-node-tests
    steps:
      cluster_profile: aws
      workflow: openshift-e2e-aws
      test:
        - as: test
          cli: latest
          commands: |
            openshift-tests run openshift/conformance/parallel \
              --dry-run | grep '\[sig-node\]' | \
              openshift-tests run -f - \
              --junit-dir ${ARTIFACT_DIR}/junit
          from: tests
          resources:
            requests:
              cpu: "1"
              memory: 2Gi
```

### Adding a Periodic Job

Add `cron` field to a test config, or define in `ci-operator/jobs/` (generated -- use `make jobs` after editing config).

```yaml
tests:
  - as: e2e-aws-serial-nightly
    cron: "0 4 * * *"   # 4 AM daily
    steps:
      cluster_profile: aws
      workflow: openshift-e2e-aws-serial
```

## Adding New CI Jobs -- Process

1. **Edit the config file** in `ci-operator/config/<org>/<repo>/`
2. **Regenerate jobs**: `make jobs` from `openshift/release` root
3. **Test locally** (optional): `ci-operator --config=<path> --target=<test-name>`
4. **Open a PR** to `openshift/release`
5. **Rehearsal jobs** will automatically run your new/modified job config
6. **Merge** -- DPTP team or repo approvers review and approve

## Cluster Profiles

Cluster profiles define cloud credentials and configuration for test clusters:

| Profile | Cloud | Notes |
|---|---|---|
| `aws` | AWS | Standard AWS account |
| `aws-2` | AWS | Secondary account for parallel jobs |
| `gcp` | GCP | Standard GCP project |
| `azure4` | Azure | Azure subscription |
| `vsphere` | vSphere | On-prem vSphere |
| `packet` | Equinix Metal | Bare metal |

## Useful Commands

```bash
# Clone the release repo
git clone https://github.com/openshift/release.git
cd release

# Regenerate job configs from ci-operator configs
make jobs

# Validate config
make ci-operator-config

# Find all jobs for a repo
grep -r "machine-config-operator" ci-operator/jobs/
```
