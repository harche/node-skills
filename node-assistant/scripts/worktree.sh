#!/usr/bin/env bash
#
# worktree.sh -- Multi-repo worktree manager
#
# Creates and manages isolated workspaces across git submodules so you
# can work on features that span multiple repos simultaneously.
#
# Works with any repo that has git submodules -- submodules are discovered
# dynamically from .gitmodules, not hardcoded.
#
# Usage:
#   ./worktree.sh sync                 Fetch and update all submodules
#   ./worktree.sh create <name>        Create a new workspace
#   ./worktree.sh merge <name>         Merge workspace branches back
#   ./worktree.sh remove <name>        Remove a workspace
#   ./worktree.sh list                 List active workspaces
#   ./worktree.sh --help               Show this help

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}"
WORKTREE_DIR="${ROOT_DIR}/.worktrees"
BRANCH_PREFIX="wt"

# ---------------------------------------------------------------------------
# Colors and output helpers
# ---------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${BLUE}[info]${RESET}  $*"; }
success() { echo -e "${GREEN}[ok]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[warn]${RESET}  $*"; }
error()   { echo -e "${RED}[error]${RESET} $*" >&2; }

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_sync() {
    info "Syncing all submodules to latest remote..."

    # Fetch root repo
    info "Fetching root repo..."
    git -C "${ROOT_DIR}" fetch --quiet 2>/dev/null || true

    # Init submodules (ensures .git dirs exist before we fetch)
    git -C "${ROOT_DIR}" submodule update --init --quiet

    # Each submodule: fetch, checkout its tracked branch, fast-forward if clean
    git -C "${ROOT_DIR}" submodule foreach --quiet '
        tracked=$(git config -f "$toplevel/.gitmodules" --get "submodule.$name.branch" 2>/dev/null || echo "main")
        git fetch --quiet origin 2>/dev/null || true
        git checkout "$tracked" --quiet 2>/dev/null || git checkout -b "$tracked" "origin/$tracked" --quiet 2>/dev/null || true

        # Only fast-forward -- never rebase/merge to avoid conflict loops
        if git merge-base --is-ancestor HEAD "origin/$tracked" 2>/dev/null; then
            echo "  $sm_path: fast-forwarding $tracked..."
            git merge --ff-only --quiet "origin/$tracked" 2>/dev/null || true
        elif git merge-base --is-ancestor "origin/$tracked" HEAD 2>/dev/null; then
            echo "  $sm_path: already ahead of origin/$tracked (local commits), skipping pull"
        else
            echo "  $sm_path: WARNING — diverged from origin/$tracked, skipping pull (resolve manually)"
        fi
    '

    success "All submodules synced."
}

cmd_create() {
    local name="${1:-}"
    if [[ -z "${name}" ]]; then
        error "Usage: worktree.sh create <name>"
        exit 1
    fi

    local workspace_dir="${WORKTREE_DIR}/${name}"
    if [[ -d "${workspace_dir}" ]]; then
        error "Workspace '${name}' already exists at ${workspace_dir}"
        error "Remove it first with: ./worktree.sh remove ${name}"
        exit 1
    fi

    info "Creating workspace ${BOLD}${name}${RESET} ..."

    local branch="${BRANCH_PREFIX}/${name}"

    # Create root repo worktree (this also creates the workspace directory)
    if git -C "${ROOT_DIR}" show-ref --verify --quiet "refs/heads/${branch}" 2>/dev/null; then
        warn "Branch ${branch} already exists in root -- reusing it"
        git -C "${ROOT_DIR}" worktree add "${workspace_dir}" "${branch}" 2>/dev/null || {
            error "Failed to create root worktree. Branch may already be checked out."
            exit 1
        }
    else
        git -C "${ROOT_DIR}" worktree add -b "${branch}" "${workspace_dir}" 2>/dev/null || {
            error "Failed to create root worktree."
            exit 1
        }
    fi
    success "Created root worktree at ${workspace_dir} (branch: ${branch})"

    # Create worktrees for each initialized submodule
    local created=0
    git -C "${ROOT_DIR}" submodule foreach --quiet '
        name_arg="'"${name}"'"
        ws="'"${workspace_dir}"'"
        branch="'"${BRANCH_PREFIX}"'/$name_arg"
        wt_path="$ws/$sm_path"

        if git worktree add "$wt_path" -b "$branch" HEAD 2>/dev/null; then
            echo "  created: $sm_path (branch: $branch)"
        elif git worktree add "$wt_path" "$branch" 2>/dev/null; then
            echo "  reused:  $sm_path (branch: $branch)"
        else
            echo "  FAILED:  $sm_path" >&2
        fi
    '

    echo ""
    success "Workspace ${BOLD}${name}${RESET} created."
    info "Start working:"
    info "  cd ${workspace_dir}/"
}

