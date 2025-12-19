#!/bin/bash

# repo-commands.sh - Repository configuration commands for gitRepoUtils
# Commands: update-ci-branches, configure-repo, clean-repo

# This file is sourced by the main gitRepoUtils.sh script

show_update_ci_branches_usage() {
    echo "Usage: $0 update-ci-branches [options] <git-directory>"
    echo ""
    echo "Update CI workflow branch triggers from 'feature/*' pattern to 'all except main'"
    echo "or vice versa. Includes full workflow automation: clean, fetch, branch, commit, and PR."
    echo ""
    echo "Options:"
    echo "  --pattern PATTERN        Target pattern: all-except-main or feature-only"
    echo "                          (default: all-except-main)"
    echo "  --branch-name NAME      Custom branch name (default: auto-generated with timestamp)"
    echo "  --target BRANCH         Target branch for PR (default: main)"
    echo "  --create-pr             Automatically create a pull request"
    echo "  --pr-title TITLE        Custom PR title (default: auto-generated)"
    echo "  --pr-body BODY          Custom PR body (default: auto-generated)"
    echo "  --skip-fetch            Skip fetching from remote (use existing local state)"
    echo "  --skip-branch           Make changes directly without creating a branch"
    echo "  --no-commit             Make changes but don't commit (manual commit required)"
    echo "  --dry-run               Show what would be changed without making changes"
    echo "  --force                 Force operations (stash changes, recreate branch, etc.)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Full automated workflow with PR creation"
    echo "  $0 update-ci-branches --create-pr ~/projects/my-project"
    echo ""
    echo "  # Dry run to preview changes"
    echo "  $0 update-ci-branches --dry-run ~/projects/my-project"
    echo ""
    echo "  # Update with custom branch name"
    echo "  $0 update-ci-branches --branch-name chore/ci-update ~/projects/my-project"
    echo ""
    echo "  # Create PR with custom title and body"
    echo "  $0 update-ci-branches --create-pr --pr-title 'Update CI' ~/projects/my-project"
    echo ""
    echo "  # Direct changes without branch (for manual workflow)"
    echo "  $0 update-ci-branches --skip-branch --no-commit ~/projects/my-project"
    echo ""
    echo "  # Revert to feature-only pattern"
    echo "  $0 update-ci-branches --pattern feature-only --create-pr ~/projects/my-project"
    echo ""
    echo "Pattern Options:"
    echo "  all-except-main: CI runs on all branches except main"
    echo "    Changes 'branches: [feature/*]' to 'branches-ignore: [main]'"
    echo ""
    echo "  feature-only: CI runs only on feature/* branches"
    echo "    Changes 'branches-ignore: [main]' to 'branches: [feature/*]'"
    echo ""
    echo "Workflow Steps:"
    echo "  1. Clean working directory (stash if needed with --force)"
    echo "  2. Fetch latest from remote and sync target branch"
    echo "  3. Create feature branch from target branch"
    echo "  4. Update CI workflow files"
    echo "  5. Commit changes with descriptive message"
    echo "  6. Push branch to remote"
    echo "  7. Create pull request (if --create-pr)"
    echo ""
    echo "Requirements:"
    echo "  - Git repository with .github/workflows/ directory"
    echo "  - GitHub CLI (gh) installed and authenticated (for --create-pr)"
    echo "  - Write permissions on the repository"
    echo ""
    echo "Notes:"
    echo "  - Creates backup files (*.backup) for all modified workflows"
    echo "  - Preserves other workflow triggers (workflow_dispatch, schedule, etc.)"
    echo "  - Handles uncommitted changes safely (stash with --force or abort)"
    echo "  - Supports both .yml and .yaml workflow files"
    echo ""
}

# Function to show usage for approve-pr command
show_configure_repo_usage() {
    echo "Usage: $0 configure-repo [options] <git-directory>"
    echo ""
    echo "Configure repository settings including auto-merge, branch protection,"
    echo "and other GitHub repository features."
    echo ""
    echo "Options:"
    echo "  --enable-auto-merge      Enable auto-merge feature for the repository"
    echo "  --disable-auto-merge     Disable auto-merge feature for the repository"
    echo "  --enable-delete-branch   Enable automatic branch deletion on merge"
    echo "  --disable-delete-branch  Disable automatic branch deletion on merge"
    echo "  --enable-issues          Enable issues for the repository"
    echo "  --disable-issues         Disable issues for the repository"
    echo "  --enable-wiki            Enable wiki for the repository"
    echo "  --disable-wiki           Disable wiki for the repository"
    echo "  --enable-projects        Enable projects for the repository"
    echo "  --disable-projects       Disable projects for the repository"
    echo "  --allow-squash           Allow squash merging"
    echo "  --disallow-squash        Disallow squash merging"
    echo "  --allow-merge-commit     Allow merge commits"
    echo "  --disallow-merge-commit  Disallow merge commits"
    echo "  --allow-rebase           Allow rebase merging"
    echo "  --disallow-rebase        Disallow rebase merging"
    echo "  --default-branch BRANCH  Set default branch"
    echo "  --description TEXT       Set repository description"
    echo "  --topics TOPICS          Set repository topics (comma-separated)"
    echo "  --visibility VISIBILITY  Set visibility: public, private, or internal"
    echo "  --check                  Show current repository settings"
    echo "  --force                  Skip confirmation prompts"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Enable auto-merge for repository"
    echo "  $0 configure-repo --enable-auto-merge ~/projects/my-project"
    echo ""
    echo "  # Enable auto-merge and auto-delete branches"
    echo "  $0 configure-repo --enable-auto-merge --enable-delete-branch ~/projects/my-project"
    echo ""
    echo "  # Configure merge methods"
    echo "  $0 configure-repo --allow-squash --disallow-merge-commit ~/projects/my-project"
    echo ""
    echo "  # Check current settings"
    echo "  $0 configure-repo --check ~/projects/my-project"
    echo ""
    echo "  # Set multiple settings at once"
    echo "  $0 configure-repo --enable-auto-merge --allow-squash --enable-delete-branch ~/projects/my-project"
    echo ""
    echo "  # Update repository metadata"
    echo "  $0 configure-repo --description 'My awesome project' --topics 'api,golang' ~/projects/my-project"
    echo ""
    echo "Requirements:"
    echo "  - GitHub CLI (gh) must be installed and authenticated"
    echo "  - Admin permissions on the repository"
    echo ""
    echo "Note: Some settings require specific GitHub plans or organization settings."
    echo "      Private repositories may have different feature availability."
    echo ""
}

