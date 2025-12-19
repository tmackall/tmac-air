#!/bin/bash

# Script to migrate GitHub Actions workflows from Git Flow to GitHub Flow
# This script updates workflow files to remove develop branch triggers and
# creates a PR with the changes

set -e

# Function to show usage
show_usage() {
    echo "Usage: $0 [options] <git-directory>"
    echo ""
    echo "This script migrates GitHub Actions workflows from Git Flow to GitHub Flow by:"
    echo "  1. Syncing main branch with remote"
    echo "  2. Creating a feature branch from main"
    echo "  3. Updating workflow files to remove develop branch triggers"
    echo "  4. Committing the changes"
    echo "  5. Creating a pull request to main (GitHub Flow)"
    echo ""
    echo "Options:"
    echo "  --branch-name NAME       Feature branch name (default: chore/migrate-workflows-to-github-flow)"
    echo "  --target BRANCH          Target branch for PR (default: main)"
    echo "  --title TITLE            PR title (default: auto-generated)"
    echo "  --body BODY              PR body/description (default: auto-generated)"
    echo "  --force-recreate         Delete and recreate migration branch if it exists"
    echo "  --dry-run                Show what would be changed without making changes"
    echo "  --skip-pr                Update files but don't create PR"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 ~/projects/my-project                                    # Standard migration"
    echo "  $0 --dry-run ~/projects/my-project                          # Preview changes only"
    echo "  $0 --skip-pr ~/projects/my-project                          # Update files, no PR"
    echo "  $0 --force-recreate ~/projects/my-project                   # Delete existing branch and start fresh"
    echo "  $0 --branch-name feature/new-workflows ~/projects/my-proj  # Custom branch name"
    echo "  $0 --target develop ~/projects/my-project                   # Target develop (for transitional PR)"
    echo ""
    echo "Requirements:"
    echo "  - GitHub CLI (gh) must be installed and authenticated"
    echo "  - Write permissions on the repository"
    echo ""
    echo "Workflow File Changes:"
    echo "  Main/Deploy Workflow (e.g., ds-service-*-main-workflow.yml):"
    echo "    * Removes 'develop' from branches trigger list"
    echo "    * Keeps only 'main' branch trigger"
    echo ""
    echo "  CI Workflow (e.g., ds-service-*-ci-workflow.yml):"
    echo "    * Changes from 'branches-ignore: [main, develop]'"
    echo "    * To 'branches: [feature/*]'"
    echo "    * Ensures CI runs only on feature branches"
    echo ""
    echo "  Image Metadata (image-metadata-app.yml):"
    echo "    * Updates naming conventions if needed"
    echo "    * Removes 'ds-' prefix for consistency"
}

# Default options
BRANCH_NAME="chore/migrate-workflows-to-github-flow"
TARGET_BRANCH="main"
PR_TITLE=""
PR_BODY=""
FORCE_RECREATE=false
DRY_RUN=false
SKIP_PR=false
GIT_DIR=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --branch-name)
            BRANCH_NAME="$2"
            shift 2
            ;;
        --target)
            TARGET_BRANCH="$2"
            shift 2
            ;;
        --title)
            PR_TITLE="$2"
            shift 2
            ;;
        --body)
            PR_BODY="$2"
            shift 2
            ;;
        --force-recreate)
            FORCE_RECREATE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-pr)
            SKIP_PR=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo "Error: Unknown option: $1"
            echo "Run '$0 --help' for usage information."
            exit 1
            ;;
        *)
            if [ -z "$GIT_DIR" ]; then
                GIT_DIR="$1"
            else
                echo "Error: Multiple git directories specified"
                echo "Usage: $0 [options] <git-directory>"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if git directory was provided
if [ -z "$GIT_DIR" ]; then
    echo "Error: No git directory specified"
    echo "Usage: $0 [options] <git-directory>"
    echo "Run '$0 --help' for more information."
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

