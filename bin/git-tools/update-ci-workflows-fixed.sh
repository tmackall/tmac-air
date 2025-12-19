#!/bin/bash

# Fixed update-ci-branches function
# This standalone script can be used to update CI workflows

set -e

# Default options
DRY_RUN=false
FORCE=false
PATTERN="all-except-main"
BRANCH_NAME=""
CREATE_PR=false
PR_TITLE=""
PR_BODY=""
TARGET_BRANCH="main"
SKIP_FETCH=false
SKIP_BRANCH=false
AUTO_COMMIT=true
GIT_DIR="."

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
            echo "Usage: $0 [options]"
            echo "Updates CI workflows to trigger on all branches except main"
            echo ""
            echo "Options:"
            echo "  --create-pr    Create a pull request"
            echo "  --dry-run      Preview changes only"
            echo "  --force        Force operations"
            echo "  --help         Show this help"
            exit 0
            ;;
        *)
            GIT_DIR="$1"
            shift
            ;;
    esac
done

# Expand the path
GIT_DIR=$(eval echo "$GIT_DIR")
if [ "$GIT_DIR" != "." ]; then
    GIT_DIR=$(cd "$GIT_DIR" 2>/dev/null && pwd || echo "$GIT_DIR")
fi

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
REPO_NAME=$(basename "$PWD")

# Check for GitHub CLI if creating PR
if [ "$CREATE_PR" = true ]; then
    if ! command -v gh >/dev/null 2>&1; then
        echo "Error: GitHub CLI (gh) is not installed"
        echo "Please install it from: https://cli.github.com/"
        exit 1
    fi
    
    if ! gh auth status >/dev/null 2>&1; then
        echo "Error: GitHub CLI is not authenticated"
        echo "Please run: gh auth login"
        exit 1
    fi
    
    REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
fi

# Generate branch name if not provided
if [ -z "$BRANCH_NAME" ] && [ "$SKIP_BRANCH" = false ]; then
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BRANCH_NAME="chore/update-ci-all-branches-$TIMESTAMP"
fi

echo "=========================================="
echo "Update CI Workflow Branch Triggers"
echo "=========================================="
echo "Repository: $REPO_NAME"
if [ "$CREATE_PR" = true ]; then
    echo "GitHub: $REPO_FULL"
fi
echo "Pattern: $PATTERN"
if [ "$SKIP_BRANCH" = false ]; then
    echo "Branch: $BRANCH_NAME"
fi
if [ "$DRY_RUN" = true ]; then
    echo "Mode: DRY RUN"
fi
echo "=========================================="
echo ""

# Step 1: Clean working directory
if [ "$DRY_RUN" = false ] && [ "$SKIP_BRANCH" = false ]; then
    echo "Step 1: Cleaning working directory..."
    
    if ! git diff --quiet || ! git diff --cached --quiet; then
        if [ "$FORCE" = true ]; then
            echo "Stashing changes..."
            git stash push -m "update-ci-branches: auto-stash"
            echo "[OK] Changes stashed"
        else
            echo "Error: Uncommitted changes. Use --force to stash."
            exit 1
        fi
    else
        echo "[OK] Working directory clean"
    fi
    echo ""
fi

# Step 2: Fetch and sync
if [ "$SKIP_FETCH" = false ] && [ "$SKIP_BRANCH" = false ] && [ "$DRY_RUN" = false ]; then
    echo "Step 2: Syncing with remote..."
    
    git fetch origin
    
    if git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1; then
        git checkout "$TARGET_BRANCH"
        git pull origin "$TARGET_BRANCH"
    else
        git checkout -b "$TARGET_BRANCH" "origin/$TARGET_BRANCH"
    fi
    echo "[OK] Synced with remote"
    echo ""
fi

# Step 3: Create feature branch
if [ "$SKIP_BRANCH" = false ] && [ "$DRY_RUN" = false ]; then
    echo "Step 3: Creating feature branch..."
    
    if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
        if [ "$FORCE" = true ]; then
            git branch -D "$BRANCH_NAME"
            git checkout -b "$BRANCH_NAME"
        else
            echo "Error: Branch exists. Use --force to recreate."
            exit 1
        fi
    else
        git checkout -b "$BRANCH_NAME"
    fi
    echo "[OK] Created branch: $BRANCH_NAME"
    echo ""
fi

# Step 4: Update workflow files
echo "Step 4: Updating workflow files..."

WORKFLOWS_DIR=".github/workflows"
if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo "Error: No workflows directory found"
    exit 1
fi

# Find CI workflow files
CI_WORKFLOWS=$(find "$WORKFLOWS_DIR" -type f \( -name "*.yml" -o -name "*.yaml" \) | grep -E "(ci|CI)" || true)