# Function to show usage for clean-repo command
show_clean_repo_usage() {
    echo "Usage: $0 clean-repo [options] <git-directory>"
    echo ""
    echo "Clean working directory, fetch updates, sync branches, and handle uncommitted changes."
    echo "Useful for preparing a repository for operations that require a clean state."
    echo ""
    echo "Options:"
    echo "  --branch BRANCH          Target branch to sync (default: main, falls back to master)"
    echo "  --stash                  Stash changes instead of prompting"
    echo "  --discard                Discard all local changes (dangerous!)"
    echo "  --force                  Auto-stash changes without prompting"
    echo "  --fetch-only             Only fetch, don't sync branches"
    echo "  --sync-only              Only sync current branch, don't fetch"
    echo "  --prune                  Prune deleted remote branches"
    echo "  --pull-all               Pull all tracking branches"
    echo "  --reset-hard             Reset current branch to match remote (dangerous!)"
    echo "  --checkout BRANCH        Switch to specified branch after cleaning"
    echo "  --create-branch NAME     Create new branch from target after cleaning"
    echo "  --status                 Show repository status without making changes"
    echo "  --verbose                Show detailed progress information"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Basic clean and sync"
    echo "  $0 clean-repo ~/projects/my-project"
    echo ""
    echo "  # Force stash and sync"
    echo "  $0 clean-repo --force ~/projects/my-project"
    echo ""
    echo "  # Check status only"
    echo "  $0 clean-repo --status ~/projects/my-project"
    echo ""
    echo "  # Discard changes and reset to remote main"
    echo "  $0 clean-repo --discard --reset-hard --branch main ~/projects/my-project"
    echo ""
    echo "  # Stash, fetch, and create new feature branch"
    echo "  $0 clean-repo --stash --create-branch feature/new-feature ~/projects/my-project"
    echo ""
    echo "  # Clean and switch to develop branch"
    echo "  $0 clean-repo --force --checkout develop ~/projects/my-project"
    echo ""
    echo "  # Fetch and prune deleted branches"
    echo "  $0 clean-repo --fetch-only --prune ~/projects/my-project"
    echo ""
    echo "  # Pull all tracking branches"
    echo "  $0 clean-repo --pull-all ~/projects/my-project"
    echo ""
    echo "Actions performed (by default):"
    echo "  1. Check for uncommitted changes"
    echo "  2. Handle uncommitted changes (prompt, stash, or discard)"
    echo "  3. Fetch latest from all remotes"
    echo "  4. Sync target branch with remote"
    echo "  5. Optionally checkout or create branch"
    echo ""
    echo "Safety features:"
    echo "  - Prompts before stashing (unless --force or --stash)"
    echo "  - Warns before discarding changes"
    echo "  - Shows what will be done before doing it"
    echo "  - Creates stash with descriptive message"
    echo "  - Auto-detects default branch (falls back to 'master' if 'main' not found)"
    echo ""
}

