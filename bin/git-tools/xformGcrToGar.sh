#!/bin/bash

# Script to transform GitHub Actions workflows from any docker publishing to GAR publishing
# - Takes a Git repo directory as input
# - Cleans/fetches and creates a new branch
# - Modifies workflows that publish docker images (and aren't already using GAR)
# - Transforms according to the GCR -> GAR migration pattern

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
BRANCH_NAME="feature/gcr-to-gar-migration"
SOURCE_BRANCH="main"
DRY_RUN=false
CREATE_PR=true

# Function to show usage
show_usage() {
    echo "Usage: $0 [options] <repo-directory>"
    echo ""
    echo "Options:"
    echo "  -b, --branch NAME        Branch name to create (default: feature/gcr-to-gar-migration)"
    echo "  -s, --source-branch NAME Source branch to create from (default: main)"
    echo "  -d, --dry-run            Show what would be changed without making changes"
    echo "  --no-pr                  Skip PR creation (just leave changes uncommitted)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Description:"
    echo "  This script transforms GitHub Actions workflows to use GAR for docker publishing."
    echo "  It will:"
    echo "    1. Fetch the repository and checkout the source branch (default: main)"
    echo "    2. Create a new branch from the source branch"
    echo "    3. Find workflows with docker publishing (that aren't already using GAR)"
    echo "    4. Transform them to use GAR instead"
    echo "    5. Commit, push, and create a PR (unless --no-pr is specified)"
    echo ""
    echo "  If no workflows need transformation, no changes are made."
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/repo"
    echo "  $0 -b my-branch /path/to/repo"
    echo "  $0 -s develop /path/to/repo      # Use develop as source branch"
    echo "  $0 --no-pr /path/to/repo         # Make changes but don't create PR"
    echo "  $0 --dry-run /path/to/repo"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
REPO_DIR=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--branch)
            BRANCH_NAME="$2"
            shift 2
            ;;
        -s|--source-branch)
            SOURCE_BRANCH="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-pr)
            CREATE_PR=false
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$REPO_DIR" ]; then
                REPO_DIR="$1"
            else
                log_error "Too many arguments"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate repo directory
if [ -z "$REPO_DIR" ]; then
    log_error "Repository directory is required"
    show_usage
    exit 1
fi

if [ ! -d "$REPO_DIR" ]; then
    log_error "Directory does not exist: $REPO_DIR"
    exit 1
fi

if [ ! -d "$REPO_DIR/.git" ]; then
    log_error "Not a Git repository: $REPO_DIR"
    exit 1
fi

# Change to repo directory
cd "$REPO_DIR"
log_info "Working in repository: $(pwd)"

# Check for uncommitted changes BEFORE doing anything
if ! git diff --quiet || ! git diff --cached --quiet; then
    log_error "Repository has uncommitted changes. Please commit or stash them first."
    log_error "Run 'git status' to see the changes."
    exit 1
fi

# Check for untracked files in workflows directory
if [ -d ".github/workflows" ]; then
    UNTRACKED=$(git ls-files --others --exclude-standard .github/workflows 2>/dev/null)
    if [ -n "$UNTRACKED" ]; then
        log_warn "Untracked files in workflows directory:"
        echo "$UNTRACKED"
        log_error "Please remove or commit these files first."
        exit 1
    fi
fi

# Check for workflows directory
WORKFLOWS_DIR=".github/workflows"
if [ ! -d "$WORKFLOWS_DIR" ]; then
    log_warn "No workflows directory found at $WORKFLOWS_DIR"
    log_info "No changes needed - exiting"
    exit 0
fi

# Find workflows with docker publishing that's not already GAR
log_info "Searching for workflows with docker publishing (not already GAR)..."
QUALIFYING_FILES=()
for file in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
    if [ -f "$file" ]; then
        # Check if file has docker-image deployment
        if grep -q "fnd tanagra:deploy:docker-image" "$file" 2>/dev/null; then
            # Check if it's NOT already using GAR (no common-gar-auth step)
            if ! grep -q "name: common-gar-auth" "$file" 2>/dev/null; then
                QUALIFYING_FILES+=("$file")
                log_info "  Found: $file"
            else
                log_info "  Skipping (already GAR): $file"
            fi
        fi
    fi
done

