# Debugging CI Failures

## Finding Job Results in Prow

### From a PR

1. Go to the PR on GitHub
2. Scroll to the status checks section at the bottom
3. Click "Details" next to a failed job to open the Prow job page
4. The Prow page links to build logs, artifacts, and job history

### Direct Prow URL

```
# PR jobs
https://prow.ci.openshift.org/pr/<org>/<repo>/<pr-number>

# Specific job run
https://prow.ci.openshift.org/view/gs/test-platform-results/pr-logs/pull/<org>_<repo>/<pr-number>/<job-name>/<run-id>

# Periodic jobs
https://prow.ci.openshift.org/?type=periodic&job=periodic-ci-openshift-release-master-nightly-4.16-e2e-aws
```

### Searching Jobs

```
# All recent runs of a job
https://prow.ci.openshift.org/?job=pull-ci-openshift-machine-config-operator-master-e2e-aws

# Filter by state
https://prow.ci.openshift.org/?job=<job-name>&state=failure
```

## Reading Build Logs

### Log Structure

The build log (`build-log.txt`) contains:

1. **ci-operator setup** -- image builds, dependency resolution
2. **Cluster provisioning** (for e2e jobs) -- install logs, cluster creation
3. **Test execution** -- actual test output
4. **Teardown** -- cluster deprovisioning, artifact upload

### Navigating Large Logs

Search for these markers in the build log:

| Marker | What Follows |
|---|---|
| `Running step` | Start of a multi-stage step |
| `failed:` | Failure point |
| `error:` | Error messages |
| `FAIL` | Individual test failure |
| `Failing tests:` | Summary of failed tests (openshift-tests) |
| `JUnit report` | Path to JUnit artifacts |

### Quick Log Analysis

```bash
# Download build log via gsutil
gsutil cat gs://test-platform-results/pr-logs/pull/<org>_<repo>/<pr>/<job>/<run>/build-log.txt

# Or use the Prow artifacts link and navigate to build-log.txt
```

## Artifacts

Every job run uploads artifacts to GCS. Access them via the Prow job page under "Artifacts."

### Common Artifact Locations

```
artifacts/
  <test-name>/
    build-log.txt                    # Step-level logs
    junit/
      junit_e2e_*.xml               # JUnit test results
    must-gather/
      event-filter.html             # Searchable cluster events
      cluster-scoped-resources/     # Cluster state dump
      namespaces/                   # Per-namespace resources
    audit-logs/
      kube-apiserver/               # API audit logs
    pods/
      openshift-machine-config-operator/  # MCO pod logs
      openshift-kube-apiserver/           # API server pod logs
```

### must-gather Analysis

The `must-gather` artifact is the most useful for node debugging. It contains:

- Node descriptions: `cluster-scoped-resources/core/nodes/`
- Machine configs: `cluster-scoped-resources/machineconfiguration.openshift.io/`
- Pod logs from all openshift namespaces
- Events filtered by severity

```bash
# Download must-gather from artifacts
# Look for node conditions
cat cluster-scoped-resources/core/nodes/<node>.yaml | grep -A5 conditions

# Check MCO state
cat cluster-scoped-resources/machineconfiguration.openshift.io/machineconfigpools/worker.yaml
```

### JUnit Analysis

```bash
# List failed tests from JUnit
xmllint --xpath '//testcase[failure]/@name' junit_e2e_*.xml

# Get failure messages
xmllint --xpath '//testcase[failure]/failure/@message' junit_e2e_*.xml
```

## CI Infrastructure Failures vs Real Test Failures

### Infrastructure Failures

These are not your fault. Common signs:

| Symptom | Cause | Action |
|---|---|---|
| `error creating cluster` in provisioning step | Cloud quota or API issue | Retest (`/retest`) |
| `context deadline exceeded` during install | Cluster install timed out | Retest |
| `could not resolve host` | DNS/network issue in CI | Retest |
| `failed to pull image` from CI registry | Registry outage | Retest, check CI status |
| Job stuck in `pending` for hours | Cluster pool exhaustion | Wait or retest later |
| `lease not acquired` | No cloud credentials available | Wait and retest |

### Real Test Failures

Indicators that the failure is caused by your change:

- The failing test is related to the code you changed
- The test passes on the base branch (check job history)
- Multiple runs fail with the same test
- The failure message references behavior your PR modifies

## Flaky Test Identification

### Check Test History

1. **Search.ci**: `https://search.ci.openshift.org/` -- search for test names across all job runs
2. **Sippy**: `https://sippy.dptools.openshift.org/` -- test pass rate dashboard
3. **Component Readiness**: tracks per-component test health across releases

### Using search.ci

```
# Search for a specific test failure
https://search.ci.openshift.org/?search=<test+name>&type=junit

# Filter by job
https://search.ci.openshift.org/?search=<test+name>&job=<job-name>
```

### Identifying a Flake

A test is flaky if:
- It fails intermittently across unrelated PRs
- It has a pass rate below 100% on the base branch
- The failure is non-deterministic (different error each time)
- It passes on retest without code changes

### Reporting Flakes

1. Search for an existing bug in Jira: `project = OCPBUGS AND summary ~ "<test name>" AND component = "Node"`
2. If none exists, file a new bug with:
   - Component: `Node` (or `Machine Config Operator`, `CRI-O`)
   - Summary: `[Flake] <test name>`
   - Links to failed job runs
   - Pass rate from Sippy

## TestGrid for Job Health Overview

TestGrid provides a dashboard view of job pass/fail history:

```
https://testgrid.k8s.io/redhat-openshift-ocp-release-4.16-informing
https://testgrid.k8s.io/redhat-openshift-ocp-release-4.16-blocking
```

### Node-Relevant Dashboards

- `redhat-openshift-ocp-release-4.x-informing` -- informing periodic jobs
- `redhat-openshift-ocp-release-4.x-blocking` -- blocking periodic jobs (gate releases)

### Reading TestGrid

- **Green squares**: passing runs
- **Red squares**: failing runs
- **Orange squares**: flaky (some tests failed)
- Click a cell to see the specific job run and failing tests
- Look for patterns: consistent red = regression, intermittent red = flake

## Debugging Workflow Summary

1. **Click the failed check** on the PR to open Prow
2. **Check if infrastructure failure** -- look at setup/provisioning logs
3. **Find the test failure** -- search for `FAIL` or `Failing tests:` in build-log.txt
4. **Check artifacts** -- JUnit for failure details, must-gather for cluster state
5. **Check test history** -- search.ci or Sippy to see if it is a known flake
6. **If flake** -- `/retest` and file/update a bug
7. **If real** -- investigate using failure message, node logs from must-gather, and your code change
