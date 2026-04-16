#!/usr/bin/env bash
#
# worktree_test.sh -- Integration tests for worktree.sh
#
# Creates a temporary workspace with bare repos and submodules,
# then runs through the critical worktree scenarios.
#
# Usage:
#   ./scripts/worktree_test.sh
#

# Clear any inherited git env vars that would confuse operations
unset GIT_DIR GIT_WORK_TREE GIT_CEILING_DIRECTORIES 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKTREE_SH="${SCRIPT_DIR}/worktree.sh"
TEST_DIR=""
WORKSPACE=""
PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup() {
    TEST_DIR="$(mktemp -d)"
    echo "Test directory: ${TEST_DIR}"
    echo ""

    git config --global protocol.file.allow always 2>/dev/null || true

    for repo in repo-a repo-b; do
        git init --bare "${TEST_DIR}/remotes/${repo}.git" --quiet
        local seed="${TEST_DIR}/seed-${repo}"
        mkdir -p "${seed}"
        git -C "${seed}" init --quiet
        echo "# ${repo}" > "${seed}/README.md"
        git -C "${seed}" add README.md
        git -C "${seed}" commit -m "initial commit" --quiet
        git -C "${seed}" remote add origin "${TEST_DIR}/remotes/${repo}.git"
        git -C "${seed}" push --quiet origin main 2>/dev/null
    done

    local ws="${TEST_DIR}/workspace"
    mkdir -p "${ws}"
    git -C "${ws}" init --quiet
    git -C "${ws}" submodule add "${TEST_DIR}/remotes/repo-a.git" repo-a 2>/dev/null
    git -C "${ws}" submodule add "${TEST_DIR}/remotes/repo-b.git" repo-b 2>/dev/null
    git -C "${ws}" commit -m "add submodules" --quiet

    cp "${WORKTREE_SH}" "${ws}/worktree.sh"
    chmod +x "${ws}/worktree.sh"
    WORKSPACE="${ws}"
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "${TEST_DIR}"
    fi
}

# Run git command against a repo path
repo_git() {
    local path="$1"
    shift
    git -C "${path}" "$@"
}

# Commit a file in a worktree submodule
wt_commit() {
    local wt_path="$1"
    local filename="$2"
    local content="$3"
    local message="$4"
    echo "${content}" > "${wt_path}/${filename}"
    repo_git "${wt_path}" add "${filename}" 2>&1
    repo_git "${wt_path}" commit -m "${message}" --quiet 2>&1
}

assert_file_exists() {
    [[ -f "$1" ]] || { echo "  ASSERT FAILED: file $1 missing"; return 1; }
}

assert_commit_on_main() {
    local repo_path="$1"
    local pattern="$2"
    local log
    log="$(repo_git "${repo_path}" log --oneline main 2>/dev/null)"
    echo "${log}" | grep -q "${pattern}" || {
        echo "  ASSERT FAILED: '${pattern}' not on main in ${repo_path}"
        return 1
    }
}