if [ ${#QUALIFYING_FILES[@]} -eq 0 ]; then
    log_info "No workflows found with non-GAR docker publishing"
    log_info "No changes needed - exiting"
    exit 0
fi

log_info "Found ${#QUALIFYING_FILES[@]} workflow(s) to transform"

if [ "$DRY_RUN" = true ]; then
    log_warn "DRY RUN MODE - No changes will be made"
    echo ""
    echo "Would transform the following files:"
    for file in "${QUALIFYING_FILES[@]}"; do
        echo "  - $file"
    done
    exit 0
fi

# Fetch latest from remote (but don't modify working directory yet)
log_info "Fetching latest changes..."
git fetch --all --prune

# Verify source branch exists
if ! git show-ref --verify --quiet "refs/remotes/origin/$SOURCE_BRANCH"; then
    log_error "Source branch 'origin/$SOURCE_BRANCH' does not exist"
    log_error "Available remote branches:"
    git branch -r | head -10
    exit 1
fi
log_info "Source branch: $SOURCE_BRANCH"

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$SOURCE_BRANCH" ]; then
    log_info "Switching to $SOURCE_BRANCH..."
    git checkout "$SOURCE_BRANCH"
fi

# Pull latest
log_info "Pulling latest from $SOURCE_BRANCH..."
git pull origin "$SOURCE_BRANCH"

# Verify we're in sync with remote
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse "origin/$SOURCE_BRANCH")
if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
    log_error "Local $SOURCE_BRANCH is not in sync with remote. Please resolve manually."
    exit 1
fi
log_info "Verified: local is in sync with origin/$SOURCE_BRANCH"

# Create new branch
log_info "Creating branch: $BRANCH_NAME"
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    log_warn "Branch '$BRANCH_NAME' already exists locally, deleting it..."
    git branch -D "$BRANCH_NAME"
fi
git checkout -b "$BRANCH_NAME"

# Function to transform a single workflow file
transform_workflow() {
    local file="$1"
    local temp_file=$(mktemp)
    local temp_file2=$(mktemp)
    
    log_info "Transforming: $file"
    
    cp "$file" "$temp_file"
    
    # Step 1: Add IMAGE_REGISTRY_HOSTNAME and IMAGE_BASE_PATH env variables
    # Find the env section under jobs and add the new variables if not present
    if ! grep -q "IMAGE_REGISTRY_HOSTNAME:" "$temp_file"; then
        # Use perl for complex multi-line transformations
        perl -i -0pe '
            # Find NAMESPACE_AIRLOCK_NAME line and add new env vars after it
            s/(NAMESPACE_AIRLOCK_NAME:\s*\S+\n)/$1      IMAGE_REGISTRY_HOSTNAME: us-docker.pkg.dev\n      IMAGE_BASE_PATH: '\''d-ulti-cs-gar-27fb\/data-science\/images'\''\n/g;
        ' "$temp_file"
        log_info "  ✓ Added IMAGE_REGISTRY_HOSTNAME and IMAGE_BASE_PATH env variables"
    else
        log_info "  - IMAGE_REGISTRY_HOSTNAME already exists, skipping"
    fi
    
    # Step 2: Replace docker publish step with common-gar-auth + publish-docker-image-to-gar
    # This matches any step name that publishes docker images (not just publish-docker-image-to-gcr)
    if grep -q "fnd tanagra:deploy:docker-image" "$temp_file" && ! grep -q "name: common-gar-auth" "$temp_file"; then
        # Use Python for more reliable YAML-aware transformation
        python3 - "$temp_file" "$temp_file2" << 'PYTHON_EOF'
import sys
import re

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'r') as f:
    content = f.read()

# Pattern to match any docker publish step (flexible step name)
# Matches: publish-docker-image-to-gcr, publish-docker-image, publish-docker, etc.
pattern = r'''(\n)([ \t]+)(- name: [^\n]*(?:publish[^\n]*docker|docker[^\n]*publish|deploy[^\n]*docker|docker[^\n]*image)[^\n]*\n)([ \t]+run: \|-\n)([ \t]+fnd tanagra:deploy:docker-image \\\n)([ \t]+--docker_host=\S+ \\\n)([ \t]+--registry_hostname=\S+ \\\n)([ \t]+--registry_project_root=\S+ \\\n)([ \t]+--registry_username=\S+ \\\n)([ \t]+--registry_password=\S+)'''

def replace_step(match):
    newline = match.group(1)
    indent = match.group(2)
    sub_indent = indent + "  "
    run_indent = indent + "    "
    
    lines = [
        newline + indent + "- name: common-gar-auth",
        sub_indent + "uses: UKGEPIC/sl-actions/gcp-util/svc-wif-gar@v0+svc-wif-gar",
        sub_indent + "id: gar-auth",
        indent + "- name: publish-docker-image-to-gar",
        sub_indent + "id: publish-docker-image",
        sub_indent + "run: |-",
        run_indent + "fnd tanagra:deploy:docker-image \\",
        run_indent + "  --docker_host=unix:///var/run/docker.sock \\",
        run_indent + "  --registry_hostname=$IMAGE_REGISTRY_HOSTNAME \\",
        run_indent + "  --registry_project_root=$IMAGE_BASE_PATH \\",
        run_indent + "  --registry_username=oauth2accesstoken \\",
        run_indent + "  --registry_password='${{ steps.gar-auth.outputs.access_token }}' \\",
        run_indent + "  --wiz_container_policy_name='' \\",
        run_indent + "  --environment_json='{}'",
    ]
    return "\n".join(lines)

result = re.sub(pattern, replace_step, content, flags=re.MULTILINE | re.IGNORECASE)

with open(output_file, 'w') as f:
    f.write(result)

sys.exit(0 if 'common-gar-auth' in result else 1)
PYTHON_EOF
        
        # Check if the transformation worked
        if [ $? -eq 0 ] && grep -q "name: common-gar-auth" "$temp_file2"; then
            mv "$temp_file2" "$temp_file"
            log_info "  ✓ Replaced docker publish step with GAR steps"
        else
            rm -f "$temp_file2"
            log_warn "  ! Pattern not matched - file may have different format"
            log_warn "  ! Please check the file manually"
        fi
    fi
    
    # Move transformed file back
    mv "$temp_file" "$file"
}

