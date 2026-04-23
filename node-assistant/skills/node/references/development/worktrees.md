# Worktrees: Parallel Multi-Repo Workspaces

`scripts/worktree.sh` creates isolated workspaces with a `wt/<name>` branch under `.worktrees/<name>/`. Works with any git repo — single repos or repos with submodules. When submodules are present, each one gets its own worktree and branch inside the workspace automatically.

## Commands

| Command | What it does |
|---|---|
| `sync` | Fetch + fast-forward all submodules to their tracked branch (from `.gitmodules`) |
| `create <name> [base]` | Sync, then create a workspace branching from `base` (default: `HEAD`) |
| `pull <name>` | Sync main, then merge main into every worktree branch (keeps you up to date) |
| `merge <name>` | Merge all `wt/<name>` branches back into their tracked main branches |
| `remove <name>` | Delete the workspace directory and all `wt/<name>` branches |
| `list` | Show active workspaces and their submodule branch status |

## Typical Workflow

```
./scripts/worktree.sh create my-feature
cd .worktrees/my-feature/
# work across repos...
# optionally pull in upstream changes:
./scripts/worktree.sh pull my-feature
# done — merge back and clean up:
./scripts/worktree.sh merge my-feature
./scripts/worktree.sh remove my-feature
```

## Non-Obvious Details

- **Branch prefix is `wt/`** — every workspace creates `wt/<name>` branches in the root and all submodules. Don't manually create branches with this prefix.
- **`create` always syncs first** — it fetches and fast-forwards all submodules before branching, so your workspace starts from the latest remote state.
- **`merge` fetches remote `wt/` branches** — if an agent or CI pushed commits to `origin/wt/<name>`, merge will pick them up before merging into main. This handles the case where worktree agents push directly.
- **`merge` reconciles submodule pointers** — after merging, it ensures each submodule's main branch matches the commit the root repo expects. This prevents pointer drift when branches were already cleaned up from a prior remove.
- **`sync` only fast-forwards** — it never rebases or creates merge commits. If a submodule has diverged from its remote, sync will warn and skip it so you can resolve manually.
- **`pull` skips submodules not on the worktree branch** — if you've manually switched a submodule to a different branch, pull won't touch it.
- **First-time repos** — if the root repo has no commits, `create` will make an initial commit automatically.