# Check if GitHub CLI is installed (unless skip-pr)
if [ "$SKIP_PR" = false ]; then
    if ! command -v gh >/dev/null 2>&1; then
        echo "Error: GitHub CLI (gh) is not installed"
        echo "Please install it from: https://cli.github.com/"
        echo "Or use --skip-pr to skip PR creation"
        exit 1
    fi

    # Check if gh is authenticated
    if ! gh auth status >/dev/null 2>&1; then
        echo "Error: GitHub CLI is not authenticated"
        echo "Please run: gh auth login"
        echo "Or use --skip-pr to skip PR creation"
        exit 1
    fi
fi

# Change to git directory
cd "$GIT_DIR"

# Get repository name
REPO_NAME=$(basename "$GIT_DIR")

# Get the repository owner/name for GitHub (if not skipping PR)
if [ "$SKIP_PR" = false ]; then
    REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
    if [ -z "$REPO_FULL" ]; then
        echo "Error: Could not determine GitHub repository"
        echo "Make sure this is a GitHub repository with a remote configured"
        echo "Or use --skip-pr to skip PR creation"
        exit 1
    fi
fi

echo "=========================================="
echo "Migrate Workflows: Git Flow -> GitHub Flow"
echo "=========================================="
echo "Repository: $REPO_NAME"
if [ "$SKIP_PR" = false ]; then
    echo "GitHub: $REPO_FULL"
fi
echo "Path: $GIT_DIR"
echo "Feature Branch: $BRANCH_NAME"
echo "Target Branch: $TARGET_BRANCH"
if [ "$DRY_RUN" = true ]; then
    echo "Mode: DRY RUN (no changes will be made)"
fi
echo "=========================================="
echo ""

# Step 1: Sync with remote
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

# Check if develop branch exists
if ! git rev-parse --verify "origin/develop" >/dev/null 2>&1; then
    echo "Warning: Remote branch 'origin/develop' does not exist"
    echo "This repository may have already been migrated to GitHub Flow"
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

# Sync develop branch if it exists
if git rev-parse --verify "origin/develop" >/dev/null 2>&1; then
    echo "Syncing develop branch..."
    if git rev-parse --verify develop >/dev/null 2>&1; then
        git checkout develop
        git pull origin develop
        echo "[OK] develop branch updated"
    else
        git checkout -b develop origin/develop
        echo "[OK] develop branch created from origin/develop"
    fi
    echo ""
fi

# Step 2: Create feature branch
echo "=========================================="
echo "Step 2: Creating Feature Branch"
echo "=========================================="
echo ""

# Start from main (GitHub Flow - always branch from main)
START_BRANCH="main"

echo "Creating feature branch from $START_BRANCH..."
git checkout "$START_BRANCH"

# Check if feature branch already exists
if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
    if [ "$FORCE_RECREATE" = true ]; then
        echo "Branch '$BRANCH_NAME' already exists"
        echo "Force recreate enabled - deleting existing branch..."
        
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would delete branch: $BRANCH_NAME"
            echo "[DRY RUN] Would create new branch: $BRANCH_NAME"
        else
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
        fi
    else
        echo "Warning: Branch '$BRANCH_NAME' already exists"
        echo "Checking out existing branch..."
        echo "(Use --force-recreate to delete and start fresh)"
        git checkout "$BRANCH_NAME"
    fi
else
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would create branch: $BRANCH_NAME"
    else
        git checkout -b "$BRANCH_NAME"
        echo "[OK] Created branch: $BRANCH_NAME"
    fi
fi
echo ""

# Step 3: Find and update workflow files
echo "=========================================="
echo "Step 3: Finding Workflow Files"
echo "=========================================="
echo ""

WORKFLOWS_DIR=".github/workflows"

if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo "Error: Workflows directory not found: $WORKFLOWS_DIR"
    echo "This repository may not use GitHub Actions"
    exit 1
fi

echo "Scanning for workflow files in $WORKFLOWS_DIR..."
echo ""

