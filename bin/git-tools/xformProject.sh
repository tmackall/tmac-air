#!/bin/bash

# Wrapper script to process GitHub workflow files in a project directory
# Changes to <project>/.github/workflows, runs xformWorkflows.sh, then returns

set -e

# Function to show usage
show_usage() {
    echo "Usage: $0 [options] <project-directory>"
    echo ""
    echo "Options:"
    echo "  -s, --structure-only     Apply only structural changes"
    echo "  -p, --patterns-only      Apply only pattern transformations"
    echo "  --prefix PREFIX          Prefix for pattern transformation (default: qrk_data-science_dev_)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  BRANCH                   Create a new branch and commit changes to it"
    echo "                           (default: feature/gsm-migration)"
    echo ""
    echo "Examples:"
    echo "  $0 ~/projects/my-project                            # Uses default branch: feature/gsm-migration"
    echo "  BRANCH=custom-branch $0 ~/projects/my-project       # Uses custom branch name"
    echo "  BRANCH= $0 ~/projects/my-project                    # No branch, stay on develop"
    echo "  $0 -s ../another-project                            # Structure changes only"
    echo "  $0 --prefix custom_ /path/to/project                # Custom prefix"
    echo ""
    echo "This script will:"
    echo "  1. Reset git repo to tip of 'develop' branch (discards local changes)"
    echo "  2. Create new branch from BRANCH env var (if set)"
    echo "  3. Navigate to <project-directory>/.github/workflows"
    echo "  4. Run xformWorkflows.sh on all workflow files"
    echo "  5. Commit changes to the branch (if BRANCH env var is set)"
    echo "  6. Push branch to origin (if remote exists)"
    echo "  7. Create pull request via GitHub CLI (if 'gh' is installed)"
    echo "  8. Return to the starting directory"
    echo ""
    echo "WARNING: This will discard any uncommitted changes in the project!"
}

# Check if xformWorkflows.sh exists in the same directory as this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XFORM_SCRIPT="$SCRIPT_DIR/xformWorkflows.sh"

if [ ! -f "$XFORM_SCRIPT" ]; then
    echo "Error: xformWorkflows.sh not found in $SCRIPT_DIR"
    echo "Please ensure xformWorkflows.sh is in the same directory as this script."
    exit 1
fi

# Store the starting directory
START_DIR="$(pwd)"

# Set default branch name if BRANCH is not set (not just empty)
# To disable branching, explicitly set BRANCH="" in the environment
if [ -z "${BRANCH+x}" ]; then
    # BRANCH is unset, use default
    BRANCH="feature/gsm-migration"
fi
# If BRANCH is set but empty (BRANCH=""), it will remain empty

# Parse options
OPTIONS=()
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--structure-only)
            OPTIONS+=("$1")
            shift
            ;;
        -p|--patterns-only)
            OPTIONS+=("$1")
            shift
            ;;
        --prefix)
            OPTIONS+=("$1" "$2")
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            if [ -z "$PROJECT_DIR" ]; then
                PROJECT_DIR="$1"
            else
                echo "Error: Multiple project directories specified"
                echo "Usage: $0 [options] <project-directory>"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if project directory was provided
if [ -z "$PROJECT_DIR" ]; then
    echo "Error: No project directory specified"
    echo "Usage: $0 [options] <project-directory>"
    echo "Run '$0 --help' for more information."
    exit 1
fi

# Expand the path (handle ~, relative paths, etc.)
PROJECT_DIR=$(eval echo "$PROJECT_DIR")
PROJECT_DIR=$(cd "$PROJECT_DIR" 2>/dev/null && pwd || echo "$PROJECT_DIR")

# Check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Project directory '$PROJECT_DIR' not found"
    exit 1
fi

# Check if it's a git repository
if [ ! -d "$PROJECT_DIR/.git" ]; then
    echo "Error: '$PROJECT_DIR' is not a git repository"
    exit 1
fi

# Check if .github/workflows directory exists
WORKFLOWS_DIR="$PROJECT_DIR/.github/workflows"
if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo "Error: Workflows directory '$WORKFLOWS_DIR' not found"
    echo "Expected: $PROJECT_DIR/.github/workflows"
    exit 1
fi

# Ensure we return to starting directory even if script fails
trap "cd '$START_DIR'" EXIT

echo "=========================================="
echo "Processing workflows in: $PROJECT_DIR"
echo "=========================================="
echo ""

# Change to project directory for git operations
cd "$PROJECT_DIR"

echo "Resetting git repository to develop branch..."
echo ""

# Check if there are uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "Warning: Repository has uncommitted changes. They will be discarded."
fi

# Fetch latest changes from remote (if remote exists)
if git remote | grep -q "origin"; then
    echo "Fetching latest changes from remote..."
    if ! git fetch origin; then
        echo "Warning: Failed to fetch from remote, continuing anyway..."
    fi
else
    echo "No remote 'origin' configured, skipping fetch..."
fi

# Reset to clean state and checkout develop
echo "Cleaning working directory..."
git reset --hard HEAD
git clean -fd

echo "Checking out develop branch..."
if ! git checkout develop; then
    echo "Error: Failed to checkout develop branch"
    echo "Does the develop branch exist?"
    exit 1
fi

# Reset to origin/develop if it exists, otherwise just stay at current develop
if git rev-parse --verify origin/develop >/dev/null 2>&1; then
    echo "Resetting to origin/develop..."
    if ! git reset --hard origin/develop; then
        echo "Error: Failed to reset to origin/develop"
        exit 1
    fi
else
    echo "No origin/develop found, using local develop branch..."
fi

echo "✓ Repository reset to tip of develop branch"
echo ""

