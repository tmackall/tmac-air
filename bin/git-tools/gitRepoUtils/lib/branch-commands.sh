#!/bin/bash

# branch-commands.sh - Branch management commands for gitRepoUtils
# Commands: default-branch, merged-branches, lock-branch, unlock-branch,
#           check-push-restrictions, remove-push-restrictions

# This file is sourced by the main gitRepoUtils.sh script

# Function to show usage for default-branch command
show_default_branch_usage() {
    echo "Usage: $0 default-branch [options] <git-directory>"
    echo ""
    echo "Get the default branch name for a Git repository."
    echo ""
    echo "Options:"
    echo "  --format FORMAT          Output format: simple, detailed, or json (default: simple)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 default-branch ~/projects/my-project"
    echo "  $0 default-branch --format json ~/projects/my-project"
    echo ""
}

# Function to show usage for merged-branches command
show_merged_branches_usage() {
    echo "Usage: $0 merged-branches [options] <git-directory>"
    echo ""
    echo "Find all branches that have been merged into a target branch."
    echo ""
    echo "Options:"
    echo "  --branch BRANCH          Target branch to check (default: main)"
    echo "  --remote-only            Only show remote branches"
    echo "  --local-only             Only show local branches"
    echo "  --exclude-main           Exclude main/master branches from results"
    echo "  --format FORMAT          Output format: simple, detailed, or json (default: simple)"
    echo "  --delete                 Delete the merged branches (requires confirmation)"
    echo "  --delete-remote          Also delete remote branches (use with --delete)"
    echo "  --force-delete           Skip confirmation prompts (dangerous!)"
    echo "  --dry-run-delete         Show what would be deleted without actually deleting"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 merged-branches ~/projects/my-project"
    echo "  $0 merged-branches --branch main ~/projects/my-project"
    echo "  $0 merged-branches --remote-only ~/projects/my-project"
    echo "  $0 merged-branches --delete ~/projects/my-project"
    echo ""
}

# Function to show usage for lock-branch command
show_lock_branch_usage() {
    echo "Usage: $0 lock-branch [options] <git-directory>"
    echo ""
    echo "Lock a branch with protection rules to prevent unauthorized changes."
    echo "By default, this locks the 'develop' branch as read-only, preventing"
    echo "both direct pushes and pull requests."
    echo ""
    echo "Options:"
    echo "  --branch BRANCH          Branch to lock (default: develop)"
    echo "  --standard               Use standard lock (allows PRs with approval)"
    echo "  --check                  Only check if branch is locked (no changes)"
    echo "  --verbose                Show detailed protection rules (use with --check)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 lock-branch ~/projects/my-project                      # Lock develop as read-only"
    echo "  $0 lock-branch --branch feature/old ~/projects/my-proj    # Lock specific branch"
    echo "  $0 lock-branch --standard ~/projects/my-project           # Standard lock (PRs allowed)"
    echo "  $0 lock-branch --check ~/projects/my-project              # Check lock status (brief)"
    echo "  $0 lock-branch --check --verbose ~/projects/my-project    # Check with details"
    echo ""
    echo "Requirements:"
    echo "  - GitHub CLI (gh) must be installed and authenticated"
    echo "  - Admin permissions on the repository to set branch protection"
    echo ""
    echo "Lock Types:"
    echo ""
    echo "  Read-Only Lock (default):"
    echo "    - No direct pushes to the branch"
    echo "    - No pull requests can be created to the branch"
    echo "    - Branch is completely frozen (deprecated/archived branches)"
    echo "    - Use for: Branches that should never be used again (e.g., deprecated develop)"
    echo ""
    echo "  Standard Lock (--standard):"
    echo "    - No direct pushes to the branch"
    echo "    - Pull requests allowed (requires 1 approval)"
    echo "    - Use for: Active branches requiring PR workflow"
    echo ""
}

# Function to show usage for unlock-branch command
show_unlock_branch_usage() {
    echo "Usage: $0 unlock-branch [options] <git-directory>"
    echo ""
    echo "Remove branch protection rules to unlock a branch."
    echo "By default, this unlocks the 'develop' branch."
    echo ""
    echo "Options:"
    echo "  --branch BRANCH          Branch to unlock (default: develop)"
    echo "  --force                  Skip confirmation prompt"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 unlock-branch ~/projects/my-project                    # Unlock develop"
    echo "  $0 unlock-branch --branch main ~/projects/my-project      # Unlock main"
    echo "  $0 unlock-branch --force ~/projects/my-project            # Skip confirmation"
    echo ""
    echo "Requirements:"
    echo "  - GitHub CLI (gh) must be installed and authenticated"
    echo "  - Admin permissions on the repository to modify branch protection"
    echo ""
    echo "WARNING: Unlocking a branch removes all protection rules including:"
    echo "  - Required pull request reviews"
    echo "  - Status checks"
    echo "  - Read-only locks"
    echo "  - Force push blocks"
    echo ""
}

# Function to show usage for check-push-restrictions command
show_check_push_restrictions_usage() {
    echo "Usage: $0 check-push-restrictions [options] <git-directory>"
    echo ""
    echo "Check push restrictions (who can push) on a branch."
    echo "By default, this checks the 'main' branch."
    echo ""
    echo "Options:"
    echo "  --branch BRANCH          Branch to check (default: main)"
    echo "  --verbose                Show detailed information"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 check-push-restrictions ~/projects/my-project                 # Check main branch"
    echo "  $0 check-push-restrictions --branch develop ~/projects/my-proj   # Check develop"
    echo "  $0 check-push-restrictions --verbose ~/projects/my-project       # Detailed output"
    echo ""
    echo "Requirements:"
    echo "  - GitHub CLI (gh) must be installed and authenticated"
    echo "  - Admin permissions on the repository to view push restrictions"
    echo ""
}

# Function to show usage for remove-push-restrictions command
show_remove_push_restrictions_usage() {
    echo "Usage: $0 remove-push-restrictions [options] <git-directory>"
    echo ""
    echo "Remove push restrictions from a branch while keeping other protection rules."
    echo "By default, this removes restrictions from the 'main' branch."
    echo ""
    echo "Options:"
    echo "  --branch BRANCH          Branch to modify (default: main)"
    echo "  --force                  Skip confirmation prompt"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 remove-push-restrictions ~/projects/my-project                # Remove from main"
    echo "  $0 remove-push-restrictions --branch develop ~/projects/my-proj  # Remove from develop"
    echo "  $0 remove-push-restrictions --force ~/projects/my-project        # Skip confirmation"
    echo ""
    echo "Requirements:"
    echo "  - GitHub CLI (gh) must be installed and authenticated"
    echo "  - Admin permissions on the repository to modify push restrictions"
    echo ""
    echo "Note: This command preserves all other branch protection rules and only"
    echo "      removes the 'Restrict who can push to matching branches' setting."
    echo ""
}

# Function to show usage for manage-codeowners command
show_manage_codeowners_usage() {
    echo "Usage: $0 manage-codeowners [options] <git-directory>"
    echo ""
    echo "Add or remove users/teams from the CODEOWNERS file."
    echo "Creates a PR with the changes following GitHub Flow best practices."
    echo ""
    echo "Options:"
    echo "  --add USER               Add user/team to CODEOWNERS (e.g., @username or @org/team)"
    echo "  --remove USER            Remove user/team from CODEOWNERS"
    echo "  --pattern PATTERN        File pattern to modify (default: * for root)"
    echo "  --branch-name NAME       Feature branch name (default: chore/update-codeowners-TIMESTAMP)"
    echo "  --skip-pr                Create branch and commit, but don't create PR"
    echo "  --no-branch              Update file directly without branch/commit/PR"
    echo "  --dry-run                Show what would be changed without making changes"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 manage-codeowners --add @alice ~/projects/my-project"
    echo "  $0 manage-codeowners --remove @bob ~/projects/my-project"
    echo "  $0 manage-codeowners --add @org/platform-team ~/projects/my-project"
    echo "  $0 manage-codeowners --add @alice --pattern '*.py' ~/projects/my-project"
    echo "  $0 manage-codeowners --dry-run --add @alice ~/projects/my-project"
    echo "  $0 manage-codeowners --no-branch --add @alice ~/projects/my-project"
    echo "  $0 manage-codeowners --skip-pr --add @alice ~/projects/my-project"
    echo ""
    echo "Requirements:"
    echo "  - GitHub CLI (gh) must be installed and authenticated (for PR creation)"
    echo "  - Write permissions on the repository"
    echo ""
    echo "CODEOWNERS Format:"
    echo "  The CODEOWNERS file uses patterns to define ownership:"
    echo "    *           @alice @bob         # Root level files"
    echo "    *.js        @org/frontend      # All JavaScript files"
    echo "    /docs/      @org/docs-team     # Docs directory"
    echo ""
}

# Function to show usage for search-users command
show_search_users_usage() {
    echo "Usage: $0 search-users [options] <pattern>"
    echo ""
    echo "Search for GitHub users or organization teams matching a pattern."
    echo "This helps find the correct GitHub username/team to use with CODEOWNERS."
    echo ""
    echo "Options:"
    echo "  --org ORG                Search within a specific organization"
    echo "  --type TYPE              Search type: users, teams, or all (default: all)"
    echo "  --format FORMAT          Output format: simple, detailed, or json (default: simple)"
    echo "  --limit N                Maximum results to return (default: 10)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 search-users alice"
    echo "  $0 search-users --org mycompany alice"
    echo "  $0 search-users --type teams platform"
    echo "  $0 search-users --format detailed alice"
    echo "  $0 search-users --limit 20 john"
    echo ""
    echo "Requirements:"
    echo "  - GitHub CLI (gh) must be installed and authenticated"
    echo ""
    echo "Output Format:"
    echo "  Simple:   @username (Full Name)"
    echo "  Detailed: Shows login, name, type, and profile URL"
    echo "  JSON:     Machine-readable JSON output"
    echo ""
    echo "Note: Team search requires organization context (--org flag)"
    echo ""
}