# Find main/deploy workflow files
MAIN_WORKFLOWS=$(find "$WORKFLOWS_DIR" -type f -name "*-main-workflow.yml" -o -name "*-main.yml" 2>/dev/null)
CI_WORKFLOWS=$(find "$WORKFLOWS_DIR" -type f -name "*-ci-workflow.yml" -o -name "*-ci.yml" 2>/dev/null)

# Find image metadata file
IMAGE_METADATA=""
if [ -f "image-metadata-app.yml" ]; then
    IMAGE_METADATA="image-metadata-app.yml"
fi

if [ -z "$MAIN_WORKFLOWS" ] && [ -z "$CI_WORKFLOWS" ] && [ -z "$IMAGE_METADATA" ]; then
    echo "Error: No workflow files found to migrate"
    echo "Expected files:"
    echo "  - *-main-workflow.yml or *-main.yml"
    echo "  - *-ci-workflow.yml or *-ci.yml"
    echo "  - image-metadata-app.yml (optional)"
    exit 1
fi

echo "Found workflow files:"
if [ -n "$MAIN_WORKFLOWS" ]; then
    echo "  Main/Deploy workflows:"
    echo "$MAIN_WORKFLOWS" | while read -r file; do
        echo "    * $file"
    done
fi
if [ -n "$CI_WORKFLOWS" ]; then
    echo "  CI workflows:"
    echo "$CI_WORKFLOWS" | while read -r file; do
        echo "    * $file"
    done
fi
if [ -n "$IMAGE_METADATA" ]; then
    echo "  Image metadata:"
    echo "    * $IMAGE_METADATA"
fi
echo ""

# Step 4: Update workflow files
echo "=========================================="
echo "Step 4: Updating Workflow Files"
echo "=========================================="
echo ""

CHANGES_MADE=false

# Function to update main workflow files
update_main_workflow() {
    local file="$1"
    echo "Processing: $file"
    
    local file_modified=false
    
    # Check if file contains 'develop' in branches list
    if grep -q "branches:" "$file" && grep -A 5 "branches:" "$file" | grep -q "develop"; then
        echo "  -> Found 'develop' branch trigger"
        
        if [ "$DRY_RUN" = true ]; then
            echo "  -> [DRY RUN] Would remove 'develop' from branches list"
        else
            # Create a backup
            cp "$file" "${file}.backup"
            
            # Remove 'develop' from branches list using Python for better YAML handling
            python3 - "$file" << 'EOF'
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    content = f.read()

# Pattern to match branches section with develop
# This handles both:
#   branches:
#     - main
#     - develop
# and:
#   branches: [main, develop]

# First, try to remove from list format - IMPROVED to preserve what comes after
# Match and remove the "- develop" line but preserve subsequent content at correct indentation
modified = re.sub(
    r'(\s+branches:\s*\n(?:\s+-\s+[\w\-\/\*]+\n)*?)\s+-\s+develop\s*\n',
    r'\1',
    content
)

# Also handle array format: branches: [main, develop]
modified = re.sub(
    r'(branches:\s*\[.*?),\s*develop\s*\]',
    r'\1]',
    modified
)

# Handle case where develop is first: branches: [develop, main]
modified = re.sub(
    r'(branches:\s*\[)\s*develop\s*,\s*',
    r'\1',
    modified
)

# Handle case where develop is the only branch: branches: [develop] or - develop
modified = re.sub(
    r'branches:\s*\[\s*develop\s*\]',
    'branches:\n      - main',
    modified
)

with open(file_path, 'w') as f:
    f.write(modified)
EOF
            
            echo "  -> Removed 'develop' from branches list"
            CHANGES_MADE=true
            file_modified=true
        fi
    else
        echo "  -> No 'develop' branch trigger found (already migrated or not present)"
    fi
    
    # ALWAYS check for workflow_dispatch indentation issues, even if no develop was found
    echo "  -> Checking for workflow_dispatch indentation issues..."
    
    # Check if file has workflow_dispatch with wrong indentation
    if grep -A 1 "^\s*-\s*main\s*$" "$file" 2>/dev/null | grep -q "^\s\{6,\}workflow_dispatch:"; then
        echo "  -> [!] Found workflow_dispatch indentation issue"
        
        if [ "$DRY_RUN" = true ]; then
            echo "  -> [DRY RUN] Would fix workflow_dispatch indentation"
        else
            # Create backup if not already created
            if [ "$file_modified" = false ]; then
                cp "$file" "${file}.backup"
            fi
            
            # Fix the indentation
            python3 - "$file" << 'EOF'
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    content = f.read()

# CRITICAL FIX: Detect and fix workflow_dispatch indentation issues
# Pattern: branches section ends, followed by workflow_dispatch with wrong indentation
# Look for: "- branch\n      workflow_dispatch:" (6+ spaces = wrong)
# Fix to: "- branch\n  workflow_dispatch:" (2 spaces = correct, same level as push)
modified = re.sub(
    r'(\n\s+branches:\s*\n(?:\s+-\s+[\w\-\/\*]+\s*\n)+)\s{6,}(workflow_dispatch:)',
    r'\1  \2',
    content
)

# Also fix case where workflow_dispatch immediately follows a branch with wrong indent
modified = re.sub(
    r'(\s+-\s+[\w\-\/\*]+)\s*\n\s{6,}(workflow_dispatch:)',
    r'\1\n  \2',
    modified
)

with open(file_path, 'w') as f:
    f.write(modified)
EOF
            
            echo "  -> Fixed workflow_dispatch indentation"
            CHANGES_MADE=true
            file_modified=true
        fi
    else
        echo "  -> No workflow_dispatch indentation issues found"
    fi
    
    echo ""
}