# Handle repo-related commands
handle_repo_command() {
    local cmd="$1"
    shift
    
    case $cmd in
    update-ci-branches)
        # Handle update-ci-branches command
        
        # Default options
        DRY_RUN=false
        FORCE=false
        PATTERN="all-except-main"  # or "feature-only"
        BRANCH_NAME=""
        CREATE_PR=false
        PR_TITLE=""
        PR_BODY=""
        TARGET_BRANCH="main"
        SKIP_FETCH=false
        SKIP_BRANCH=false
        AUTO_COMMIT=true
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --pattern)
                    PATTERN="$2"
                    shift 2
                    ;;
                --branch-name)
                    BRANCH_NAME="$2"
                    shift 2
                    ;;
                --create-pr)
                    CREATE_PR=true
                    shift
                    ;;
                --pr-title)
                    PR_TITLE="$2"
                    shift 2
                    ;;
                --pr-body)
                    PR_BODY="$2"
                    shift 2
                    ;;
                --target)
                    TARGET_BRANCH="$2"
                    shift 2
                    ;;
                --skip-fetch)
                    SKIP_FETCH=true
                    shift
                    ;;
                --skip-branch)
                    SKIP_BRANCH=true
                    shift
                    ;;
                --no-commit)
                    AUTO_COMMIT=false
                    shift
                    ;;
                --dry-run)
                    DRY_RUN=true
                    shift
                    ;;
                --force)
                    FORCE=true
                    shift
                    ;;
                -h|--help)
                    show_update_ci_branches_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 update-ci-branches --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 update-ci-branches [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Check if git directory was provided
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 update-ci-branches [options] <git-directory>"
            echo "Run '$0 update-ci-branches --help' for more information."
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
        
        # Check if GitHub CLI is installed (if creating PR)
        if [ "$CREATE_PR" = true ]; then
            if ! command -v gh >/dev/null 2>&1; then
                echo "Error: GitHub CLI (gh) is not installed"
                echo "Please install it from: https://cli.github.com/"
                echo "Or remove --create-pr flag"
                exit 1
            fi
            
            if ! gh auth status >/dev/null 2>&1; then
                echo "Error: GitHub CLI is not authenticated"
                echo "Please run: gh auth login"
                echo "Or remove --create-pr flag"
                exit 1
            fi
        fi
        
        # Generate branch name if not provided
        if [ -z "$BRANCH_NAME" ] && [ "$SKIP_BRANCH" = false ]; then
            TIMESTAMP=$(date +%Y%m%d-%H%M%S)
            if [ "$PATTERN" = "all-except-main" ]; then
                BRANCH_NAME="chore/update-ci-all-branches-$TIMESTAMP"
            else
                BRANCH_NAME="chore/update-ci-feature-only-$TIMESTAMP"
            fi
        fi
        
        # Change to git directory
        cd "$GIT_DIR"
        
        # Get repository name
        REPO_NAME=$(basename "$GIT_DIR")
        
        # Get the repository owner/name for GitHub (if creating PR)
        if [ "$CREATE_PR" = true ]; then
            REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
            if [ -z "$REPO_FULL" ]; then
                echo "Error: Could not determine GitHub repository"
                echo "Make sure this is a GitHub repository with a remote configured"
                exit 1
            fi
        fi
        
        echo "=========================================="
        echo "Update CI Workflow Branch Triggers"
        echo "=========================================="
        echo "Repository: $REPO_NAME"
        if [ "$CREATE_PR" = true ]; then
            echo "GitHub: $REPO_FULL"
        fi
        echo "Path: $GIT_DIR"
        echo "Pattern: $PATTERN"
        if [ "$SKIP_BRANCH" = false ]; then
            echo "Branch: $BRANCH_NAME"
            echo "Target: $TARGET_BRANCH"
        fi
        if [ "$CREATE_PR" = true ]; then
            echo "PR Creation: Enabled"
        fi
        if [ "$DRY_RUN" = true ]; then
            echo "Mode: DRY RUN (no changes will be made)"
        fi
        echo "=========================================="
        echo ""
        
        # Step 1: Clean working directory
        if [ "$DRY_RUN" = false ] && [ "$SKIP_BRANCH" = false ]; then
            echo "=========================================="
            echo "Step 1: Cleaning Working Directory"
            echo "=========================================="
            echo ""
            
            # Check for uncommitted changes
            if ! git diff --quiet || ! git diff --cached --quiet; then
                echo "Warning: You have uncommitted changes in the repository"
                
                if [ "$FORCE" = true ]; then
                    echo "Force flag set - stashing changes..."
                    git stash push -m "gitRepoUtils: Stashed before CI update"
                    echo "[OK] Changes stashed"
                else
                    echo ""
                    echo "Please commit or stash your changes before proceeding."
                    echo "Or use --force to automatically stash changes."
                    exit 1
                fi
            else
                echo "[OK] Working directory is clean"
            fi
            echo ""
        fi
        
        # Step 2: Fetch and sync with remote
        if [ "$SKIP_FETCH" = false ] && [ "$SKIP_BRANCH" = false ]; then
            echo "=========================================="
            echo "Step 2: Syncing with Remote"
            echo "=========================================="
            echo ""
            
            if ! git remote | grep -q "origin"; then
                echo "Error: No remote 'origin' configured"
                exit 1
            fi
            
            if [ "$DRY_RUN" = false ]; then
                echo "Fetching latest changes from remote..."
                if ! git fetch origin; then
                    echo "Error: Failed to fetch from remote"
                    exit 1
                fi
                echo "[OK] Fetched latest commits"
                echo ""
                
                # Check if target branch exists
                if ! git rev-parse --verify "origin/$TARGET_BRANCH" >/dev/null 2>&1; then
                    echo "Error: Remote branch 'origin/$TARGET_BRANCH' does not exist"
                    exit 1
                fi
                
                # Sync target branch
                echo "Syncing $TARGET_BRANCH branch..."
                if git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1; then
                    git checkout "$TARGET_BRANCH"
                    git pull origin "$TARGET_BRANCH"
                    echo "[OK] $TARGET_BRANCH branch updated"
                else
                    git checkout -b "$TARGET_BRANCH" "origin/$TARGET_BRANCH"
                    echo "[OK] $TARGET_BRANCH branch created from origin/$TARGET_BRANCH"
                fi
                echo ""
            else
                echo "[DRY RUN] Would fetch from origin and sync $TARGET_BRANCH branch"
                echo ""
            fi
        fi
        
        # Step 3: Create feature branch
        if [ "$SKIP_BRANCH" = false ]; then
            echo "=========================================="
            echo "Step 3: Creating Feature Branch"
            echo "=========================================="
            echo ""
            
            if [ "$DRY_RUN" = false ]; then
                echo "Creating feature branch from $TARGET_BRANCH..."
                
                # Check if feature branch already exists
                if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
                    if [ "$FORCE" = true ]; then
                        echo "Branch '$BRANCH_NAME' already exists"
                        echo "Force flag set - deleting and recreating..."
                        
                        # Delete local branch
                        git branch -D "$BRANCH_NAME" 2>/dev/null || true
                        echo "Deleted local branch: $BRANCH_NAME"
                        
                        # Delete remote branch if it exists
                        if git ls-remote --exit-code --heads origin "$BRANCH_NAME" >/dev/null 2>&1; then
                            git push origin --delete "$BRANCH_NAME" 2>/dev/null || true
                            echo "Deleted remote branch: origin/$BRANCH_NAME"
                        fi
                        
                        # Create new branch
                        git checkout -b "$BRANCH_NAME"
                        echo "[OK] Created fresh branch: $BRANCH_NAME"
                    else
                        echo "Warning: Branch '$BRANCH_NAME' already exists"
                        echo "Use --force to delete and recreate, or --branch-name to specify different name"
                        exit 1
                    fi
                else
                    git checkout -b "$BRANCH_NAME"
                    echo "[OK] Created branch: $BRANCH_NAME"
                fi
                echo ""
            else
                echo "[DRY RUN] Would create branch: $BRANCH_NAME from $TARGET_BRANCH"
                echo ""
            fi
        fi
        
        # Step 4: Check for workflow directory
        WORKFLOWS_DIR=".github/workflows"
        
        if [ ! -d "$WORKFLOWS_DIR" ]; then
            echo "Error: Workflows directory not found: $WORKFLOWS_DIR"
            echo "This repository may not use GitHub Actions"
            exit 1
        fi
        
        echo "Scanning for CI workflow files in $WORKFLOWS_DIR..."
        echo ""
        
        # Find CI workflow files
        CI_WORKFLOWS=$(find "$WORKFLOWS_DIR" -type f \( -name "*-ci-workflow.yml" -o -name "*-ci.yml" -o -name "ci.yml" -o -name "ci.yaml" \) 2>/dev/null)
        
        if [ -z "$CI_WORKFLOWS" ]; then
            echo "Warning: No CI workflow files found"
            echo "Looking for any workflow with 'push' triggers..."
            CI_WORKFLOWS=$(grep -l "push:" "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml 2>/dev/null || echo "")
        fi
        
        if [ -z "$CI_WORKFLOWS" ]; then
            echo "Error: No workflow files with push triggers found"
            exit 1
        fi
        
        echo "Found workflow files:"
        echo "$CI_WORKFLOWS" | while read -r file; do
            echo "  * $file"
        done
        echo ""
        
        # Update workflow files
        echo "=========================================="
        echo "Updating Workflow Files"
        echo "=========================================="
        echo ""
        
        CHANGES_MADE=false
        
        echo "$CI_WORKFLOWS" | while read -r file; do
            if [ -f "$file" ]; then
                echo "Processing: $file"
                
                # Check current pattern
                HAS_FEATURE_ONLY=false
                HAS_BRANCHES_IGNORE=false
                
                if grep -q "branches:\s*\n\s*-\s*feature/\*" "$file" || grep -q "branches:\s*\[.*feature/\*.*\]" "$file"; then
                    HAS_FEATURE_ONLY=true
                    echo "  -> Currently triggers on: feature/* branches only"
                fi
                
                if grep -q "branches-ignore:" "$file"; then
                    HAS_BRANCHES_IGNORE=true
                    echo "  -> Currently uses branches-ignore pattern"
                fi
                
                if [ "$PATTERN" = "all-except-main" ]; then
                    echo "  -> Updating to trigger on all branches except main"
                    
                    if [ "$DRY_RUN" = true ]; then
                        echo "  -> [DRY RUN] Would change to 'branches-ignore: [main]'"
                    else
                        # Create backup
                        cp "$file" "${file}.backup"
                        
                        # Update using Python for proper YAML handling
                        python3 - "$file" << 'EOF'
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    lines = f.readlines()

# Process line by line to handle various YAML formats
new_lines = []
i = 0
updated = False

while i < len(lines):
    line = lines[i]
    
    # Look for 'on:' section (with or without quotes)
    if re.match(r'^[\s\']*on[\'"]?:\s*$', line) or "'on':" in line:
        new_lines.append(line)
        i += 1
        
        # Look for push: in the next few lines
        while i < len(lines):
            line = lines[i]
            
            if 'push:' in line:
                new_lines.append(line)
                i += 1
                
                # Get indentation level
                indent = len(line) - len(line.lstrip())
                
                # Skip any existing branches or branches-ignore sections
                found_branches = False
                while i < len(lines):
                    next_line = lines[i]
                    
                    # Check if this is a branches or branches-ignore line
                    if re.match(r'^\s*(branches|branches-ignore):', next_line):
                        found_branches = True
                        # Skip this line and its children
                        i += 1
                        # Skip all indented lines that belong to this section
                        while i < len(lines):
                            if lines[i].strip() and not lines[i].startswith(' ' * (indent + 2)):
                                break
                            if not lines[i].strip():  # Empty line
                                i += 1
                                break
                            i += 1
                        
                        # Add our new branches-ignore
                        new_lines.append(' ' * (indent + 2) + 'branches-ignore:\n')
                        new_lines.append(' ' * (indent + 4) + '- main\n')
                        updated = True
                        break
                    # Check if we've moved past the push section
                    elif next_line.strip() and not next_line.startswith(' ' * (indent + 2)):
                        # No branches section found, add one
                        new_lines.append(' ' * (indent + 2) + 'branches-ignore:\n')
                        new_lines.append(' ' * (indent + 4) + '- main\n')
                        updated = True
                        break
                    else:
                        new_lines.append(next_line)
                        i += 1
                
                if not found_branches and not updated:
                    # Add branches-ignore at current position
                    new_lines.append(' ' * (indent + 2) + 'branches-ignore:\n')
                    new_lines.append(' ' * (indent + 4) + '- main\n')
                    updated = True
            else:
                new_lines.append(line)
                i += 1
    else:
        new_lines.append(line)
        i += 1

# Write the updated content
with open(file_path, 'w') as f:
    f.writelines(new_lines)

if updated:
    print(f"  -> Updated to branches-ignore: [main]")
else:
    print(f"  -> Warning: Could not find push trigger to update")
EOF
                        
                        CHANGES_MADE=true
                    fi
                    
                elif [ "$PATTERN" = "feature-only" ]; then
                    echo "  -> Updating to trigger on feature/* branches only"
                    
                    if [ "$DRY_RUN" = true ]; then
                        echo "  -> [DRY RUN] Would change to 'branches: [feature/*]'"
                    else
                        # Create backup
                        cp "$file" "${file}.backup"
                        
                        # Update using Python for proper YAML handling
                        python3 - "$file" << 'EOF'
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    content = f.read()

# Replace branches-ignore with branches: feature/*
modified = re.sub(
    r'(\s+push:\s*\n)\s+branches-ignore:\s*\n(?:\s+-\s+[\w\-\/\*]+\s*\n)+',
    r'\1    branches:\n      - feature/*\n',
    content
)

# Also handle inline array format
modified = re.sub(
    r'(\s+push:\s*\n)\s+branches-ignore:\s*\[.*?\]\s*\n',
    r'\1    branches:\n      - feature/*\n',
    modified
)

with open(file_path, 'w') as f:
    f.write(modified)
EOF
                        
                        echo "  -> Updated to branches: [feature/*]"
                        CHANGES_MADE=true
                    fi
                else
                    echo "  -> Unknown pattern: $PATTERN"
                fi
                echo ""
            fi
        done
        
        if [ "$DRY_RUN" = true ]; then
            echo "=========================================="
            echo "DRY RUN Complete"
            echo "=========================================="
            echo ""
            echo "No changes were made."
            echo "Re-run without --dry-run to apply changes."
            exit 0
        fi
        
        # Check if any changes were made
        if git diff --quiet; then
            echo "=========================================="
            echo "No Changes Detected"
            echo "=========================================="
            echo ""
            echo "The workflow files appear to already be configured correctly."
            echo "No modifications were necessary."
            echo ""
            
            # Clean up feature branch if we created one
            if [ "$SKIP_BRANCH" = false ]; then
                git checkout "$TARGET_BRANCH"
                git branch -D "$BRANCH_NAME" 2>/dev/null || true
            fi
            
            exit 0
        fi
        
        CHANGES_MADE=true
        
        # Step 5: Commit changes
        if [ "$AUTO_COMMIT" = true ] && [ "$SKIP_BRANCH" = false ]; then
            echo "=========================================="
            echo "Step 5: Committing Changes"
            echo "=========================================="
            echo ""
            
            echo "Modified files:"
            git status --short
            echo ""
            
            echo "Detailed changes:"
            git diff --stat
            echo ""
            
            # Stage workflow files
            echo "Staging modified workflow files..."
            
            # Need to stage files from the CI_WORKFLOWS variable
            # Add each file individually to ensure they're properly staged
            STAGED_COUNT=0
            echo "$CI_WORKFLOWS" | while read -r file; do
                if [ -f "$file" ]; then
                    git add "$file"
                    echo "  Staged: $(basename $file)"
                    ((STAGED_COUNT++)) || true
                fi
            done
            
            # Fallback: if no files were staged, try adding all workflow files
            if ! git diff --cached --quiet; then
                echo "[OK] Files staged successfully"
            else
                echo "[!] No files staged with individual add, trying directory add..."
                git add -A "$WORKFLOWS_DIR"
                if ! git diff --cached --quiet; then
                    echo "[OK] Files staged with directory add"
                else
                    echo "Error: Failed to stage files. Check git status:"
                    git status
                    exit 1
                fi
            fi
            
            # Create commit message
            if [ "$PATTERN" = "all-except-main" ]; then
                COMMIT_MESSAGE="chore: update CI workflows to trigger on all branches except main

This commit updates CI/CD workflows to run on any branch except main,
removing the restriction to only feature/* branches.

Changes:
- Modified push triggers from 'branches: [feature/*]' to 'branches-ignore: [main]'
- CI now runs on all branch naming patterns (feature/*, bugfix/*, hotfix/*, etc.)
- Aligns with GitHub Flow best practices

Benefits:
- No more branch naming restrictions
- Better test coverage for all branches
- More flexibility for developers"
            else
                COMMIT_MESSAGE="chore: update CI workflows to trigger only on feature branches

This commit updates CI/CD workflows to run only on feature/* branches.

Changes:
- Modified push triggers to 'branches: [feature/*]'
- CI now runs only on branches following feature/* naming pattern
- Enforces consistent branch naming conventions"
            fi
            
            echo "Committing changes..."
            git commit -m "$COMMIT_MESSAGE"
            echo "[OK] Changes committed"
            echo ""
            
            # Step 6: Push branch
            echo "=========================================="
            echo "Step 6: Pushing Feature Branch"
            echo "=========================================="
            echo ""
            
            echo "Pushing $BRANCH_NAME to remote..."
            if [ "$FORCE" = true ]; then
                git push --force origin "$BRANCH_NAME"
                echo "[OK] Feature branch force-pushed"
            else
                git push origin "$BRANCH_NAME"
                echo "[OK] Feature branch pushed"
            fi
            echo ""
        fi
        
        # Step 7: Create pull request
        if [ "$CREATE_PR" = true ] && [ "$SKIP_BRANCH" = false ]; then
            echo "=========================================="
            echo "Step 7: Creating Pull Request"
            echo "=========================================="
            echo ""
            
            # Set default PR title if not provided
            if [ -z "$PR_TITLE" ]; then
                if [ "$PATTERN" = "all-except-main" ]; then
                    PR_TITLE="chore: Update CI to run on all branches except main"
                else
                    PR_TITLE="chore: Update CI to run only on feature branches"
                fi
            fi
            
            # Set default PR body if not provided
            if [ -z "$PR_BODY" ]; then
                if [ "$PATTERN" = "all-except-main" ]; then
                    PR_BODY="## Summary
This PR updates CI workflows to trigger on all branches except main, removing the feature-only restriction.

## Changes Made

### CI Workflow Updates
- **Changed from**: \`branches: [feature/*]\`
- **Changed to**: \`branches-ignore: [main]\`
- **Result**: CI now runs on any branch that could be merged to main

## Benefits

ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ **No naming restrictions** - Use any branch name pattern
ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ **Better coverage** - All branches get tested before merge
ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ **GitHub Flow aligned** - Follows modern best practices
ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ **More flexibility** - Supports bugfix/*, hotfix/*, chore/*, etc.

## Supported Branch Patterns

After this change, CI will run on:
- \`feature/*\` - Feature development
- \`bugfix/*\` - Bug fixes
- \`hotfix/*\` - Emergency fixes
- \`chore/*\` - Maintenance tasks
- \`refactor/*\` - Code refactoring
- Any custom branch name

## Testing

- [ ] Workflow files updated correctly
- [ ] No syntax errors in YAML
- [ ] CI triggers on non-feature branches
- [ ] CI does NOT trigger on main branch

## Files Modified

$(git diff --name-only | sed 's/^/- /')

---
*Generated by gitRepoUtils.sh update-ci-branches command*"
                else
                    PR_BODY="## Summary
This PR updates CI workflows to trigger only on feature/* branches.

## Changes Made

### CI Workflow Updates
- Modified push triggers to \`branches: [feature/*]\`
- CI now runs only on feature branch pattern
- Enforces naming conventions

## Files Modified

$(git diff --name-only | sed 's/^/- /')

---
*Generated by gitRepoUtils.sh update-ci-branches command*"
                fi
            fi
            
            echo "PR Title: $PR_TITLE"
            echo ""
            
            # Check if a PR already exists
            EXISTING_PR=$(gh pr list --base "$TARGET_BRANCH" --head "$BRANCH_NAME" --json number -q '.[0].number' 2>/dev/null || echo "")
            
            if [ -n "$EXISTING_PR" ]; then
                echo "[i] Pull request already exists: #$EXISTING_PR"
                PR_URL=$(gh pr view "$EXISTING_PR" --json url -q .url 2>/dev/null)
                echo "URL: $PR_URL"
                echo ""
            else
                # Create the pull request
                echo "Creating pull request from $BRANCH_NAME to $TARGET_BRANCH..."
                if PR_URL=$(gh pr create --base "$TARGET_BRANCH" --head "$BRANCH_NAME" --title "$PR_TITLE" --body "$PR_BODY" 2>&1); then
                    echo "[OK] Pull request created successfully"
                    echo "URL: $PR_URL"
                    echo ""
                    
                    # Extract PR number from URL
                    PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')
                    if [ -n "$PR_NUMBER" ]; then
                        echo "PR #$PR_NUMBER created"
                    fi
                else
                    echo "[X] Failed to create pull request"
                    echo "$PR_URL"
                    echo ""
                    echo "You can manually create the PR from the pushed branch:"
                    echo "  Branch: $BRANCH_NAME"
                    echo "  Target: $TARGET_BRANCH"
                fi
            fi
            echo ""
        fi
        
        # Step 8: Complete
        echo "=========================================="
        echo "Complete!"
        echo "=========================================="
        echo ""
        
        echo "[OK] CI workflow branch triggers updated"
        echo ""
        
        if [ "$PATTERN" = "all-except-main" ]; then
            echo "Changes applied:"
            echo "  - CI workflows now trigger on ALL branches except main"
            echo "  - Developers can use any branch naming pattern"
        else
            echo "Changes applied:"
            echo "  - CI workflows now trigger only on feature/* branches"
            echo "  - Enforces consistent branch naming"
        fi
        echo ""
        
        if [ "$SKIP_BRANCH" = false ]; then
            if [ "$AUTO_COMMIT" = true ]; then
                echo "[OK] Changes committed to: $BRANCH_NAME"
                echo "[OK] Branch pushed to remote"
            else
                echo "[i] Changes made but not committed (--no-commit flag)"
                echo "    To commit: git add -A && git commit -m 'Update CI workflows'"
            fi
            
            if [ "$CREATE_PR" = true ]; then
                if [ -n "$PR_URL" ]; then
                    echo "[OK] Pull request created"
                    echo ""
                    echo "Next steps:"
                    echo "  1. Review the PR: $PR_URL"
                    echo "  2. Get approval from team"
                    echo "  3. Merge when ready"
                else
                    echo ""
                    echo "Next steps:"
                    echo "  1. Create PR manually: gh pr create"
                    echo "  2. Or via GitHub web interface"
                fi
            else
                echo ""
                echo "Next steps:"
                echo "  1. Create a pull request:"
                echo "     gh pr create --base $TARGET_BRANCH --head $BRANCH_NAME"
                echo "  2. Or use: $0 update-ci-branches --create-pr ..."
            fi
        else
            echo "[i] Changes made directly (--skip-branch flag)"
            echo ""
            echo "Next steps:"
            echo "  1. Review changes: git diff"
            echo "  2. Stage changes: git add -A"
            echo "  3. Commit: git commit -m 'Update CI workflows'"
            echo "  4. Push and create PR manually"
        fi
        
        echo ""
        echo "Backup files created (can be deleted after verification):"
        find "$WORKFLOWS_DIR" -name "*.backup" 2>/dev/null | head -5 || echo "  (none)"
        
        exit 0
        ;;
        

    configure-repo)
        # Handle configure-repo command
        
        # Default options
        ENABLE_AUTO_MERGE=""
        ENABLE_DELETE_BRANCH=""
        ENABLE_ISSUES=""
        ENABLE_WIKI=""
        ENABLE_PROJECTS=""
        ALLOW_SQUASH=""
        ALLOW_MERGE_COMMIT=""
        ALLOW_REBASE=""
        DEFAULT_BRANCH=""
        DESCRIPTION=""
        TOPICS=""
        VISIBILITY=""
        CHECK=false
        FORCE=false
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --enable-auto-merge)
                    ENABLE_AUTO_MERGE=true
                    shift
                    ;;
                --disable-auto-merge)
                    ENABLE_AUTO_MERGE=false
                    shift
                    ;;
                --enable-delete-branch)
                    ENABLE_DELETE_BRANCH=true
                    shift
                    ;;
                --disable-delete-branch)
                    ENABLE_DELETE_BRANCH=false
                    shift
                    ;;
                --enable-issues)
                    ENABLE_ISSUES=true
                    shift
                    ;;
                --disable-issues)
                    ENABLE_ISSUES=false
                    shift
                    ;;
                --enable-wiki)
                    ENABLE_WIKI=true
                    shift
                    ;;
                --disable-wiki)
                    ENABLE_WIKI=false
                    shift
                    ;;
                --enable-projects)
                    ENABLE_PROJECTS=true
                    shift
                    ;;
                --disable-projects)
                    ENABLE_PROJECTS=false
                    shift
                    ;;
                --allow-squash)
                    ALLOW_SQUASH=true
                    shift
                    ;;
                --disallow-squash)
                    ALLOW_SQUASH=false
                    shift
                    ;;
                --allow-merge-commit)
                    ALLOW_MERGE_COMMIT=true
                    shift
                    ;;
                --disallow-merge-commit)
                    ALLOW_MERGE_COMMIT=false
                    shift
                    ;;
                --allow-rebase)
                    ALLOW_REBASE=true
                    shift
                    ;;
                --disallow-rebase)
                    ALLOW_REBASE=false
                    shift
                    ;;
                --default-branch)
                    DEFAULT_BRANCH="$2"
                    shift 2
                    ;;
                --description)
                    DESCRIPTION="$2"
                    shift 2
                    ;;
                --topics)
                    TOPICS="$2"
                    shift 2
                    ;;
                --visibility)
                    VISIBILITY="$2"
                    shift 2
                    ;;
                --check)
                    CHECK=true
                    shift
                    ;;
                --force)
                    FORCE=true
                    shift
                    ;;
                -h|--help)
                    show_configure_repo_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 configure-repo --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 configure-repo [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Check if git directory was provided
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 configure-repo [options] <git-directory>"
            echo "Run '$0 configure-repo --help' for more information."
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
        if [ "$CHECK" = true ]; then
            echo "Repository Settings Check"
        else
            echo "Configure Repository Settings"
        fi
        echo "=========================================="
        echo "Repository: $REPO_NAME"
        echo "GitHub: $REPO_FULL"
        echo "=========================================="
        echo ""
        
        # Get current settings
        CURRENT_SETTINGS=$(gh api "repos/$REPO_FULL" 2>/dev/null)
        
        if [ -z "$CURRENT_SETTINGS" ]; then
            echo "Error: Failed to fetch repository settings"
            echo "You may not have admin permissions on this repository"
            exit 1
        fi
        
        # If checking, display current settings
        if [ "$CHECK" = true ]; then
            echo "Current Repository Settings:"
            echo ""
            
            # Basic info
            VISIBILITY=$(echo "$CURRENT_SETTINGS" | jq -r '.visibility // .private')
            if [ "$VISIBILITY" = "true" ]; then
                VISIBILITY="private"
            elif [ "$VISIBILITY" = "false" ]; then
                VISIBILITY="public"
            fi
            echo "Basic Information:"
            echo "  Name: $(echo "$CURRENT_SETTINGS" | jq -r '.name')"
            echo "  Description: $(echo "$CURRENT_SETTINGS" | jq -r '.description // "Not set"')"
            echo "  Visibility: $VISIBILITY"
            echo "  Default Branch: $(echo "$CURRENT_SETTINGS" | jq -r '.default_branch')"
            echo "  Topics: $(echo "$CURRENT_SETTINGS" | jq -r '.topics // [] | join(", ")')"
            echo ""
            
            # Features
            echo "Features:"
            echo "  Issues: $(echo "$CURRENT_SETTINGS" | jq -r '.has_issues')"
            echo "  Wiki: $(echo "$CURRENT_SETTINGS" | jq -r '.has_wiki')"
            echo "  Projects: $(echo "$CURRENT_SETTINGS" | jq -r '.has_projects')"
            echo "  Discussions: $(echo "$CURRENT_SETTINGS" | jq -r '.has_discussions // false')"
            echo ""
            
            # Merge settings
            echo "Merge Settings:"
            echo "  Allow Merge Commits: $(echo "$CURRENT_SETTINGS" | jq -r '.allow_merge_commit')"
            echo "  Allow Squash Merge: $(echo "$CURRENT_SETTINGS" | jq -r '.allow_squash_merge')"
            echo "  Allow Rebase Merge: $(echo "$CURRENT_SETTINGS" | jq -r '.allow_rebase_merge')"
            echo "  Auto-Merge Allowed: $(echo "$CURRENT_SETTINGS" | jq -r '.allow_auto_merge // false')"
            echo "  Delete Branch on Merge: $(echo "$CURRENT_SETTINGS" | jq -r '.delete_branch_on_merge // false')"
            echo ""
            
            # Security
            echo "Security:"
            echo "  Vulnerability Alerts: $(echo "$CURRENT_SETTINGS" | jq -r '.security_and_analysis.advanced_security.status // "disabled"')"
            echo "  Secret Scanning: $(echo "$CURRENT_SETTINGS" | jq -r '.security_and_analysis.secret_scanning.status // "disabled"')"
            echo ""
            
            exit 0
        fi
        
        # Build update payload
        UPDATE_PAYLOAD="{}"
        CHANGES_MADE=false
        
        # Add settings to payload
        if [ -n "$ENABLE_AUTO_MERGE" ]; then
            UPDATE_PAYLOAD=$(echo "$UPDATE_PAYLOAD" | jq --argjson val "$ENABLE_AUTO_MERGE" '. + {allow_auto_merge: $val}')
            CHANGES_MADE=true
            if [ "$ENABLE_AUTO_MERGE" = true ]; then
                echo "Will ENABLE auto-merge for repository"
            else
                echo "Will DISABLE auto-merge for repository"
            fi
        fi
        
        if [ -n "$ENABLE_DELETE_BRANCH" ]; then
            UPDATE_PAYLOAD=$(echo "$UPDATE_PAYLOAD" | jq --argjson val "$ENABLE_DELETE_BRANCH" '. + {delete_branch_on_merge: $val}')
            CHANGES_MADE=true
            if [ "$ENABLE_DELETE_BRANCH" = true ]; then
                echo "Will ENABLE automatic branch deletion on merge"
            else
                echo "Will DISABLE automatic branch deletion on merge"
            fi
        fi
        
        if [ -n "$ENABLE_ISSUES" ]; then
            UPDATE_PAYLOAD=$(echo "$UPDATE_PAYLOAD" | jq --argjson val "$ENABLE_ISSUES" '. + {has_issues: $val}')
            CHANGES_MADE=true
        fi
        
        if [ -n "$ENABLE_WIKI" ]; then
            UPDATE_PAYLOAD=$(echo "$UPDATE_PAYLOAD" | jq --argjson val "$ENABLE_WIKI" '. + {has_wiki: $val}')
            CHANGES_MADE=true
        fi
        
        if [ -n "$ENABLE_PROJECTS" ]; then
            UPDATE_PAYLOAD=$(echo "$UPDATE_PAYLOAD" | jq --argjson val "$ENABLE_PROJECTS" '. + {has_projects: $val}')
            CHANGES_MADE=true
        fi
        
        if [ -n "$ALLOW_SQUASH" ]; then
            UPDATE_PAYLOAD=$(echo "$UPDATE_PAYLOAD" | jq --argjson val "$ALLOW_SQUASH" '. + {allow_squash_merge: $val}')
            CHANGES_MADE=true
            if [ "$ALLOW_SQUASH" = true ]; then
                echo "Will ALLOW squash merging"
            else
                echo "Will DISALLOW squash merging"
            fi
        fi
        
        if [ -n "$ALLOW_MERGE_COMMIT" ]; then
            UPDATE_PAYLOAD=$(echo "$UPDATE_PAYLOAD" | jq --argjson val "$ALLOW_MERGE_COMMIT" '. + {allow_merge_commit: $val}')
            CHANGES_MADE=true
            if [ "$ALLOW_MERGE_COMMIT" = true ]; then
                echo "Will ALLOW merge commits"
            else
                echo "Will DISALLOW merge commits"
            fi
        fi
        
        if [ -n "$ALLOW_REBASE" ]; then
            UPDATE_PAYLOAD=$(echo "$UPDATE_PAYLOAD" | jq --argjson val "$ALLOW_REBASE" '. + {allow_rebase_merge: $val}')
            CHANGES_MADE=true
            if [ "$ALLOW_REBASE" = true ]; then
                echo "Will ALLOW rebase merging"
            else
                echo "Will DISALLOW rebase merging"
            fi
        fi
        
        if [ -n "$DEFAULT_BRANCH" ]; then
            UPDATE_PAYLOAD=$(echo "$UPDATE_PAYLOAD" | jq --arg val "$DEFAULT_BRANCH" '. + {default_branch: $val}')
            CHANGES_MADE=true
            echo "Will set default branch to: $DEFAULT_BRANCH"
        fi
        
        if [ -n "$DESCRIPTION" ]; then
            UPDATE_PAYLOAD=$(echo "$UPDATE_PAYLOAD" | jq --arg val "$DESCRIPTION" '. + {description: $val}')
            CHANGES_MADE=true
            echo "Will update description"
        fi
        
        if [ -n "$VISIBILITY" ]; then
            # Validate visibility
            if [[ ! "$VISIBILITY" =~ ^(public|private|internal)$ ]]; then
                echo "Error: Invalid visibility '$VISIBILITY'"
                echo "Must be: public, private, or internal"
                exit 1
            fi
            UPDATE_PAYLOAD=$(echo "$UPDATE_PAYLOAD" | jq --arg val "$VISIBILITY" '. + {visibility: $val}')
            CHANGES_MADE=true
            echo "Will change visibility to: $VISIBILITY"
        fi
        
        # Check if any changes to make
        if [ "$CHANGES_MADE" = false ]; then
            echo "No settings specified to change."
            echo "Use --check to see current settings or specify settings to change."
            exit 0
        fi
        
        echo ""
        
        # Confirm unless force flag is set
        if [ "$FORCE" = false ]; then
            echo "=========================================="
            echo "CONFIRMATION REQUIRED"
            echo "=========================================="
            echo ""
            echo "You are about to modify repository settings for:"
            echo "  $REPO_FULL"
            echo ""
            echo "Settings to apply:"
            echo "$UPDATE_PAYLOAD" | jq '.'
            echo ""
            read -p "Are you sure you want to proceed? (yes/no): " -r
            echo ""
            
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                echo "Operation cancelled."
                exit 0
            fi
        fi
        
        # Apply settings
        echo "Applying repository settings..."
        echo ""
        
        RESULT=$(gh api "repos/$REPO_FULL" \
            --method PATCH \
            --input - <<< "$UPDATE_PAYLOAD" 2>&1)
        
        API_EXIT_CODE=$?
        
        if [ $API_EXIT_CODE -eq 0 ]; then
            echo "[OK] Repository settings updated successfully!"
            echo ""
            
            # Show specific success messages for important settings
            if [ "$ENABLE_AUTO_MERGE" = "true" ]; then
                echo "Ã¢Å“â€¦ Auto-merge is now ENABLED for $REPO_FULL"
                echo ""
                echo "You can now enable auto-merge on individual PRs with:"
                echo "  $0 enable-auto-merge --pr <NUMBER> $GIT_DIR"
                echo ""
            elif [ "$ENABLE_AUTO_MERGE" = "false" ]; then
                echo "Ã¢ÂÅ’ Auto-merge is now DISABLED for $REPO_FULL"
                echo ""
            fi
            
            if [ "$ENABLE_DELETE_BRANCH" = "true" ]; then
                echo "Ã¢Å“â€¦ Branches will be automatically deleted after merge"
            elif [ "$ENABLE_DELETE_BRANCH" = "false" ]; then
                echo "Ã¢ÂÅ’ Branches will NOT be automatically deleted after merge"
            fi
            
            # Handle topics separately as they use a different API endpoint
            if [ -n "$TOPICS" ]; then
                echo ""
                echo "Updating repository topics..."
                
                # Convert comma-separated topics to JSON array
                TOPICS_JSON=$(echo "$TOPICS" | tr ',' '\n' | jq -R . | jq -s '.')
                
                if gh api "repos/$REPO_FULL/topics" \
                    --method PUT \
                    --field names="$TOPICS_JSON" >/dev/null 2>&1; then
                    echo "[OK] Topics updated"
                else
                    echo "[WARN] Failed to update topics"
                fi
            fi
            
        else
            echo "[FAIL] Failed to update repository settings"
            echo ""
            echo "Error details:"
            echo "$RESULT" | head -20
            echo ""
            
            # Special handling for auto-merge errors
            if echo "$RESULT" | grep -q "auto_merge"; then
                echo "Note: Auto-merge may not be available for your repository because:"
                echo "  - Your GitHub plan doesn't support it"
                echo "  - Organization settings don't allow it"
                echo "  - Repository type doesn't support it"
                echo ""
                echo "Check your GitHub plan and organization settings."
            fi
            
            exit 1
        fi
        
        echo ""
        echo "=========================================="
        echo "Complete!"
        echo "=========================================="
        echo ""
        echo "View updated settings:"
        echo "  $0 configure-repo --check $GIT_DIR"
        echo ""
        echo "Repository settings page:"
        echo "  https://github.com/$REPO_FULL/settings"
        
        exit 0
        ;;
        

    clean-repo)
        # Handle clean-repo command
        
        # Default options
        TARGET_BRANCH="main"
        TARGET_BRANCH_EXPLICIT=false
        STASH=false
        DISCARD=false
        FORCE=false
        FETCH_ONLY=false
        SYNC_ONLY=false
        PRUNE=false
        PULL_ALL=false
        RESET_HARD=false
        CHECKOUT_BRANCH=""
        CREATE_BRANCH=""
        STATUS_ONLY=false
        VERBOSE=false
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --branch)
                    TARGET_BRANCH="$2"
                    TARGET_BRANCH_EXPLICIT=true
                    shift 2
                    ;;
                --stash)
                    STASH=true
                    shift
                    ;;
                --discard)
                    DISCARD=true
                    shift
                    ;;
                --force)
                    FORCE=true
                    shift
                    ;;
                --fetch-only)
                    FETCH_ONLY=true
                    shift
                    ;;
                --sync-only)
                    SYNC_ONLY=true
                    shift
                    ;;
                --prune)
                    PRUNE=true
                    shift
                    ;;
                --pull-all)
                    PULL_ALL=true
                    shift
                    ;;
                --reset-hard)
                    RESET_HARD=true
                    shift
                    ;;
                --checkout)
                    CHECKOUT_BRANCH="$2"
                    shift 2
                    ;;
                --create-branch)
                    CREATE_BRANCH="$2"
                    shift 2
                    ;;
                --status)
                    STATUS_ONLY=true
                    shift
                    ;;
                --verbose)
                    VERBOSE=true
                    shift
                    ;;
                -h|--help)
                    show_clean_repo_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 clean-repo --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 clean-repo [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Check if git directory was provided
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 clean-repo [options] <git-directory>"
            echo "Run '$0 clean-repo --help' for more information."
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
        
        # Change to git directory
        cd "$GIT_DIR"
        
        # Get repository name
        REPO_NAME=$(basename "$GIT_DIR")
        
        echo "=========================================="
        if [ "$STATUS_ONLY" = true ]; then
            echo "Repository Status Check"
        else
            echo "Clean Repository"
        fi
        echo "=========================================="
        echo "Repository: $REPO_NAME"
        echo "Path: $GIT_DIR"
        echo "=========================================="
        echo ""
        
        # Get current branch
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        if [ -z "$CURRENT_BRANCH" ]; then
            echo "Error: Could not determine current branch"
            exit 1
        fi
        
        echo "Current branch: $CURRENT_BRANCH"
        
        # Check for remotes
        if ! git remote | grep -q "origin"; then
            echo "Error: No remote 'origin' configured"
            exit 1
        fi
        
        # Step 1: Check for uncommitted changes
        echo ""
        echo "Step 1: Checking for uncommitted changes..."
        
        HAS_CHANGES=false
        CHANGES_STAGED=false
        CHANGES_UNSTAGED=false
        UNTRACKED_FILES=false
        
        if ! git diff --cached --quiet; then
            CHANGES_STAGED=true
            HAS_CHANGES=true
        fi
        
        if ! git diff --quiet; then
            CHANGES_UNSTAGED=true
            HAS_CHANGES=true
        fi
        
        if [ -n "$(git ls-files --others --exclude-standard)" ]; then
            UNTRACKED_FILES=true
            HAS_CHANGES=true
        fi
        
        if [ "$HAS_CHANGES" = true ]; then
            echo "Found uncommitted changes:"
            
            if [ "$CHANGES_STAGED" = true ]; then
                echo "  - Staged changes"
                if [ "$VERBOSE" = true ]; then
                    git diff --cached --stat
                fi
            fi
            
            if [ "$CHANGES_UNSTAGED" = true ]; then
                echo "  - Unstaged changes"
                if [ "$VERBOSE" = true ]; then
                    git diff --stat
                fi
            fi
            
            if [ "$UNTRACKED_FILES" = true ]; then
                echo "  - Untracked files"
                if [ "$VERBOSE" = true ]; then
                    git ls-files --others --exclude-standard | head -10
                fi
            fi
            
            # If status only, show and exit
            if [ "$STATUS_ONLY" = true ]; then
                echo ""
                echo "Working directory is not clean."
                echo "Use --stash, --discard, or commit changes before proceeding."
                exit 0
            fi
            
            # Handle uncommitted changes
            if [ "$DISCARD" = true ]; then
                echo ""
                echo "WARNING: Discarding all local changes..."
                git reset --hard HEAD
                git clean -fd
                echo "[OK] All changes discarded"
            elif [ "$STASH" = true ] || [ "$FORCE" = true ]; then
                echo ""
                echo "Stashing changes..."
                STASH_MSG="gitRepoUtils clean-repo: Stashed on $(date '+%Y-%m-%d %H:%M:%S')"
                git stash push -m "$STASH_MSG" --include-untracked
                echo "[OK] Changes stashed: $STASH_MSG"
                echo "To restore: git stash pop"
            else
                echo ""
                echo "=========================================="
                echo "ACTION REQUIRED"
                echo "=========================================="
                echo ""
                echo "You have uncommitted changes in the repository."
                echo ""
                echo "Options:"
                echo "  1. Commit your changes: git add . && git commit -m 'message'"
                echo "  2. Stash changes: $0 clean-repo --stash $GIT_DIR"
                echo "  3. Discard changes: $0 clean-repo --discard $GIT_DIR"
                echo "  4. Force stash: $0 clean-repo --force $GIT_DIR"
                echo ""
                read -p "Do you want to stash these changes? (yes/no): " -r
                echo ""
                
                if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                    STASH_MSG="gitRepoUtils clean-repo: Stashed on $(date '+%Y-%m-%d %H:%M:%S')"
                    git stash push -m "$STASH_MSG" --include-untracked
                    echo "[OK] Changes stashed: $STASH_MSG"
                else
                    echo "Operation cancelled. Commit or stash your changes first."
                    exit 1
                fi
            fi
        else
            echo "[OK] Working directory is clean"
        fi
        
        # If status only, exit here
        if [ "$STATUS_ONLY" = true ]; then
            echo ""
            echo "=========================================="
            echo "Status Check Complete"
            echo "=========================================="
            exit 0
        fi
        
        # Step 2: Fetch from remotes
        if [ "$SYNC_ONLY" = false ]; then
            echo ""
            echo "Step 2: Fetching from remotes..."
            
            if [ "$PRUNE" = true ]; then
                echo "Fetching with prune (removing deleted remote branches)..."
                if [ "$VERBOSE" = true ]; then
                    git fetch --all --prune --verbose
                else
                    git fetch --all --prune
                fi
                echo "[OK] Fetched and pruned"
            else
                echo "Fetching all remotes..."
                if [ "$VERBOSE" = true ]; then
                    git fetch --all --verbose
                else
                    git fetch --all
                fi
                echo "[OK] Fetched latest changes"
            fi
        fi
        
        # Step 3: Sync target branch
        if [ "$FETCH_ONLY" = false ]; then
            echo ""
            echo "Step 3: Syncing branches..."
            
            # Check if target branch exists
            if ! git rev-parse --verify "origin/$TARGET_BRANCH" >/dev/null 2>&1; then
                # If using default 'main' and it doesn't exist, try 'master'
                if [ "$TARGET_BRANCH" = "main" ] && [ "$TARGET_BRANCH_EXPLICIT" = false ]; then
                    if git rev-parse --verify "origin/master" >/dev/null 2>&1; then
                        echo "[i] Branch 'main' not found, falling back to 'master'"
                        TARGET_BRANCH="master"
                    else
                        echo "Error: Neither 'origin/main' nor 'origin/master' exists"
                        exit 1
                    fi
                else
                    echo "Error: Remote branch 'origin/$TARGET_BRANCH' does not exist"
                    exit 1
                fi
            fi
            
            # Sync target branch
            if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
                echo "Switching to $TARGET_BRANCH branch..."
                
                if git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1; then
                    git checkout "$TARGET_BRANCH"
                else
                    git checkout -b "$TARGET_BRANCH" "origin/$TARGET_BRANCH"
                fi
            fi
            
            echo "Syncing $TARGET_BRANCH with origin/$TARGET_BRANCH..."
            
            if [ "$RESET_HARD" = true ]; then
                echo "WARNING: Hard reset to origin/$TARGET_BRANCH..."
                git reset --hard "origin/$TARGET_BRANCH"
                echo "[OK] Hard reset complete"
            else
                # Check if we can fast-forward
                LOCAL_COMMIT=$(git rev-parse HEAD)
                REMOTE_COMMIT=$(git rev-parse "origin/$TARGET_BRANCH")
                BASE_COMMIT=$(git merge-base HEAD "origin/$TARGET_BRANCH")
                
                if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
                    echo "[OK] Already up to date"
                elif [ "$LOCAL_COMMIT" = "$BASE_COMMIT" ]; then
                    # We're behind, can fast-forward
                    git pull origin "$TARGET_BRANCH"
                    echo "[OK] Fast-forwarded to latest"
                elif [ "$REMOTE_COMMIT" = "$BASE_COMMIT" ]; then
                    # We're ahead
                    echo "[i] Local branch is ahead of remote"
                    echo "    Use --reset-hard to force sync with remote"
                else
                    # Diverged
                    echo "[!] Local and remote have diverged"
                    echo "    Use --reset-hard to force sync with remote"
                    echo "    Or manually resolve with git rebase or merge"
                fi
            fi
        fi
        
        # Step 4: Pull all tracking branches (optional)
        if [ "$PULL_ALL" = true ]; then
            echo ""
            echo "Step 4: Pulling all tracking branches..."
            
            for branch in $(git branch -r | grep -v HEAD | sed 's/origin\///'); do
                if git show-ref --verify --quiet "refs/heads/$branch"; then
                    echo "Updating $branch..."
                    git checkout "$branch" 2>/dev/null
                    git pull origin "$branch" 2>/dev/null || echo "  [!] Could not update $branch"
                fi
            done
            
            # Return to original or target branch
            if [ -n "$CHECKOUT_BRANCH" ]; then
                git checkout "$CHECKOUT_BRANCH" 2>/dev/null
            elif [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
                git checkout "$CURRENT_BRANCH" 2>/dev/null
            else
                git checkout "$TARGET_BRANCH" 2>/dev/null
            fi
            
            echo "[OK] All tracking branches updated"
        fi
        
        # Step 5: Checkout or create branch (optional)
        if [ -n "$CHECKOUT_BRANCH" ]; then
            echo ""
            echo "Step 5: Checking out branch..."
            
            if git rev-parse --verify "$CHECKOUT_BRANCH" >/dev/null 2>&1; then
                git checkout "$CHECKOUT_BRANCH"
                echo "[OK] Switched to branch: $CHECKOUT_BRANCH"
            elif git rev-parse --verify "origin/$CHECKOUT_BRANCH" >/dev/null 2>&1; then
                git checkout -b "$CHECKOUT_BRANCH" "origin/$CHECKOUT_BRANCH"
                echo "[OK] Created and switched to branch: $CHECKOUT_BRANCH"
            else
                echo "Error: Branch '$CHECKOUT_BRANCH' not found"
                exit 1
            fi
        elif [ -n "$CREATE_BRANCH" ]; then
            echo ""
            echo "Step 5: Creating new branch..."
            
            if git rev-parse --verify "$CREATE_BRANCH" >/dev/null 2>&1; then
                echo "Error: Branch '$CREATE_BRANCH' already exists"
                exit 1
            fi
            
            git checkout -b "$CREATE_BRANCH"
            echo "[OK] Created and switched to new branch: $CREATE_BRANCH"
        fi
        
        # Summary
        echo ""
        echo "=========================================="
        echo "Clean Complete!"
        echo "=========================================="
        echo ""
        
        FINAL_BRANCH=$(git branch --show-current)
        echo "Current branch: $FINAL_BRANCH"
        echo "Status: $(git status --porcelain | wc -l) uncommitted changes"
        
        # Show recent commits
        echo ""
        echo "Recent commits:"
        git log --oneline -5
        
        echo ""
        echo "Repository is ready for operations."
        
        # Show stash reminder if we stashed
        if [ "$HAS_CHANGES" = true ] && ([ "$STASH" = true ] || [ "$FORCE" = true ]); then
            echo ""
            echo "Remember: You have stashed changes. To restore them:"
            echo "  git stash list  # View stashes"
            echo "  git stash pop   # Restore most recent stash"
        fi
        
        exit 0
        ;;

    *)
        echo "Error: Unknown repo command: $cmd"
        return 1
        ;;
    esac
}