# Create new branch if BRANCH env var is set
if [ -n "$BRANCH" ]; then
    echo "Creating new branch: $BRANCH"
    
    # Check if branch already exists
    if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
        echo "Warning: Branch '$BRANCH' already exists locally"
        echo "Deleting existing branch and creating fresh..."
        git branch -D "$BRANCH"
    fi
    
    # Create and checkout new branch
    if ! git checkout -b "$BRANCH"; then
        echo "Error: Failed to create branch '$BRANCH'"
        exit 1
    fi
    
    echo "✓ Created and checked out branch: $BRANCH"
    echo ""
else
    echo "Note: No BRANCH env var set, staying on develop branch"
    echo ""
fi

# Change to workflows directory
cd "$WORKFLOWS_DIR"

# Count workflow files
WORKFLOW_COUNT=$(find . -maxdepth 1 -type f \( -name "*.yml" -o -name "*.yaml" \) | wc -l | tr -d ' ')

if [ "$WORKFLOW_COUNT" -eq 0 ]; then
    echo "No workflow files found in $WORKFLOWS_DIR"
    exit 0
fi

echo "Found $WORKFLOW_COUNT workflow file(s) in .github/workflows"
echo ""

# Run xformWorkflows.sh with the collected options
bash "$XFORM_SCRIPT" "${OPTIONS[@]}"

echo ""

# If BRANCH env var is set, commit the changes
if [ -n "$BRANCH" ]; then
    echo "=========================================="
    echo "Committing changes to branch: $BRANCH"
    echo "=========================================="
    echo ""
    
    # Go back to project root for git operations
    cd "$PROJECT_DIR"
    
    # Check if there are any changes to commit
    if git diff --quiet && git diff --cached --quiet; then
        echo "No changes to commit (workflows may have already been transformed)"
    else
        # Stage all changes in .github/workflows
        echo "Staging changes in .github/workflows/..."
        git add .github/workflows/
        
        # Show what will be committed
        echo ""
        echo "Changes to be committed:"
        git diff --cached --stat
        echo ""
        
        # Commit the changes
        COMMIT_MESSAGE="chore: Transform workflows from Airlock to GSM

- Add workload identity permissions
- Replace NAMESPACE_AIRLOCK_HASH with NAMESPACE_GSM_SVC_EMAIL
- Change NAMESPACE_AIRLOCK_NAME from 'dev' to 'gsm'
- Add wif-gsm-auth authentication step
- Transform secrets.dev:: patterns to secrets.gsm::

Automated transformation by xformProject.sh"
        
        if git commit -m "$COMMIT_MESSAGE"; then
            echo "✓ Changes committed successfully"
            echo ""
            echo "Branch: $BRANCH"
            echo "Commit: $(git rev-parse --short HEAD)"
            echo ""
            
            # Push to origin if remote exists
            if git remote | grep -q "origin"; then
                echo "Pushing branch to origin..."
                # Use --force since we may have deleted and recreated the branch
                if git push -u origin "$BRANCH" --force 2>&1; then
                    echo "✓ Branch pushed to origin/$BRANCH"
                    echo ""
                    
                    # Try to create a PR using GitHub CLI if available
                    if command -v gh >/dev/null 2>&1; then
                        echo "Creating pull request..."
                        
                        PR_TITLE="chore: Transform workflows from Airlock to GSM"
                        PR_BODY="## Summary
This PR automates the migration of GitHub Actions workflows from Airlock-based secrets to Google Secret Manager (GSM).

## Changes Made
- ✅ Add workload identity permissions (\`contents: read\`, \`id-token: write\`)
- ✅ Replace \`NAMESPACE_AIRLOCK_HASH\` with \`NAMESPACE_GSM_SVC_EMAIL\`
- ✅ Change \`NAMESPACE_AIRLOCK_NAME\` from 'dev' to 'gsm'
- ✅ Add \`wif-gsm-auth\` authentication step
- ✅ Transform \`secrets.dev::\` patterns to \`secrets.gsm::\`

## Testing
- [ ] Verify workflow syntax is valid
- [ ] Test workflows in a non-production environment
- [ ] Confirm secret references are correct

---
*Automated by xformProject.sh*"
                        
                        if gh pr create --base develop --head "$BRANCH" --title "$PR_TITLE" --body "$PR_BODY" 2>&1; then
                            echo "✓ Pull request created successfully"
                            echo ""
                            # Get the PR URL
                            PR_URL=$(gh pr view "$BRANCH" --json url -q .url 2>/dev/null)
                            if [ -n "$PR_URL" ]; then
                                echo "PR URL: $PR_URL"
                            fi
                        else
                            echo "Warning: Failed to create pull request via GitHub CLI"
                            echo "You can create it manually at your repository's GitHub page"
                        fi
                    else
                        echo "GitHub CLI (gh) not found. To create a PR automatically, install it from:"
                        echo "  https://cli.github.com/"
                        echo ""
                        echo "Or create PR manually at your repository's GitHub page"
                    fi
                else
                    echo "Warning: Failed to push branch to origin"
                    echo "You may need to push manually:"
                    echo "  cd $PROJECT_DIR"
                    echo "  git push -u origin $BRANCH"
                fi
            else
                echo "No remote 'origin' configured."
                echo "To push this branch:"
                echo "  cd $PROJECT_DIR"
                echo "  git remote add origin <repository-url>"
                echo "  git push -u origin $BRANCH"
            fi
        else
            echo "Error: Failed to commit changes"
            exit 1
        fi
    fi
else
    echo "Note: No BRANCH env var set, changes not committed"
fi

echo ""
echo "=========================================="
echo "Completed processing workflows"
echo "Returning to: $START_DIR"
echo "=========================================="