# Function to update CI workflow files
update_ci_workflow() {
    local file="$1"
    echo "Processing: $file"
    
    local changes_made_in_file=false
    
    # First, let's diagnose what pattern this file has
    echo "  -> Analyzing workflow pattern..."
    
    # Check what triggers exist
    local has_push_trigger=false
    local has_pull_request_trigger=false
    local has_branches=false
    local has_branches_ignore=false
    local has_develop=false
    local has_schedule=false
    local has_workflow_dispatch=false
    
    if grep -q "^\s*push:" "$file"; then
        has_push_trigger=true
        echo "     * Found 'push:' trigger"
    fi
    
    if grep -q "^\s*pull_request:" "$file"; then
        has_pull_request_trigger=true
        echo "     * Found 'pull_request:' trigger"
    fi
    
    if grep -q "^\s*branches:" "$file"; then
        has_branches=true
        echo "     * Found 'branches:' section"
    fi
    
    if grep -q "^\s*branches-ignore:" "$file"; then
        has_branches_ignore=true
        echo "     * Found 'branches-ignore:' section"
    fi
    
    if grep -A 10 "^\s*branches" "$file" | grep -q "develop"; then
        has_develop=true
        echo "     * Found 'develop' in branch configuration"
    fi
    
    if grep -q "^\s*schedule:" "$file"; then
        has_schedule=true
        echo "     * Found 'schedule:' trigger"
    fi
    
    if grep -q "^\s*workflow_dispatch:" "$file"; then
        has_workflow_dispatch=true
        echo "     * Found 'workflow_dispatch:' trigger"
    fi
    
    # Pattern 1: pull_request trigger (replace with push on feature branches)
    if [ "$has_pull_request_trigger" = true ]; then
        echo "  -> Pattern: pull_request trigger (will replace with push: feature/*)"
        
        if [ "$DRY_RUN" = true ]; then
            echo "  -> [DRY RUN] Would replace 'pull_request' with 'push: branches: [feature/*]'"
        else
            # Create a backup
            cp "$file" "${file}.backup"
            
            # Replace pull_request trigger with push on feature branches
            python3 - "$file" << 'EOF'
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    content = f.read()

# Pattern to match pull_request trigger with types
# Handles both:
#   pull_request:
#     types: [opened,synchronize,reopened]
# And:
#   pull_request:
#     types:
#       - opened
#       - synchronize
# Replace with:
#   push:
#     branches:
#       - feature/*

# First, handle inline types: pull_request:\n    types: [...]
# Capture indentation (spaces only, not the newline before)
modified = re.sub(
    r'\n(\s+)pull_request:\s*\n\s+types:\s*\[.*?\]\s*\n',
    r'\n\1push:\n\1  branches:\n\1    - feature/*\n',
    content
)

# Then handle multiline types: pull_request:\n    types:\n      - ...\n      - ...
modified = re.sub(
    r'\n(\s+)pull_request:\s*\n\s+types:\s*\n(?:\s+-\s+\w+\s*\n)+',
    r'\n\1push:\n\1  branches:\n\1    - feature/*\n',
    modified
)

# Finally, handle pull_request with no types at all (before next trigger)
modified = re.sub(
    r'\n(\s+)pull_request:\s*\n(?=\s+\w)',
    r'\n\1push:\n\1  branches:\n\1    - feature/*\n',
    modified
)

with open(file_path, 'w') as f:
    f.write(modified)
EOF
            
            echo "  -> Replaced 'pull_request' trigger with 'push: branches: [feature/*]'"
            CHANGES_MADE=true
            changes_made_in_file=true
        fi
    
    # Pattern 2: branches-ignore with main/develop
    elif [ "$has_branches_ignore" = true ]; then
        echo "  -> Pattern: branches-ignore (will change to branches: feature/*)"
        
        if [ "$DRY_RUN" = true ]; then
            echo "  -> [DRY RUN] Would change to 'branches: [feature/*]'"
        else
            # Create a backup
            cp "$file" "${file}.backup"
            
            # Replace branches-ignore with branches: feature/*
            python3 - "$file" << 'EOF'
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    content = f.read()

# Replace branches-ignore section with branches: feature/*
modified = re.sub(
    r'(\s+push:\s*\n)\s+branches-ignore:\s*\n(?:\s+-\s+[\w\-\/\*]+\s*\n)+',
    r'\1    branches:\n      - feature/*\n',
    content
)

with open(file_path, 'w') as f:
    f.write(modified)
EOF
            
            echo "  -> Changed 'branches-ignore' to 'branches: [feature/*]'"
            CHANGES_MADE=true
            changes_made_in_file=true
        fi
    
    # Pattern 3: Direct develop in branches list
    elif [ "$has_branches" = true ] && [ "$has_develop" = true ]; then
        echo "  -> Pattern: develop in branches list (will change to feature/*)"
        
        if [ "$DRY_RUN" = true ]; then
            echo "  -> [DRY RUN] Would change 'develop' to 'feature/*'"
        else
            # Create a backup
            cp "$file" "${file}.backup"
            
            # Replace develop with feature/* in branches list
            python3 - "$file" << 'EOF'
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    content = f.read()

# Replace 'develop' with 'feature/*' in branches list
# Handle list format where develop is on its own line
modified = re.sub(
    r'(\s+branches:\s*\n(?:\s+-\s+[\w\-\/\*]+\s*\n)*?\s+)-\s*develop\s*\n',
    r'\1- feature/*\n',
    content
)

# Handle array format: branches: [develop]
modified = re.sub(
    r'(branches:\s*\[)\s*develop\s*\]',
    r'\1feature/*]',
    modified
)

# Handle array format with other branches
modified = re.sub(
    r'(branches:\s*\[[^\]]*),\s*develop\s*([,\]])',
    r'\1, feature/*\2',
    modified
)
modified = re.sub(
    r'(branches:\s*\[)\s*develop\s*,',
    r'\1feature/*, ',
    modified
)

with open(file_path, 'w') as f:
    f.write(modified)
EOF
            
            echo "  -> Changed 'develop' to 'feature/*' in branches list"
            CHANGES_MADE=true
            changes_made_in_file=true
        fi
    
    # Pattern 4: No push trigger with branches at all - add it
    elif [ "$has_push_trigger" = false ] || [ "$has_branches" = false ]; then
        echo "  -> Pattern: Missing push/branches configuration (will add feature/* trigger)"
        
        if [ "$DRY_RUN" = true ]; then
            echo "  -> [DRY RUN] Would add 'push: branches: [feature/*]' trigger"
        else
            # Create a backup
            cp "$file" "${file}.backup"
            
            # Add push trigger with branches: feature/*
            python3 - "$file" << 'EOF'
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    content = f.read()

# Find the 'on:' section and add push trigger with branches if missing
# Look for pattern: name: ...\n'on':\n  workflow_dispatch:
if not re.search(r'\s+push:', content):
    # Add push trigger after 'on:' line
    modified = re.sub(
        r"('on':\s*\n)",
        r"\1  push:\n    branches:\n      - feature/*\n",
        content
    )
    
    with open(file_path, 'w') as f:
        f.write(modified)
else:
    # push exists but no branches - add branches section
    if not re.search(r'\s+branches:', content):
        modified = re.sub(
            r'(\s+push:\s*\n)',
            r'\1    branches:\n      - feature/*\n',
            content
        )
        with open(file_path, 'w') as f:
            f.write(modified)
EOF
            
            echo "  -> Added 'push: branches: [feature/*]' trigger"
            CHANGES_MADE=true
            changes_made_in_file=true
        fi
    
    # Pattern 5: Has branches but already set to feature/* or similar
    else
        echo "  -> Pattern: Already has appropriate branch configuration"
        # Check if it already has feature/* pattern
        if grep -A 5 "branches:" "$file" | grep -q "feature/\*"; then
            echo "  -> Already configured for feature branches (no changes needed)"
        else
            echo "  -> [WARNING] Unknown pattern - manual review recommended"
            echo "     Current branches configuration:"
            grep -A 10 "branches:" "$file" | head -5 | sed 's/^/     /'
        fi
    fi
    
    # Always check for and remove schedule trigger in CI workflows
    if [ "$has_schedule" = true ]; then
        echo "  -> Found 'schedule' trigger (will remove)"
        
        if [ "$DRY_RUN" = true ]; then
            echo "  -> [DRY RUN] Would remove 'schedule' trigger"
        else
            # Create a backup if not already created
            if [ "$changes_made_in_file" = false ]; then
                cp "$file" "${file}.backup"
            fi
            
            # Remove schedule trigger
            python3 - "$file" << 'EOF'
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    content = f.read()

# Remove schedule section with its content
modified = re.sub(
    r'\n\s+schedule:\s*\n(?:\s+-\s+cron:.*\n)+',
    '\n',
    content
)

# Also handle single-line format
modified = re.sub(
    r'\n\s+schedule:.*\n',
    '\n',
    modified
)

with open(file_path, 'w') as f:
    f.write(modified)
EOF
            
            echo "  -> Removed 'schedule' trigger from CI workflow"
            CHANGES_MADE=true
            changes_made_in_file=true
        fi
    fi
    
    if [ "$changes_made_in_file" = false ]; then
        if [ "$DRY_RUN" = false ]; then
            echo "  -> [i] No changes made - workflow may need manual review"
        fi
    fi
    echo ""
}

