# CI Integration with PRs

## CI System Overview

OpenShift uses Prow for CI orchestration. Jobs are defined in the
`openshift/release` repo under `ci-operator/config/` and `ci-operator/jobs/`.

Jobs run on ephemeral OpenShift clusters provisioned for each test run.

## Required CI Jobs by Repo

### openshift/machine-config-operator

| Job | What It Tests | Required |
|-----|---------------|----------|
| `ci/prow/unit` | Unit tests (`make test`) | Yes |
| `ci/prow/e2e-agnostic` | Platform-agnostic e2e tests | Yes |
| `ci/prow/e2e-aws` | Full e2e on AWS | Yes |
| `ci/prow/verify` | Linters, generated code, vendor | Yes |
| `ci/prow/e2e-aws-upgrade` | Upgrade tests on AWS | Yes |
| `ci/prow/e2e-gcp` | Full e2e on GCP | Optional |
| `ci/prow/images` | Container image build | Yes |

### openshift/kubernetes

| Job | What It Tests | Required |
|-----|---------------|----------|
| `ci/prow/unit` | Kubernetes unit tests | Yes |
| `ci/prow/e2e-aws` | Kubernetes e2e on AWS | Yes |
| `ci/prow/verify` | Verify scripts | Yes |
| `ci/prow/e2e-aws-serial` | Serial e2e tests | Yes |
| `ci/prow/e2e-aws-upgrade` | Upgrade path tests | Optional |

### openshift/cri-o

| Job | What It Tests | Required |
|-----|---------------|----------|
| `ci/prow/unit` | Unit tests | Yes |
| `ci/prow/e2e-agnostic` | e2e tests | Yes |
| `ci/prow/verify` | Linters, format checks | Yes |
| `ci/prow/images` | Image build | Yes |

### cri-o/cri-o (upstream)

Uses GitHub Actions and Cirrus CI, not Prow. Check the upstream `.github/`
directory for workflow definitions.

## Understanding Job Status on PRs

### Status Icons

| Icon | Meaning |
|------|---------|
| Green check | Job passed |
| Red X | Job failed |
| Yellow circle | Job pending / running |
| Grey dash | Job skipped or not triggered |

### Status Context

Each job reports as a GitHub status check. The check name maps to the Prow
job name. Click the "Details" link to go to the Prow job page.

### Prow Job Page

The Prow job page shows:
- **Build log**: Full console output.
- **Artifacts**: Test results, junit XML, must-gather from failed clusters.
- **Metadata**: Job config, cluster info, timing.

Artifacts are stored in GCS. The "Artifacts" link on the Prow page leads to
the GCS bucket browser.

## Retest Commands

### `/retest`

Reruns all failed **required** jobs. Use this when:
- A job failed due to infrastructure flake (not your code).
- You pushed a fix and want to revalidate.

```
/retest
```

### `/test <job-name>`

Runs a specific job. Use for optional jobs or to target one job:

```
/test e2e-aws
/test unit
/test verify
```

The job name is the short suffix, not the full Prow job name. Check the
repo's Prow config if unsure.

### `/retest-required`

Reruns all required jobs, even those that passed. Rarely needed.

## `/override` for Stuck Jobs

Sometimes a required job is broken infrastructure-wide (not related to your
PR). Admins or repo maintainers can override:

```
/override ci/prow/e2e-aws
```

This marks the job as passing without rerunning it. Use only when:
- The job is known-broken across all PRs (check other open PRs).
- There's a tracking issue for the CI breakage.
- You've confirmed the failure is unrelated to your change.

Override requires admin permissions in the repo.

## Reading Test Results

### JUnit Artifacts

Most jobs produce JUnit XML files. These are parsed by Prow and shown in the
job summary. Look for:
- Test name and failure message.
- Stack traces or log snippets in the failure output.

### Spyglass Views

Prow's Spyglass UI provides:
- **JUnit**: Parsed test results with pass/fail/skip counts.
- **Build log**: Full output, searchable.
- **Metadata**: Job parameters and timing.

### Must-Gather from Failed E2E

When an e2e job fails, the cluster's must-gather is often saved as an
artifact. Download it to inspect:
- Pod logs
- Events
- Node status
- Operator conditions

Look in the artifacts directory for `must-gather/` or `artifacts/`.

## CI Broken vs Your PR Has Issues

### Signs of Infrastructure Failure (Not Your Fault)

- Same job fails on multiple unrelated PRs.
- Failure is in cluster provisioning, not test execution.
- Error messages reference cloud quota, image pull failures, or DNS issues.
- The failure is in a test that your PR doesn't touch.

Check the CI health dashboard or ask in `#forum-ocp-crt` Slack channel.

### Signs Your PR Broke Something

- Only your PR has this failure; other PRs pass the same job.
- The failing test is related to code you changed.
- The failure is in unit tests or in the verify step.
- The error message references your code or config.

### Flaky Tests

Some e2e tests are flaky. To distinguish flake from real failure:
1. Check if the test is in the known-flaky list.
2. `/retest` once -- if it passes, likely a flake.
3. If it fails consistently (2-3 runs), investigate.

Report new flakes by opening an issue in `openshift/release` or the test's
owning repo.

## CI Configuration

### Where Jobs Are Defined

```
openshift/release/
  ci-operator/config/<org>/<repo>/         # ci-operator config
  ci-operator/jobs/<org>/<repo>/           # generated Prow job YAML
  core-services/prow/02_config/           # Prow core config
```

### Modifying CI Jobs

To add or change a CI job for a node repo:
1. Edit the ci-operator config in `openshift/release`.
2. Run `make jobs` to regenerate Prow job YAML.
3. Open a PR against `openshift/release`.
4. The release repo has its own review and CI process.

### Rehearsal Jobs

When you change CI config in `openshift/release`, Prow runs "rehearsal" jobs
to validate the new config against a real PR in the target repo. This
catches config errors before merge.

## Useful Links

| Resource | URL |
|----------|-----|
| Prow dashboard | https://prow.ci.openshift.org |
| CI search | https://search.ci.openshift.org |
| Job history | https://prow.ci.openshift.org/job-history/ |
| CI docs | https://docs.ci.openshift.org |
| Test grid | https://testgrid.k8s.io/redhat |