if [ -z "$CI_WORKFLOWS" ]; then
    # Try finding any workflow with push triggers
    CI_WORKFLOWS=$(grep -l "push:" "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml 2>/dev/null || echo "")
fi

if [ -z "$CI_WORKFLOWS" ]; then
    echo "Error: No workflow files found"
    exit 1
fi

echo "Found workflows:"
echo "$CI_WORKFLOWS" | sed 's/^/  - /'
echo ""

# Update each workflow
for file in $CI_WORKFLOWS; do
    if [ ! -f "$file" ]; then
        continue
    fi
    
    echo "Processing: $file"
    
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would update to branches-ignore: [main]"
        continue
    fi
    
    # Create backup
    cp "$file" "${file}.backup"
    
    # Update the file using a more robust approach
    python3 << EOF
import sys
import re

file_path = "$file"

with open(file_path, 'r') as f:
    lines = f.readlines()

# Find and update the push trigger section
in_push_section = False
updated = False
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]
    
    # Check if we're entering a push section
    if re.match(r'^[\s\']*on[\'"]?:\s*$', line) or 'on:' in line:
        new_lines.append(line)
        i += 1
        # Look for push in next few lines
        while i < len(lines) and i < len(lines):
            line = lines[i]
            if 'push:' in line:
                new_lines.append(line)
                i += 1
                # Now handle the branches section
                indent = len(line) - len(line.lstrip())
                
                # Skip any existing branches or branches-ignore sections
                while i < len(lines):
                    if re.match(r'^\s*(branches|branches-ignore):', lines[i]):
                        # Found branches section, skip it and its contents
                        i += 1
                        while i < len(lines) and (lines[i].startswith(' ' * (indent + 2)) or lines[i].strip().startswith('-')):
                            i += 1
                        # Add our new branches-ignore
                        new_lines.append(' ' * (indent + 2) + 'branches-ignore:\n')
                        new_lines.append(' ' * (indent + 4) + '- main\n')
                        updated = True
                        break
                    elif not lines[i].startswith(' ' * (indent + 2)) and lines[i].strip() != '':
                        # End of push section without branches
                        new_lines.append(' ' * (indent + 2) + 'branches-ignore:\n')
                        new_lines.append(' ' * (indent + 4) + '- main\n')
                        updated = True
                        break
                    else:
                        new_lines.append(lines[i])
                        i += 1
            else:
                new_lines.append(line)
                i += 1
    else:
        new_lines.append(line)
        i += 1

# Write the updated content
with open(file_path, 'w') as f:
    f.writelines(new_lines)

print(f"  [OK] Updated to branches-ignore: [main]")
EOF
    
done
echo ""

# Check if changes were made
if [ "$DRY_RUN" = false ]; then
    if git diff --quiet; then
        echo "No changes detected - workflows may already be updated"
        if [ "$SKIP_BRANCH" = false ]; then
            git checkout "$TARGET_BRANCH"
            git branch -D "$BRANCH_NAME" 2>/dev/null || true
        fi
        exit 0
    fi
fi

# Step 5: Commit changes
if [ "$AUTO_COMMIT" = true ] && [ "$SKIP_BRANCH" = false ] && [ "$DRY_RUN" = false ]; then
    echo "Step 5: Committing changes..."
    
    # Add all modified workflow files
    for file in $CI_WORKFLOWS; do
        if [ -f "$file" ]; then
            git add "$file"
        fi
    done
    
    # Check files were staged
    if git diff --cached --quiet; then
        echo "Error: No files staged. Trying alternative..."
        git add -A "$WORKFLOWS_DIR"
    fi
    
    COMMIT_MESSAGE="chore: update CI workflows to trigger on all branches except main

Updates CI/CD workflows to run on any branch except main.

Changes:
- Modified push triggers from 'branches: [feature/*]' to 'branches-ignore: [main]'
- CI now runs on all branch patterns
- Aligns with GitHub Flow best practices"
    
    git commit -m "$COMMIT_MESSAGE" || {
        echo "Error: Failed to commit. Check git status"
        git status
        exit 1
    }
    echo "[OK] Changes committed"
    echo ""
    
    # Step 6: Push branch
    echo "Step 6: Pushing branch..."
    git push origin "$BRANCH_NAME"
    echo "[OK] Branch pushed"
    echo ""
fi

# Step 7: Create PR
if [ "$CREATE_PR" = true ] && [ "$SKIP_BRANCH" = false ] && [ "$DRY_RUN" = false ]; then
    echo "Step 7: Creating pull request..."
    
    if [ -z "$PR_TITLE" ]; then
        PR_TITLE="chore: Update CI to run on all branches except main"
    fi
    
    if [ -z "$PR_BODY" ]; then
        PR_BODY="## Summary
Updates CI workflows to trigger on all branches except main.

## Changes
- Modified push triggers to \`branches-ignore: [main]\`
- CI now runs on any branch pattern
- No more naming restrictions

## Benefits
✅ Any branch name works
✅ Better test coverage
✅ GitHub Flow aligned"
    fi
    
    if PR_URL=$(gh pr create --base "$TARGET_BRANCH" --head "$BRANCH_NAME" --title "$PR_TITLE" --body "$PR_BODY" 2>&1); then
        echo "[OK] Pull request created"
        echo "URL: $PR_URL"
    else
        echo "Error creating PR: $PR_URL"
        echo "Create manually with: gh pr create"
    fi
    echo ""
fi

echo "=========================================="
echo "Complete!"
echo "=========================================="

if [ "$DRY_RUN" = false ]; then
    echo "✅ CI workflows updated successfully"
    if [ "$CREATE_PR" = true ] && [ -n "$PR_URL" ]; then
        echo "✅ Pull request created: $PR_URL"
    fi
fi
