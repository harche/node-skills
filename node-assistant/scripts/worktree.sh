#!/bin/bash
# worktree.sh — create/remove/list parallel workspaces with all submodules
#
# Usage:
#   lightspeed-operator/hack/worktree.sh sync                           # fetch + checkout main in all submodules
#   lightspeed-operator/hack/worktree.sh create <name> [base-branch]   # create a workspace (runs sync first)
#   lightspeed-operator/hack/worktree.sh pull <name>                    # sync main + merge into worktree branches
#   lightspeed-operator/hack/worktree.sh merge <name>                   # merge worktree branches into main + update root
#   lightspeed-operator/hack/worktree.sh remove <name>                  # tear it down
#   lightspeed-operator/hack/worktree.sh list                           # show active workspaces
#
# After creating:
#   claude --cwd .worktrees/<name>
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WT_DIR="$ROOT/.worktrees"

cmd_sync() {
  echo "Syncing all submodules to latest remote main..."

  # Fetch + pull root repo
  echo "  root: fetching..."
  git -C "$ROOT" fetch --quiet

  # Init submodules first (ensures .git dirs exist before we fetch)
  git -C "$ROOT" submodule update --init --quiet

  # Each submodule: fetch, checkout its tracked branch, fast-forward if clean
  git -C "$ROOT" submodule foreach --quiet '
    tracked=$(git config -f "$toplevel/.gitmodules" --get "submodule.$name.branch" 2>/dev/null || echo "main")
    git fetch --quiet origin
    git checkout "$tracked" --quiet 2>/dev/null || git checkout -b "$tracked" "origin/$tracked" --quiet

    # Only fast-forward — never rebase/merge to avoid conflict loops
    if git merge-base --is-ancestor HEAD "origin/$tracked" 2>/dev/null; then
      echo "  $sm_path: fast-forwarding $tracked..."
      git merge --ff-only --quiet "origin/$tracked"
    elif git merge-base --is-ancestor "origin/$tracked" HEAD 2>/dev/null; then
      echo "  $sm_path: already ahead of origin/$tracked (local commits), skipping pull"
    else
      echo "  $sm_path: WARNING — diverged from origin/$tracked, skipping pull (resolve manually)"
    fi
  '

  echo "All submodules synced."
  echo ""
}

cmd_create() {
  local name="${1:?usage: worktree.sh create <name> [base-branch]}"
  local base="${2:-HEAD}"
  local ws="$WT_DIR/$name"

  if [ -d "$ws" ]; then
    echo "error: workspace '$name' already exists at $ws" >&2
    exit 1
  fi

  # If root repo has no commits yet, create an initial one so worktrees have
  # something to branch from (common when setting up the repo for the first time)
  if ! git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1; then
    echo "No commits in root repo — creating initial commit..."
    git -C "$ROOT" add -A
    git -C "$ROOT" commit -m "Initial commit: register submodules" --quiet
  fi

  # Sync all submodules to latest remote main before branching
  cmd_sync

  echo "Creating workspace '$name' from $base..."

  # Root repo worktree
  git -C "$ROOT" worktree add "$ws" -b "wt/$name" "$base" 2>/dev/null \
    || git -C "$ROOT" worktree add "$ws" "wt/$name"

  # Submodule worktrees — each sub-repo gets its own branch inside the workspace
  git -C "$ROOT" submodule foreach --quiet '
    name="'"$name"'"
    ws="'"$ws"'"
    branch="wt/'"$name"'"
    # Create worktree for this submodule inside the workspace directory
    git worktree add "$ws/$sm_path" -b "$branch" HEAD 2>/dev/null \
      || git worktree add "$ws/$sm_path" "$branch"
  '

  echo ""
  echo "Workspace ready at: $ws"
  echo ""
  echo "  claude --cwd $ws"
  echo ""
}