cmd_merge() {
    local name="${1:-}"
    if [[ -z "${name}" ]]; then
        error "Usage: worktree.sh merge <name>"
        exit 1
    fi

    local workspace_dir="${WORKTREE_DIR}/${name}"
    if [[ ! -d "${workspace_dir}" ]]; then
        error "Workspace '${name}' does not exist."
        exit 1
    fi

    info "Merging workspace ${BOLD}${name}${RESET} ..."

    local branch="${BRANCH_PREFIX}/${name}"

    # --- Merge root repo's wt/<name> branch first ---
    if git -C "${ROOT_DIR}" rev-parse --verify "${branch}" >/dev/null 2>&1; then
        local root_main
        root_main="$(git -C "${ROOT_DIR}" rev-parse --abbrev-ref HEAD)"
        local root_ahead
        root_ahead="$(git -C "${ROOT_DIR}" rev-list --count "${root_main}..${branch}" 2>/dev/null || echo "0")"
        if [[ "${root_ahead}" != "0" ]]; then
            info "Merging ${branch} (${root_ahead} commit(s)) into ${root_main} in ${BOLD}root${RESET} ..."
            if git -C "${ROOT_DIR}" merge --ff-only "${branch}" --quiet 2>/dev/null; then
                success "Fast-forward merged root"
            elif git -C "${ROOT_DIR}" merge "${branch}" --no-edit --quiet 2>/dev/null; then
                success "Merged root (merge commit created)"
            else
                error "Merge conflict in ${BOLD}root${RESET}!"
                error "Resolve conflicts in ${ROOT_DIR}, then re-run merge"
                git -C "${ROOT_DIR}" merge --abort 2>/dev/null || true
                exit 1
            fi
        else
            info "No changes on ${branch} in root -- skipping"
        fi
    fi

    # --- Merge each submodule's wt/<name> branch ---
    git -C "${ROOT_DIR}" submodule foreach --quiet '
        name_arg="'"${name}"'"
        branch="'"${BRANCH_PREFIX}"'/$name_arg"
        tracked=$(git config -f "$toplevel/.gitmodules" --get "submodule.$name.branch" 2>/dev/null || echo "main")

        # Check if the worktree branch exists locally
        if ! git rev-parse --verify "$branch" >/dev/null 2>&1; then
            echo "  $sm_path: no branch $branch, skipping"
            exit 0
        fi

        # Fetch remote and update local wt branch if remote has commits we lack
        # (worktree agents may have pushed directly to origin/wt/<name>)
        git fetch --quiet origin 2>/dev/null || true
        if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
            if ! git merge-base --is-ancestor "origin/$branch" "$branch" 2>/dev/null; then
                echo "  $sm_path: syncing $branch with remote..."
                if git merge-base --is-ancestor "$branch" "origin/$branch" 2>/dev/null; then
                    # Local is behind remote -- fast-forward the ref directly
                    git update-ref "refs/heads/$branch" "$(git rev-parse "origin/$branch")"
                else
                    # Diverged -- checkout, merge, return
                    cur=$(git branch --show-current 2>/dev/null || echo "")
                    git checkout "$branch" --quiet
                    git merge --no-edit --quiet "origin/$branch"
                    [ -n "$cur" ] && git checkout "$cur" --quiet 2>/dev/null || git checkout "$tracked" --quiet
                fi
            fi
        fi

        # Check if worktree branch has any commits beyond main
        ahead=$(git rev-list --count "$tracked..$branch" 2>/dev/null || echo "0")
        if [ "$ahead" = "0" ]; then
            echo "  $sm_path: no changes on $branch, skipping"
            exit 0
        fi

        echo "  $sm_path: merging $branch ($ahead commit(s)) into $tracked..."
        git checkout "$tracked" --quiet
        if git merge --ff-only "$branch" --quiet 2>/dev/null; then
            echo "  $sm_path: fast-forward merge ✓"
        elif git merge "$branch" --no-edit --quiet; then
            echo "  $sm_path: merge commit created ✓"
        else
            echo "  $sm_path: CONFLICT — resolve manually, then re-run merge" >&2
            exit 1
        fi
    '

    if [[ $? -ne 0 ]]; then
        echo ""
        error "Merge stopped due to conflicts. Resolve them, then re-run:"
        error "  ./worktree.sh merge ${name}"
        exit 1
    fi

    # Update root repo submodule pointers
    echo ""
    info "Updating root repo submodule pointers..."
    git -C "${ROOT_DIR}" add -A 2>/dev/null || true
    if ! git -C "${ROOT_DIR}" diff --cached --quiet 2>/dev/null; then
        git -C "${ROOT_DIR}" commit -m "Merge workspace '${name}' submodule updates" --quiet 2>/dev/null
        success "Root repo submodule pointers updated"
    else
        info "No submodule pointer changes to commit"
    fi

    echo ""
    success "Merge complete. You can now remove the workspace:"
    info "  ./worktree.sh remove ${name}"
}

