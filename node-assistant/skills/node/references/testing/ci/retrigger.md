# Retriggering CI Jobs

## Basic Commands

All commands are issued as PR comments on GitHub. Prow bot processes them and triggers the corresponding actions.

### Retest Failed Jobs

```
/retest
```

Reruns all failed required presubmit jobs. Does not rerun passed or optional jobs.

### Run a Specific Job

```
/test <job-name>
```

Triggers a specific job by its short name (the `as` field in ci-operator config, not the full Prow job name).

```
# Examples
/test unit
/test e2e-aws
/test e2e-aws-ovn
/test e2e-aws-serial
```

### Override a Failed Required Job

```
/override <job-name>
```

Marks a failed required job as passed so the PR can merge. Requires approval from a member with override permissions (typically leads or DPTP).

```
# Example
/override ci/prow/e2e-aws
```

Use overrides sparingly -- only for confirmed infrastructure failures or known flakes with tracked bugs.

### Retest All Jobs

```
/test all
```

Reruns all configured presubmit jobs (passed and failed). Use this when you want a completely fresh CI run.

## Bot Commands for PR Management

### Labels

```
/lgtm              # Add lgtm label (reviewer approval)
/approve            # Add approved label (approver approval)
/hold               # Prevent merge (adds do-not-merge/hold)
/unhold             # Remove hold
/cc @username       # Request review from someone
/uncc @username     # Remove review request
```

### Priority and Triage

```
/priority critical-urgent     # Set priority
/kind bug                     # Label as bug fix
/kind feature                 # Label as feature
/sig node                     # Assign to sig-node
```

### Cherry-Pick

```
/cherry-pick release-4.16     # Create a cherry-pick PR to release-4.16
```

### Merge Control

```
/lgtm cancel        # Remove lgtm
/approve cancel      # Remove approval
/retest              # Rerun failed jobs
```

## When to Retest vs Investigate

### Retest When

- The failure is in cluster provisioning or teardown (infrastructure issue)
- The failing test is a known flake (check search.ci or Sippy)
- The failure is unrelated to your change (different component, different test area)
- The error message indicates CI infrastructure problems (DNS, registry, quota)
- A single run failed but other identical jobs passed

### Investigate When

- The failing test is directly related to your code change
- Multiple retests produce the same failure
- The test has a high pass rate on the base branch (not a known flake)
- The failure message references behavior your PR modifies
- A new test you added is failing

### Decision Process

```
1. Job failed
2. Is it an infrastructure error?
   Yes -> /retest
   No  -> Continue
3. Is the failing test related to my change?
   No  -> Check if known flake (search.ci)
          Known flake -> /retest, file/update bug
          Unknown     -> Investigate briefly, likely /retest
   Yes -> Investigate and fix
4. After 2 retests with same failure -> Investigate regardless
```

## Advanced Triggering

### Running Optional Jobs

Optional jobs don't run automatically. Trigger them explicitly:

```
/test <optional-job-name>
```

### Running Jobs After Config Changes

If you modified CI configuration in `openshift/release`, rehearsal jobs run automatically on your PR to test the new config. These appear as:

```
pull-ci-openshift-release-master-ci-operator-config-change-rehearse-<job>
```

### Cancelling a Running Job

There is no direct command to cancel a running job. Options:
- Push a new commit (supersedes the current run for presubmit jobs)
- Wait for it to finish or time out
- Ask DPTP in `#forum-ocp-testplatform` Slack channel

## Rate Limits and Etiquette

- Do not spam `/retest` -- if it fails twice with the same error, investigate
- Use `/test <specific-job>` instead of `/test all` when only one job needs rerunning
- Overrides should be exceptional, not routine -- track the underlying issue
- If CI is broadly broken, check `#forum-ocp-testplatform` before retesting repeatedly
- Peak CI hours (US morning) may cause longer queue times -- retesting adds to the load

## Checking Job Status

```bash
# Use gh to check PR status
gh pr checks <pr-number> --repo openshift/machine-config-operator

# Check specific job history
# Visit: https://prow.ci.openshift.org/?job=<full-job-name>
```