# Transform all qualifying files
echo ""
log_info "Starting transformation..."
echo ""

for file in "${QUALIFYING_FILES[@]}"; do
    transform_workflow "$file"
    echo ""
done

# Show summary of changes
log_info "Transformation complete!"
echo ""
echo "Summary of changes:"
git status --short "$WORKFLOWS_DIR"
echo ""

# Verify changes are only what we expect
log_info "Verifying changes..."
UNEXPECTED_CHANGES=false

# Check that we only see the expected patterns in the diff
DIFF_OUTPUT=$(git diff "$WORKFLOWS_DIR")

# Look for unexpected changes (things we should NOT be changing)
if echo "$DIFF_OUTPUT" | grep -q "secrets\.dev::"; then
    log_error "UNEXPECTED: Found 'secrets.dev::' in diff - this script should not add these"
    UNEXPECTED_CHANGES=true
fi

if echo "$DIFF_OUTPUT" | grep -qE "^\-.*NAMESPACE_GSM_SVC_EMAIL"; then
    log_error "UNEXPECTED: Removing NAMESPACE_GSM_SVC_EMAIL - this script should not do this"
    UNEXPECTED_CHANGES=true
fi

if echo "$DIFF_OUTPUT" | grep -qE "^\+.*NAMESPACE_AIRLOCK_HASH"; then
    log_error "UNEXPECTED: Adding NAMESPACE_AIRLOCK_HASH - this script should not do this"
    UNEXPECTED_CHANGES=true
fi

# Verify expected changes ARE present
if ! echo "$DIFF_OUTPUT" | grep -q "common-gar-auth"; then
    log_warn "Expected 'common-gar-auth' step not found in diff"
fi

if ! echo "$DIFF_OUTPUT" | grep -q "publish-docker-image-to-gar"; then
    log_warn "Expected 'publish-docker-image-to-gar' step not found in diff"
fi

if ! echo "$DIFF_OUTPUT" | grep -q "IMAGE_REGISTRY_HOSTNAME"; then
    log_warn "Expected 'IMAGE_REGISTRY_HOSTNAME' env var not found in diff"
fi

# Check that old docker publish steps were removed
if echo "$DIFF_OUTPUT" | grep -qE "^\+.*registry_password=secrets\.(gsm|dev)::"; then
    log_error "UNEXPECTED: Still adding old-style registry_password with secrets"
    UNEXPECTED_CHANGES=true
fi