# Function to update image metadata
update_image_metadata() {
    local file="$1"
    echo "Processing: $file"
    
    # Check if file has ds- prefix in names
    if grep -q "name: ds-service-" "$file"; then
        echo "  -> Found 'ds-service-' naming pattern"
        
        if [ "$DRY_RUN" = true ]; then
            echo "  -> [DRY RUN] Would standardize to 'service-' naming"
        else
            # Create a backup
            cp "$file" "${file}.backup"
            
            # Remove ds- prefix
            sed -i.bak 's/name: ds-service-/name: service-/g' "$file"
            rm -f "${file}.bak"
            
            echo "  -> Standardized naming: ds-service-* -> service-*"
            CHANGES_MADE=true
        fi
    else
        echo "  -> Naming already standardized or different pattern"
    fi
    echo ""
}

# Update main workflow files
if [ -n "$MAIN_WORKFLOWS" ]; then
    echo "Updating main/deploy workflow files:"
    echo ""
    echo "$MAIN_WORKFLOWS" | while read -r file; do
        if [ -f "$file" ]; then
            update_main_workflow "$file"
        fi
    done
fi

# Update CI workflow files
if [ -n "$CI_WORKFLOWS" ]; then
    echo "Updating CI workflow files:"
    echo ""
    echo "$CI_WORKFLOWS" | while read -r file; do
        if [ -f "$file" ]; then
            update_ci_workflow "$file"
        fi
    done