cmd_remove() {
    local name="${1:-}"
    if [[ -z "${name}" ]]; then
        error "Usage: worktree.sh remove <name>"
        exit 1
    fi

    local workspace_dir="${WORKTREE_DIR}/${name}"
    if [[ ! -d "${workspace_dir}" ]]; then
        error "Workspace '${name}' does not exist."
        exit 1
    fi

    info "Removing workspace ${BOLD}${name}${RESET} ..."

    local branch="${BRANCH_PREFIX}/${name}"

    # Remove submodule worktrees and branches
    git -C "${ROOT_DIR}" submodule foreach --quiet '
        name_arg="'"${name}"'"
        ws="'"${workspace_dir}"'"
        branch="'"${BRANCH_PREFIX}"'/$name_arg"
        wt_path="$ws/$sm_path"

        if [ -d "$wt_path" ]; then
            git worktree remove --force "$wt_path" 2>/dev/null || true
        fi
        git branch -D "$branch" 2>/dev/null || true
    '

    # Remove root worktree and branch
    git -C "${ROOT_DIR}" worktree remove --force "${workspace_dir}" 2>/dev/null || true
    git -C "${ROOT_DIR}" branch -D "${branch}" 2>/dev/null || true

    # Clean up if anything remains
    rm -rf "${workspace_dir}" 2>/dev/null || true

    # Remove .worktrees/ if empty
    if [[ -d "${WORKTREE_DIR}" ]] && [[ -z "$(ls -A "${WORKTREE_DIR}" 2>/dev/null)" ]]; then
        rmdir "${WORKTREE_DIR}" 2>/dev/null || true
    fi

    success "Workspace ${BOLD}${name}${RESET} removed."
}

cmd_list() {
    if [[ ! -d "${WORKTREE_DIR}" ]]; then
        info "No active workspaces."
        return
    fi

    local has_workspaces=false
    echo -e "${BOLD}Active workspaces:${RESET}"
    echo ""
    for ws_dir in "${WORKTREE_DIR}"/*/; do
        [[ -d "${ws_dir}" ]] || continue
        has_workspaces=true
        local ws_name
        ws_name="$(basename "${ws_dir}")"
        echo -e "  ${GREEN}${ws_name}${RESET}  →  ${ws_dir}"

        # Show submodule branch status
        git -C "${ROOT_DIR}" submodule foreach --quiet '
            ws="'"${ws_dir}"'"
            if [ -d "$ws/$sm_path" ]; then
                branch=$(git -C "$ws/$sm_path" branch --show-current 2>/dev/null || echo "detached")
                echo "    $sm_path ($branch)"
            fi
        '
        echo ""
    done

    if [[ "${has_workspaces}" == "false" ]]; then
        info "No active workspaces."
    fi
}

cmd_help() {
    cat <<'HELP'
worktree.sh -- Multi-repo worktree manager

USAGE
    ./worktree.sh <command> [arguments]

COMMANDS
    sync              Fetch latest and update all submodules to their
                      tracked branches (from .gitmodules).

    create <name>     Create a new workspace. This creates a git worktree
                      for the root repo and each initialized submodule
                      under .worktrees/<name>/ with a branch named wt/<name>.

    merge <name>      Merge the wt/<name> branches back into the default
                      branch of each submodule and the root repo.
                      Fetches remote wt/<name> branches before merging
                      to pick up commits pushed by worktree agents.

    remove <name>     Remove a workspace and delete its branches.

    list              List all active workspaces and their submodules.

    --help, -h        Show this help message.

SUBMODULES
    Submodules are discovered dynamically from .gitmodules -- any repo
    with git submodules works. No hardcoded list required.

EXAMPLES
    # Set up and start a new feature
    ./worktree.sh sync
    ./worktree.sh create ocpnode-1234
    cd .worktrees/ocpnode-1234/

    # Work across repos, then merge and clean up
    ./worktree.sh merge ocpnode-1234
    ./worktree.sh remove ocpnode-1234
HELP
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

main() {
    local command="${1:-}"
    shift || true

    case "${command}" in
        sync)   cmd_sync ;;
        create) cmd_create "$@" ;;
        merge)  cmd_merge "$@" ;;
        remove) cmd_remove "$@" ;;
        list)   cmd_list ;;
        --help|-h|help) cmd_help ;;
        "")
            error "No command specified."
            echo ""
            cmd_help
            exit 1
            ;;
        *)
            error "Unknown command: ${command}"
            echo ""
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