run_test() {
    local test_name="$1"
    local test_func="$2"
    echo "--- ${test_name} ---"
    # Each test gets a fresh workspace to avoid inter-test interference
    teardown
    setup
    if ${test_func}; then
        echo "  PASS"
        PASS=$((PASS + 1))
    else
        echo "  FAIL"
        FAIL=$((FAIL + 1))
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_basic_create_merge() {
    local w="${WORKSPACE}"

    "${w}/worktree.sh" create basic >/dev/null 2>&1

    [[ -d "${w}/.worktrees/basic/repo-a" ]] || { echo "  repo-a worktree missing"; return 1; }
    [[ -d "${w}/.worktrees/basic/repo-b" ]] || { echo "  repo-b worktree missing"; return 1; }

    wt_commit "${w}/.worktrees/basic/repo-a" "feature.txt" "feature A" "add feature A" || return 1
    wt_commit "${w}/.worktrees/basic/repo-b" "feature.txt" "feature B" "add feature B" || return 1

    "${w}/worktree.sh" merge basic >/dev/null 2>&1

    assert_commit_on_main "${w}/repo-a" "add feature A" || return 1
    assert_commit_on_main "${w}/repo-b" "add feature B" || return 1
    assert_file_exists "${w}/repo-a/feature.txt" || return 1
    assert_file_exists "${w}/repo-b/feature.txt" || return 1

    return 0
}

test_remote_sync() {
    local w="${WORKSPACE}"

    "${w}/worktree.sh" create remote-test >/dev/null 2>&1

    # Local commit + push
    wt_commit "${w}/.worktrees/remote-test/repo-a" "local.txt" "local work" "local commit" || return 1
    repo_git "${w}/.worktrees/remote-test/repo-a" push origin wt/remote-test --quiet 2>/dev/null

    # Agent pushes extra commits via separate clone
    local agent="${TEST_DIR}/agent-clone"
    git clone "${TEST_DIR}/remotes/repo-a.git" "${agent}" --quiet 2>/dev/null
    git -C "${agent}" checkout wt/remote-test --quiet 2>/dev/null
    echo "agent 1" > "${agent}/agent1.txt"
    git -C "${agent}" add agent1.txt
    git -C "${agent}" commit -m "agent commit 1" --quiet
    echo "agent 2" > "${agent}/agent2.txt"
    git -C "${agent}" add agent2.txt
    git -C "${agent}" commit -m "agent commit 2" --quiet
    git -C "${agent}" push origin wt/remote-test --quiet 2>/dev/null
    rm -rf "${agent}"

    # Merge -- must pick up agent commits
    "${w}/worktree.sh" merge remote-test >/dev/null 2>&1

    assert_commit_on_main "${w}/repo-a" "local commit" || return 1
    assert_commit_on_main "${w}/repo-a" "agent commit 1" || return 1
    assert_commit_on_main "${w}/repo-a" "agent commit 2" || return 1
    assert_file_exists "${w}/repo-a/local.txt" || return 1
    assert_file_exists "${w}/repo-a/agent1.txt" || return 1
    assert_file_exists "${w}/repo-a/agent2.txt" || return 1

    return 0
}

test_root_repo_merge() {
    local w="${WORKSPACE}"

    "${w}/worktree.sh" create root-test >/dev/null 2>&1

    # Verify root worktree branch
    local root_branch
    root_branch=$(repo_git "${w}/.worktrees/root-test" branch --show-current 2>/dev/null)
    [[ "${root_branch}" == "wt/root-test" ]] || { echo "  expected wt/root-test, got ${root_branch}"; return 1; }

    # Commit in root repo worktree
    wt_commit "${w}/.worktrees/root-test" "DOCS.md" "# Root docs" "add root docs" || return 1

    # Commit in submodule worktree
    wt_commit "${w}/.worktrees/root-test/repo-b" "sub.txt" "sub work" "submodule work" || return 1

    # DOCS.md should NOT exist on main yet
    [[ ! -f "${w}/DOCS.md" ]] || { echo "  DOCS.md should not exist on main yet"; return 1; }

    "${w}/worktree.sh" merge root-test >/dev/null 2>&1

    assert_file_exists "${w}/DOCS.md" || return 1
    assert_commit_on_main "${w}" "add root docs" || return 1
    assert_commit_on_main "${w}/repo-b" "submodule work" || return 1
    assert_file_exists "${w}/repo-b/sub.txt" || return 1

    return 0
}

test_remove_cleanup() {
    local w="${WORKSPACE}"

    "${w}/worktree.sh" create cleanup-test >/dev/null 2>&1
    [[ -d "${w}/.worktrees/cleanup-test" ]] || { echo "  workspace should exist"; return 1; }

    "${w}/worktree.sh" remove cleanup-test >/dev/null 2>&1

    [[ ! -d "${w}/.worktrees/cleanup-test" ]] || { echo "  workspace dir should be gone"; return 1; }

    repo_git "${w}/repo-a" show-ref --verify --quiet "refs/heads/wt/cleanup-test" 2>/dev/null && \
        { echo "  wt/cleanup-test should be gone from repo-a"; return 1; }
    repo_git "${w}" show-ref --verify --quiet "refs/heads/wt/cleanup-test" 2>/dev/null && \
        { echo "  wt/cleanup-test should be gone from root"; return 1; }

    return 0
}

test_list() {
    local w="${WORKSPACE}"

    "${w}/worktree.sh" create list-a >/dev/null 2>&1
    "${w}/worktree.sh" create list-b >/dev/null 2>&1

    local output
    output=$("${w}/worktree.sh" list 2>&1)
    echo "${output}" | grep -q "list-a" || { echo "  should contain list-a"; return 1; }
    echo "${output}" | grep -q "list-b" || { echo "  should contain list-b"; return 1; }

    return 0
}

test_no_changes_merge() {
    local w="${WORKSPACE}"

    "${w}/worktree.sh" create no-changes >/dev/null 2>&1

    local output
    output=$("${w}/worktree.sh" merge no-changes 2>&1)
    echo "${output}" | grep -qi "no changes\|skipping" || { echo "  should report skipping"; return 1; }

    return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

trap teardown EXIT

echo "========================================="
echo " worktree.sh integration tests"
echo "========================================="
echo ""

run_test "Basic create + commit + merge"        test_basic_create_merge
run_test "Remote sync (agent push scenario)"     test_remote_sync
run_test "Root repo branch merge"                test_root_repo_merge
run_test "Remove + cleanup"                      test_remove_cleanup
run_test "List workspaces"                       test_list
run_test "Merge with no changes"                 test_no_changes_merge

echo "========================================="
echo " Results: ${PASS} passed, ${FAIL} failed"
echo "========================================="

[[ ${FAIL} -eq 0 ]]