fi

# Update image metadata
if [ -n "$IMAGE_METADATA" ]; then
    echo "Updating image metadata file:"
    echo ""
    update_image_metadata "$IMAGE_METADATA"
fi

# Check if any files were modified
if [ "$DRY_RUN" = false ]; then
    if git diff --quiet; then
        echo "=========================================="
        echo "No Changes Detected"
        echo "=========================================="
        echo ""
        echo "The workflow files appear to already be configured for GitHub Flow."
        echo "No modifications were necessary."
        echo ""
        
        # Clean up feature branch
        git checkout "$START_BRANCH"
        git branch -D "$BRANCH_NAME" 2>/dev/null || true
        
        exit 0
    fi
    CHANGES_MADE=true
fi

if [ "$CHANGES_MADE" = false ] && [ "$DRY_RUN" = false ]; then
    echo "No changes were made to workflow files."
    echo ""
    exit 0
fi

# Step 5: Show changes
echo "=========================================="
echo "Step 5: Review Changes"
echo "=========================================="
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Changes that would be made:"
    echo ""
    echo "The script would update workflow files to:"
    echo "  * Remove 'develop' branch triggers from main workflows"
    echo "  * Change CI workflows from 'branches-ignore' to 'branches: feature/*'"
    echo "  * Standardize naming in image metadata (if applicable)"
    echo ""
    echo "Re-run without --dry-run to apply changes."
    exit 0
