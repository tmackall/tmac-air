#!/bin/bash

# gitRepoUtils.sh - Git Repository Utilities
# A modular toolkit for working with Git repositories and GitHub
#
# This is the main dispatcher that routes commands to specialized modules.

set -e

# Determine script directory for sourcing modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source common utilities
source "$LIB_DIR/common.sh"

# Source command modules
source "$LIB_DIR/branch-commands.sh"
source "$LIB_DIR/pr-commands.sh"
source "$LIB_DIR/user-commands.sh"
source "$LIB_DIR/repo-commands.sh"

# Main usage function
show_usage() {
    echo "Usage: $0 <command> [options] <git-directory>"
    echo ""
    echo "A modular toolkit for Git repository management and GitHub operations."
    echo ""
    echo "Branch Commands:"
    echo "  default-branch           Get the default branch name for the repository"
    echo "  merged-branches          Find all branches merged into a target branch"
    echo "  lock-branch              Lock a branch (read-only or standard protection)"
    echo "  unlock-branch            Remove branch protection (unlock a branch)"
    echo "  check-push-restrictions  Check who can push to a branch"
    echo "  remove-push-restrictions Remove push restrictions from a branch"
    echo ""
    echo "Pull Request Commands:"
    echo "  list-prs                 List pull requests with filtering options"
    echo "  my-prs                   List your PRs with date range filtering"
    echo "  approve-pr               Approve a pull request (with optional comment)"
    echo "  merge-pr                 Merge a pull request (with various strategies)"
    echo "  enable-auto-merge        Enable auto-merge on a PR"
    echo ""
    echo "User & Team Commands:"
    echo "  manage-codeowners        Add or remove users from CODEOWNERS file"
    echo "  search-users             Search for GitHub users/teams by pattern"
    echo ""
    echo "Repository Commands:"
    echo "  update-ci-branches       Update CI workflow branch triggers"
    echo "  configure-repo           Configure repository settings"
    echo "  clean-repo               Clean working directory and sync branches"
    echo ""
    echo "Run '$0 <command> --help' for command-specific options"
    echo ""
    echo "Examples:"
    echo "  $0 default-branch ~/projects/my-project"
    echo "  $0 merged-branches --branch main ~/projects/my-project"
    echo "  $0 lock-branch ~/projects/my-project"
    echo "  $0 list-prs --unapproved ~/projects/my-project"
    echo "  $0 my-prs --yesterday ~/projects/my-project"
    echo "  $0 approve-pr --pr 123 ~/projects/my-project"
    echo "  $0 merge-pr --pr 123 ~/projects/my-project"
    echo "  $0 enable-auto-merge --pr 123 ~/projects/my-project"
    echo "  $0 manage-codeowners --add @username ~/projects/my-project"
    echo "  $0 search-users alice"
    echo "  $0 update-ci-branches ~/projects/my-project"
    echo "  $0 configure-repo --enable-auto-merge ~/projects/my-project"
    echo "  $0 clean-repo ~/projects/my-project"
}

# Check if command was provided
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

COMMAND="$1"
shift

# Route to appropriate command handler
case $COMMAND in
    # Branch commands
    default-branch|merged-branches|lock-branch|unlock-branch|check-push-restrictions|remove-push-restrictions)
        handle_branch_command "$COMMAND" "$@"
        ;;
    
    # PR commands
    list-prs|my-prs|approve-pr|merge-pr|enable-auto-merge)
        handle_pr_command "$COMMAND" "$@"
        ;;
    
    # User commands
    manage-codeowners|search-users)
        handle_user_command "$COMMAND" "$@"
        ;;
    
    # Repo commands
    update-ci-branches|configure-repo|clean-repo)
        handle_repo_command "$COMMAND" "$@"
        ;;
    
    # Help
    -h|--help)
        show_usage
        exit 0
        ;;
    
    # Unknown command
    *)
        echo "Error: Unknown command: $COMMAND"
        echo ""
        show_usage
        exit 1
        ;;
esac
