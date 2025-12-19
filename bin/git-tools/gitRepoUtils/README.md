=== File Structure ===

```
gitRepoUtils/
├── gitRepoUtils.sh      # Main dispatcher (115 lines)
└── lib/
    ├── common.sh        # Shared utilities (227 lines)
    ├── branch-commands.sh   # Branch ops (2,219 lines)
    ├── pr-commands.sh       # PR ops (3,300 lines)
    ├── repo-commands.sh     # Repo config (1,913 lines)
    └── user-commands.sh     # User/teams (1,027 lines)
```

## Usage

```bash
# Run from anywhere
./gitRepoUtils.sh <command> [options] <git-directory>

# Or add to PATH
export PATH="$PATH:/path/to/gitRepoUtils"
gitRepoUtils.sh my-prs --yesterday ~/projects/myrepo
```

## Module Overview

| Module | Commands |
|--------|----------|
| **branch-commands.sh** | `default-branch`, `merged-branches`, `lock-branch`, `unlock-branch`, `check-push-restrictions`, `remove-push-restrictions` |
| **pr-commands.sh** | `list-prs`, `my-prs`, `approve-pr`, `merge-pr`, `enable-auto-merge` |
| **repo-commands.sh** | `update-ci-branches`, `configure-repo`, `clean-repo` |
| **user-commands.sh** | `manage-codeowners`, `search-users` |
| **common.sh** | Shared utilities: colors, validation, path resolution, date helpers |

## Adding New Commands

1. Add usage function to appropriate module
2. Add command implementation to the module's `handle_*_command()` function
3. Add to the case statement in `gitRepoUtils.sh` main dispatcher
4. Update the main help text

## Dependencies

- GitHub CLI (`gh`) - authenticated
- `jq` - for JSON processing
- Git