fi

echo "Modified files:"
git status --short
echo ""

echo "Detailed changes:"
echo ""
git diff
echo ""

# Step 6: Commit changes
echo "=========================================="
echo "Step 6: Committing Changes"
echo "=========================================="
echo ""

echo "Staging modified workflow files..."
git add .github/workflows/*.yml
if [ -n "$IMAGE_METADATA" ]; then
    git add "$IMAGE_METADATA"
fi

COMMIT_MESSAGE="chore: migrate GitHub Actions workflows from Git Flow to GitHub Flow

This commit updates the CI/CD workflows to support the GitHub Flow branching strategy:

Changes:
- Main/Deploy workflows: Removed 'develop' branch trigger (now only triggers on 'main')
- CI workflows: Changed from 'branches-ignore: [main, develop]' to 'branches: [feature/*]'
- Image metadata: Standardized naming conventions (if applicable)

These changes ensure that:
- Only merges to 'main' trigger deployments
- CI checks run on all feature branches
- Workflows align with GitHub Flow best practices

Related to: GitHub Flow migration initiative"

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
if [ "$FORCE_RECREATE" = true ]; then
    # Force push when recreating branch to overwrite remote
    git push --force origin "$BRANCH_NAME"
    echo "[OK] Feature branch force-pushed (recreated)"
else
    git push origin "$BRANCH_NAME"
    echo "[OK] Feature branch pushed"
fi
echo ""

# Step 8: Create pull request
if [ "$SKIP_PR" = false ]; then
    echo "=========================================="
    echo "Step 8: Creating Pull Request"
    echo "=========================================="
    echo ""
    
    # Set default PR title if not provided
    if [ -z "$PR_TITLE" ]; then
        PR_TITLE="chore: Migrate workflows from Git Flow to GitHub Flow"
    fi
    
    # Set default PR body if not provided
    if [ -z "$PR_BODY" ]; then
        PR_BODY="## Summary
This PR migrates GitHub Actions workflows from Git Flow to GitHub Flow branching strategy.

## Changes Made

### Main/Deploy Workflow Files
- **Removed** \`develop\` branch from trigger list
- **Result**: Deployments now only trigger on merges to \`main\`

### CI Workflow Files
- **Changed from**: \`branches-ignore: [main, develop]\`
- **Changed to**: \`branches: [feature/*]\`
- **Result**: CI checks now explicitly run on feature branches only

### Image Metadata (if applicable)
- Standardized naming conventions
- Removed \`ds-\` prefix for consistency with Quark pipelines

## Migration Context

This is part of the broader GitHub Flow migration initiative. These workflow changes ensure that:

1. [OK] Only \`main\` branch triggers deployments (not \`develop\`)
2. [OK] CI runs on all feature branches before merge
3. [OK] Workflows align with simplified GitHub Flow model
4. [OK] Naming conventions are consistent across the system

## Testing Checklist

Before merging this PR:

- [ ] Review all workflow file changes
- [ ] Verify no unintended modifications
- [ ] Confirm CI workflow triggers correctly on feature branches
- [ ] Ensure main workflow only triggers on \`main\` branch
- [ ] Check that backup files (*.backup) are not included in commit

## Post-Merge Actions

After merging this PR:

1. Monitor the first few CI runs on feature branches
2. Verify main workflow triggers correctly after next merge to main
3. Update team documentation if needed
4. Communicate changes to the development team

## Rollback Plan

If issues occur, rollback by:
1. Reverting this commit
2. Restoring previous workflow configurations from backups
3. Re-pushing to repository

## Related Documentation

- GitHub Flow Migration Guide
- CI/CD Release Process Documentation

---

**[OK] GitHub Flow Ready**: This PR targets \`main\` directly, following GitHub Flow best practices. Once merged, your workflows will be fully configured for GitHub Flow branching strategy.

---
*Generated by migrateWorkflowsToGitHubFlow.sh*"
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
            exit 1
        fi
    fi
    echo ""
fi

# Step 9: Complete
echo "=========================================="
echo "Migration Complete!"
echo "=========================================="
echo ""

echo "[OK] Workflow files updated for GitHub Flow"
echo "[OK] Changes committed to: $BRANCH_NAME"
echo "[OK] Branch pushed to remote"

if [ "$SKIP_PR" = false ]; then
    echo "[OK] Pull request created"
    echo ""
    echo "Next steps:"
    echo "  1. Review the pull request at: $PR_URL"
    echo "  2. Have the changes reviewed by your team"
    echo "  3. Merge the PR when ready (coordinate with Git Flow migration)"
    echo ""
    echo "[!]  Important: This PR should be merged to '$TARGET_BRANCH' BEFORE"
    echo "   completing the final Git Flow -> GitHub Flow migration."
else
    echo ""
    echo "Next steps:"
    echo "  1. Review the changes in branch: $BRANCH_NAME"
    echo "  2. Create a pull request manually when ready"
    echo "  3. Target branch: $TARGET_BRANCH"
fi

echo ""
echo "Backup files created (can be deleted after verification):"
find .github/workflows -name "*.backup" 2>/dev/null || echo "  (none)"
if [ -f "image-metadata-app.yml.backup" ]; then
    echo "  image-metadata-app.yml.backup"
fi

echo ""
echo "To view branch protection settings:"
if [ "$SKIP_PR" = false ]; then
    echo "  https://github.com/$REPO_FULL/settings/branches"
else
    echo "  Check your repository's GitHub settings"
fi
