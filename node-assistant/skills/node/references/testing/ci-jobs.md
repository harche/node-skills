# CI/Prow Jobs for Node Components

## Overview

OpenShift uses Prow as its CI system, operated by the DPTP (Developer Productivity and Tools Program) team. All CI configuration lives in the `openshift/release` repository. Prow jobs build, test, and validate every PR and periodically run against release branches.

## Job Types

### Presubmit Jobs

Run on every PR update. Must pass before merge (unless overridden). Triggered by PR push events.

```
# Naming convention
pull-ci-<org>-<repo>-<branch>-<job-name>
# Example
pull-ci-openshift-machine-config-operator-master-e2e-aws
```

### Postsubmit Jobs

Run after a PR merges. Used for image builds, release payloads, and post-merge validation.

```
# Naming convention
branch-ci-<org>-<repo>-<branch>-<job-name>
```

### Periodic Jobs

Run on a schedule (cron). Used for nightly testing, release qualification, and long-running suites.

```
# Naming convention
periodic-ci-<org>-<repo>-<branch>-<job-name>
```

## Node Team Relevant Jobs

### Kubelet / Kubernetes

| Job | What It Tests |
|---|---|
| `pull-ci-openshift-kubernetes-master-e2e-aws` | Full e2e suite on AWS |
| `pull-ci-openshift-kubernetes-master-e2e-gcp` | Full e2e suite on GCP |
| `pull-ci-openshift-kubernetes-master-node-e2e` | Kubernetes node e2e tests |
| `pull-ci-openshift-kubernetes-master-unit` | All Kubernetes unit tests |
| `periodic-ci-openshift-kubernetes-master-e2e-aws-serial` | Serial e2e on AWS (nightly) |

### Machine Config Operator

| Job | What It Tests |
|---|---|
| `pull-ci-openshift-machine-config-operator-master-unit` | MCO unit tests |
| `pull-ci-openshift-machine-config-operator-master-e2e-aws` | MCO e2e on AWS |
| `pull-ci-openshift-machine-config-operator-master-e2e-aws-ovn` | MCO e2e with OVN networking |
| `pull-ci-openshift-machine-config-operator-master-e2e-upgrade` | Upgrade testing |
| `periodic-ci-openshift-machine-config-operator-master-e2e-aws-serial` | Serial e2e (nightly) |

### CRI-O

| Job | What It Tests |
|---|---|
| `pull-ci-cri-o-cri-o-main-test` | CRI-O unit tests |
| `pull-ci-cri-o-cri-o-main-integration` | CRI-O integration + critest |
| `pull-ci-cri-o-cri-o-main-e2e-aws` | CRI-O e2e on AWS (OpenShift) |
| `periodic-ci-cri-o-cri-o-main-e2e-aws-serial` | Serial e2e (nightly) |

### Node-Relevant Cross-Repo Jobs

| Job | What It Tests |
|---|---|
| `periodic-ci-openshift-release-master-nightly-4.x-e2e-aws` | Full nightly e2e |
| `periodic-ci-openshift-release-master-nightly-4.x-e2e-aws-serial` | Full nightly serial e2e |
| `periodic-ci-openshift-release-master-nightly-4.x-upgrade-from-stable-4.y` | Upgrade from previous version |
| `periodic-ci-openshift-release-master-ci-4.x-e2e-aws-ovn-node` | Node-focused e2e subset |

## Understanding Job Results

### Prow Dashboard

All job results are visible at:
- **PR jobs**: `https://prow.ci.openshift.org/pr/<org>/<repo>/<pr-number>`
- **All jobs for a PR**: linked from the GitHub PR status checks
- **Periodic jobs**: `https://prow.ci.openshift.org/?type=periodic&job=<job-name>`

### Job States

| State | Meaning |
|---|---|
| `success` | All tests passed |
| `failure` | One or more tests failed |
| `error` | Infrastructure error (not a test failure) |
| `aborted` | Job was cancelled (superseded by newer run or manual abort) |
| `pending` | Job is queued, waiting for cluster resources |

### Artifacts

Each job run produces artifacts stored in GCS:
- `build-log.txt` -- full job output
- `artifacts/` -- test-specific outputs
  - `junit/` -- JUnit XML results
  - `must-gather/` -- cluster state dump on failure
  - `audit-logs/` -- API server audit logs
  - `pods/` -- pod logs from the test namespace

## Job Lifecycle in a PR

1. Developer pushes commits to PR
2. Prow triggers configured presubmit jobs
3. `ci-operator` provisions a test cluster (for e2e jobs) or runs in a pod (for unit tests)
4. Tests execute, results reported back to GitHub
5. Required jobs must pass for the `tide` merge bot to merge
6. Optional jobs show status but don't block merge

## Identifying Required vs Optional Jobs

Required jobs are configured in the repo's OWNERS or Prow config:
- Check the GitHub PR: required jobs show "Required" next to the status check
- In Prow config: `always_run: true` + not in `optional` list = required

## Job Retrigger Commands

See [Retrigger CI Jobs](ci/retrigger.md) for commands to rerun, override, or manage CI jobs.

## Sub-References

- [Prow Configuration](ci/prow-config.md) -- how jobs are configured in openshift/release
- [Debugging CI Failures](ci/debugging-ci.md) -- finding logs, artifacts, identifying flakes
- [Retriggering CI Jobs](ci/retrigger.md) -- bot commands for rerunning and overriding jobs