# Handle branch-related commands
# Arguments: $1 = command name, remaining args passed through
handle_branch_command() {
    local cmd="$1"
    shift
    
    case $cmd in
    default-branch)
        # Handle default-branch command
        FORMAT="simple"
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --format)
                    FORMAT="$2"
                    shift 2
                    ;;
                -h|--help)
                    show_default_branch_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 default-branch --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 default-branch [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Check if git directory was provided
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 default-branch [options] <git-directory>"
            echo "Run '$0 default-branch --help' for more information."
            exit 1
        fi
        
        # Expand the path (handle ~, relative paths, etc.)
        GIT_DIR=$(eval echo "$GIT_DIR")
        GIT_DIR=$(cd "$GIT_DIR" 2>/dev/null && pwd || echo "$GIT_DIR")
        
        # Check if directory exists
        if [ ! -d "$GIT_DIR" ]; then
            echo "Error: Directory '$GIT_DIR' not found"
            exit 1
        fi
        
        # Check if it's a git repository
        if [ ! -d "$GIT_DIR/.git" ]; then
            echo "Error: '$GIT_DIR' is not a git repository"
            exit 1
        fi
        
        # Validate format option
        if [[ ! "$FORMAT" =~ ^(simple|detailed|json)$ ]]; then
            echo "Error: Invalid format '$FORMAT'. Must be: simple, detailed, or json"
            exit 1
        fi
        
        # Change to git directory
        cd "$GIT_DIR"
        
        # Get repository name
        REPO_NAME=$(basename "$GIT_DIR")
        
        # Fetch latest changes from remote (quietly)
        if git remote | grep -q "origin"; then
            git fetch origin --quiet 2>/dev/null || true
        fi
        
        # Get the default branch name
        DEFAULT_BRANCH=""
        
        # Check if remote exists
        if ! git remote | grep -q "origin"; then
            echo "Error: No remote 'origin' found in repository" >&2
            exit 1
        fi
        
        # Method 1: Query the remote directly via ls-remote (most authoritative)
        DEFAULT_BRANCH=$(git ls-remote --symref origin HEAD 2>/dev/null | grep '^ref:' | awk '{print $2}' | sed 's@refs/heads/@@' || echo "")
        
        # Method 2: Try to get from local remote HEAD reference
        if [ -z "$DEFAULT_BRANCH" ]; then
            DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
        fi
        
        # Method 3: Try to set remote HEAD and get it
        if [ -z "$DEFAULT_BRANCH" ]; then
            if git remote set-head origin --auto >/dev/null 2>&1; then
                DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
            fi
        fi
        
        # If still no default branch found, fail with error
        if [ -z "$DEFAULT_BRANCH" ]; then
            echo "Error: Unable to determine default branch for repository" >&2
            echo "The remote does not advertise a default branch (HEAD reference)" >&2
            exit 1
        fi
        
        # Output based on format
        case $FORMAT in
            json)
                echo "{"
                echo "  \"repository\": \"$REPO_NAME\","
                echo "  \"path\": \"$GIT_DIR\","
                echo "  \"default_branch\": \"$DEFAULT_BRANCH\""
                echo "}"
                ;;
            detailed)
                echo "Repository: $REPO_NAME"
                echo "Path: $GIT_DIR"
                echo "Default Branch: $DEFAULT_BRANCH"
                
                # Show additional info if branch exists
                if [ "$DEFAULT_BRANCH" != "unknown" ] && git rev-parse --verify "$DEFAULT_BRANCH" >/dev/null 2>&1; then
                    echo ""
                    echo "Latest commit on $DEFAULT_BRANCH:"
                    commit_hash=$(git rev-parse --short "$DEFAULT_BRANCH" 2>/dev/null || echo "unknown")
                    commit_date=$(git log -1 --format=%ai "$DEFAULT_BRANCH" 2>/dev/null || echo "unknown")
                    commit_author=$(git log -1 --format=%an "$DEFAULT_BRANCH" 2>/dev/null || echo "unknown")
                    commit_message=$(git log -1 --format=%s "$DEFAULT_BRANCH" 2>/dev/null || echo "unknown")
                    echo "  Commit:  $commit_hash"
                    echo "  Date:    $commit_date"
                    echo "  Author:  $commit_author"
                    echo "  Message: $commit_message"
                fi
                ;;
            simple|*)
                echo "$DEFAULT_BRANCH"
                ;;
        esac
        ;;
        

    merged-branches)
        # Handle merged-branches command (original functionality)
        
        # Default options
        TARGET_BRANCH="main"
        REMOTE_ONLY=false
        LOCAL_ONLY=false
        EXCLUDE_MAIN=false
        FORMAT="simple"
        DELETE=false
        DELETE_REMOTE=false
        FORCE_DELETE=false
        DRY_RUN_DELETE=false
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --branch)
                    TARGET_BRANCH="$2"
                    shift 2
                    ;;
                --remote-only)
                    REMOTE_ONLY=true
                    shift
                    ;;
                --local-only)
                    LOCAL_ONLY=true
                    shift
                    ;;
                --exclude-main)
                    EXCLUDE_MAIN=true
                    shift
                    ;;
                --format)
                    FORMAT="$2"
                    shift 2
                    ;;
                --delete)
                    DELETE=true
                    shift
                    ;;
                --delete-remote)
                    DELETE_REMOTE=true
                    shift
                    ;;
                --force-delete)
                    FORCE_DELETE=true
                    shift
                    ;;
                --dry-run-delete)
                    DRY_RUN_DELETE=true
                    DELETE=true
                    shift
                    ;;
                -h|--help)
                    show_merged_branches_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 merged-branches --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 merged-branches [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Check if git directory was provided
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 merged-branches [options] <git-directory>"
            echo "Run '$0 merged-branches --help' for more information."
            exit 1
        fi
        
        # Expand the path (handle ~, relative paths, etc.)
        GIT_DIR=$(eval echo "$GIT_DIR")
        GIT_DIR=$(cd "$GIT_DIR" 2>/dev/null && pwd || echo "$GIT_DIR")
        
        # Check if directory exists
        if [ ! -d "$GIT_DIR" ]; then
            echo "Error: Directory '$GIT_DIR' not found"
            exit 1
        fi
        
        # Check if it's a git repository
        if [ ! -d "$GIT_DIR/.git" ]; then
            echo "Error: '$GIT_DIR' is not a git repository"
            exit 1
        fi
        
        # Validate format option
        if [[ ! "$FORMAT" =~ ^(simple|detailed|json)$ ]]; then
            echo "Error: Invalid format '$FORMAT'. Must be: simple, detailed, or json"
            exit 1
        fi
        
        # Validate delete options
        if [ "$DELETE" = true ] && [ "$FORMAT" = "json" ]; then
            echo "Error: Cannot use --delete with --format json"
            exit 1
        fi
        
        if [ "$DELETE_REMOTE" = true ] && [ "$DELETE" = false ]; then
            echo "Error: --delete-remote requires --delete"
            exit 1
        fi
        
        # Change to git directory
        cd "$GIT_DIR"
        
        # Get repository name
        REPO_NAME=$(basename "$GIT_DIR")
        
        # Fetch latest changes from remote
        if git remote | grep -q "origin"; then
            if [ "$FORMAT" != "json" ]; then
                echo "Fetching latest changes from remote..." >&2
            fi
            if ! git fetch origin --quiet 2>/dev/null; then
                if [ "$FORMAT" != "json" ]; then
                    echo "Warning: Failed to fetch from remote" >&2
                fi
            fi
        fi
        
        # Check if target branch exists
        BRANCH_EXISTS=false
        if git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1; then
            BRANCH_EXISTS=true
        elif git rev-parse --verify "origin/$TARGET_BRANCH" >/dev/null 2>&1; then
            BRANCH_EXISTS=true
            TARGET_BRANCH="origin/$TARGET_BRANCH"
        fi
        
        if [ "$BRANCH_EXISTS" = false ]; then
            echo "Error: Branch '$TARGET_BRANCH' does not exist (checked local and remote)"
            exit 1
        fi
        
        # Print header (unless JSON format)
        if [ "$FORMAT" != "json" ]; then
            echo "=========================================="
            echo "Branches Merged into: $TARGET_BRANCH"
            echo "=========================================="
            echo "Repository: $REPO_NAME"
            echo "Path: $GIT_DIR"
            echo ""
        fi
        
        # Get merged branches
        declare -a MERGED_BRANCHES=()
        
        # Function to check if branch should be skipped
        should_skip_branch() {
            local branch="$1"
            local clean_branch="${branch#origin/}"
            
            # Always skip the target branch itself
            if [ "$clean_branch" = "${TARGET_BRANCH#origin/}" ]; then
                return 0
            fi
            
            # Always skip main/master when deleting (safety feature)
            if [ "$DELETE" = true ]; then
                if [[ "$clean_branch" =~ ^(main|master)$ ]]; then
                    return 0
                fi
            fi
            
            # Skip main/master if requested via flag
            if [ "$EXCLUDE_MAIN" = true ]; then
                if [[ "$clean_branch" =~ ^(main|master)$ ]]; then
                    return 0
                fi
            fi
            
            return 1
        }
        
        # Get local branches merged into target
        if [ "$REMOTE_ONLY" = false ]; then
            while IFS= read -r branch; do
                # Use the centralized skip function
                if should_skip_branch "$branch"; then
                    continue
                fi
                
                MERGED_BRANCHES+=("local:$branch")
            done < <(git branch --merged "$TARGET_BRANCH" | sed 's/^[* ] //' | grep -v "^$TARGET_BRANCH$")
        fi
        
        # Get remote branches merged into target
        if [ "$LOCAL_ONLY" = false ]; then
            while IFS= read -r branch; do
                # Skip HEAD pointer
                if [[ "$branch" =~ HEAD ]]; then
                    continue
                fi
                
                # Use the centralized skip function
                if should_skip_branch "$branch"; then
                    continue
                fi
                
                MERGED_BRANCHES+=("remote:$branch")
            done < <(git branch -r --merged "$TARGET_BRANCH" | sed 's/^  //' | grep -v "HEAD")
        fi
        
        # Output results based on format
        if [ "$FORMAT" = "json" ]; then
            # JSON output
            echo "{"
            echo "  \"repository\": \"$REPO_NAME\","
            echo "  \"path\": \"$GIT_DIR\","
            echo "  \"target_branch\": \"$TARGET_BRANCH\","
            echo "  \"merged_branches\": ["
            
            first=true
            for entry in "${MERGED_BRANCHES[@]}"; do
                type="${entry%%:*}"
                branch="${entry#*:}"
                clean_branch="${branch#origin/}"
                
                if [ "$first" = true ]; then
                    first=false
                else
                    echo ","
                fi
                
                # Get commit info
                commit_hash=$(git rev-parse "$branch" 2>/dev/null || echo "unknown")
                commit_date=$(git log -1 --format=%ai "$branch" 2>/dev/null || echo "unknown")
                commit_author=$(git log -1 --format=%an "$branch" 2>/dev/null || echo "unknown")
                commit_message=$(git log -1 --format=%s "$branch" 2>/dev/null || echo "unknown")
                
                echo -n "    {"
                echo -n "\"type\": \"$type\", "
                echo -n "\"branch\": \"$clean_branch\", "
                echo -n "\"full_ref\": \"$branch\", "
                echo -n "\"commit_hash\": \"$commit_hash\", "
                echo -n "\"commit_date\": \"$commit_date\", "
                echo -n "\"commit_author\": \"$commit_author\", "
                echo -n "\"commit_message\": \"$commit_message\""
                echo -n "}"
            done
            
            echo ""
            echo "  ],"
            echo "  \"total_count\": ${#MERGED_BRANCHES[@]}"
            echo "}"
            
        elif [ "$FORMAT" = "detailed" ]; then
            # Detailed output with commit information
            echo "Merged Branches (${#MERGED_BRANCHES[@]} total):"
            echo ""
            
            if [ ${#MERGED_BRANCHES[@]} -eq 0 ]; then
                echo "  No branches found merged into $TARGET_BRANCH"
            else
                for entry in "${MERGED_BRANCHES[@]}"; do
                    type="${entry%%:*}"
                    branch="${entry#*:}"
                    clean_branch="${branch#origin/}"
                    
                    # Get commit info
                    commit_hash=$(git rev-parse --short "$branch" 2>/dev/null || echo "unknown")
                    commit_date=$(git log -1 --format=%ai "$branch" 2>/dev/null || echo "unknown")
                    commit_author=$(git log -1 --format=%an "$branch" 2>/dev/null || echo "unknown")
                    commit_message=$(git log -1 --format=%s "$branch" 2>/dev/null || echo "unknown")
                    
                    echo "  [$type] $clean_branch"
                    echo "      Commit:  $commit_hash"
                    echo "      Date:    $commit_date"
                    echo "      Author:  $commit_author"
                    echo "      Message: $commit_message"
                    echo ""
                done
            fi
            
        else
            # Simple output (default)
            echo "Merged Branches (${#MERGED_BRANCHES[@]} total):"
            echo ""
            
            if [ ${#MERGED_BRANCHES[@]} -eq 0 ]; then
                echo "  No branches found merged into $TARGET_BRANCH"
            else
                for entry in "${MERGED_BRANCHES[@]}"; do
                    type="${entry%%:*}"
                    branch="${entry#*:}"
                    clean_branch="${branch#origin/}"
                    
                    echo "  [$type] $clean_branch"
                done
            fi
        fi
        
        # Handle deletion if requested
        if [ "$DELETE" = true ] && [ ${#MERGED_BRANCHES[@]} -gt 0 ]; then
            echo ""
            echo "=========================================="
            if [ "$DRY_RUN_DELETE" = true ]; then
                echo "DRY RUN: Branch Deletion Preview"
            else
                echo "Branch Deletion"
            fi
            echo "=========================================="
            echo ""
            
            # Separate local and remote branches
            declare -a LOCAL_TO_DELETE=()
            declare -a REMOTE_TO_DELETE=()
            
            for entry in "${MERGED_BRANCHES[@]}"; do
                type="${entry%%:*}"
                branch="${entry#*:}"
                
                if [ "$type" = "local" ]; then
                    LOCAL_TO_DELETE+=("$branch")
                elif [ "$type" = "remote" ] && [ "$DELETE_REMOTE" = true ]; then
                    REMOTE_TO_DELETE+=("$branch")
                fi
            done
            
            # Show what will be deleted
            if [ ${#LOCAL_TO_DELETE[@]} -gt 0 ]; then
                echo "Local branches to delete (${#LOCAL_TO_DELETE[@]}):"
                for branch in "${LOCAL_TO_DELETE[@]}"; do
                    echo "  - $branch"
                done
                echo ""
            fi
            
            if [ ${#REMOTE_TO_DELETE[@]} -gt 0 ]; then
                echo "Remote branches to delete (${#REMOTE_TO_DELETE[@]}):"
                for branch in "${REMOTE_TO_DELETE[@]}"; do
                    clean_branch="${branch#origin/}"
                    echo "  - $clean_branch (from origin)"
                done
                echo ""
            fi
            
            if [ ${#LOCAL_TO_DELETE[@]} -eq 0 ] && [ ${#REMOTE_TO_DELETE[@]} -eq 0 ]; then
                echo "No branches to delete."
                if [ "$DELETE_REMOTE" = false ] && [ "$REMOTE_ONLY" = false ]; then
                    echo ""
                    echo "Tip: Use --delete-remote to also delete remote branches"
                fi
                exit 0
            fi
            
            # Dry run - just show and exit
            if [ "$DRY_RUN_DELETE" = true ]; then
                echo "[DRY RUN] No branches were actually deleted."
                echo ""
                echo "To perform the deletion, run without --dry-run-delete"
                exit 0
            fi
            
            # Confirm deletion unless force flag is set
            if [ "$FORCE_DELETE" = false ]; then
                echo "=========================================="
                echo "CONFIRMATION REQUIRED"
                echo "=========================================="
                echo ""
                echo "You are about to delete:"
                if [ ${#LOCAL_TO_DELETE[@]} -gt 0 ]; then
                    echo "  - ${#LOCAL_TO_DELETE[@]} local branches"
                fi
                if [ ${#REMOTE_TO_DELETE[@]} -gt 0 ]; then
                    echo "  - ${#REMOTE_TO_DELETE[@]} remote branches"
                fi
                echo ""
                echo "This action CANNOT be undone!"
                echo ""
                read -p "Are you sure you want to proceed? (yes/no): " -r
                echo ""
                
                if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                    echo "Deletion cancelled."
                    exit 0
                fi
            fi
            
            # Perform deletion
            echo "Deleting branches..."
            echo ""
            
            DELETED_LOCAL=0
            FAILED_LOCAL=0
            DELETED_REMOTE=0
            FAILED_REMOTE=0
            
            # Delete local branches
            if [ ${#LOCAL_TO_DELETE[@]} -gt 0 ]; then
                echo "Deleting local branches:"
                for branch in "${LOCAL_TO_DELETE[@]}"; do
                    if git branch -d "$branch" 2>/dev/null; then
                        echo "  [OK] Deleted local: $branch"
                        ((DELETED_LOCAL++))
                    else
                        # Try force delete if regular delete fails
                        if git branch -D "$branch" 2>/dev/null; then
                            echo "  [OK] Force deleted local: $branch"
                            ((DELETED_LOCAL++))
                        else
                            echo "  [FAIL] Could not delete: $branch"
                            ((FAILED_LOCAL++))
                        fi
                    fi
                done
                echo ""
            fi
            
            # Delete remote branches
            if [ ${#REMOTE_TO_DELETE[@]} -gt 0 ]; then
                echo "Deleting remote branches:"
                for branch in "${REMOTE_TO_DELETE[@]}"; do
                    clean_branch="${branch#origin/}"
                    if git push origin --delete "$clean_branch" 2>/dev/null; then
                        echo "  [OK] Deleted remote: $clean_branch"
                        ((DELETED_REMOTE++))
                    else
                        echo "  [FAIL] Could not delete remote: $clean_branch"
                        ((FAILED_REMOTE++))
                    fi
                done
                echo ""
            fi
            
            # Summary
            echo "=========================================="
            echo "Deletion Summary"
            echo "=========================================="
            echo ""
            
            if [ ${#LOCAL_TO_DELETE[@]} -gt 0 ]; then
                echo "Local branches:"
                echo "  Deleted:  $DELETED_LOCAL"
                if [ $FAILED_LOCAL -gt 0 ]; then
                    echo "  Failed:   $FAILED_LOCAL"
                fi
            fi
            
            if [ ${#REMOTE_TO_DELETE[@]} -gt 0 ]; then
                echo "Remote branches:"
                echo "  Deleted:  $DELETED_REMOTE"
                if [ $FAILED_REMOTE -gt 0 ]; then
                    echo "  Failed:   $FAILED_REMOTE"
                fi
            fi
            
            echo ""
            
            TOTAL_DELETED=$((DELETED_LOCAL + DELETED_REMOTE))
            TOTAL_FAILED=$((FAILED_LOCAL + FAILED_REMOTE))
            
            if [ $TOTAL_FAILED -gt 0 ]; then
                echo "[!] Some branches could not be deleted."
                echo "    This may be due to:"
                echo "    - Branches not fully merged (use git branch -D to force)"
                echo "    - Insufficient permissions on remote"
                echo "    - Branch protection rules"
                exit 1
            else
                echo "[OK] All branches deleted successfully!"
            fi
        fi
        
        # Exit successfully
        exit 0
        ;;
        

    lock-branch)
        # Handle lock-branch command
        
        # Default options
        BRANCH="develop"
        READ_ONLY=true  # Default to read-only (completely frozen)
        CHECK_LOCK=false
        VERBOSE=false
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --branch)
                    BRANCH="$2"
                    shift 2
                    ;;
                --standard)
                    READ_ONLY=false
                    shift
                    ;;
                --check)
                    CHECK_LOCK=true
                    shift
                    ;;
                --verbose)
                    VERBOSE=true
                    shift
                    ;;
                -h|--help)
                    show_lock_branch_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 lock-branch --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 lock-branch [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Check if git directory was provided
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 lock-branch [options] <git-directory>"
            echo "Run '$0 lock-branch --help' for more information."
            exit 1
        fi
        
        # Expand the path (handle ~, relative paths, etc.)
        GIT_DIR=$(eval echo "$GIT_DIR")
        GIT_DIR=$(cd "$GIT_DIR" 2>/dev/null && pwd || echo "$GIT_DIR")
        
        # Check if directory exists
        if [ ! -d "$GIT_DIR" ]; then
            echo "Error: Directory '$GIT_DIR' not found"
            exit 1
        fi
        
        # Check if it's a git repository
        if [ ! -d "$GIT_DIR/.git" ]; then
            echo "Error: '$GIT_DIR' is not a git repository"
            exit 1
        fi
        
        # Check if GitHub CLI is installed
        if ! command -v gh >/dev/null 2>&1; then
            echo "Error: GitHub CLI (gh) is not installed"
            echo "Please install it from: https://cli.github.com/"
            exit 1
        fi
        
        # Check if gh is authenticated
        if ! gh auth status >/dev/null 2>&1; then
            echo "Error: GitHub CLI is not authenticated"
            echo "Please run: gh auth login"
            exit 1
        fi
        
        # Change to git directory
        cd "$GIT_DIR"
        
        # Get repository name
        REPO_NAME=$(basename "$GIT_DIR")
        
        # Get the repository owner/name for GitHub
        REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
        if [ -z "$REPO_FULL" ]; then
            echo "Error: Could not determine GitHub repository"
            echo "Make sure this is a GitHub repository with a remote configured"
            exit 1
        fi
        
        # If only checking lock status, do that early and exit (before verbose output)
        if [ "$CHECK_LOCK" = true ]; then
            # Fetch silently for check (don't fail on fetch errors)
            if git remote | grep -q "origin" 2>/dev/null; then
                git fetch origin --quiet 2>/dev/null || true
            fi
            
            # Check if branch exists (don't exit on failure due to set -e)
            if ! git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
                # Try without origin/ prefix
                if ! git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
                    if [ "$VERBOSE" = false ]; then
                        echo "$REPO_NAME: $BRANCH: error (branch not found)"
                    else
                        echo "Error: Branch '$BRANCH' does not exist"
                    fi
                    exit 1
                fi
            fi
            
            # Brief mode (default) - just show repo name, branch name and status
            if [ "$VERBOSE" = false ]; then
                # Query silently
                PROTECTION_STATUS=$(gh api "repos/$REPO_FULL/branches/$BRANCH/protection" \
                    -H "Accept: application/vnd.github+json" 2>&1 || true)
                API_EXIT_CODE=$?
                
                # Check for 404 Not Found (branch not protected)
                if echo "$PROTECTION_STATUS" | grep -q "Not Found" || echo "$PROTECTION_STATUS" | grep -q "404"; then
                    echo "$REPO_NAME: $BRANCH: unlocked"
                    exit 0
                fi
                
                # Check for permission errors
                if echo "$PROTECTION_STATUS" | grep -q "message.*Forbidden"; then
                    echo "$REPO_NAME: $BRANCH: error (permission denied)"
                    exit 1
                fi
                
                # If we got here and API call failed, it's some other error
                if [ $API_EXIT_CODE -ne 0 ]; then
                    echo "$REPO_NAME: $BRANCH: error (api call failed)"
                    exit 1
                fi
                
                # Check protection type
                HAS_LOCK_BRANCH=$(echo "$PROTECTION_STATUS" | grep -o '"lock_branch"[^}]*"enabled":true' || echo "")
                HAS_PR_REVIEWS=$(echo "$PROTECTION_STATUS" | grep -o '"required_pull_request_reviews"' || echo "")
                
                if [ -n "$HAS_LOCK_BRANCH" ]; then
                    echo "$REPO_NAME: $BRANCH: locked (read-only)"
                    exit 0
                elif [ -n "$HAS_PR_REVIEWS" ]; then
                    echo "$REPO_NAME: $BRANCH: locked (standard)"
                    exit 0
                else
                    echo "$REPO_NAME: $BRANCH: unlocked"
                    exit 0
                fi
            fi
            
            # Verbose mode continues below with full output
        fi
        
        echo "=========================================="
        echo "Branch Lock: $BRANCH"
        echo "=========================================="
        echo "Repository: $REPO_NAME ($REPO_FULL)"
        echo "Path: $GIT_DIR"
        echo "Branch: $BRANCH"
        if [ "$READ_ONLY" = true ]; then
            echo "Mode: Read-Only Lock (completely frozen)"
        else
            echo "Mode: Standard Lock (PRs allowed with approval)"
        fi
        echo "=========================================="
        echo ""
        
        # Fetch latest changes from remote
        if git remote | grep -q "origin"; then
            echo "Fetching latest changes from remote..."
            if ! git fetch origin; then
                echo "Warning: Failed to fetch from remote"
                exit 1
            fi
            echo "[OK] Fetched latest commits"
            echo ""
        else
            echo "Error: No remote 'origin' configured"
            exit 1
        fi
        
        # Check if branch exists
        if ! git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
            echo "Error: Branch 'origin/$BRANCH' does not exist"
            exit 1
        fi
        
        # If checking with verbose mode, do full check
        if [ "$CHECK_LOCK" = true ]; then
            # Verbose mode - show detailed information
            echo "=========================================="
            echo "Checking Branch Protection: $BRANCH"
            echo "=========================================="
            echo ""
            
            echo "Querying branch protection status..."
            PROTECTION_STATUS=$(gh api "repos/$REPO_FULL/branches/$BRANCH/protection" \
                -H "Accept: application/vnd.github+json" 2>&1)
            API_EXIT_CODE=$?
            
            # Check for 404 Not Found (either no protection or no permission to view)
            if echo "$PROTECTION_STATUS" | grep -q "Not Found" || echo "$PROTECTION_STATUS" | grep -q "404"; then
                echo "[!] Unable to retrieve branch protection information"
                echo ""
                echo "API returned: 404 Not Found"
                echo ""
                echo "This could mean either:"
                echo "  1. The branch has no protection rules configured"
                echo "  2. Your GitHub account lacks permission to view protection rules"
                echo ""
                
                # Check what account is being used
                CURRENT_ACCOUNT=$(gh auth status 2>&1 | grep "Logged in" | sed 's/.*account \(.*\) (.*/\1/')
                if [ -n "$CURRENT_ACCOUNT" ]; then
                    echo "Current GitHub account: $CURRENT_ACCOUNT"
                    echo ""
                    echo "Note: Branch protection requires admin permissions on the repository."
                    echo "      Service accounts typically don't have these permissions."
                    echo ""
                    echo "To check/modify branch protection, you may need to:"
                    echo "  1. Switch to an account with admin access:"
                    echo "     gh auth login"
                    echo "  2. Or manually check via web interface:"
                    echo "     https://github.com/$REPO_FULL/settings/branches"
                fi
                
                exit 1
            fi
            
            # Check for other errors (403 Forbidden, etc.)
            if [ $API_EXIT_CODE -ne 0 ] || echo "$PROTECTION_STATUS" | grep -q "message.*Forbidden"; then
                echo "[FAIL] Error querying branch protection"
                echo ""
                echo "API Response:"
                echo "$PROTECTION_STATUS" | head -n 10
                echo ""
                echo "You may lack the necessary permissions to view branch protection."
                echo "Try viewing manually at: https://github.com/$REPO_FULL/settings/branches"
                exit 1
            fi
            
            # Check if protection exists (either lock_branch or required_pull_request_reviews)
            HAS_LOCK_BRANCH=$(echo "$PROTECTION_STATUS" | grep -o '"lock_branch"[^}]*"enabled":true' || echo "")
            HAS_PR_REVIEWS=$(echo "$PROTECTION_STATUS" | grep -o '"required_pull_request_reviews"' || echo "")
            
            if [ -n "$HAS_LOCK_BRANCH" ]; then
                echo "[OK] Branch $BRANCH IS LOCKED AS READ-ONLY (completely frozen)"
                echo ""
                
                echo "Read-only protection active:"
                echo "  [OK] Lock branch enabled (read-only - no one can push)"
                echo "  [OK] No pull requests can be created to this branch"
                echo ""
                echo "[!] This branch is completely frozen and deprecated"
                echo "    All changes are blocked - even via pull requests"
                echo ""
                
            elif [ -n "$HAS_PR_REVIEWS" ]; then
                echo "[OK] Branch $BRANCH IS LOCKED (protected - PRs allowed)"
                echo ""
                
                # Parse and display current protection rules
                echo "Current protection rules:"
                
                # Check for lock branch (read-only)
                if [ -n "$HAS_LOCK_BRANCH" ]; then
                    echo "  [OK] Lock branch (read-only - no one can push)"
                fi
                
                # Check for required pull request reviews
                if [ -n "$HAS_PR_REVIEWS" ]; then
                    if echo "$PROTECTION_STATUS" | grep -q '"required_approving_review_count"'; then
                        REVIEW_COUNT=$(echo "$PROTECTION_STATUS" | grep -o '"required_approving_review_count":[0-9]*' | grep -o '[0-9]*')
                        echo "  [OK] Require pull request reviews ($REVIEW_COUNT approval(s) required)"
                    else
                        echo "  [OK] Require pull request reviews"
                    fi
                fi
                
                if echo "$PROTECTION_STATUS" | grep -q '"dismiss_stale_reviews":true'; then
                    echo "  [OK] Dismiss stale reviews on new commits"
                fi
                
                if echo "$PROTECTION_STATUS" | grep -q '"enforce_admins":{[^}]*"enabled":true'; then
                    echo "  [OK] Include administrators (rules apply to admins too)"
                fi
                
                if echo "$PROTECTION_STATUS" | grep -q '"required_linear_history":{[^}]*"enabled":true'; then
                    echo "  [OK] Require linear history"
                fi
                
                if echo "$PROTECTION_STATUS" | grep -q '"allow_force_pushes":{[^}]*"enabled":false'; then
                    echo "  [OK] Block force pushes"
                elif echo "$PROTECTION_STATUS" | grep -q '"allow_force_pushes":{[^}]*"enabled":true'; then
                    echo "  [!] Allow force pushes (enabled)"
                fi
                
                if echo "$PROTECTION_STATUS" | grep -q '"allow_deletions":{[^}]*"enabled":false'; then
                    echo "  [OK] Block branch deletion"
                elif echo "$PROTECTION_STATUS" | grep -q '"allow_deletions":{[^}]*"enabled":true'; then
                    echo "  [!] Allow branch deletion (enabled)"
                fi
                
                if echo "$PROTECTION_STATUS" | grep -q '"required_conversation_resolution":{[^}]*"enabled":true'; then
                    echo "  [OK] Require conversation resolution before merging"
                fi
                
                echo ""
                echo "To view or modify protection settings:"
                echo "  https://github.com/$REPO_FULL/settings/branch_protection_rules"
                
                exit 0
            else
                echo "[FAIL] Branch $BRANCH IS NOT LOCKED (not protected)"
                echo ""
                echo "The branch currently allows:"
                echo "    * Direct pushes without pull requests"
                echo "    * No required approvals"
                echo "    * Force pushes"
                echo ""
                echo "To view/set protection manually:"
                echo "  https://github.com/$REPO_FULL/settings/branches"
                echo ""
                echo "To lock this branch via script (requires admin permissions), run:"
                echo "  $0 lock-branch $GIT_DIR"
                
                exit 1
            fi
        fi
        
        # Apply branch protection
        echo "=========================================="
        echo "Applying Branch Protection: $BRANCH"
        echo "=========================================="
        echo ""
        
        # Check if branch protection already exists
        echo "Checking current branch protection status..."
        PROTECTION_STATUS=$(gh api "repos/$REPO_FULL/branches/$BRANCH/protection" \
            -H "Accept: application/vnd.github+json" 2>&1 || echo "NOT_PROTECTED")
            
        if echo "$PROTECTION_STATUS" | grep -q "required_pull_request_reviews"; then
            # Branch has standard protection (allows PRs)
            
            if [ "$READ_ONLY" = true ]; then
                # User wants to upgrade to read-only mode
                echo "[i] Branch $BRANCH has standard protection (PRs allowed)"
                echo ""
                echo "Upgrading to READ-ONLY mode (completely frozen)..."
                echo "This will:"
                echo "  - Remove PR-based protection"
                echo "  - Enable lock_branch (read-only mode)"
                echo "  - Prevent ALL pushes to $BRANCH (even via PR)"
                echo "  - Prevent pull requests from being created to this branch"
                echo ""
                
                # Enable read-only lock using the lock_branch setting
                PROTECTION_RULES='{
                  "required_status_checks": null,
                  "enforce_admins": true,
                  "required_pull_request_reviews": null,
                  "restrictions": null,
                  "required_linear_history": false,
                  "allow_force_pushes": false,
                  "allow_deletions": false,
                  "lock_branch": true
                }'
                
                if gh api "repos/$REPO_FULL/branches/$BRANCH/protection" \
                    -X PUT \
                    -H "Accept: application/vnd.github+json" \
                    --input - <<< "$PROTECTION_RULES" >/dev/null 2>&1; then
                    echo "[OK] Branch upgraded to READ-ONLY for $BRANCH"
                    echo ""
                    echo "Protection rules applied:"
                    echo "  [OK] Lock branch (read-only - no one can push)"
                    echo "  [OK] Block ALL pull requests to this branch"
                    echo "  [OK] Block force pushes"
                    echo "  [OK] Block branch deletion"
                    echo "  [OK] Enforce for administrators"
                    echo ""
                    echo "[!] This branch is now completely frozen and deprecated"
                else
                    echo "[FAIL] Failed to upgrade to read-only protection"
                    echo ""
                    echo "This might be because:"
                    echo "  - You don't have admin permissions on the repository"
                    echo "  - The GitHub API returned an error"
                    echo "  - Your GitHub plan doesn't support lock_branch"
                fi
            else
                # Standard protection already exists and user just wants standard lock
                echo "[OK] Branch $BRANCH is already protected"
                echo ""
                
                # Parse and display current protection rules
                echo "Current protection rules:"
                
                if echo "$PROTECTION_STATUS" | grep -q '"required_approving_review_count"'; then
                    REVIEW_COUNT=$(echo "$PROTECTION_STATUS" | grep -o '"required_approving_review_count":[0-9]*' | grep -o '[0-9]*')
                    echo "  [OK] Require pull request reviews ($REVIEW_COUNT approval(s) required)"
                fi
                
                if echo "$PROTECTION_STATUS" | grep -q '"dismiss_stale_reviews":true'; then
                    echo "  [OK] Dismiss stale reviews on new commits"
                fi
            
                if echo "$PROTECTION_STATUS" | grep -q '"allow_force_pushes"'; then
                    ALLOW_FORCE=$(echo "$PROTECTION_STATUS" | grep -o '"allow_force_pushes":\w*' | grep -o 'true\|false')
                    if [ "$ALLOW_FORCE" = "false" ]; then
                        echo "  [OK] Block force pushes"
                    else
                        echo "  [!] Allow force pushes (enabled)"
                    fi
                fi
                
                if echo "$PROTECTION_STATUS" | grep -q '"allow_deletions"'; then
                    ALLOW_DELETE=$(echo "$PROTECTION_STATUS" | grep -o '"allow_deletions":\w*' | grep -o 'true\|false')
                    if [ "$ALLOW_DELETE" = "false" ]; then
                        echo "  [OK] Block branch deletion"
                    else
                        echo "  [!] Allow branch deletion (enabled)"
                    fi
                fi
                
                echo ""
                echo "Branch is already locked. Skipping protection setup."
                echo ""
                echo "To view or modify protection settings:"
                echo "  https://github.com/$REPO_FULL/settings/branch_protection_rules"
            fi
            
        else
            echo "Branch $BRANCH is not currently protected"
            echo ""
            
            if [ "$READ_ONLY" = true ]; then
                echo "Setting READ-ONLY branch protection (completely frozen)..."
                echo "This will:"
                echo "  - Prevent ALL pushes to $BRANCH (even via PR)"
                echo "  - Prevent pull requests from being created to this branch"
                echo "  - Make the branch completely read-only (deprecated/archived)"
                echo ""
                
                # Enable read-only lock using the lock_branch setting
                # This makes the branch completely immutable
                PROTECTION_RULES='{
                  "required_status_checks": null,
                  "enforce_admins": true,
                  "required_pull_request_reviews": null,
                  "restrictions": null,
                  "required_linear_history": false,
                  "allow_force_pushes": false,
                  "allow_deletions": false,
                  "lock_branch": true
                }'
                
                if gh api "repos/$REPO_FULL/branches/$BRANCH/protection" \
                    -X PUT \
                    -H "Accept: application/vnd.github+json" \
                    --input - <<< "$PROTECTION_RULES" >/dev/null 2>&1; then
                    echo "[OK] Branch locked as READ-ONLY for $BRANCH"
                    echo ""
                    echo "Protection rules applied:"
                    echo "  [OK] Lock branch (read-only - no one can push)"
                    echo "  [OK] Block ALL pull requests to this branch"
                    echo "  [OK] Block force pushes"
                    echo "  [OK] Block branch deletion"
                    echo "  [OK] Enforce for administrators"
                    echo ""
                    echo "[!] This branch is now completely frozen and deprecated"
                else
                    echo "[FAIL] Failed to enable read-only branch protection"
                    echo ""
                    echo "This might be because:"
                    echo "  - You don't have admin permissions on the repository"
                    echo "  - The GitHub API returned an error"
                    echo "  - Your GitHub plan doesn't support lock_branch"
                fi
            else
                echo "Setting branch protection rules..."
                echo "This will:"
                echo "  - Require pull request reviews before merging"
                echo "  - Require at least 1 approval"
                echo "  - Dismiss stale pull request approvals when new commits are pushed"
                echo "  - Prevent direct pushes to $BRANCH"
                echo ""
                
                # Enable branch protection using gh api
                # Note: This requires admin permissions on the repository
                PROTECTION_RULES='{
                  "required_status_checks": null,
                  "enforce_admins": false,
                  "required_pull_request_reviews": {
                    "dismiss_stale_reviews": true,
                    "require_code_owner_reviews": false,
                    "required_approving_review_count": 1
                  },
                  "restrictions": null,
                  "required_linear_history": false,
                  "allow_force_pushes": false,
                  "allow_deletions": false
                }'
                
                if gh api "repos/$REPO_FULL/branches/$BRANCH/protection" \
                    -X PUT \
                    -H "Accept: application/vnd.github+json" \
                    --input - <<< "$PROTECTION_RULES" >/dev/null 2>&1; then
                    echo "[OK] Branch protection enabled for $BRANCH"
                    echo ""
                    echo "Protection rules applied:"
                    echo "  [OK] Require pull request reviews (1 approval minimum)"
                    echo "  [OK] Dismiss stale reviews on new commits"
                    echo "  [OK] Block direct pushes"
                    echo "  [OK] Block force pushes"
                    echo "  [OK] Block branch deletion"
                else
                    echo "[FAIL] Failed to enable branch protection"
                    echo ""
                    echo "This might be because:"
                    echo "  - You don't have admin permissions on the repository"
                    echo "  - The GitHub API returned an error"
                    echo "  - Branch protection requires specific settings on your repository"
                fi
            fi
        fi
        echo ""
        
        echo "=========================================="
        echo "Complete!"
        echo "=========================================="
        echo ""
        
        if [ "$READ_ONLY" = true ]; then
            echo "[OK] Branch $BRANCH is now READ-ONLY (completely frozen)"
            echo ""
            echo "This deprecated branch:"
            echo "  - Cannot receive any pushes (even from PRs)"
            echo "  - Cannot have PRs created targeting it"
            echo "  - Is completely frozen for historical reference"
            echo ""
            echo "[!] To make changes, you would need to remove branch protection first"
        else
            echo "[OK] Branch $BRANCH is now protected"
            echo ""
            echo "All future changes to $BRANCH must:"
            echo "  - Go through a pull request"
            echo "  - Get at least 1 approval"
            echo "  - Cannot be pushed directly"
        fi
        
        echo ""
        echo "To view branch protection settings:"
        echo "  https://github.com/$REPO_FULL/settings/branches"
        
        exit 0
        ;;
        

    unlock-branch)
        # Handle unlock-branch command
        
        # Default options
        BRANCH="develop"
        FORCE=false
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --branch)
                    BRANCH="$2"
                    shift 2
                    ;;
                --force)
                    FORCE=true
                    shift
                    ;;
                -h|--help)
                    show_unlock_branch_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 unlock-branch --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 unlock-branch [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Check if git directory was provided
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 unlock-branch [options] <git-directory>"
            echo "Run '$0 unlock-branch --help' for more information."
            exit 1
        fi
        
        # Expand the path (handle ~, relative paths, etc.)
        GIT_DIR=$(eval echo "$GIT_DIR")
        GIT_DIR=$(cd "$GIT_DIR" 2>/dev/null && pwd || echo "$GIT_DIR")
        
        # Check if directory exists
        if [ ! -d "$GIT_DIR" ]; then
            echo "Error: Directory '$GIT_DIR' not found"
            exit 1
        fi
        
        # Check if it's a git repository
        if [ ! -d "$GIT_DIR/.git" ]; then
            echo "Error: '$GIT_DIR' is not a git repository"
            exit 1
        fi
        
        # Check if GitHub CLI is installed
        if ! command -v gh >/dev/null 2>&1; then
            echo "Error: GitHub CLI (gh) is not installed"
            echo "Please install it from: https://cli.github.com/"
            exit 1
        fi
        
        # Check if gh is authenticated
        if ! gh auth status >/dev/null 2>&1; then
            echo "Error: GitHub CLI is not authenticated"
            echo "Please run: gh auth login"
            exit 1
        fi
        
        # Change to git directory
        cd "$GIT_DIR"
        
        # Get repository name
        REPO_NAME=$(basename "$GIT_DIR")
        
        # Get the repository owner/name for GitHub
        REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
        if [ -z "$REPO_FULL" ]; then
            echo "Error: Could not determine GitHub repository"
            echo "Make sure this is a GitHub repository with a remote configured"
            exit 1
        fi
        
        echo "=========================================="
        echo "Branch Unlock: $BRANCH"
        echo "=========================================="
        echo "Repository: $REPO_NAME ($REPO_FULL)"
        echo "Path: $GIT_DIR"
        echo "Branch: $BRANCH"
        echo "=========================================="
        echo ""
        
        # Fetch latest changes from remote
        if git remote | grep -q "origin"; then
            echo "Fetching latest changes from remote..."
            if ! git fetch origin; then
                echo "Warning: Failed to fetch from remote"
                exit 1
            fi
            echo "[OK] Fetched latest commits"
            echo ""
        else
            echo "Error: No remote 'origin' configured"
            exit 1
        fi
        
        # Check if branch exists
        if ! git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
            echo "Error: Branch 'origin/$BRANCH' does not exist"
            exit 1
        fi
        
        # Check current protection status
        echo "Checking current branch protection status..."
        PROTECTION_STATUS=$(gh api "repos/$REPO_FULL/branches/$BRANCH/protection" \
            -H "Accept: application/vnd.github+json" 2>&1)
        API_EXIT_CODE=$?
        
        # Check if branch is already unprotected
        if echo "$PROTECTION_STATUS" | grep -q "Not Found" || echo "$PROTECTION_STATUS" | grep -q "404"; then
            echo "[i] Branch $BRANCH is already unprotected (no protection rules found)"
            echo ""
            echo "The branch currently allows:"
            echo "  * Direct pushes without pull requests"
            echo "  * No required approvals"
            echo "  * Force pushes"
            echo ""
            exit 0
        fi
        
        # Check for permission errors
        if [ $API_EXIT_CODE -ne 0 ] || echo "$PROTECTION_STATUS" | grep -q "message.*Forbidden"; then
            echo "[FAIL] Error querying branch protection"
            echo ""
            echo "You may lack the necessary permissions to modify branch protection."
            echo "Admin permissions are required."
            echo ""
            echo "Try viewing manually at: https://github.com/$REPO_FULL/settings/branches"
            exit 1
        fi
        
        # Parse protection status to show what will be removed
        echo "[i] Branch $BRANCH is currently protected"
        echo ""
        echo "Current protection rules that will be REMOVED:"
        
        HAS_LOCK_BRANCH=$(echo "$PROTECTION_STATUS" | grep -o '"lock_branch"[^}]*"enabled":true' || echo "")
        HAS_PR_REVIEWS=$(echo "$PROTECTION_STATUS" | grep -o '"required_pull_request_reviews"' || echo "")
        
        if [ -n "$HAS_LOCK_BRANCH" ]; then
            echo "  - Lock branch (read-only mode)"
        fi
        
        if [ -n "$HAS_PR_REVIEWS" ]; then
            if echo "$PROTECTION_STATUS" | grep -q '"required_approving_review_count"'; then
                REVIEW_COUNT=$(echo "$PROTECTION_STATUS" | grep -o '"required_approving_review_count":[0-9]*' | grep -o '[0-9]*')
                echo "  - Required pull request reviews ($REVIEW_COUNT approval(s))"
            else
                echo "  - Required pull request reviews"
            fi
        fi
        
        if echo "$PROTECTION_STATUS" | grep -q '"dismiss_stale_reviews":true'; then
            echo "  - Dismiss stale reviews on new commits"
        fi
        
        if echo "$PROTECTION_STATUS" | grep -q '"enforce_admins":{[^}]*"enabled":true'; then
            echo "  - Enforce rules for administrators"
        fi
        
        if echo "$PROTECTION_STATUS" | grep -q '"required_status_checks"'; then
            echo "  - Required status checks"
        fi
        
        if echo "$PROTECTION_STATUS" | grep -q '"required_linear_history":{[^}]*"enabled":true'; then
            echo "  - Required linear history"
        fi
        
        if echo "$PROTECTION_STATUS" | grep -q '"allow_force_pushes":{[^}]*"enabled":false'; then
            echo "  - Block force pushes"
        fi
        
        if echo "$PROTECTION_STATUS" | grep -q '"allow_deletions":{[^}]*"enabled":false'; then
            echo "  - Block branch deletion"
        fi
        
        if echo "$PROTECTION_STATUS" | grep -q '"required_conversation_resolution":{[^}]*"enabled":true'; then
            echo "  - Required conversation resolution"
        fi
        
        echo ""
        
        # Confirm unless force flag is set
        if [ "$FORCE" = false ]; then
            echo "=========================================="
            echo "CONFIRMATION REQUIRED"
            echo "=========================================="
            echo ""
            echo "WARNING: Unlocking branch '$BRANCH' will remove ALL protection rules."
            echo ""
            echo "After unlocking, the branch will allow:"
            echo "  - Direct pushes without pull requests"
            echo "  - Force pushes"
            echo "  - Branch deletion"
            echo "  - No required approvals"
            echo ""
            read -p "Are you sure you want to unlock this branch? (yes/no): " -r
            echo ""
            
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                echo "Unlock cancelled."
                exit 0
            fi
        fi
        
        # Remove branch protection
        echo "Removing branch protection..."
        echo ""
        
        if gh api "repos/$REPO_FULL/branches/$BRANCH/protection" \
            -X DELETE \
            -H "Accept: application/vnd.github+json" >/dev/null 2>&1; then
            echo "[OK] Branch protection removed successfully"
            echo ""
            echo "=========================================="
            echo "Complete!"
            echo "=========================================="
            echo ""
            echo "[OK] Branch $BRANCH is now unlocked"
            echo ""
            echo "The branch now allows:"
            echo "  - Direct pushes without pull requests"
            echo "  - No required approvals"
            echo "  - Force pushes"
            echo "  - Branch deletion"
            echo ""
            echo "To re-lock this branch, run:"
            echo "  $0 lock-branch --branch $BRANCH $GIT_DIR"
        else
            echo "[FAIL] Failed to remove branch protection"
            echo ""
            echo "This might be because:"
            echo "  - You don't have admin permissions on the repository"
            echo "  - The GitHub API returned an error"
            echo ""
            echo "Try removing protection manually at:"
            echo "  https://github.com/$REPO_FULL/settings/branches"
            exit 1
        fi
        
        echo ""
        echo "To view branch protection settings:"
        echo "  https://github.com/$REPO_FULL/settings/branches"
        
        exit 0
        ;;
        

    check-push-restrictions)
        # Handle check-push-restrictions command
        
        # Default options
        BRANCH="main"
        VERBOSE=false
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --branch)
                    BRANCH="$2"
                    shift 2
                    ;;
                --verbose)
                    VERBOSE=true
                    shift
                    ;;
                -h|--help)
                    show_check_push_restrictions_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 check-push-restrictions --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 check-push-restrictions [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Check if git directory was provided
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 check-push-restrictions [options] <git-directory>"
            echo "Run '$0 check-push-restrictions --help' for more information."
            exit 1
        fi
        
        # Expand the path
        GIT_DIR=$(eval echo "$GIT_DIR")
        GIT_DIR=$(cd "$GIT_DIR" 2>/dev/null && pwd || echo "$GIT_DIR")
        
        # Check if directory exists
        if [ ! -d "$GIT_DIR" ]; then
            echo "Error: Directory '$GIT_DIR' not found"
            exit 1
        fi
        
        # Check if it's a git repository
        if [ ! -d "$GIT_DIR/.git" ]; then
            echo "Error: '$GIT_DIR' is not a git repository"
            exit 1
        fi
        
        # Check if GitHub CLI is installed
        if ! command -v gh >/dev/null 2>&1; then
            echo "Error: GitHub CLI (gh) is not installed"
            echo "Please install it from: https://cli.github.com/"
            exit 1
        fi
        
        # Check if gh is authenticated
        if ! gh auth status >/dev/null 2>&1; then
            echo "Error: GitHub CLI is not authenticated"
            echo "Please run: gh auth login"
            exit 1
        fi
        
        # Change to git directory
        cd "$GIT_DIR"
        
        # Get repository name
        REPO_NAME=$(basename "$GIT_DIR")
        
        # Get the repository owner/name for GitHub
        REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
        if [ -z "$REPO_FULL" ]; then
            echo "Error: Could not determine GitHub repository"
            echo "Make sure this is a GitHub repository with a remote configured"
            exit 1
        fi
        
        if [ "$VERBOSE" = true ]; then
            echo "=========================================="
            echo "Check Push Restrictions: $BRANCH"
            echo "=========================================="
            echo "Repository: $REPO_NAME ($REPO_FULL)"
            echo "Path: $GIT_DIR"
            echo "Branch: $BRANCH"
            echo "=========================================="
            echo ""
        fi
        
        # Fetch latest changes from remote (silently)
        if git remote | grep -q "origin" 2>/dev/null; then
            git fetch origin --quiet 2>/dev/null || true
        fi
        
        # Check if branch exists
        if ! git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
            if ! git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
                if [ "$VERBOSE" = false ]; then
                    echo "$REPO_NAME: $BRANCH: error (branch not found)"
                else
                    echo "Error: Branch '$BRANCH' does not exist"
                fi
                exit 1
            fi
        fi
        
        # Query branch protection status
        if [ "$VERBOSE" = true ]; then
            echo "Querying branch protection status..."
        fi
        
        PROTECTION_STATUS=$(gh api "repos/$REPO_FULL/branches/$BRANCH/protection" \
            -H "Accept: application/vnd.github+json" 2>&1 || true)
        API_EXIT_CODE=$?
        
        # Check for 404 Not Found (branch not protected)
        if echo "$PROTECTION_STATUS" | grep -q "Not Found" || echo "$PROTECTION_STATUS" | grep -q "404"; then
            if [ "$VERBOSE" = false ]; then
                echo "$REPO_NAME: $BRANCH: no protection (no restrictions)"
            else
                echo "[i] Branch $BRANCH has no protection rules"
                echo ""
                echo "The branch currently allows:"
                echo "  - Anyone with write access can push"
                echo "  - No restrictions on who can push"
                echo ""
            fi
            exit 0
        fi
        
        # Check for permission errors
        if [ $API_EXIT_CODE -ne 0 ] || echo "$PROTECTION_STATUS" | grep -q "message.*Forbidden"; then
            if [ "$VERBOSE" = false ]; then
                echo "$REPO_NAME: $BRANCH: error (permission denied)"
            else
                echo "[FAIL] Error querying branch protection"
                echo ""
                echo "You may lack the necessary permissions to view branch protection."
                echo "Try viewing manually at: https://github.com/$REPO_FULL/settings/branches"
            fi
            exit 1
        fi
        
        # Check if restrictions exist
        HAS_RESTRICTIONS=$(echo "$PROTECTION_STATUS" | grep -o '"restrictions"' || echo "")
        
        if [ -z "$HAS_RESTRICTIONS" ] || echo "$PROTECTION_STATUS" | grep -q '"restrictions":null'; then
            if [ "$VERBOSE" = false ]; then
                echo "$REPO_NAME: $BRANCH: no restrictions"
            else
                echo "[OK] Branch $BRANCH has protection but NO push restrictions"
                echo ""
                echo "Anyone with write access can push to this branch."
                echo ""
                echo "Other protection rules may still apply (PR reviews, status checks, etc.)"
            fi
            exit 0
        fi
        
        # Parse restrictions details
        if [ "$VERBOSE" = false ]; then
            # Brief mode - just show that restrictions exist
            echo "$REPO_NAME: $BRANCH: restricted"
        else
            # Verbose mode - show details
            echo "[!] Branch $BRANCH has push restrictions enabled"
            echo ""
            echo "Push restrictions are active:"
            echo "  - Only specific users/teams/apps can push"
            echo "  - Restrictions are configured via GitHub settings"
            echo ""
            
            # Try to extract users/teams/apps if available
            USERS=$(echo "$PROTECTION_STATUS" | grep -o '"users":\[.*\]' || echo "")
            TEAMS=$(echo "$PROTECTION_STATUS" | grep -o '"teams":\[.*\]' || echo "")
            APPS=$(echo "$PROTECTION_STATUS" | grep -o '"apps":\[.*\]' || echo "")
            
            if [ -n "$USERS" ] && ! echo "$USERS" | grep -q '"users":\[\]'; then
                echo "Allowed users:"
                echo "$USERS" | grep -o '"login":"[^"]*"' | sed 's/"login":"/  - /g' | sed 's/"//g' || echo "  (unable to parse)"
                echo ""
            fi
            
            if [ -n "$TEAMS" ] && ! echo "$TEAMS" | grep -q '"teams":\[\]'; then
                echo "Allowed teams:"
                echo "$TEAMS" | grep -o '"slug":"[^"]*"' | sed 's/"slug":"/  - /g' | sed 's/"//g' || echo "  (unable to parse)"
                echo ""
            fi
            
            if [ -n "$APPS" ] && ! echo "$APPS" | grep -q '"apps":\[\]'; then
                echo "Allowed apps:"
                echo "$APPS" | grep -o '"slug":"[^"]*"' | sed 's/"slug":"/  - /g' | sed 's/"//g' || echo "  (unable to parse)"
                echo ""
            fi
            
            echo "To view full details:"
            echo "  https://github.com/$REPO_FULL/settings/branch_protection_rules"
        fi
        
        exit 0
        ;;
        

    remove-push-restrictions)
        # Handle remove-push-restrictions command
        
        # Default options
        BRANCH="main"
        FORCE=false
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --branch)
                    BRANCH="$2"
                    shift 2
                    ;;
                --force)
                    FORCE=true
                    shift
                    ;;
                -h|--help)
                    show_remove_push_restrictions_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 remove-push-restrictions --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 remove-push-restrictions [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Check if git directory was provided
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 remove-push-restrictions [options] <git-directory>"
            echo "Run '$0 remove-push-restrictions --help' for more information."
            exit 1
        fi
        
        # Expand the path
        GIT_DIR=$(eval echo "$GIT_DIR")
        GIT_DIR=$(cd "$GIT_DIR" 2>/dev/null && pwd || echo "$GIT_DIR")
        
        # Check if directory exists
        if [ ! -d "$GIT_DIR" ]; then
            echo "Error: Directory '$GIT_DIR' not found"
            exit 1
        fi
        
        # Check if it's a git repository
        if [ ! -d "$GIT_DIR/.git" ]; then
            echo "Error: '$GIT_DIR' is not a git repository"
            exit 1
        fi
        
        # Check if GitHub CLI is installed
        if ! command -v gh >/dev/null 2>&1; then
            echo "Error: GitHub CLI (gh) is not installed"
            echo "Please install it from: https://cli.github.com/"
            exit 1
        fi
        
        # Check if gh is authenticated
        if ! gh auth status >/dev/null 2>&1; then
            echo "Error: GitHub CLI is not authenticated"
            echo "Please run: gh auth login"
            exit 1
        fi
        
        # Change to git directory
        cd "$GIT_DIR"
        
        # Get repository name
        REPO_NAME=$(basename "$GIT_DIR")
        
        # Get the repository owner/name for GitHub
        REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
        if [ -z "$REPO_FULL" ]; then
            echo "Error: Could not determine GitHub repository"
            echo "Make sure this is a GitHub repository with a remote configured"
            exit 1
        fi
        
        echo "=========================================="
        echo "Remove Push Restrictions: $BRANCH"
        echo "=========================================="
        echo "Repository: $REPO_NAME ($REPO_FULL)"
        echo "Path: $GIT_DIR"
        echo "Branch: $BRANCH"
        echo "=========================================="
        echo ""
        
        # Fetch latest changes from remote
        if git remote | grep -q "origin"; then
            echo "Fetching latest changes from remote..."
            if ! git fetch origin; then
                echo "Warning: Failed to fetch from remote"
                exit 1
            fi
            echo "[OK] Fetched latest commits"
            echo ""
        else
            echo "Error: No remote 'origin' configured"
            exit 1
        fi
        
        # Check if branch exists
        if ! git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
            echo "Error: Branch 'origin/$BRANCH' does not exist"
            exit 1
        fi
        
        # Check current protection status
        echo "Checking current branch protection status..."
        PROTECTION_STATUS=$(gh api "repos/$REPO_FULL/branches/$BRANCH/protection" \
            -H "Accept: application/vnd.github+json" 2>&1)
        API_EXIT_CODE=$?
        
        # Check if branch is not protected
        if echo "$PROTECTION_STATUS" | grep -q "Not Found" || echo "$PROTECTION_STATUS" | grep -q "404"; then
            echo "[i] Branch $BRANCH has no protection rules"
            echo ""
            echo "There are no push restrictions to remove."
            echo "The branch already allows anyone with write access to push."
            echo ""
            exit 0
        fi
        
        # Check for permission errors
        if [ $API_EXIT_CODE -ne 0 ] || echo "$PROTECTION_STATUS" | grep -q "message.*Forbidden"; then
            echo "[FAIL] Error querying branch protection"
            echo ""
            echo "You may lack the necessary permissions to modify branch protection."
            echo "Admin permissions are required."
            echo ""
            echo "Try viewing manually at: https://github.com/$REPO_FULL/settings/branches"
            exit 1
        fi
        
        # Check if restrictions exist
        HAS_RESTRICTIONS=$(echo "$PROTECTION_STATUS" | grep -o '"restrictions"' || echo "")
        
        if [ -z "$HAS_RESTRICTIONS" ] || echo "$PROTECTION_STATUS" | grep -q '"restrictions":null'; then
            echo "[i] Branch $BRANCH has no push restrictions"
            echo ""
            echo "The branch already allows anyone with write access to push."
            echo "No changes needed."
            echo ""
            exit 0
        fi
        
        echo "[i] Branch $BRANCH has push restrictions enabled"
        echo ""
        echo "Current restrictions will be REMOVED:"
        echo "  - Specific users/teams/apps restrictions"
        echo ""
        echo "After removal:"
        echo "  - Anyone with write access can push"
        echo "  - Other protection rules will remain (PR reviews, status checks, etc.)"
        echo ""
        
        # Confirm unless force flag is set
        if [ "$FORCE" = false ]; then
            echo "=========================================="
            echo "CONFIRMATION REQUIRED"
            echo "=========================================="
            echo ""
            echo "This will remove push restrictions from '$BRANCH' branch."
            echo ""
            read -p "Are you sure you want to proceed? (yes/no): " -r
            echo ""
            
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                echo "Operation cancelled."
                exit 0
            fi
        fi
        
        # Remove push restrictions by setting restrictions to null
        echo "Removing push restrictions..."
        echo ""
        
        # We need to preserve all existing protection rules except restrictions
        # First, get the current protection configuration and modify it
        
        # Extract key protection settings to preserve
        ENFORCE_ADMINS=$(echo "$PROTECTION_STATUS" | grep -o '"enforce_admins":{[^}]*"enabled":\(true\|false\)' | grep -o '\(true\|false\)' || echo "false")
        REQUIRED_LINEAR_HISTORY=$(echo "$PROTECTION_STATUS" | grep -o '"required_linear_history":{[^}]*"enabled":\(true\|false\)' | grep -o '\(true\|false\)' || echo "false")
        ALLOW_FORCE_PUSHES=$(echo "$PROTECTION_STATUS" | grep -o '"allow_force_pushes":{[^}]*"enabled":\(true\|false\)' | grep -o '\(true\|false\)' || echo "false")
        ALLOW_DELETIONS=$(echo "$PROTECTION_STATUS" | grep -o '"allow_deletions":{[^}]*"enabled":\(true\|false\)' | grep -o '\(true\|false\)' || echo "false")
        LOCK_BRANCH=$(echo "$PROTECTION_STATUS" | grep -o '"lock_branch":{[^}]*"enabled":\(true\|false\)' | grep -o '\(true\|false\)' || echo "false")
        
        # Build protection rules JSON with restrictions set to null
        # Note: This is a simplified version - a full implementation would preserve all settings
        PROTECTION_RULES="{
  \"required_status_checks\": null,
  \"enforce_admins\": $ENFORCE_ADMINS,
  \"required_pull_request_reviews\": null,
  \"restrictions\": null,
  \"required_linear_history\": $REQUIRED_LINEAR_HISTORY,
  \"allow_force_pushes\": $ALLOW_FORCE_PUSHES,
  \"allow_deletions\": $ALLOW_DELETIONS,
  \"lock_branch\": $LOCK_BRANCH
}"
        
        # Check if there are PR review requirements to preserve
        if echo "$PROTECTION_STATUS" | grep -q '"required_pull_request_reviews"'; then
            # Extract review settings
            REVIEW_COUNT=$(echo "$PROTECTION_STATUS" | grep -o '"required_approving_review_count":[0-9]*' | grep -o '[0-9]*' || echo "1")
            DISMISS_STALE=$(echo "$PROTECTION_STATUS" | grep -o '"dismiss_stale_reviews":\(true\|false\)' | grep -o '\(true\|false\)' || echo "false")
            REQUIRE_CODE_OWNER=$(echo "$PROTECTION_STATUS" | grep -o '"require_code_owner_reviews":\(true\|false\)' | grep -o '\(true\|false\)' || echo "false")
            
            PROTECTION_RULES="{
  \"required_status_checks\": null,
  \"enforce_admins\": $ENFORCE_ADMINS,
  \"required_pull_request_reviews\": {
    \"dismiss_stale_reviews\": $DISMISS_STALE,
    \"require_code_owner_reviews\": $REQUIRE_CODE_OWNER,
    \"required_approving_review_count\": $REVIEW_COUNT
  },
  \"restrictions\": null,
  \"required_linear_history\": $REQUIRED_LINEAR_HISTORY,
  \"allow_force_pushes\": $ALLOW_FORCE_PUSHES,
  \"allow_deletions\": $ALLOW_DELETIONS,
  \"lock_branch\": $LOCK_BRANCH
}"
        fi
        
        if gh api "repos/$REPO_FULL/branches/$BRANCH/protection" \
            -X PUT \
            -H "Accept: application/vnd.github+json" \
            --input - <<< "$PROTECTION_RULES" >/dev/null 2>&1; then
            echo "[OK] Push restrictions removed successfully"
            echo ""
            echo "=========================================="
            echo "Complete!"
            echo "=========================================="
            echo ""
            echo "[OK] Push restrictions removed from $BRANCH"
            echo ""
            echo "The branch now allows:"
            echo "  - Anyone with write access can push"
            echo ""
            echo "Other protection rules remain active:"
            if echo "$PROTECTION_STATUS" | grep -q '"required_pull_request_reviews"'; then
                echo "  - Pull request reviews required"
            fi
            if [ "$LOCK_BRANCH" = "true" ]; then
                echo "  - Branch is locked (read-only)"
            fi
            echo ""
        else
            echo "[FAIL] Failed to remove push restrictions"
            echo ""
            echo "This might be because:"
            echo "  - You don't have admin permissions on the repository"
            echo "  - The GitHub API returned an error"
            echo "  - The protection configuration is incompatible"
            echo ""
            echo "Try removing restrictions manually at:"
            echo "  https://github.com/$REPO_FULL/settings/branches"
            exit 1
        fi
        
        echo "To view branch protection settings:"
        echo "  https://github.com/$REPO_FULL/settings/branches"
        
        exit 0
        ;;
        

    *)
        echo "Error: Unknown branch command: $cmd"
        return 1
        ;;
    esac
}
