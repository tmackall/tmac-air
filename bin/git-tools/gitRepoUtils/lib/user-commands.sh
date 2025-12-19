#!/bin/bash

# user-commands.sh - User and CODEOWNERS management commands for gitRepoUtils
# Commands: manage-codeowners, search-users

# This file is sourced by the main gitRepoUtils.sh script

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

# Function to show usage for update-ci-branches command

# Handle user-related commands
handle_user_command() {
    local cmd="$1"
    shift
    
    case $cmd in
    manage-codeowners)
        # Handle manage-codeowners command
        
        # Default options
        ACTION=""
        USER=""
        PATTERN="*"
        BRANCH_NAME=""
        SKIP_PR=false
        NO_BRANCH=false
        DRY_RUN=false
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --add)
                    ACTION="add"
                    USER="$2"
                    shift 2
                    ;;
                --remove)
                    ACTION="remove"
                    USER="$2"
                    shift 2
                    ;;
                --pattern)
                    PATTERN="$2"
                    shift 2
                    ;;
                --branch-name)
                    BRANCH_NAME="$2"
                    shift 2
                    ;;
                --skip-pr)
                    SKIP_PR=true
                    shift
                    ;;
                --no-branch)
                    NO_BRANCH=true
                    shift
                    ;;
                --dry-run)
                    DRY_RUN=true
                    shift
                    ;;
                -h|--help)
                    show_manage_codeowners_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 manage-codeowners --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 manage-codeowners [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Validate required arguments
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 manage-codeowners [options] <git-directory>"
            echo "Run '$0 manage-codeowners --help' for more information."
            exit 1
        fi
        
        if [ -z "$ACTION" ]; then
            echo "Error: Must specify either --add or --remove"
            echo "Run '$0 manage-codeowners --help' for more information."
            exit 1
        fi
        
        if [ -z "$USER" ]; then
            echo "Error: Must specify a user/team with --add or --remove"
            echo "Run '$0 manage-codeowners --help' for more information."
            exit 1
        fi
        
        # Validate user format (must start with @)
        if [[ ! "$USER" =~ ^@ ]]; then
            echo "Error: User must start with @ (e.g., @username or @org/team)"
            echo "Got: $USER"
            exit 1
        fi
        
        # Generate branch name if not provided
        if [ -z "$BRANCH_NAME" ]; then
            TIMESTAMP=$(date +%Y%m%d-%H%M%S)
            BRANCH_NAME="chore/update-codeowners-$TIMESTAMP"
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
        
        # Check if GitHub CLI is installed (unless skip-pr or no-branch)
        if [ "$SKIP_PR" = false ] && [ "$NO_BRANCH" = false ]; then
            if ! command -v gh >/dev/null 2>&1; then
                echo "Error: GitHub CLI (gh) is not installed"
                echo "Please install it from: https://cli.github.com/"
                echo "Or use --skip-pr to skip PR creation"
                echo "Or use --no-branch to update directly without branch/PR"
                exit 1
            fi
            
            if ! gh auth status >/dev/null 2>&1; then
                echo "Error: GitHub CLI is not authenticated"
                echo "Please run: gh auth login"
                echo "Or use --skip-pr to skip PR creation"
                echo "Or use --no-branch to update directly without branch/PR"
                exit 1
            fi
        fi
        
        # Change to git directory
        cd "$GIT_DIR"
        
        # Get repository name
        REPO_NAME=$(basename "$GIT_DIR")
        
        # Get the repository owner/name for GitHub (if not skipping PR and not no-branch)
        if [ "$SKIP_PR" = false ] && [ "$NO_BRANCH" = false ]; then
            REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
            if [ -z "$REPO_FULL" ]; then
                echo "Error: Could not determine GitHub repository"
                echo "Make sure this is a GitHub repository with a remote configured"
                echo "Or use --skip-pr to skip PR creation"
                echo "Or use --no-branch to update directly without branch/PR"
                exit 1
            fi
        fi
        
        echo "=========================================="
        echo "Manage CODEOWNERS"
        echo "=========================================="
        echo "Repository: $REPO_NAME"
        if [ "$SKIP_PR" = false ] && [ "$NO_BRANCH" = false ]; then
            echo "GitHub: $REPO_FULL"
        fi
        echo "Path: $GIT_DIR"
        echo "Action: $ACTION"
        echo "User/Team: $USER"
        echo "Pattern: $PATTERN"
        if [ "$NO_BRANCH" = false ]; then
            echo "Branch: $BRANCH_NAME"
        else
            echo "Mode: Direct update (no branch/commit/PR)"
        fi
        if [ "$DRY_RUN" = true ]; then
            echo "Mode: DRY RUN (no changes will be made)"
        fi
        echo "=========================================="
        echo ""
        
        # Step 1: Fetch and sync main branch (skip if --no-branch)
        if [ "$NO_BRANCH" = false ]; then
            echo "=========================================="
            echo "Step 1: Syncing with Remote"
            echo "=========================================="
            echo ""
            
            if ! git remote | grep -q "origin"; then
                echo "Error: No remote 'origin' configured"
                exit 1
            fi
            
            echo "Fetching latest changes from remote..."
            if ! git fetch origin; then
                echo "Error: Failed to fetch from remote"
                exit 1
            fi
            echo "[OK] Fetched latest commits"
            echo ""
            
            # Check if main branch exists
            if ! git rev-parse --verify "origin/main" >/dev/null 2>&1; then
                echo "Error: Remote branch 'origin/main' does not exist"
                exit 1
            fi
            
            # Sync main branch
            echo "Syncing main branch..."
            if git rev-parse --verify main >/dev/null 2>&1; then
                git checkout main
                git pull origin main
                echo "[OK] main branch updated"
            else
                git checkout -b main origin/main
                echo "[OK] main branch created from origin/main"
            fi
            echo ""
            
            # Step 2: Create feature branch
            echo "=========================================="
            echo "Step 2: Creating Feature Branch"
            echo "=========================================="
            echo ""
            
            # Check if feature branch already exists
            if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
                echo "Warning: Branch '$BRANCH_NAME' already exists"
                echo "Checking out existing branch..."
                git checkout "$BRANCH_NAME"
            else
                if [ "$DRY_RUN" = true ]; then
                    echo "[DRY RUN] Would create branch: $BRANCH_NAME"
                else
                    git checkout -b "$BRANCH_NAME"
                    echo "[OK] Created branch: $BRANCH_NAME"
                fi
            fi
            echo ""
        else
            echo "=========================================="
            echo "Step 1: Direct Update Mode"
            echo "=========================================="
            echo ""
            echo "[i] Skipping branch creation and remote sync"
            echo "[i] File will be updated directly on current branch"
            echo ""
        fi
        
        # Step 3: Locate or create CODEOWNERS file
        echo "=========================================="
        echo "Step 3: Locating CODEOWNERS File"
        echo "=========================================="
        echo ""
        
        # CODEOWNERS can be in multiple locations
        CODEOWNERS_PATH=""
        POSSIBLE_PATHS=("CODEOWNERS" ".github/CODEOWNERS" "docs/CODEOWNERS")
        
        for path in "${POSSIBLE_PATHS[@]}"; do
            if [ -f "$path" ]; then
                CODEOWNERS_PATH="$path"
                echo "[OK] Found CODEOWNERS at: $path"
                break
            fi
        done
        
        if [ -z "$CODEOWNERS_PATH" ]; then
            # No CODEOWNERS file exists - create one in .github/
            CODEOWNERS_PATH=".github/CODEOWNERS"
            echo "[i] No CODEOWNERS file found"
            
            if [ "$DRY_RUN" = true ]; then
                echo "[DRY RUN] Would create CODEOWNERS at: $CODEOWNERS_PATH"
            else
                echo "Creating new CODEOWNERS file at: $CODEOWNERS_PATH"
                mkdir -p .github
                cat > "$CODEOWNERS_PATH" << 'EOF'
# CODEOWNERS file
# This file defines code ownership for the repository
# See: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners

EOF
                echo "[OK] Created new CODEOWNERS file"
            fi
        fi
        echo ""
        
        # Step 4: Modify CODEOWNERS file
        echo "=========================================="
        echo "Step 4: Modifying CODEOWNERS"
        echo "=========================================="
        echo ""
        
        if [ "$DRY_RUN" = false ]; then
            # Create a backup
            cp "$CODEOWNERS_PATH" "${CODEOWNERS_PATH}.backup"
        fi
        
        if [ "$ACTION" = "add" ]; then
            echo "Adding $USER to pattern: $PATTERN"
            
            # Check if pattern already exists
            if grep -q "^${PATTERN}" "$CODEOWNERS_PATH" 2>/dev/null; then
                # Pattern exists - check if user is already in it
                if grep "^${PATTERN}" "$CODEOWNERS_PATH" | grep -q "$USER"; then
                    echo "[i] User $USER is already assigned to pattern $PATTERN"
                    CHANGE_MADE=false
                else
                    # Add user to existing line
                    if [ "$DRY_RUN" = true ]; then
                        echo "[DRY RUN] Would add $USER to existing pattern: $PATTERN"
                    else
                        # Use sed to append user to the end of the line
                        sed -i.bak "s|^${PATTERN}.*|& $USER|" "$CODEOWNERS_PATH"
                        rm -f "${CODEOWNERS_PATH}.bak"
                        echo "[OK] Added $USER to existing pattern"
                    fi
                    CHANGE_MADE=true
                fi
            else
                # Pattern doesn't exist - add new line
                if [ "$DRY_RUN" = true ]; then
                    echo "[DRY RUN] Would add new line: $PATTERN $USER"
                else
                    echo "$PATTERN $USER" >> "$CODEOWNERS_PATH"
                    echo "[OK] Added new pattern with $USER"
                fi
                CHANGE_MADE=true
            fi
            
        elif [ "$ACTION" = "remove" ]; then
            echo "Removing $USER from pattern: $PATTERN"
            
            # Check if pattern exists
            if ! grep -q "^${PATTERN}" "$CODEOWNERS_PATH" 2>/dev/null; then
                echo "[i] Pattern $PATTERN not found in CODEOWNERS"
                CHANGE_MADE=false
            else
                # Check if user is in the pattern
                if ! grep "^${PATTERN}" "$CODEOWNERS_PATH" | grep -q "$USER"; then
                    echo "[i] User $USER is not assigned to pattern $PATTERN"
                    CHANGE_MADE=false
                else
                    if [ "$DRY_RUN" = true ]; then
                        echo "[DRY RUN] Would remove $USER from pattern: $PATTERN"
                    else
                        # Remove user from line
                        # Use sed to remove the user while preserving the rest of the line
                        sed -i.bak "s|\(^${PATTERN}.*\) ${USER}\(.*\)|\1\2|" "$CODEOWNERS_PATH"
                        
                        # Clean up extra spaces
                        sed -i.bak "s/  */ /g" "$CODEOWNERS_PATH"
                        
                        # If line only has pattern and no users, remove the entire line
                        sed -i.bak "/^${PATTERN}[[:space:]]*$/d" "$CODEOWNERS_PATH"
                        
                        rm -f "${CODEOWNERS_PATH}.bak"
                        echo "[OK] Removed $USER from pattern"
                    fi
                    CHANGE_MADE=true
                fi
            fi
        fi
        echo ""
        
        # Check if any changes were made
        if [ "$DRY_RUN" = false ]; then
            if git diff --quiet "$CODEOWNERS_PATH"; then
                echo "=========================================="
                echo "No Changes Needed"
                echo "=========================================="
                echo ""
                echo "The CODEOWNERS file already has the desired configuration."
                echo "No modifications were necessary."
                echo ""
                
                # Clean up feature branch
                git checkout main
                git branch -D "$BRANCH_NAME" 2>/dev/null || true
                
                exit 0
            fi
        fi
        
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Changes that would be made:"
            echo ""
            echo "The script would update CODEOWNERS to:"
            if [ "$ACTION" = "add" ]; then
                echo "  * Add $USER to pattern: $PATTERN"
            else
                echo "  * Remove $USER from pattern: $PATTERN"
            fi
            echo ""
            echo "Re-run without --dry-run to apply changes."
            exit 0
        fi
        
        # Step 5: Show changes
        echo "=========================================="
        echo "Step 5: Review Changes"
        echo "=========================================="
        echo ""
        
        echo "Modified files:"
        git status --short
        echo ""
        
        echo "Changes to CODEOWNERS:"
        echo ""
        git diff "$CODEOWNERS_PATH"
        echo ""
        
        # Step 6: Commit changes (skip if --no-branch)
        if [ "$NO_BRANCH" = false ]; then
            echo "=========================================="
            echo "Step 6: Committing Changes"
            echo "=========================================="
            echo ""
            
            ACTION_VERB="add"
            if [ "$ACTION" = "remove" ]; then
                ACTION_VERB="remove"
            fi
            
            COMMIT_MESSAGE="chore: ${ACTION_VERB} ${USER} to CODEOWNERS for pattern ${PATTERN}

This commit updates the CODEOWNERS file to ${ACTION_VERB} ${USER} as a code owner for files matching pattern: ${PATTERN}

Changes:
- Modified CODEOWNERS file
- Pattern: ${PATTERN}
- User/Team: ${USER}
- Action: ${ACTION}

Related to: Code ownership management"
            
            echo "Staging CODEOWNERS file..."
            git add "$CODEOWNERS_PATH"
            
            echo "Committing changes..."
            git commit -m "$COMMIT_MESSAGE"
            echo "[OK] Changes committed"
            echo ""
            
            # Step 7: Push feature branch
            echo "=========================================="
            echo "Step 7: Pushing Feature Branch"
            echo "=========================================="
            echo ""
            
            echo "Pushing $BRANCH_NAME to remote..."
            git push origin "$BRANCH_NAME"
            echo "[OK] Feature branch pushed"
            echo ""
        else
            echo "=========================================="
            echo "Step 6: Changes Applied"
            echo "=========================================="
            echo ""
            echo "[i] File updated directly (no commit made)"
            echo "[i] Changes are unstaged and ready for you to commit"
            echo ""
        fi
        
        # Step 8: Create pull request
        if [ "$SKIP_PR" = false ] && [ "$NO_BRANCH" = false ]; then
            echo "=========================================="
            echo "Step 8: Creating Pull Request"
            echo "=========================================="
            echo ""
            
            PR_TITLE="chore: ${ACTION_VERB^} ${USER} to CODEOWNERS for ${PATTERN}"
            
            PR_BODY="## Summary
This PR updates the CODEOWNERS file to ${ACTION_VERB} ${USER} as a code owner.

## Changes Made

- **Action**: ${ACTION_VERB^} user/team
- **User/Team**: ${USER}
- **Pattern**: \`${PATTERN}\`
- **File**: ${CODEOWNERS_PATH}

## Code Ownership

"
            
            if [ "$ACTION" = "add" ]; then
                PR_BODY+="After this change, ${USER} will be automatically requested for review on PRs that modify files matching pattern \`${PATTERN}\`.
"
            else
                PR_BODY+="After this change, ${USER} will no longer be automatically requested for review on PRs that modify files matching pattern \`${PATTERN}\`.
"
            fi
            
            PR_BODY+="
## Testing Checklist

- [ ] Review CODEOWNERS file changes
- [ ] Verify pattern syntax is correct
- [ ] Confirm user/team identifier is valid (${USER})
- [ ] Test by creating a test PR that modifies matching files

## Documentation

For more information about CODEOWNERS:
- [GitHub Docs: About Code Owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)

---
*Generated by gitRepoUtils.sh manage-codeowners command*"
            
            echo "PR Title: $PR_TITLE"
            echo ""
            
            # Check if a PR already exists
            EXISTING_PR=$(gh pr list --base main --head "$BRANCH_NAME" --json number -q '.[0].number' 2>/dev/null || echo "")
            
            if [ -n "$EXISTING_PR" ]; then
                echo "[i] Pull request already exists: #$EXISTING_PR"
                PR_URL=$(gh pr view "$EXISTING_PR" --json url -q .url 2>/dev/null)
                echo "URL: $PR_URL"
                echo ""
            else
                # Create the pull request
                echo "Creating pull request from $BRANCH_NAME to main..."
                if PR_URL=$(gh pr create --base main --head "$BRANCH_NAME" --title "$PR_TITLE" --body "$PR_BODY" 2>&1); then
                    echo "[OK] Pull request created successfully"
                    echo "URL: $PR_URL"
                    echo ""
                else
                    echo "[X] Failed to create pull request"
                    echo "$PR_URL"
                    echo ""
                    echo "You can manually create the PR from the pushed branch:"
                    echo "  Branch: $BRANCH_NAME"
                    echo "  Target: main"
                    exit 1
                fi
            fi
            echo ""
        fi
        
        # Step 9: Complete
        echo "=========================================="
        echo "Complete!"
        echo "=========================================="
        echo ""
        
        echo "[OK] CODEOWNERS file updated"
        
        if [ "$NO_BRANCH" = false ]; then
            echo "[OK] Changes committed to: $BRANCH_NAME"
            echo "[OK] Branch pushed to remote"
            
            if [ "$SKIP_PR" = false ]; then
                echo "[OK] Pull request created"
                echo ""
                echo "Next steps:"
                echo "  1. Review the pull request at: $PR_URL"
                echo "  2. Have the changes reviewed by your team"
                echo "  3. Merge the PR when ready"
            else
                echo ""
                echo "Next steps:"
                echo "  1. Review the changes in branch: $BRANCH_NAME"
                echo "  2. Create a pull request manually when ready"
                echo "  3. Target branch: main"
            fi
        else
            echo "[i] Changes applied directly (not committed)"
            echo ""
            echo "Next steps:"
            echo "  1. Review the changes: git diff $CODEOWNERS_PATH"
            echo "  2. Stage the changes: git add $CODEOWNERS_PATH"
            echo "  3. Commit when ready: git commit -m 'Update CODEOWNERS'"
            echo "  4. Push and create PR as needed"
        fi
        
        echo ""
        echo "Backup file created (can be deleted after verification):"
        if [ -f "${CODEOWNERS_PATH}.backup" ]; then
            echo "  ${CODEOWNERS_PATH}.backup"
        fi
        
        exit 0
        ;;
        

    search-users)
        # Handle search-users command
        
        # Default options
        PATTERN=""
        ORG=""
        TYPE="all"
        FORMAT="simple"
        LIMIT=10
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --org)
                    ORG="$2"
                    shift 2
                    ;;
                --type)
                    TYPE="$2"
                    shift 2
                    ;;
                --format)
                    FORMAT="$2"
                    shift 2
                    ;;
                --limit)
                    LIMIT="$2"
                    shift 2
                    ;;
                -h|--help)
                    show_search_users_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 search-users --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$PATTERN" ]; then
                        PATTERN="$1"
                    else
                        echo "Error: Multiple patterns specified"
                        echo "Usage: $0 search-users [options] <pattern>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Validate required arguments
        if [ -z "$PATTERN" ]; then
            echo "Error: No search pattern specified"
            echo "Usage: $0 search-users [options] <pattern>"
            echo "Run '$0 search-users --help' for more information."
            exit 1
        fi
        
        # Validate type option
        if [[ ! "$TYPE" =~ ^(users|teams|all)$ ]]; then
            echo "Error: Invalid type '$TYPE'. Must be: users, teams, or all"
            exit 1
        fi
        
        # Validate format option
        if [[ ! "$FORMAT" =~ ^(simple|detailed|json)$ ]]; then
            echo "Error: Invalid format '$FORMAT'. Must be: simple, detailed, or json"
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
        
        # Show header for non-JSON output
        if [ "$FORMAT" != "json" ]; then
            echo "=========================================="
            echo "GitHub User/Team Search"
            echo "=========================================="
            echo "Pattern: $PATTERN"
            if [ -n "$ORG" ]; then
                echo "Organization: $ORG"
            fi
            echo "Type: $TYPE"
            echo "Limit: $LIMIT"
            echo "=========================================="
            echo ""
        fi
        
        # Search for users
        USERS_RESULTS=""
        if [[ "$TYPE" == "users" || "$TYPE" == "all" ]]; then
            if [ "$FORMAT" != "json" ]; then
                echo "Searching for users matching '$PATTERN'..."
            fi
            
            # Use GitHub CLI to search for users
            USERS_RESULTS=$(gh api "search/users?q=${PATTERN}&per_page=${LIMIT}" \
                -H "Accept: application/vnd.github+json" 2>/dev/null || echo "")
            
            if [ -z "$USERS_RESULTS" ]; then
                if [ "$FORMAT" != "json" ]; then
                    echo "[!] Failed to search users (API error)"
                fi
            fi
        fi
        
        # Search for teams (only if org is specified)
        TEAMS_RESULTS=""
        if [[ "$TYPE" == "teams" || "$TYPE" == "all" ]]; then
            if [ -z "$ORG" ]; then
                if [[ "$TYPE" == "teams" ]]; then
                    echo "Error: Team search requires --org flag"
                    echo "Example: $0 search-users --org mycompany --type teams platform"
                    exit 1
                fi
                # Skip teams if no org specified and type is "all"
            else
                if [ "$FORMAT" != "json" ]; then
                    echo "Searching for teams in organization '$ORG' matching '$PATTERN'..."
                fi
                
                # List all teams in the org and filter locally (GitHub API doesn't support team search)
                TEAMS_RESULTS=$(gh api "orgs/${ORG}/teams?per_page=100" \
                    -H "Accept: application/vnd.github+json" 2>/dev/null || echo "")
                
                if [ -z "$TEAMS_RESULTS" ]; then
                    if [ "$FORMAT" != "json" ]; then
                        echo "[!] Failed to list teams (API error or no access to org)"
                    fi
                fi
            fi
        fi
        
        # Parse and display results
        if [ "$FORMAT" = "json" ]; then
            # JSON output
            echo "{"
            echo "  \"pattern\": \"$PATTERN\","
            if [ -n "$ORG" ]; then
                echo "  \"organization\": \"$ORG\","
            fi
            echo "  \"results\": {"
            
            # Users
            if [ -n "$USERS_RESULTS" ]; then
                echo "    \"users\": ["
                TOTAL_COUNT=$(echo "$USERS_RESULTS" | grep -o '"total_count":[0-9]*' | grep -o '[0-9]*' || echo "0")
                
                # Parse user items
                USER_COUNT=0
                while IFS= read -r line; do
                    if [ -n "$line" ]; then
                        if [ $USER_COUNT -gt 0 ]; then
                            echo ","
                        fi
                        echo "      $line"
                        ((USER_COUNT++))
                    fi
                done < <(echo "$USERS_RESULTS" | grep -o '"login":"[^"]*","id":[^,]*,"node_id":"[^"]*","avatar_url":"[^"]*","[^"]*":"[^"]*","html_url":"[^"]*","type":"[^"]*"' | sed 's/^/{/' | sed 's/$/}/' || echo "")
                
                echo ""
                echo "    ],"
                echo "    \"users_count\": $TOTAL_COUNT"
            else
                echo "    \"users\": [],"
                echo "    \"users_count\": 0"
            fi
            
            # Teams
            if [ -n "$TEAMS_RESULTS" ] && [ -n "$ORG" ]; then
                echo ","
                echo "    \"teams\": ["
                
                # Filter teams matching pattern
                TEAM_COUNT=0
                while IFS= read -r line; do
                    if echo "$line" | grep -qi "$PATTERN"; then
                        if [ $TEAM_COUNT -gt 0 ]; then
                            echo ","
                        fi
                        echo "      $line"
                        ((TEAM_COUNT++))
                        
                        if [ $TEAM_COUNT -ge $LIMIT ]; then
                            break
                        fi
                    fi
                done < <(echo "$TEAMS_RESULTS" | grep -o '"name":"[^"]*","id":[^,]*,"node_id":"[^"]*","slug":"[^"]*","description":"[^"]*"[^}]*"html_url":"[^"]*"' | sed 's/^/{/' | sed 's/$/}/' || echo "")
                
                echo ""
                echo "    ],"
                echo "    \"teams_count\": $TEAM_COUNT"
            else
                echo ","
                echo "    \"teams\": [],"
                echo "    \"teams_count\": 0"
            fi
            
            echo "  }"
            echo "}"
            
        elif [ "$FORMAT" = "detailed" ]; then
            # Detailed output
            
            # Display users
            if [ -n "$USERS_RESULTS" ]; then
                TOTAL_COUNT=$(echo "$USERS_RESULTS" | grep -o '"total_count":[0-9]*' | grep -o '[0-9]*' || echo "0")
                echo "Users (found $TOTAL_COUNT):"
                echo ""
                
                # Parse and display user details
                DISPLAYED=0
                while IFS= read -r login; do
                    if [ -n "$login" ] && [ $DISPLAYED -lt $LIMIT ]; then
                        # Get full user details
                        USER_DETAILS=$(gh api "users/${login}" \
                            -H "Accept: application/vnd.github+json" 2>/dev/null || echo "")
                        
                        if [ -n "$USER_DETAILS" ]; then
                            NAME=$(echo "$USER_DETAILS" | grep -o '"name":"[^"]*"' | head -1 | sed 's/"name":"//;s/"$//' || echo "")
                            TYPE=$(echo "$USER_DETAILS" | grep -o '"type":"[^"]*"' | head -1 | sed 's/"type":"//;s/"$//' || echo "")
                            URL=$(echo "$USER_DETAILS" | grep -o '"html_url":"[^"]*"' | head -1 | sed 's/"html_url":"//;s/"$//' || echo "")
                            BIO=$(echo "$USER_DETAILS" | grep -o '"bio":"[^"]*"' | head -1 | sed 's/"bio":"//;s/"$//' || echo "")
                            
                            echo "  @${login}"
                            if [ -n "$NAME" ] && [ "$NAME" != "null" ]; then
                                echo "    Name: $NAME"
                            fi
                            echo "    Type: $TYPE"
                            if [ -n "$URL" ]; then
                                echo "    URL:  $URL"
                            fi
                            if [ -n "$BIO" ] && [ "$BIO" != "null" ]; then
                                echo "    Bio:  $BIO"
                            fi
                            echo ""
                            ((DISPLAYED++))
                        fi
                    fi
                done < <(echo "$USERS_RESULTS" | grep -o '"login":"[^"]*"' | sed 's/"login":"//;s/"$//' || echo "")
            fi
            
            # Display teams
            if [ -n "$TEAMS_RESULTS" ] && [ -n "$ORG" ]; then
                echo "Teams in @${ORG}:"
                echo ""
                
                DISPLAYED=0
                while IFS= read -r team_data; do
                    if [ -n "$team_data" ]; then
                        TEAM_NAME=$(echo "$team_data" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"$//' || echo "")
                        TEAM_SLUG=$(echo "$team_data" | grep -o '"slug":"[^"]*"' | sed 's/"slug":"//;s/"$//' || echo "")
                        TEAM_DESC=$(echo "$team_data" | grep -o '"description":"[^"]*"' | sed 's/"description":"//;s/"$//' || echo "")
                        
                        # Filter by pattern
                        if echo "$TEAM_NAME $TEAM_SLUG" | grep -qi "$PATTERN"; then
                            echo "  @${ORG}/${TEAM_SLUG}"
                            echo "    Name: $TEAM_NAME"
                            if [ -n "$TEAM_DESC" ] && [ "$TEAM_DESC" != "null" ]; then
                                echo "    Desc: $TEAM_DESC"
                            fi
                            echo ""
                            ((DISPLAYED++))
                            
                            if [ $DISPLAYED -ge $LIMIT ]; then
                                break
                            fi
                        fi
                    fi
                done < <(echo "$TEAMS_RESULTS" | grep -o '{[^}]*"slug":"[^"]*"[^}]*}' || echo "")
            fi
            
        else
            # Simple output (default)
            
            # Display users
            if [ -n "$USERS_RESULTS" ]; then
                TOTAL_COUNT=$(echo "$USERS_RESULTS" | grep -o '"total_count":[0-9]*' | grep -o '[0-9]*' || echo "0")
                echo "Users (found $TOTAL_COUNT):"
                echo ""
                
                DISPLAYED=0
                while IFS= read -r login; do
                    if [ -n "$login" ] && [ $DISPLAYED -lt $LIMIT ]; then
                        # Get user name for display
                        USER_DETAILS=$(gh api "users/${login}" \
                            -H "Accept: application/vnd.github+json" 2>/dev/null || echo "")
                        
                        NAME=$(echo "$USER_DETAILS" | grep -o '"name":"[^"]*"' | head -1 | sed 's/"name":"//;s/"$//' || echo "")
                        
                        if [ -n "$NAME" ] && [ "$NAME" != "null" ]; then
                            echo "  @${login} ($NAME)"
                        else
                            echo "  @${login}"
                        fi
                        ((DISPLAYED++))
                    fi
                done < <(echo "$USERS_RESULTS" | grep -o '"login":"[^"]*"' | sed 's/"login":"//;s/"$//' || echo "")
                echo ""
            fi
            
            # Display teams
            if [ -n "$TEAMS_RESULTS" ] && [ -n "$ORG" ]; then
                echo "Teams in @${ORG}:"
                echo ""
                
                DISPLAYED=0
                while IFS= read -r team_data; do
                    if [ -n "$team_data" ]; then
                        TEAM_NAME=$(echo "$team_data" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"$//' || echo "")
                        TEAM_SLUG=$(echo "$team_data" | grep -o '"slug":"[^"]*"' | sed 's/"slug":"//;s/"$//' || echo "")
                        
                        # Filter by pattern
                        if echo "$TEAM_NAME $TEAM_SLUG" | grep -qi "$PATTERN"; then
                            echo "  @${ORG}/${TEAM_SLUG} ($TEAM_NAME)"
                            ((DISPLAYED++))
                            
                            if [ $DISPLAYED -ge $LIMIT ]; then
                                break
                            fi
                        fi
                    fi
                done < <(echo "$TEAMS_RESULTS" | grep -o '{[^}]*"slug":"[^"]*"[^}]*}' || echo "")
                echo ""
            fi
        fi
        
        # Summary for non-JSON output
        if [ "$FORMAT" != "json" ]; then
            echo "=========================================="
            echo ""
            echo "Tip: Use the full identifier (e.g., @username or @org/team) with manage-codeowners"
            echo "Example: $0 manage-codeowners --add @username <git-directory>"
        fi
        
        exit 0
        ;;
        

    *)
        echo "Error: Unknown user command: $cmd"
        return 1
        ;;
    esac
}