cmd_pull() {
  local wsname="${1:?usage: worktree.sh pull <name>}"
  local ws="$WT_DIR/$wsname"
  local branch="wt/$wsname"

  if [ ! -d "$ws" ]; then
    echo "error: workspace '$wsname' not found at $ws" >&2
    exit 1
  fi

  # Sync main to latest remote first
  cmd_sync

  echo "Merging main into workspace '$wsname'..."
  echo ""

  # Merge main into each submodule's worktree branch
  git -C "$ROOT" submodule foreach --quiet '
    wsname="'"$wsname"'"
    ws="'"$ws"'"
    branch="wt/'"$wsname"'"
    tracked=$(git config -f "$toplevel/.gitmodules" --get "submodule.$name.branch" 2>/dev/null || echo "main")

    if [ ! -d "$ws/$sm_path" ]; then
      echo "  $sm_path: not in workspace, skipping"
      exit 0
    fi

    cur=$(git -C "$ws/$sm_path" branch --show-current 2>/dev/null || echo "")
    if [ "$cur" != "$branch" ]; then
      echo "  $sm_path: not on $branch (on $cur), skipping"
      exit 0
    fi

    behind=$(git -C "$ws/$sm_path" rev-list --count HEAD.."$tracked" 2>/dev/null || echo "0")
    if [ "$behind" = "0" ]; then
      echo "  $sm_path: already up to date with $tracked"
      exit 0
    fi

    echo "  $sm_path: merging $tracked ($behind commit(s)) into $branch..."
    if git -C "$ws/$sm_path" merge "$tracked" --no-edit --quiet; then
      echo "  $sm_path: merged ✓"
    else
      echo "  $sm_path: CONFLICT — resolve in $ws/$sm_path, then re-run pull" >&2
      exit 1
    fi
  '

  if [ $? -ne 0 ]; then
    echo ""
    echo "Pull stopped due to conflicts. Resolve them, then run:"
    echo "  lightspeed-operator/hack/worktree.sh pull $wsname"
    exit 1
  fi

  # Update root worktree submodule pointers
  git -C "$ws" add -A 2>/dev/null
  if ! git -C "$ws" diff --cached --quiet 2>/dev/null; then
    git -C "$ws" commit -m "Sync all submodules with main"
    echo ""
    echo "Root worktree pointers updated."
  else
    echo ""
    echo "No submodule pointer changes."
  fi

  echo ""
  echo "Workspace '$wsname' is up to date with main."
  echo ""
}

cmd_merge() {
  local name="${1:?usage: worktree.sh merge <name>}"
  local ws="$WT_DIR/$name"
  local branch="wt/$name"

  if [ ! -d "$ws" ]; then
    echo "error: workspace '$name' not found at $ws" >&2
    exit 1
  fi

  echo "Merging workspace '$name'..."
  echo ""

  # --- Merge root repo's wt/<name> branch first ---
  if git -C "$ROOT" rev-parse --verify "$branch" >/dev/null 2>&1; then
    local root_main
    root_main=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)
    local root_ahead
    root_ahead=$(git -C "$ROOT" rev-list --count "$root_main..$branch" 2>/dev/null || echo "0")
    if [ "$root_ahead" != "0" ]; then
      echo "  root: merging $branch ($root_ahead commit(s)) into $root_main..."
      if git -C "$ROOT" merge --ff-only "$branch" --quiet 2>/dev/null; then
        echo "  root: fast-forward merge ✓"
      elif git -C "$ROOT" merge "$branch" --no-edit --quiet; then
        echo "  root: merge commit created ✓"
      else
        echo "  root: CONFLICT — resolve manually, then re-run merge" >&2
        exit 1
      fi
    else
      echo "  root: no changes on $branch, skipping"
    fi
  fi

  # --- Merge each submodule's wt/<name> branch into its tracked main branch ---
  git -C "$ROOT" submodule foreach --quiet '
    name="'"$name"'"
    branch="wt/'"$name"'"
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
          # Local is behind remote — fast-forward the ref directly
          git update-ref "refs/heads/$branch" "$(git rev-parse "origin/$branch")"
        else
          # Diverged — checkout, merge, return
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

  if [ $? -ne 0 ]; then
    echo ""
    echo "Merge stopped due to conflicts. Resolve them, then run:"
    echo "  lightspeed-operator/hack/worktree.sh merge $name"
    exit 1
  fi

  # Reconcile: ensure each submodule's main includes the commit the root expects.
  # This catches cases where the root merge fast-forwarded a submodule pointer
  # but the submodule's wt/ branch was already deleted (from a prior remove),
  # leaving the submodule's main behind.
  echo ""
  echo "Reconciling submodule branches with root pointers..."
  git -C "$ROOT" submodule foreach --quiet '
    tracked=$(git config -f "$toplevel/.gitmodules" --get "submodule.$name.branch" 2>/dev/null || echo "main")
    # What does the root repo expect this submodule to be at?
    expected=$(git -C "$toplevel" ls-tree HEAD -- "$sm_path" | awk "{print \$3}")
    current=$(git rev-parse HEAD 2>/dev/null || echo "")
    if [ -n "$expected" ] && [ "$expected" != "$current" ]; then
      if git merge-base --is-ancestor "$current" "$expected" 2>/dev/null; then
        echo "  $sm_path: fast-forwarding $tracked to match root pointer..."
        git checkout "$tracked" --quiet 2>/dev/null || true
        git merge --ff-only "$expected" --quiet 2>/dev/null || true
      fi
    fi
  '

  # Update root repo submodule pointers for any submodules that changed
  echo ""
  echo "Updating root repo submodule pointers..."
  # Stage any submodule pointer changes
  git -C "$ROOT" add -A 2>/dev/null
  if ! git -C "$ROOT" diff --cached --quiet 2>/dev/null; then
    git -C "$ROOT" commit -m "Merge workspace '$name' submodule updates"
    echo "Root repo updated."
  else
    echo "No submodule pointer changes to commit."
  fi

  echo ""
  echo "Merge complete. You can now remove the workspace:"
  echo "  lightspeed-operator/hack/worktree.sh remove $name"
  echo ""
}