if [ "$UNEXPECTED_CHANGES" = true ]; then
    log_error ""
    log_error "UNEXPECTED CHANGES DETECTED!"
    log_error "The diff contains changes this script should not make."
    log_error "Please review carefully before committing."
    log_error ""
    log_error "This script should ONLY:"
    log_error "  1. Add IMAGE_REGISTRY_HOSTNAME and IMAGE_BASE_PATH env vars"
    log_error "  2. Add common-gar-auth step"
    log_error "  3. Replace publish-docker-image-to-gcr with publish-docker-image-to-gar"
    echo ""
fi

# Show diff
log_info "Changes made:"
git diff "$WORKFLOWS_DIR"

echo ""

# If there were unexpected changes, don't proceed with PR
if [ "$UNEXPECTED_CHANGES" = true ]; then
    log_error "Aborting due to unexpected changes. Please review and fix manually."
    exit 1
fi

# Check if there are actually any changes to commit
if git diff --quiet "$WORKFLOWS_DIR"; then
    log_warn "No changes detected in workflow files."
    log_info "Nothing to commit or push."
    exit 0
fi

# Create PR if requested
if [ "$CREATE_PR" = true ]; then
    # Check if gh CLI is available
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed. Cannot create PR."
        log_info "Install it from: https://cli.github.com/"
        log_info ""
        log_info "Manual steps:"
        echo "  1. Stage the changes: git add $WORKFLOWS_DIR"
        echo "  2. Commit: git commit -m 'Migrate docker publishing from GCR to GAR'"
        echo "  3. Push: git push origin $BRANCH_NAME"
        echo "  4. Create PR manually on GitHub"
        exit 1
    fi
    
    # Check if gh is authenticated
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated. Run 'gh auth login' first."
        exit 1
    fi
    
    # Stage and commit changes
    log_info "Staging changes..."
    git add "$WORKFLOWS_DIR"
    
    # Get list of modified files for commit message
    MODIFIED_FILES=$(git diff --cached --name-only | tr '\n' ', ' | sed 's/,$//')
    
    log_info "Committing changes..."
    git commit -m "Migrate docker publishing from GCR to GAR" -m "Updated workflows: $MODIFIED_FILES" -m "Changes:
- Added IMAGE_REGISTRY_HOSTNAME and IMAGE_BASE_PATH env variables
- Added common-gar-auth step for Workload Identity Federation
- Replaced publish-docker-image-to-gcr with publish-docker-image-to-gar
- Updated registry parameters to use GAR"
    
    # Push branch
    log_info "Pushing branch to origin..."
    git push -u origin "$BRANCH_NAME"
    
    # Create PR
    log_info "Creating pull request..."
    PR_TITLE="Migrate docker publishing from GCR to GAR"
    PR_BODY="## Summary
This PR migrates the Docker image publishing from Google Container Registry (GCR) to Google Artifact Registry (GAR).

## Changes
- Added \`IMAGE_REGISTRY_HOSTNAME\` and \`IMAGE_BASE_PATH\` environment variables
- Added \`common-gar-auth\` step using Workload Identity Federation
- Replaced \`publish-docker-image-to-gcr\` step with \`publish-docker-image-to-gar\`
- Updated registry parameters to use the new env vars and WIF auth token

## Modified Files
$MODIFIED_FILES

## Testing
- [ ] Workflow runs successfully
- [ ] Docker image is published to GAR
"
    
    PR_URL=$(gh pr create \
        --base "$SOURCE_BRANCH" \
        --head "$BRANCH_NAME" \
        --title "$PR_TITLE" \
        --body "$PR_BODY" \
        2>&1)
    
    if [ $? -eq 0 ]; then
        log_info "Pull request created successfully!"
        echo ""
        echo "  $PR_URL"
        echo ""
    else
        log_error "Failed to create pull request:"
        echo "$PR_URL"
        exit 1
    fi
else
    log_info "Skipping PR creation (--no-pr specified)"
    echo ""
    log_info "Next steps:"
    echo "  1. Review the changes: git diff"
    echo "  2. Stage the changes: git add $WORKFLOWS_DIR"
    echo "  3. Commit: git commit -m 'Migrate docker publishing from GCR to GAR'"
    echo "  4. Push: git push origin $BRANCH_NAME"
    echo "  5. Create PR manually on GitHub"
fi