cmd_remove() {
  local name="${1:?usage: worktree.sh remove <name>}"
  local ws="$WT_DIR/$name"

  if [ ! -d "$ws" ]; then
    echo "error: workspace '$name' not found at $ws" >&2
    exit 1
  fi

  echo "Removing workspace '$name'..."

  # Remove submodule worktrees first
  git -C "$ROOT" submodule foreach --quiet '
    ws="'"$ws"'"
    name="'"$name"'"
    if git worktree list --porcelain | grep -q "worktree $ws/$sm_path"; then
      git worktree remove --force "$ws/$sm_path" 2>/dev/null || true
    fi
    # Clean up the branch
    git branch -D "wt/'"$name"'" 2>/dev/null || true
  '

  # Remove root worktree
  git -C "$ROOT" worktree remove --force "$ws" 2>/dev/null || true
  git -C "$ROOT" branch -D "wt/$name" 2>/dev/null || true

  # Clean up empty dir if anything remains
  rm -rf "$ws" 2>/dev/null || true

  echo "Workspace '$name' removed."
}

cmd_list() {
  if [ ! -d "$WT_DIR" ]; then
    echo "No workspaces. Create one with: lightspeed-operator/hack/worktree.sh create <name>"
    return
  fi

  echo "Active workspaces:"
  echo ""
  for ws in "$WT_DIR"/*/; do
    [ -d "$ws" ] || continue
    local name="$(basename "$ws")"
    echo "  $name  →  $ws"
    # Show submodule branch status
    git -C "$ROOT" submodule foreach --quiet '
      ws="'"$ws"'"
      if [ -d "$ws/$sm_path" ]; then
        branch=$(git -C "$ws/$sm_path" branch --show-current 2>/dev/null || echo "detached")
        echo "    $sm_path ($branch)"
      fi
    '
    echo ""
  done
}

case "${1:-help}" in
  sync)   cmd_sync ;;
  create) shift; cmd_create "$@" ;;
  pull)   shift; cmd_pull "$@" ;;
  merge)  shift; cmd_merge "$@" ;;
  remove) shift; cmd_remove "$@" ;;
  list)   cmd_list ;;
  *)
    echo "Usage: lightspeed-operator/hack/worktree.sh {sync|create|pull|merge|remove|list} [args...]"
    echo ""
    echo "  sync                  — fetch + checkout main in all submodules"
    echo "  create <name> [base]  — sync + create parallel workspace"
    echo "  pull <name>           — sync main + merge into all worktree branches"
    echo "  merge <name>          — merge worktree branches into main + update root"
    echo "  remove <name>         — tear down workspace"
    echo "  list                  — show active workspaces"
    ;;
esac
