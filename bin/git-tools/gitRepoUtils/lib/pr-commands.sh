#!/bin/bash

# pr-commands.sh - Pull Request management commands for gitRepoUtils
# Commands: list-prs, my-prs, approve-pr, merge-pr, enable-auto-merge

# This file is sourced by the main gitRepoUtils.sh script

show_approve_pr_usage() {
    echo "Usage: $0 approve-pr [options] <git-directory>"
    echo ""
    echo "Approve a pull request on GitHub. Can approve the current branch's PR,"
    echo "a specific PR by number, or interactively select from open PRs."
    echo ""
    echo "Options:"
    echo "  --pr NUMBER              PR number to approve (default: current branch's PR)"
    echo "  --comment TEXT           Add a comment with the approval"
    echo "  --merge                  Also merge the PR after approval (requires merge permissions)"
    echo "  --merge-method METHOD    Merge method: merge, squash, or rebase (default: squash)"
    echo "  --delete-branch          Delete the branch after merge (use with --merge)"
    echo "  --list                   List all open PRs instead of approving"
    echo "  --interactive            Interactively select a PR to approve from list"
    echo "  --review-state STATE     Set review state: APPROVE, COMMENT, or REQUEST_CHANGES"
    echo "                          (default: APPROVE)"
    echo "  --body TEXT              Review body/comment (alternative to --comment)"
    echo "  --force                  Skip confirmation prompts"
    echo "  --check                  Check approval status of PR without approving"
    echo "  --bypass-restrictions    Bypass branch protection rules (admin only, use with --merge)"
    echo "  --enable-auto-merge      Enable auto-merge after approval (PR merges when requirements met)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Approve the PR for current branch"
    echo "  $0 approve-pr ~/projects/my-project"
    echo ""
    echo "  # Approve specific PR with comment"
    echo "  $0 approve-pr --pr 123 --comment 'LGTM!' ~/projects/my-project"
    echo ""
    echo "  # Approve and merge PR"
    echo "  $0 approve-pr --pr 123 --merge ~/projects/my-project"
    echo ""
    echo "  # Approve and enable auto-merge"
    echo "  $0 approve-pr --pr 123 --enable-auto-merge ~/projects/my-project"
    echo ""
    echo "  # List all open PRs"
    echo "  $0 approve-pr --list ~/projects/my-project"
    echo ""
    echo "  # Interactive PR selection"
    echo "  $0 approve-pr --interactive ~/projects/my-project"
    echo ""
    echo "  # Check approval status of PR #123"
    echo "  $0 approve-pr --pr 123 --check ~/projects/my-project"
    echo ""
    echo "  # Approve and squash merge with branch deletion"
    echo "  $0 approve-pr --pr 123 --merge --merge-method squash --delete-branch ~/projects/my-project"
    echo ""
    echo "  # Request changes on a PR"
    echo "  $0 approve-pr --pr 123 --review-state REQUEST_CHANGES --comment 'Please fix the tests' ~/projects/my-project"
    echo ""
    echo "Requirements:"
    echo "  - GitHub CLI (gh) must be installed and authenticated"
    echo "  - Write permissions on the repository (for approval)"
    echo "  - Merge permissions (for --merge option)"
    echo ""
    echo "Review States:"
    echo "  APPROVE          - Approve the PR (allows merging if requirements met)"
    echo "  COMMENT          - Add a comment without approval"
    echo "  REQUEST_CHANGES  - Request changes (blocks merging)"
    echo ""
    echo "Merge Methods:"
    echo "  merge   - Create a merge commit"
    echo "  squash  - Squash and merge (default, creates single commit)"
    echo "  rebase  - Rebase and merge (rewrites history)"
    echo ""
}

# Function to show usage for merge-pr command
show_merge_pr_usage() {
    echo "Usage: $0 merge-pr [options] <git-directory>"
    echo ""
    echo "Merge a pull request with various merge strategies and options."
    echo ""
    echo "Options:"
    echo "  --pr NUMBER              PR number to merge (required unless current branch)"
    echo "  --merge-method METHOD    Merge method: merge, squash, or rebase (default: squash)"
    echo "  --delete-branch          Delete the branch after merge (default: true)"
    echo "  --no-delete-branch       Keep the branch after merge"
    echo "  --title TEXT             Custom merge commit title (for squash/merge)"
    echo "  --body TEXT              Custom merge commit body"
    echo "  --admin                  Use admin privileges to bypass branch protection"
    echo "  --auto                   Enable auto-merge instead of immediate merge"
    echo "  --approve-first          Approve the PR before merging"
    echo "  --comment TEXT           Comment to add when approving (with --approve-first)"
    echo "  --check                  Check if PR is ready to merge without merging"
    echo "  --force                  Skip confirmation prompts"
    echo "  --wait-for-checks        Wait for status checks to complete before merging"
    echo "  --timeout SECONDS        Timeout for waiting (default: 600 seconds)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Simple merge with default settings (squash)"
    echo "  $0 merge-pr --pr 123 ~/projects/my-project"
    echo ""
    echo "  # Merge with specific method"
    echo "  $0 merge-pr --pr 123 --merge-method merge ~/projects/my-project"
    echo ""
    echo "  # Approve and merge in one command"
    echo "  $0 merge-pr --pr 123 --approve-first ~/projects/my-project"
    echo ""
    echo "  # Wait for checks then merge"
    echo "  $0 merge-pr --pr 123 --wait-for-checks ~/projects/my-project"
    echo ""
    echo "  # Check if ready to merge"
    echo "  $0 merge-pr --pr 123 --check ~/projects/my-project"
    echo ""
    echo "  # Admin bypass protection"
    echo "  $0 merge-pr --pr 123 --admin ~/projects/my-project"
    echo ""
    echo "  # Custom commit message for squash"
    echo "  $0 merge-pr --pr 123 --title 'feat: Add new feature' --body 'Detailed description' ~/projects/my-project"
    echo ""
    echo "  # Enable auto-merge instead of immediate merge"
    echo "  $0 merge-pr --pr 123 --auto ~/projects/my-project"
    echo ""
    echo "Requirements:"
    echo "  - GitHub CLI (gh) must be installed and authenticated"
    echo "  - Merge permissions on the repository"
    echo "  - PR must be approved (unless using --admin)"
    echo "  - All required status checks must pass (unless using --admin)"
    echo ""
    echo "Merge Methods:"
    echo "  merge   - Create a merge commit (preserves all commits)"
    echo "  squash  - Squash all commits into one (default, clean history)"
    echo "  rebase  - Rebase and merge (linear history)"
    echo ""
}

# Function to show usage for list-prs command
show_list_prs_usage() {
    echo "Usage: $0 list-prs [options] <git-directory>"
    echo ""
    echo "List pull requests with various filtering options."
    echo "Especially useful for finding PRs that need review or approval."
    echo ""
    echo "Options:"
    echo "  --state STATE            Filter by state: open, closed, merged, all (default: open)"
    echo "  --unapproved             Show only PRs without approvals (pending review)"
    echo "  --approved               Show only approved PRs"
    echo "  --changes-requested      Show only PRs with changes requested"
    echo "  --draft                  Show only draft PRs"
    echo "  --ready                  Show only non-draft PRs (ready for review)"
    echo "  --author USER            Filter by PR author (e.g., @username)"
    echo "  --assignee USER          Filter by assignee"
    echo "  --label LABEL            Filter by label"
    echo "  --base BRANCH            Filter by base branch (default: all)"
    echo "  --head BRANCH            Filter by head branch"
    echo "  --needs-my-review        Show PRs that need review from current user"
    echo "  --reviewed-by-me         Show PRs already reviewed by current user"
    echo "  --mine                   Show only PRs authored by current user"
    echo "  --sort FIELD             Sort by: created, updated, popularity, reactions (default: updated)"
    echo "  --limit NUMBER           Maximum number of PRs to show (default: 30)"
    echo "  --format FORMAT          Output format: table, simple, detailed, json, csv (default: table)"
    echo "  --no-checks              Skip status check information (faster)"
    echo "  --show-reviews           Include detailed review information"
    echo "  --show-files             Show changed files count"
    echo "  --urls                   Show PR URLs in output"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  # List all unapproved PRs"
    echo "  $0 list-prs --unapproved ~/projects/my-project"
    echo ""
    echo "  # List PRs needing your review"
    echo "  $0 list-prs --needs-my-review ~/projects/my-project"
    echo ""
    echo "  # List approved PRs ready to merge"
    echo "  $0 list-prs --approved --ready ~/projects/my-project"
    echo ""
    echo "  # List draft PRs by a specific author"
    echo "  $0 list-prs --draft --author @alice ~/projects/my-project"
    echo ""
    echo "  # List PRs with changes requested"
    echo "  $0 list-prs --changes-requested ~/projects/my-project"
    echo ""
    echo "  # List all closed PRs in CSV format"
    echo "  $0 list-prs --state closed --format csv ~/projects/my-project"
    echo ""
    echo "  # List PRs targeting main branch that are unapproved"
    echo "  $0 list-prs --base main --unapproved ~/projects/my-project"
    echo ""
    echo "  # Show detailed review information for open PRs"
    echo "  $0 list-prs --show-reviews --format detailed ~/projects/my-project"
    echo ""
    echo "Output Formats:"
    echo "  table    - Formatted table with key information (default)"
    echo "  simple   - Basic list with PR number and title"
    echo "  detailed - Full details including body and reviews"
    echo "  json     - Machine-readable JSON output"
    echo "  csv      - CSV format for spreadsheet import"
    echo ""
    echo "Review States:"
    echo "  PENDING           - No reviews yet (unapproved)"
    echo "  APPROVED          - Has approval(s)"
    echo "  CHANGES_REQUESTED - Changes requested by reviewer(s)"
    echo "  CONFLICTING       - Mixed reviews (some approved, some requested changes)"
    echo ""
}

# Function to show usage for my-prs command
show_my_prs_usage() {
    echo "Usage: $0 my-prs [git-directory] [options]"
    echo ""
    echo "List your pull requests with flexible date filtering."
    echo "Defaults to showing PRs updated in the last day."
    echo ""
    echo "Arguments:"
    echo "  git-directory           Path to git repository (default: current directory)"
    echo ""
    echo "Date Options (mutually exclusive with each other):"
    echo "  --days N                Number of days to look back (default: 1 day if no date specified)"
    echo "  --yesterday             Show yesterday's PRs specifically"
    echo "  --start-date YYYY-MM-DD Start date for PR search"
    echo "  --end-date YYYY-MM-DD   End date for PR search (default: today)"
    echo "  --created-only          Filter by PR creation date instead of last updated"
    echo ""
    echo "  Note: By default, searches for PRs UPDATED in the date range (includes created,"
    echo "        merged, commented). Use --created-only to only find PRs CREATED in the range."
    echo ""
    echo "Display Options:"
    echo "  --no-summary            Don't show summary at the end"
    echo "  --with-urls             Include PR URLs in output"
    echo "  --compact               Compact one-line format"
    echo "  --verbose               Detailed format with extra information"
    echo "  --no-color              Disable colored output"
    echo "  --debug                 Show debug information (search queries, etc.)"
    echo ""
    echo "Filter Options:"
    echo "  --author USER           PR author (default: @me)"
    echo "  --state STATE           PR state: all, open, closed, merged (default: all)"
    echo "  --limit N               Maximum number of PRs to fetch (default: 100)"
    echo ""
    echo "Directory Options:"
    echo "  --recursive             Search for git repos recursively in directory"
    echo "  --pattern PATTERN       Filter repos by name pattern (e.g., 'ds-service-*')"
    echo ""
    echo "Examples:"
    echo "  # Today's PRs in current repo"
    echo "  $0 my-prs"
    echo ""
    echo "  # Today's PRs in specific repo"
    echo "  $0 my-prs ~/projects/myrepo"
    echo ""
    echo "  # Yesterday's PRs in specific repo"
    echo "  $0 my-prs ~/projects/myrepo --yesterday"
    echo ""
    echo "  # Last 7 days in specific repo"
    echo "  $0 my-prs ~/projects/myrepo --days 7"
    echo ""
    echo "  # PRs from Jan 1 to today"
    echo "  $0 my-prs . --start-date 2024-01-01"
    echo ""
    echo "  # January 2024 PRs (specific range)"
    echo "  $0 my-prs . --start-date 2024-01-01 --end-date 2024-01-31"
    echo ""
    echo "  # Today's PRs in all repos under ~/work"
    echo "  $0 my-prs ~/work --recursive"
    echo ""
    echo "  # Pattern match repos recursively"
    echo "  $0 my-prs ~/work --recursive --pattern 'ds-*'"
    echo ""
    echo "  # Open PRs from last 30 days"
    echo "  $0 my-prs ~/projects/myrepo --days 30 --state open"
    echo ""
    echo "  # Debug yesterday's search query"
    echo "  $0 my-prs . --debug --yesterday"
    echo ""
    echo "Requirements:"
    echo "  - GitHub CLI (gh) must be installed and authenticated"
    echo "  - Git repository must have a GitHub remote configured"
    echo ""
}

# Function to show usage for enable-auto-merge command
show_enable_auto_merge_usage() {
    echo "Usage: $0 enable-auto-merge [options] <git-directory>"
    echo ""
    echo "Enable auto-merge on a pull request. The PR will automatically merge"
    echo "when all branch protection requirements are met (checks, approvals, etc.)."
    echo ""
    echo "Options:"
    echo "  --pr NUMBER              PR number to enable auto-merge on (required unless current branch)"
    echo "  --merge-method METHOD    Merge method: merge, squash, or rebase (default: squash)"
    echo "  --delete-branch          Delete the branch after merge (default: true)"
    echo "  --no-delete-branch       Keep the branch after merge"
    echo "  --approve                Also approve the PR before enabling auto-merge"
    echo "  --comment TEXT           Add a comment when approving (use with --approve)"
    echo "  --disable                Disable auto-merge instead of enabling it"
    echo "  --status                 Check auto-merge status of PR"
    echo "  --list                   List all PRs with auto-merge enabled"
    echo "  --force                  Skip confirmation prompts"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Enable auto-merge for PR #123"
    echo "  $0 enable-auto-merge --pr 123 ~/projects/my-project"
    echo ""
    echo "  # Enable auto-merge with squash and branch deletion"
    echo "  $0 enable-auto-merge --pr 123 --merge-method squash ~/projects/my-project"
    echo ""
    echo "  # Approve and enable auto-merge in one command"
    echo "  $0 enable-auto-merge --pr 123 --approve --comment 'LGTM' ~/projects/my-project"
    echo ""
    echo "  # Check if auto-merge is enabled on PR #123"
    echo "  $0 enable-auto-merge --pr 123 --status ~/projects/my-project"
    echo ""
    echo "  # Disable auto-merge on PR #123"
    echo "  $0 enable-auto-merge --pr 123 --disable ~/projects/my-project"
    echo ""
    echo "  # List all PRs with auto-merge enabled"
    echo "  $0 enable-auto-merge --list ~/projects/my-project"
    echo ""
    echo "  # Enable auto-merge for current branch's PR"
    echo "  $0 enable-auto-merge ~/projects/my-project"
    echo ""
    echo "Requirements:"
    echo "  - GitHub CLI (gh) must be installed and authenticated"
    echo "  - Repository must have branch protection rules configured"
    echo "  - User must have permission to merge PRs"
    echo "  - PR must be in a mergeable state (no conflicts, not draft)"
    echo ""
    echo "Auto-merge behavior:"
    echo "  - PR will merge automatically when ALL requirements are met:"
    echo "    * Required status checks pass"
    echo "    * Required approvals obtained"
    echo "    * Branch is up-to-date (if required)"
    echo "    * No merge conflicts"
    echo "  - Auto-merge is cancelled if:"
    echo "    * New changes are pushed to the PR"
    echo "    * Merge conflicts arise"
    echo "    * A reviewer requests changes"
    echo ""
    echo "Note: Auto-merge must be enabled in the repository settings."
    echo "      Check: Settings -> General -> Pull Requests -> Allow auto-merge"
    echo ""
}

# Function to show usage for configure-repo command

# Handle PR-related commands
handle_pr_command() {
    local cmd="$1"
    shift
    
    case $cmd in
    merge-pr)
        # Handle merge-pr command
        
        # Default options
        PR_NUMBER=""
        MERGE_METHOD="squash"
        DELETE_BRANCH=true
        NO_DELETE_BRANCH=false
        TITLE=""
        BODY=""
        ADMIN=false
        AUTO=false
        APPROVE_FIRST=false
        COMMENT=""
        CHECK=false
        FORCE=false
        WAIT_FOR_CHECKS=false
        TIMEOUT=600
        SKIP_CHECKS=false
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --pr)
                    PR_NUMBER="$2"
                    shift 2
                    ;;
                --merge-method)
                    MERGE_METHOD="$2"
                    shift 2
                    ;;
                --delete-branch)
                    DELETE_BRANCH=true
                    NO_DELETE_BRANCH=false
                    shift
                    ;;
                --no-delete-branch)
                    DELETE_BRANCH=false
                    NO_DELETE_BRANCH=true
                    shift
                    ;;
                --title)
                    TITLE="$2"
                    shift 2
                    ;;
                --body)
                    BODY="$2"
                    shift 2
                    ;;
                --admin)
                    ADMIN=true
                    shift
                    ;;
                --auto)
                    AUTO=true
                    shift
                    ;;
                --approve-first)
                    APPROVE_FIRST=true
                    shift
                    ;;
                --comment)
                    COMMENT="$2"
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
                --wait-for-checks)
                    WAIT_FOR_CHECKS=true
                    shift
                    ;;
                --skip-checks)
                    SKIP_CHECKS=true
                    shift
                    ;;
                --timeout)
                    TIMEOUT="$2"
                    shift 2
                    ;;
                -h|--help)
                    show_merge_pr_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 merge-pr --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 merge-pr [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Check if git directory was provided
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 merge-pr [options] <git-directory>"
            echo "Run '$0 merge-pr --help' for more information."
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
        
        # Validate merge method
        if [[ ! "$MERGE_METHOD" =~ ^(merge|squash|rebase)$ ]]; then
            echo "Error: Invalid merge method '$MERGE_METHOD'"
            echo "Must be: merge, squash, or rebase"
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
        
        # If no PR number specified, try to find PR for current branch
        if [ -z "$PR_NUMBER" ]; then
            echo "No PR number specified, checking for PR associated with current branch..."
            
            # Get current branch name
            CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
            
            if [ -z "$CURRENT_BRANCH" ]; then
                echo "Error: Could not determine current branch"
                echo "Please specify PR number with --pr NUMBER"
                exit 1
            fi
            
            echo "Current branch: $CURRENT_BRANCH"
            
            # Find PR for this branch
            PR_NUMBER=$(gh pr list --head "$CURRENT_BRANCH" --json number -q '.[0].number' 2>/dev/null || echo "")
            
            if [ -z "$PR_NUMBER" ]; then
                echo "Error: No PR found for branch '$CURRENT_BRANCH'"
                echo "Please specify PR number with --pr NUMBER"
                exit 1
            fi
            
            echo "Found PR #$PR_NUMBER for branch '$CURRENT_BRANCH'"
            echo ""
        fi
        
        # Get PR details
        PR_DETAILS=$(gh pr view "$PR_NUMBER" --json number,title,author,state,isDraft,headRefName,baseRefName,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup 2>/dev/null || echo "")
        
        if [ -z "$PR_DETAILS" ]; then
            echo "Error: Pull request #$PR_NUMBER not found"
            exit 1
        fi
        
        # Parse PR details
        PR_TITLE=$(echo "$PR_DETAILS" | jq -r '.title')
        PR_AUTHOR=$(echo "$PR_DETAILS" | jq -r '.author.login')
        PR_STATE=$(echo "$PR_DETAILS" | jq -r '.state')
        PR_IS_DRAFT=$(echo "$PR_DETAILS" | jq -r '.isDraft')
        PR_HEAD=$(echo "$PR_DETAILS" | jq -r '.headRefName')
        PR_BASE=$(echo "$PR_DETAILS" | jq -r '.baseRefName')
        PR_MERGEABLE=$(echo "$PR_DETAILS" | jq -r '.mergeable')
        MERGE_STATE=$(echo "$PR_DETAILS" | jq -r '.mergeStateStatus')
        REVIEW_DECISION=$(echo "$PR_DETAILS" | jq -r '.reviewDecision // "NONE"')
        
        echo "=========================================="
        if [ "$CHECK" = true ]; then
            echo "Merge Readiness Check"
        elif [ "$AUTO" = true ]; then
            echo "Enable Auto-Merge"
        else
            echo "Merge Pull Request"
        fi
        echo "=========================================="
        echo "Repository: $REPO_NAME ($REPO_FULL)"
        echo "PR: #$PR_NUMBER - $PR_TITLE"
        echo "Author: @$PR_AUTHOR"
        echo "Branch: $PR_HEAD -> $PR_BASE"
        echo "=========================================="
        echo ""
        
        # Check PR state
        if [ "$PR_STATE" != "OPEN" ]; then
            echo "Error: PR #$PR_NUMBER is not open (state: $PR_STATE)"
            exit 1
        fi
        
        if [ "$PR_IS_DRAFT" = "true" ]; then
            echo "Error: Cannot merge a draft PR"
            echo "The PR must be marked as ready for review first."
            exit 1
        fi
        
        # Check merge readiness
        echo "Merge Readiness:"
        echo "  PR State: $PR_STATE"
        echo "  Mergeable: $PR_MERGEABLE"
        echo "  Merge State: $MERGE_STATE"
        echo "  Review Status: $REVIEW_DECISION"
        
        # Check status checks (skip if --skip-checks is set)
        if [ "$SKIP_CHECKS" = true ]; then
            echo ""
            echo "Status Checks: (skipped)"
            CHECKS_PASSED="unknown"
        else
            echo ""
            echo "Status Checks:"
            CHECK_STATUS=$(echo "$PR_DETAILS" | jq -r '.statusCheckRollup // "null"')
            if [ "$CHECK_STATUS" = "null" ] || [ -z "$CHECK_STATUS" ]; then
                echo "  No status checks configured"
                CHECKS_PASSED=true
            else
                # Get individual check status with timeout
                CHECKS=$(timeout 5 gh pr checks "$PR_NUMBER" --json name,status,conclusion 2>/dev/null || echo "")
                
                if [ -z "$CHECKS" ]; then
                    # Try alternative approach or skip
                    echo "  Unable to fetch check details (may be no checks or API issue)"
                    CHECKS_PASSED="unknown"
                elif [ "$CHECKS" = "[]" ]; then
                    echo "  No status checks found"
                    CHECKS_PASSED=true
                else
                    PENDING=0
                    FAILED=0
                    PASSED=0
                    
                    while IFS= read -r check; do
                        STATUS=$(echo "$check" | jq -r '.status // "UNKNOWN"')
                        CONCLUSION=$(echo "$check" | jq -r '.conclusion // "pending"')
                        NAME=$(echo "$check" | jq -r '.name // "Unknown Check"')
                        
                        if [ "$STATUS" = "COMPLETED" ]; then
                            if [ "$CONCLUSION" = "SUCCESS" ] || [ "$CONCLUSION" = "NEUTRAL" ] || [ "$CONCLUSION" = "SKIPPED" ]; then
                                ((PASSED++)) || true
                                echo "  ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ $NAME"
                            else
                                ((FAILED++)) || true
                                echo "  ÃƒÂ¢Ã…â€œÃ¢â‚¬â€ $NAME ($CONCLUSION)"
                            fi
                        else
                            ((PENDING++)) || true
                            echo "  ÃƒÂ¢Ã‚ÂÃ‚Â³ $NAME (pending)"
                        fi
                    done < <(echo "$CHECKS" | jq -c '.[]' 2>/dev/null || echo "")
                    
                    if [ $PASSED -gt 0 ] || [ $FAILED -gt 0 ] || [ $PENDING -gt 0 ]; then
                        echo ""
                        echo "  Summary: $PASSED passed, $FAILED failed, $PENDING pending"
                    fi
                    
                    if [ $FAILED -gt 0 ]; then
                        CHECKS_PASSED=false
                    elif [ $PENDING -gt 0 ]; then
                        CHECKS_PASSED="pending"
                    else
                        CHECKS_PASSED=true
                    fi
                fi
            fi
        fi
        echo ""
        
        # If only checking, stop here
        if [ "$CHECK" = true ]; then
            echo "=========================================="
            echo "Merge Readiness Summary"
            echo "=========================================="
            echo ""
            
            CAN_MERGE=true
            WARNINGS=""
            
            if [ "$PR_MERGEABLE" = "CONFLICTING" ]; then
                echo "ÃƒÂ¢Ã‚ÂÃ…â€™ PR has merge conflicts - must be resolved"
                CAN_MERGE=false
            fi
            
            if [ "$REVIEW_DECISION" != "APPROVED" ] && [ "$REVIEW_DECISION" != "null" ]; then
                if [ "$REVIEW_DECISION" = "CHANGES_REQUESTED" ]; then
                    echo "ÃƒÂ¢Ã‚ÂÃ…â€™ Changes requested - must be addressed"
                    CAN_MERGE=false
                elif [ "$REVIEW_DECISION" = "REVIEW_REQUIRED" ] || [ "$REVIEW_DECISION" = "NONE" ]; then
                    echo "ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â  Review required - PR needs approval"
                    WARNINGS="yes"
                fi
            else
                echo "ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ PR is approved"
            fi
            
            if [ "$CHECKS_PASSED" = false ]; then
                echo "ÃƒÂ¢Ã‚ÂÃ…â€™ Status checks failed - must be fixed"
                CAN_MERGE=false
            elif [ "$CHECKS_PASSED" = "pending" ]; then
                echo "ÃƒÂ¢Ã‚ÂÃ‚Â³ Status checks pending - waiting for completion"
                WARNINGS="yes"
            elif [ "$CHECKS_PASSED" = true ]; then
                echo "ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ All status checks passed"
            fi
            
            echo ""
            if [ "$CAN_MERGE" = true ]; then
                if [ -n "$WARNINGS" ]; then
                    echo "ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â  PR can be merged but has warnings"
                    echo ""
                    echo "To merge anyway (if you have permission):"
                    echo "  $0 merge-pr --pr $PR_NUMBER $GIT_DIR"
                    echo ""
                    echo "To bypass protection (admin only):"
                    echo "  $0 merge-pr --pr $PR_NUMBER --admin $GIT_DIR"
                else
                    echo "ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ PR is ready to merge!"
                    echo ""
                    echo "To merge:"
                    echo "  $0 merge-pr --pr $PR_NUMBER $GIT_DIR"
                fi
            else
                echo "ÃƒÂ¢Ã‚ÂÃ…â€™ PR cannot be merged - issues must be resolved"
                echo ""
                echo "Fix the issues above, then try again."
            fi
            
            exit 0
        fi
        
        # Approve first if requested
        if [ "$APPROVE_FIRST" = true ]; then
            echo "Approving PR before merge..."
            
            REVIEW_BODY=""
            if [ -n "$COMMENT" ]; then
                REVIEW_BODY="$COMMENT"
            else
                REVIEW_BODY="Approved and merging via gitRepoUtils.sh"
            fi
            
            if gh pr review "$PR_NUMBER" --approve --body "$REVIEW_BODY" 2>&1; then
                echo "[OK] PR approved"
                REVIEW_DECISION="APPROVED"
            else
                echo "[WARN] Could not approve PR (may already be approved)"
            fi
            echo ""
        fi
        
        # Wait for checks if requested
        if [ "$WAIT_FOR_CHECKS" = true ] && [ "$CHECKS_PASSED" = "pending" ]; then
            echo "Waiting for status checks to complete..."
            echo "Timeout: $TIMEOUT seconds"
            echo ""
            
            START_TIME=$(date +%s)
            
            while true; do
                # Check timeout
                CURRENT_TIME=$(date +%s)
                ELAPSED=$((CURRENT_TIME - START_TIME))
                
                if [ $ELAPSED -gt $TIMEOUT ]; then
                    echo ""
                    echo "Timeout reached after $TIMEOUT seconds"
                    echo "Status checks are still pending."
                    echo ""
                    echo "You can:"
                    echo "  1. Wait longer: $0 merge-pr --pr $PR_NUMBER --wait-for-checks --timeout 1200 $GIT_DIR"
                    echo "  2. Check status: gh pr checks $PR_NUMBER --watch"
                    echo "  3. Force merge (admin): $0 merge-pr --pr $PR_NUMBER --admin $GIT_DIR"
                    exit 1
                fi
                
                # Check current status
                CHECKS=$(gh pr checks "$PR_NUMBER" --json status 2>/dev/null)
                PENDING_COUNT=$(echo "$CHECKS" | jq '[.[] | select(.status != "COMPLETED")] | length' 2>/dev/null || echo "1")
                
                if [ "$PENDING_COUNT" -eq 0 ]; then
                    echo "All checks completed!"
                    
                    # Check if they all passed
                    FAILED_COUNT=$(gh pr checks "$PR_NUMBER" --json conclusion | jq '[.[] | select(.conclusion != "SUCCESS" and .conclusion != "NEUTRAL" and .conclusion != "SKIPPED")] | length' 2>/dev/null || echo "0")
                    
                    if [ "$FAILED_COUNT" -gt 0 ]; then
                        echo "Warning: $FAILED_COUNT check(s) failed"
                        CHECKS_PASSED=false
                    else
                        echo "All checks passed!"
                        CHECKS_PASSED=true
                    fi
                    break
                fi
                
                echo "  Waiting... ($PENDING_COUNT checks pending, ${ELAPSED}s elapsed)"
                sleep 10
            done
            echo ""
        fi
        
        # If enabling auto-merge
        if [ "$AUTO" = true ]; then
            echo "Enabling auto-merge for PR #$PR_NUMBER..."
            echo "  Method: $MERGE_METHOD"
            if [ "$DELETE_BRANCH" = true ]; then
                echo "  Branch will be deleted after merge"
            fi
            echo ""
            
            AUTO_MERGE_CMD="gh pr merge $PR_NUMBER --auto --$MERGE_METHOD"
            
            if [ "$DELETE_BRANCH" = true ]; then
                AUTO_MERGE_CMD="$AUTO_MERGE_CMD --delete-branch"
            fi
            
            if eval "$AUTO_MERGE_CMD" 2>&1; then
                echo "[OK] Auto-merge enabled successfully!"
                echo ""
                echo "PR #$PR_NUMBER will automatically merge when all requirements are met."
            else
                echo "[FAIL] Failed to enable auto-merge"
                echo ""
                echo "Note: Auto-merge may not be enabled in repository settings."
                echo "Enable it with: $0 configure-repo --enable-auto-merge $GIT_DIR"
                exit 1
            fi
            
            exit 0
        fi
        
        # Confirm merge unless force flag is set
        if [ "$FORCE" = false ]; then
            echo "=========================================="
            echo "CONFIRMATION REQUIRED"
            echo "=========================================="
            echo ""
            echo "You are about to merge PR #$PR_NUMBER"
            echo ""
            echo "Merge settings:"
            echo "  Method: $MERGE_METHOD"
            if [ "$DELETE_BRANCH" = true ]; then
                echo "  Delete branch after merge: Yes"
            else
                echo "  Delete branch after merge: No"
            fi
            
            if [ "$ADMIN" = true ]; then
                echo "  Admin override: Yes (bypass protection)"
            fi
            
            if [ -n "$TITLE" ]; then
                echo "  Custom title: $TITLE"
            fi
            
            if [ -n "$BODY" ]; then
                echo "  Custom body: Yes"
            fi
            echo ""
            
            # Show warnings
            if [ "$REVIEW_DECISION" != "APPROVED" ] && [ "$ADMIN" = false ]; then
                echo "ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â  Warning: PR may not be approved"
            fi
            
            if [ "$CHECKS_PASSED" = false ] && [ "$ADMIN" = false ]; then
                echo "ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â  Warning: Some checks have failed"
            elif [ "$CHECKS_PASSED" = "pending" ] && [ "$ADMIN" = false ]; then
                echo "ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â  Warning: Some checks are still pending"
            fi
            
            if [ "$PR_MERGEABLE" = "CONFLICTING" ]; then
                echo "ÃƒÂ¢Ã‚ÂÃ…â€™ Warning: PR has merge conflicts!"
            fi
            
            echo ""
            read -p "Are you sure you want to proceed? (yes/no): " -r
            echo ""
            
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                echo "Operation cancelled."
                exit 0
            fi
        fi
        
        # Perform the merge
        echo "Merging PR #$PR_NUMBER..."
        echo ""
        
        # Build merge command
        MERGE_CMD="gh pr merge $PR_NUMBER --$MERGE_METHOD"
        
        if [ "$DELETE_BRANCH" = true ]; then
            MERGE_CMD="$MERGE_CMD --delete-branch"
        fi
        
        if [ "$ADMIN" = true ]; then
            MERGE_CMD="$MERGE_CMD --admin"
        fi
        
        if [ -n "$TITLE" ]; then
            MERGE_CMD="$MERGE_CMD --subject \"$TITLE\""
        fi
        
        if [ -n "$BODY" ]; then
            MERGE_CMD="$MERGE_CMD --body \"$BODY\""
        fi
        
        # Execute merge
        if eval "$MERGE_CMD" 2>&1; then
            echo ""
            echo "=========================================="
            echo "Merge Successful!"
            echo "=========================================="
            echo ""
            echo "[OK] PR #$PR_NUMBER has been merged using $MERGE_METHOD method"
            
            if [ "$DELETE_BRANCH" = true ]; then
                echo "[OK] Branch '$PR_HEAD' has been deleted"
            fi
            
            echo ""
            echo "View the merge commit:"
            echo "  https://github.com/$REPO_FULL/pull/$PR_NUMBER"
            echo ""
            
            # Pull the changes locally
            echo "To update your local repository:"
            echo "  git checkout $PR_BASE"
            echo "  git pull origin $PR_BASE"
            
        else
            echo ""
            echo "[FAIL] Failed to merge PR #$PR_NUMBER"
            echo ""
            echo "Common reasons for merge failure:"
            echo "  - PR is not approved (use --approve-first or approve separately)"
            echo "  - Required status checks haven't passed (use --wait-for-checks)"
            echo "  - Merge conflicts exist (must be resolved manually)"
            echo "  - Branch protection rules block the merge (use --admin if you have permission)"
            echo "  - You don't have merge permissions"
            echo ""
            echo "Check the PR status:"
            echo "  $0 merge-pr --pr $PR_NUMBER --check $GIT_DIR"
            echo ""
            echo "Or view on GitHub:"
            echo "  https://github.com/$REPO_FULL/pull/$PR_NUMBER"
            
            exit 1
        fi
        
        exit 0
        ;;
        

    list-prs)
        # Handle list-prs command
        
        # Default options
        STATE="open"
        UNAPPROVED=false
        APPROVED=false
        CHANGES_REQUESTED=false
        DRAFT_ONLY=false
        READY_ONLY=false
        AUTHOR=""
        ASSIGNEE=""
        LABEL=""
        BASE_BRANCH=""
        HEAD_BRANCH=""
        NEEDS_MY_REVIEW=false
        REVIEWED_BY_ME=false
        MINE=false
        SORT="updated"
        LIMIT=30
        FORMAT="table"
        NO_CHECKS=false
        SHOW_REVIEWS=false
        SHOW_FILES=false
        SHOW_URLS=false
        DEBUG=false
        NO_FILTER=false
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --state)
                    STATE="$2"
                    shift 2
                    ;;
                --unapproved)
                    UNAPPROVED=true
                    shift
                    ;;
                --approved)
                    APPROVED=true
                    shift
                    ;;
                --changes-requested)
                    CHANGES_REQUESTED=true
                    shift
                    ;;
                --draft)
                    DRAFT_ONLY=true
                    shift
                    ;;
                --ready)
                    READY_ONLY=true
                    shift
                    ;;
                --author)
                    AUTHOR="$2"
                    shift 2
                    ;;
                --assignee)
                    ASSIGNEE="$2"
                    shift 2
                    ;;
                --label)
                    LABEL="$2"
                    shift 2
                    ;;
                --base)
                    BASE_BRANCH="$2"
                    shift 2
                    ;;
                --head)
                    HEAD_BRANCH="$2"
                    shift 2
                    ;;
                --needs-my-review)
                    NEEDS_MY_REVIEW=true
                    shift
                    ;;
                --reviewed-by-me)
                    REVIEWED_BY_ME=true
                    shift
                    ;;
                --mine)
                    MINE=true
                    shift
                    ;;
                --sort)
                    SORT="$2"
                    shift 2
                    ;;
                --limit)
                    LIMIT="$2"
                    shift 2
                    ;;
                --format)
                    FORMAT="$2"
                    shift 2
                    ;;
                --no-checks)
                    NO_CHECKS=true
                    shift
                    ;;
                --show-reviews)
                    SHOW_REVIEWS=true
                    shift
                    ;;
                --show-files)
                    SHOW_FILES=true
                    shift
                    ;;
                --urls)
                    SHOW_URLS=true
                    shift
                    ;;
                --debug)
                    DEBUG=true
                    shift
                    ;;
                --no-filter)
                    NO_FILTER=true
                    shift
                    ;;
                -h|--help)
                    show_list_prs_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 list-prs --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 list-prs [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Check if git directory was provided
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 list-prs [options] <git-directory>"
            echo "Run '$0 list-prs --help' for more information."
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
        
        # Validate state
        if [[ ! "$STATE" =~ ^(open|closed|merged|all)$ ]]; then
            echo "Error: Invalid state '$STATE'"
            echo "Must be: open, closed, merged, or all"
            exit 1
        fi
        
        # Validate sort
        if [[ ! "$SORT" =~ ^(created|updated|popularity|reactions)$ ]]; then
            echo "Error: Invalid sort field '$SORT'"
            echo "Must be: created, updated, popularity, or reactions"
            exit 1
        fi
        
        # Validate format
        if [[ ! "$FORMAT" =~ ^(table|simple|detailed|json|csv)$ ]]; then
            echo "Error: Invalid format '$FORMAT'"
            echo "Must be: table, simple, detailed, json, or csv"
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
        
        # Get current user if needed
        CURRENT_USER=""
        if [ "$NEEDS_MY_REVIEW" = true ] || [ "$REVIEWED_BY_ME" = true ] || [ "$MINE" = true ]; then
            CURRENT_USER=$(gh auth status 2>&1 | grep "Logged in" | sed 's/.*account \(.*\) (.*/\1/')
            if [ -z "$CURRENT_USER" ]; then
                echo "Error: Could not determine current user"
                exit 1
            fi
        fi
        
        # Build the query
        QUERY="repo:$REPO_FULL"
        
        # Add state filter
        if [ "$STATE" != "all" ]; then
            QUERY="$QUERY is:$STATE"
        fi
        
        # Add author filter
        if [ -n "$AUTHOR" ]; then
            # Remove @ if present
            AUTHOR="${AUTHOR#@}"
            QUERY="$QUERY author:$AUTHOR"
        elif [ "$MINE" = true ]; then
            QUERY="$QUERY author:$CURRENT_USER"
        fi
        
        # Add assignee filter
        if [ -n "$ASSIGNEE" ]; then
            ASSIGNEE="${ASSIGNEE#@}"
            QUERY="$QUERY assignee:$ASSIGNEE"
        fi
        
        # Add label filter
        if [ -n "$LABEL" ]; then
            QUERY="$QUERY label:\"$LABEL\""
        fi
        
        # Add draft filter
        if [ "$DRAFT_ONLY" = true ]; then
            QUERY="$QUERY is:draft"
        elif [ "$READY_ONLY" = true ]; then
            QUERY="$QUERY -is:draft"
        fi
        
        # Add review filters
        if [ "$NEEDS_MY_REVIEW" = true ]; then
            QUERY="$QUERY review-requested:$CURRENT_USER"
        fi
        
        if [ "$REVIEWED_BY_ME" = true ]; then
            QUERY="$QUERY reviewed-by:$CURRENT_USER"
        fi
        
        # Add base/head branch filters
        if [ -n "$BASE_BRANCH" ]; then
            QUERY="$QUERY base:$BASE_BRANCH"
        fi
        
        if [ -n "$HEAD_BRANCH" ]; then
            QUERY="$QUERY head:$HEAD_BRANCH"
        fi
        
        # Print header for non-JSON/CSV formats
        if [ "$FORMAT" != "json" ] && [ "$FORMAT" != "csv" ]; then
            echo "=========================================="
            echo "Pull Requests: $REPO_NAME"
            echo "=========================================="
            echo "Repository: $REPO_FULL"
            
            # Show active filters
            echo "Filters:"
            echo "  State: $STATE"
            
            if [ "$UNAPPROVED" = true ]; then
                echo "  Review: UNAPPROVED ONLY"
            elif [ "$APPROVED" = true ]; then
                echo "  Review: APPROVED ONLY"
            elif [ "$CHANGES_REQUESTED" = true ]; then
                echo "  Review: CHANGES REQUESTED ONLY"
            fi
            
            if [ "$DRAFT_ONLY" = true ]; then
                echo "  Type: DRAFT ONLY"
            elif [ "$READY_ONLY" = true ]; then
                echo "  Type: READY FOR REVIEW ONLY"
            fi
            
            if [ -n "$AUTHOR" ]; then
                echo "  Author: @$AUTHOR"
            elif [ "$MINE" = true ]; then
                echo "  Author: @$CURRENT_USER (mine)"
            fi
            
            if [ -n "$BASE_BRANCH" ]; then
                echo "  Base: $BASE_BRANCH"
            fi
            
            if [ "$NEEDS_MY_REVIEW" = true ]; then
                echo "  Needs review from: @$CURRENT_USER"
            fi
            
            echo "  Sort: $SORT"
            echo "  Limit: $LIMIT"
            echo "=========================================="
            echo ""
        fi
        
        # Fetch PRs using GitHub CLI with search
        if [ "$FORMAT" != "json" ] && [ "$FORMAT" != "csv" ]; then
            echo "Fetching pull requests..." >&2
        fi
        
        # Get PR data with all needed fields
        if [ "$DEBUG" = true ]; then
            echo "DEBUG: Running gh pr list command..." >&2
            set -x
        fi
        
        # Build author filter argument
        AUTHOR_ARG=""
        if [ -n "$AUTHOR" ]; then
            AUTHOR_ARG="--author ${AUTHOR#@}"
        elif [ "$MINE" = true ] && [ -n "$CURRENT_USER" ]; then
            AUTHOR_ARG="--author $CURRENT_USER"
        fi
        
        # Build the gh command
        if [ "$DEBUG" = true ]; then
            echo "DEBUG: Author filter: $AUTHOR_ARG" >&2
        fi
        
        # Fetch PRs with optional author filter
        PR_DATA=$(gh pr list \
            --repo "$REPO_FULL" \
            --state "$STATE" \
            --limit "$LIMIT" \
            $AUTHOR_ARG \
            --json number,title,author,state,isDraft,headRefName,baseRefName,createdAt,updatedAt,reviewDecision,labels,assignees,body,additions,deletions,changedFiles,url \
            2>&1)
        
        GH_EXIT_CODE=$?
        
        if [ "$DEBUG" = true ]; then
            set +x
            echo "DEBUG: gh command exit code: $GH_EXIT_CODE" >&2
            echo "DEBUG: Raw PR_DATA length: ${#PR_DATA}" >&2
            if [ -n "$PR_DATA" ]; then
                echo "DEBUG: First 500 chars of PR_DATA: ${PR_DATA:0:500}" >&2
            fi
        fi
        
        # Check for gh command errors
        if [ $GH_EXIT_CODE -ne 0 ]; then
            echo "Error: Failed to fetch pull requests" >&2
            echo "Error details: $PR_DATA" >&2
            
            # Try alternative method using gh search
            echo "Trying alternative method using gh search..." >&2
            PR_DATA=$(gh search prs --repo "$REPO_FULL" --state "$STATE" --limit "$LIMIT" $AUTHOR_ARG --json number,title,author,state,isDraft,headRefName,baseRefName,createdAt,updatedAt,reviewDecision,url 2>&1)
            GH_EXIT_CODE=$?
            
            if [ $GH_EXIT_CODE -ne 0 ]; then
                echo "Alternative method also failed" >&2
                exit 1
            fi
        fi
        
        # Try to parse as JSON to check validity
        if ! echo "$PR_DATA" | jq empty 2>/dev/null; then
            echo "Error: Invalid JSON response from GitHub CLI" >&2
            echo "Response: $PR_DATA" >&2
            exit 1
        fi
        
        # Sort the results if requested (do it in jq since --sort flag may not be available)
        if [ "$SORT" != "updated" ]; then
            case "$SORT" in
                created)
                    PR_DATA=$(echo "$PR_DATA" | jq 'sort_by(.createdAt) | reverse')
                    ;;
                popularity)
                    # Sort by number of comments/reactions (approximate)
                    PR_DATA=$(echo "$PR_DATA" | jq 'sort_by(.comments // 0) | reverse')
                    ;;
                reactions)
                    PR_DATA=$(echo "$PR_DATA" | jq 'sort_by(.reactions // 0) | reverse')
                    ;;
                *)
                    # Default to updated (most recently updated first)
                    PR_DATA=$(echo "$PR_DATA" | jq 'sort_by(.updatedAt) | reverse')
                    ;;
            esac
        else
            # Sort by updated date (most recent first)
            PR_DATA=$(echo "$PR_DATA" | jq 'sort_by(.updatedAt) | reverse')
        fi
        
        if [ "$DEBUG" = true ]; then
            echo "DEBUG: Valid JSON received" >&2
            echo "DEBUG: PR_DATA content:" >&2
            echo "$PR_DATA" | jq '.' >&2
        fi
        
        if [ -z "$PR_DATA" ] || [ "$PR_DATA" = "[]" ]; then
            if [ "$DEBUG" = true ]; then
                echo "DEBUG: No PRs found (empty result)" >&2
            fi
            if [ "$FORMAT" != "json" ] && [ "$FORMAT" != "csv" ]; then
                echo "No pull requests found."
                if [ "$STATE" = "open" ]; then
                    echo ""
                    echo "This could mean:"
                    echo "  - There are no open PRs in this repository"
                    echo "  - You don't have permission to view PRs"
                    echo "  - The repository name is incorrect"
                    echo ""
                    echo "Try running: gh pr list --repo $REPO_FULL"
                fi
            elif [ "$FORMAT" = "json" ]; then
                echo "[]"
            fi
            exit 0
        fi
        
        # Filter by review status if needed (skip if --no-filter)
        if [ "$NO_FILTER" = true ]; then
            if [ "$DEBUG" = true ]; then
                echo "DEBUG: Skipping review status filtering (--no-filter set)" >&2
            fi
        elif [ "$UNAPPROVED" = true ] || [ "$APPROVED" = true ] || [ "$CHANGES_REQUESTED" = true ]; then
            if [ "$DEBUG" = true ]; then
                echo "DEBUG: Filtering by review status (unapproved=$UNAPPROVED, approved=$APPROVED, changes=$CHANGES_REQUESTED)" >&2
            fi
            
            FILTERED_DATA="[]"
            
            # Process each PR
            while IFS= read -r pr; do
                # Check if reviewDecision exists and get its value
                HAS_REVIEW=$(echo "$pr" | jq -r 'has("reviewDecision")')
                if [ "$HAS_REVIEW" = "true" ]; then
                    REVIEW_DECISION=$(echo "$pr" | jq -r '.reviewDecision // "NONE"')
                else
                    REVIEW_DECISION="NONE"
                fi
                
                # Handle null value explicitly
                if [ "$REVIEW_DECISION" = "null" ]; then
                    REVIEW_DECISION="NONE"
                fi
                
                if [ "$DEBUG" = true ]; then
                    PR_NUM=$(echo "$pr" | jq -r '.number')
                    echo "DEBUG: PR #$PR_NUM - reviewDecision='$REVIEW_DECISION' (has_review=$HAS_REVIEW)" >&2
                fi
                
                INCLUDE=false
                
                # For unapproved, include PRs with no review decision, null, PENDING, or REVIEW_REQUIRED
                if [ "$UNAPPROVED" = true ]; then
                    if [ "$DEBUG" = true ]; then
                        echo "DEBUG: PR #$PR_NUM - Testing UNAPPROVED condition:" >&2
                        echo "  REVIEW_DECISION='$REVIEW_DECISION'" >&2
                        echo "  Test NONE: $([ "$REVIEW_DECISION" = "NONE" ] && echo true || echo false)" >&2
                        echo "  Test PENDING: $([ "$REVIEW_DECISION" = "PENDING" ] && echo true || echo false)" >&2
                        echo "  Test REVIEW_REQUIRED: $([ "$REVIEW_DECISION" = "REVIEW_REQUIRED" ] && echo true || echo false)" >&2
                        echo "  Test empty: $([ -z "$REVIEW_DECISION" ] && echo true || echo false)" >&2
                    fi
                    if [ "$REVIEW_DECISION" = "NONE" ] || [ "$REVIEW_DECISION" = "PENDING" ] || [ "$REVIEW_DECISION" = "REVIEW_REQUIRED" ] || [ -z "$REVIEW_DECISION" ]; then
                        INCLUDE=true
                        if [ "$DEBUG" = true ]; then
                            echo "DEBUG: PR #$PR_NUM - INCLUDING as UNAPPROVED (reviewDecision=$REVIEW_DECISION)" >&2
                        fi
                    else
                        if [ "$DEBUG" = true ]; then
                            echo "DEBUG: PR #$PR_NUM - NOT including (reviewDecision=$REVIEW_DECISION doesn't match unapproved criteria)" >&2
                        fi
                    fi
                elif [ "$APPROVED" = true ]; then
                    if [ "$REVIEW_DECISION" = "APPROVED" ]; then
                        INCLUDE=true
                    fi
                elif [ "$CHANGES_REQUESTED" = true ]; then
                    if [ "$REVIEW_DECISION" = "CHANGES_REQUESTED" ]; then
                        INCLUDE=true
                    fi
                fi
                
                if [ "$INCLUDE" = true ]; then
                    # Append to filtered data
                    FILTERED_DATA=$(echo "$FILTERED_DATA" | jq ". += [$pr]")
                fi
            done < <(echo "$PR_DATA" | jq -c '.[]')
            
            if [ "$DEBUG" = true ]; then
                FILTERED_COUNT=$(echo "$FILTERED_DATA" | jq 'length')
                echo "DEBUG: After filtering, have $FILTERED_COUNT PRs" >&2
            fi
            
            PR_DATA="$FILTERED_DATA"
        fi
        
        # Count results
        PR_COUNT=$(echo "$PR_DATA" | jq 'length')
        
        if [ "$PR_COUNT" -eq 0 ]; then
            if [ "$FORMAT" != "json" ] && [ "$FORMAT" != "csv" ]; then
                echo "No pull requests found matching criteria."
            elif [ "$FORMAT" = "json" ]; then
                echo "[]"
            fi
            exit 0
        fi
        
        # Get additional review details if requested
        if [ "$SHOW_REVIEWS" = true ] && [ "$FORMAT" != "csv" ]; then
            echo "Fetching review details..." >&2
            
            # Add review details to each PR
            ENHANCED_DATA="[]"
            while IFS= read -r pr; do
                PR_NUM=$(echo "$pr" | jq -r '.number')
                
                # Get reviews for this PR
                REVIEWS=$(gh pr view "$PR_NUM" --repo "$REPO_FULL" --json reviews \
                    --jq '.reviews' 2>/dev/null || echo "[]")
                
                # Add reviews to PR data
                pr=$(echo "$pr" | jq --argjson reviews "$REVIEWS" '. + {reviews: $reviews}')
                ENHANCED_DATA=$(echo "$ENHANCED_DATA" | jq ". += [$pr]")
            done < <(echo "$PR_DATA" | jq -c '.[]')
            
            PR_DATA="$ENHANCED_DATA"
        fi
        
        # Output based on format
        if [ "$DEBUG" = true ]; then
            echo "DEBUG: About to output results in format: $FORMAT" >&2
            echo "DEBUG: PR_COUNT = $PR_COUNT" >&2
        fi
        
        case "$FORMAT" in
            json)
                echo "$PR_DATA"
                ;;
                
            csv)
                # CSV header
                echo "Number,Title,Author,State,Draft,Branch,Target,Review Status,Created,Updated,Additions,Deletions,Files Changed,URL"
                
                # CSV data
                echo "$PR_DATA" | jq -r '.[] | 
                    [.number,
                     .title,
                     .author.login,
                     .state,
                     .isDraft,
                     .headRefName,
                     .baseRefName,
                     (.reviewDecision // "PENDING"),
                     .createdAt,
                     .updatedAt,
                     .additions,
                     .deletions,
                     .changedFiles,
                     .url
                    ] | @csv'
                ;;
                
            simple)
                if [ "$SHOW_URLS" = true ]; then
                    echo "$PR_DATA" | jq -r '.[] | 
                        "#\(.number): \(.title)\n       \(.url)"'
                else
                    echo "$PR_DATA" | jq -r '.[] | 
                        "#\(.number): \(.title)"'
                fi
                ;;
                
            detailed)
                # Detailed output with everything
                while IFS= read -r pr; do
                    PR_NUM=$(echo "$pr" | jq -r '.number')
                    PR_TITLE=$(echo "$pr" | jq -r '.title')
                    PR_AUTHOR=$(echo "$pr" | jq -r '.author.login')
                    PR_STATE=$(echo "$pr" | jq -r '.state')
                    PR_DRAFT=$(echo "$pr" | jq -r '.isDraft')
                    PR_HEAD=$(echo "$pr" | jq -r '.headRefName')
                    PR_BASE=$(echo "$pr" | jq -r '.baseRefName')
                    PR_REVIEW=$(echo "$pr" | jq -r '.reviewDecision // "PENDING"')
                    PR_CREATED=$(echo "$pr" | jq -r '.createdAt')
                    PR_UPDATED=$(echo "$pr" | jq -r '.updatedAt')
                    PR_BODY=$(echo "$pr" | jq -r '.body // ""')
                    
                    echo "=========================================="
                    echo "PR #$PR_NUM: $PR_TITLE"
                    echo "=========================================="
                    echo "Author:    @$PR_AUTHOR"
                    echo "State:     $PR_STATE"
                    if [ "$PR_DRAFT" = "true" ]; then
                        echo "Type:      DRAFT"
                    fi
                    echo "Branch:    $PR_HEAD -> $PR_BASE"
                    echo "Review:    $PR_REVIEW"
                    echo "Created:   $PR_CREATED"
                    echo "Updated:   $PR_UPDATED"
                    
                    # Show URL if requested
                    if [ "$SHOW_URLS" = true ]; then
                        PR_URL=$(echo "$pr" | jq -r '.url // empty')
                        if [ -n "$PR_URL" ]; then
                            echo "URL:       $PR_URL"
                        fi
                    fi
                    
                    # Show labels
                    LABELS=$(echo "$pr" | jq -r '.labels[].name' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
                    if [ -n "$LABELS" ]; then
                        echo "Labels:    $LABELS"
                    fi
                    
                    # Show assignees
                    ASSIGNEES=$(echo "$pr" | jq -r '.assignees[].login' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
                    if [ -n "$ASSIGNEES" ]; then
                        echo "Assignees: $ASSIGNEES"
                    fi
                    
                    # Show file changes
                    if [ "$SHOW_FILES" = true ]; then
                        ADDITIONS=$(echo "$pr" | jq -r '.additions')
                        DELETIONS=$(echo "$pr" | jq -r '.deletions')
                        FILES_CHANGED=$(echo "$pr" | jq -r '.changedFiles')
                        echo "Changes:   +$ADDITIONS -$DELETIONS ($FILES_CHANGED files)"
                    fi
                    
                    # Show reviews if available
                    if [ "$SHOW_REVIEWS" = true ]; then
                        echo ""
                        echo "Reviews:"
                        REVIEWS=$(echo "$pr" | jq -r '.reviews[]? | "  @\(.author.login): \(.state) (\(.submittedAt))"' 2>/dev/null)
                        if [ -n "$REVIEWS" ]; then
                            echo "$REVIEWS"
                        else
                            echo "  No reviews yet"
                        fi
                    fi
                    
                    # Show body if not empty
                    if [ -n "$PR_BODY" ] && [ "$PR_BODY" != "null" ]; then
                        echo ""
                        echo "Description:"
                        echo "$PR_BODY" | sed 's/^/  /'
                    fi
                    
                    echo ""
                done < <(echo "$PR_DATA" | jq -c '.[]')
                ;;
                
            table|*)
                # Table format (default)
                echo "Found $PR_COUNT pull request(s)"
                echo ""
                
                # Table header
                printf "%-6s %-50s %-15s %-20s %-10s %-15s\n" \
                    "PR#" "Title" "Author" "Branch" "Status" "Review"
                printf "%-6s %-50s %-15s %-20s %-10s %-15s\n" \
                    "------" "--------------------------------------------------" \
                    "---------------" "--------------------" "----------" "---------------"
                
                # Table data
                while IFS= read -r pr; do
                    PR_NUM=$(echo "$pr" | jq -r '.number')
                    PR_TITLE=$(echo "$pr" | jq -r '.title')
                    PR_AUTHOR=$(echo "$pr" | jq -r '.author.login')
                    PR_STATE=$(echo "$pr" | jq -r '.state')
                    PR_DRAFT=$(echo "$pr" | jq -r '.isDraft')
                    PR_HEAD=$(echo "$pr" | jq -r '.headRefName')
                    PR_BASE=$(echo "$pr" | jq -r '.baseRefName')
                    PR_REVIEW=$(echo "$pr" | jq -r '.reviewDecision // "PENDING"')
                    
                    # Truncate long fields
                    if [ ${#PR_TITLE} -gt 47 ]; then
                        PR_TITLE="${PR_TITLE:0:47}..."
                    fi
                    
                    if [ ${#PR_HEAD} -gt 17 ]; then
                        PR_HEAD="${PR_HEAD:0:17}..."
                    fi
                    
                    # Format status
                    if [ "$PR_DRAFT" = "true" ]; then
                        STATUS="DRAFT"
                    else
                        STATUS="$PR_STATE"
                    fi
                    
                    # Format review status with icons (ASCII for macOS compatibility)
                    case "$PR_REVIEW" in
                        APPROVED) REVIEW_FMT="[+] APPROVED" ;;
                        CHANGES_REQUESTED) REVIEW_FMT="[!] CHANGES REQ" ;;
                        PENDING|NONE) REVIEW_FMT="[ ] PENDING" ;;
                        REVIEW_REQUIRED) REVIEW_FMT="[ ] NEEDS REVIEW" ;;
                        CONFLICTING) REVIEW_FMT="[X] CONFLICTING" ;;
                        *) REVIEW_FMT="[?] $PR_REVIEW" ;;
                    esac
                    
                    printf "%-6s %-50s %-15s %-20s %-10s %-15s\n" \
                        "#$PR_NUM" "$PR_TITLE" "@$PR_AUTHOR" "$PR_HEAD" "$STATUS" "$REVIEW_FMT"
                    
                    # Show URL if requested
                    if [ "$SHOW_URLS" = true ]; then
                        PR_URL=$(echo "$pr" | jq -r '.url // empty')
                        if [ -n "$PR_URL" ]; then
                            printf "       %s\n" "$PR_URL"
                        fi
                    fi
                done < <(echo "$PR_DATA" | jq -c '.[]')
                
                echo ""
                echo "=========================================="
                
                # Summary statistics
                UNAPPROVED_COUNT=$(echo "$PR_DATA" | jq '[.[] | select(.reviewDecision == null or .reviewDecision == "PENDING" or .reviewDecision == "REVIEW_REQUIRED")] | length')
                APPROVED_COUNT=$(echo "$PR_DATA" | jq '[.[] | select(.reviewDecision == "APPROVED")] | length')
                CHANGES_COUNT=$(echo "$PR_DATA" | jq '[.[] | select(.reviewDecision == "CHANGES_REQUESTED")] | length')
                DRAFT_COUNT=$(echo "$PR_DATA" | jq '[.[] | select(.isDraft == true)] | length')
                
                echo "Summary:"
                echo "  Total: $PR_COUNT PR(s)"
                if [ "$UNAPPROVED_COUNT" -gt 0 ]; then
                    echo "  Unapproved: $UNAPPROVED_COUNT"
                fi
                if [ "$APPROVED_COUNT" -gt 0 ]; then
                    echo "  Approved: $APPROVED_COUNT"
                fi
                if [ "$CHANGES_COUNT" -gt 0 ]; then
                    echo "  Changes Requested: $CHANGES_COUNT"
                fi
                if [ "$DRAFT_COUNT" -gt 0 ]; then
                    echo "  Drafts: $DRAFT_COUNT"
                fi
                echo ""
                
                # Suggest next actions
                if [ "$UNAPPROVED_COUNT" -gt 0 ]; then
                    echo "To approve PRs, use:"
                    echo "  $0 approve-pr --pr <NUMBER> $GIT_DIR"
                    echo ""
                fi
                ;;
        esac
        
        exit 0
        ;;
        

    approve-pr)
        # Handle approve-pr command
        
        # Default options
        PR_NUMBER=""
        COMMENT=""
        MERGE=false
        MERGE_METHOD="squash"
        DELETE_BRANCH=false
        LIST=false
        INTERACTIVE=false
        REVIEW_STATE="APPROVE"
        BODY=""
        FORCE=false
        CHECK=false
        BYPASS_RESTRICTIONS=false
        ENABLE_AUTO_MERGE=false
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --pr)
                    PR_NUMBER="$2"
                    shift 2
                    ;;
                --comment)
                    COMMENT="$2"
                    shift 2
                    ;;
                --merge)
                    MERGE=true
                    shift
                    ;;
                --merge-method)
                    MERGE_METHOD="$2"
                    shift 2
                    ;;
                --delete-branch)
                    DELETE_BRANCH=true
                    shift
                    ;;
                --list)
                    LIST=true
                    shift
                    ;;
                --interactive)
                    INTERACTIVE=true
                    shift
                    ;;
                --review-state)
                    REVIEW_STATE="$2"
                    shift 2
                    ;;
                --body)
                    BODY="$2"
                    shift 2
                    ;;
                --force)
                    FORCE=true
                    shift
                    ;;
                --check)
                    CHECK=true
                    shift
                    ;;
                --bypass-restrictions)
                    BYPASS_RESTRICTIONS=true
                    shift
                    ;;
                --enable-auto-merge)
                    ENABLE_AUTO_MERGE=true
                    shift
                    ;;
                -h|--help)
                    show_approve_pr_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 approve-pr --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 approve-pr [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Check if git directory was provided
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 approve-pr [options] <git-directory>"
            echo "Run '$0 approve-pr --help' for more information."
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
        
        # Validate review state
        if [[ ! "$REVIEW_STATE" =~ ^(APPROVE|COMMENT|REQUEST_CHANGES)$ ]]; then
            echo "Error: Invalid review state '$REVIEW_STATE'"
            echo "Must be: APPROVE, COMMENT, or REQUEST_CHANGES"
            exit 1
        fi
        
        # Validate merge method
        if [[ ! "$MERGE_METHOD" =~ ^(merge|squash|rebase)$ ]]; then
            echo "Error: Invalid merge method '$MERGE_METHOD'"
            echo "Must be: merge, squash, or rebase"
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
        
        # If listing PRs
        if [ "$LIST" = true ]; then
            echo "=========================================="
            echo "Open Pull Requests"
            echo "=========================================="
            echo "Repository: $REPO_NAME ($REPO_FULL)"
            echo "=========================================="
            echo ""
            
            # List open PRs with detailed information
            echo "Fetching open pull requests..."
            PR_LIST=$(gh pr list --json number,title,author,headRefName,baseRefName,state,isDraft,reviewDecision,updatedAt \
                --jq '.[] | "\(.number)|\(.title)|\(.author.login)|\(.headRefName)|\(.baseRefName)|\(.state)|\(.isDraft)|\(.reviewDecision // "PENDING")|\(.updatedAt)"' 2>/dev/null)
            
            if [ -z "$PR_LIST" ]; then
                echo "No open pull requests found."
            else
                echo "PR# | Title | Author | Branch | Target | Status | Review"
                echo "----+-------+--------+--------+--------+--------+-------"
                
                while IFS='|' read -r number title author branch target state isDraft review updated; do
                    # Truncate title if too long
                    if [ ${#title} -gt 40 ]; then
                        title="${title:0:37}..."
                    fi
                    
                    # Format draft status
                    if [ "$isDraft" = "true" ]; then
                        state="DRAFT"
                    fi
                    
                    # Format review status
                    case "$review" in
                        APPROVED) review="[OK] APPROVED" ;;
                        CHANGES_REQUESTED) review="[!] CHANGES" ;;
                        PENDING|"") review="[ ] PENDING" ;;
                        *) review="[?] $review" ;;
                    esac
                    
                    printf "#%-4s | %-40s | @%-12s | %-20s -> %-10s | %-6s | %s\n" \
                        "$number" "$title" "$author" "$branch" "$target" "$state" "$review"
                done <<< "$PR_LIST"
            fi
            
            echo ""
            echo "To approve a PR, run:"
            echo "  $0 approve-pr --pr <NUMBER> $GIT_DIR"
            exit 0
        fi
        
        # If interactive mode
        if [ "$INTERACTIVE" = true ]; then
            echo "=========================================="
            echo "Interactive PR Selection"
            echo "=========================================="
            echo "Repository: $REPO_NAME ($REPO_FULL)"
            echo "=========================================="
            echo ""
            
            # Get list of open PRs
            PR_LIST=$(gh pr list --json number,title,author,headRefName \
                --jq '.[] | "\(.number): \(.title) (by @\(.author.login), branch: \(.headRefName))"' 2>/dev/null)
            
            if [ -z "$PR_LIST" ]; then
                echo "No open pull requests found."
                exit 0
            fi
            
            echo "Open Pull Requests:"
            echo ""
            echo "$PR_LIST" | nl -v 0
            echo ""
            
            # Count PRs
            PR_COUNT=$(echo "$PR_LIST" | wc -l)
            
            read -p "Select PR to approve (0-$((PR_COUNT-1)), or 'q' to quit): " -r SELECTION
            
            if [ "$SELECTION" = "q" ] || [ "$SELECTION" = "Q" ]; then
                echo "Operation cancelled."
                exit 0
            fi
            
            if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 0 ] || [ "$SELECTION" -ge "$PR_COUNT" ]; then
                echo "Invalid selection."
                exit 1
            fi
            
            # Extract PR number from selected line
            PR_NUMBER=$(echo "$PR_LIST" | sed -n "$((SELECTION+1))p" | cut -d':' -f1)
            echo ""
            echo "Selected PR #$PR_NUMBER"
            echo ""
        fi
        
        # If no PR number specified, try to find PR for current branch
        if [ -z "$PR_NUMBER" ] && [ "$CHECK" = false ]; then
            echo "No PR number specified, checking for PR associated with current branch..."
            
            # Get current branch name
            CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
            
            if [ -z "$CURRENT_BRANCH" ]; then
                echo "Error: Could not determine current branch"
                echo "Please specify PR number with --pr NUMBER"
                exit 1
            fi
            
            echo "Current branch: $CURRENT_BRANCH"
            
            # Find PR for this branch
            PR_NUMBER=$(gh pr list --head "$CURRENT_BRANCH" --json number -q '.[0].number' 2>/dev/null || echo "")
            
            if [ -z "$PR_NUMBER" ]; then
                echo "Error: No PR found for branch '$CURRENT_BRANCH'"
                echo "Please specify PR number with --pr NUMBER"
                exit 1
            fi
            
            echo "Found PR #$PR_NUMBER for branch '$CURRENT_BRANCH'"
            echo ""
        fi
        
        # Validate PR number
        if [ -n "$PR_NUMBER" ]; then
            # Check if PR exists and get details
            PR_DETAILS=$(gh pr view "$PR_NUMBER" --json number,title,author,state,isDraft,headRefName,baseRefName,reviewDecision,body 2>/dev/null || echo "")
            
            if [ -z "$PR_DETAILS" ]; then
                echo "Error: Pull request #$PR_NUMBER not found"
                exit 1
            fi
            
            # Parse PR details
            PR_TITLE=$(echo "$PR_DETAILS" | jq -r '.title')
            PR_AUTHOR=$(echo "$PR_DETAILS" | jq -r '.author.login')
            PR_STATE=$(echo "$PR_DETAILS" | jq -r '.state')
            PR_IS_DRAFT=$(echo "$PR_DETAILS" | jq -r '.isDraft')
            PR_HEAD=$(echo "$PR_DETAILS" | jq -r '.headRefName')
            PR_BASE=$(echo "$PR_DETAILS" | jq -r '.baseRefName')
            PR_REVIEW=$(echo "$PR_DETAILS" | jq -r '.reviewDecision // "PENDING"')
            PR_BODY=$(echo "$PR_DETAILS" | jq -r '.body // ""')
        fi
        
        # If checking approval status
        if [ "$CHECK" = true ]; then
            if [ -z "$PR_NUMBER" ]; then
                echo "Error: Must specify PR number with --pr NUMBER for status check"
                exit 1
            fi
            
            echo "=========================================="
            echo "PR Approval Status Check"
            echo "=========================================="
            echo "Repository: $REPO_NAME ($REPO_FULL)"
            echo "PR: #$PR_NUMBER"
            echo "=========================================="
            echo ""
            
            echo "PR Details:"
            echo "  Title:  $PR_TITLE"
            echo "  Author: @$PR_AUTHOR"
            echo "  Branch: $PR_HEAD -> $PR_BASE"
            echo "  State:  $PR_STATE"
            
            if [ "$PR_IS_DRAFT" = "true" ]; then
                echo "  Status: DRAFT (cannot be merged)"
            fi
            echo ""
            
            echo "Review Status: $PR_REVIEW"
            echo ""
            
            # Get detailed review information
            echo "Reviews:"
            REVIEWS=$(gh pr view "$PR_NUMBER" --json reviews \
                --jq '.reviews[] | "\(.author.login)|\(.state)|\(.submittedAt)|\(.body // "")"' 2>/dev/null)
            
            if [ -z "$REVIEWS" ]; then
                echo "  No reviews yet"
            else
                while IFS='|' read -r reviewer state submitted body; do
                    echo "  @$reviewer: $state (submitted: $submitted)"
                    if [ -n "$body" ]; then
                        echo "    Comment: $body"
                    fi
                done <<< "$REVIEWS"
            fi
            echo ""
            
            # Check if current user has already reviewed
            CURRENT_USER=$(gh auth status 2>&1 | grep "Logged in" | sed 's/.*account \(.*\) (.*/\1/')
            USER_REVIEW=$(echo "$REVIEWS" | grep "^${CURRENT_USER}|" | cut -d'|' -f2)
            
            if [ -n "$USER_REVIEW" ]; then
                echo "Your review status: $USER_REVIEW"
            else
                echo "You have not reviewed this PR yet."
            fi
            echo ""
            
            # Check merge readiness
            echo "Merge Readiness:"
            CHECKS=$(gh pr checks "$PR_NUMBER" --json name,status,conclusion 2>/dev/null)
            
            if [ -n "$CHECKS" ] && [ "$CHECKS" != "[]" ]; then
                echo "  Status Checks:"
                echo "$CHECKS" | jq -r '.[] | "    \(.name): \(.status) (\(.conclusion // "pending"))"'
            else
                echo "  No status checks configured"
            fi
            
            echo ""
            exit 0
        fi
        
        echo "=========================================="
        echo "Pull Request Approval"
        echo "=========================================="
        echo "Repository: $REPO_NAME ($REPO_FULL)"
        echo "PR: #$PR_NUMBER - $PR_TITLE"
        echo "Author: @$PR_AUTHOR"
        echo "Branch: $PR_HEAD -> $PR_BASE"
        echo "=========================================="
        echo ""
        
        # Check PR state
        if [ "$PR_STATE" != "OPEN" ]; then
            echo "Error: PR #$PR_NUMBER is not open (state: $PR_STATE)"
            exit 1
        fi
        
        if [ "$PR_IS_DRAFT" = "true" ] && [ "$REVIEW_STATE" = "APPROVE" ]; then
            echo "Error: Cannot approve a draft PR"
            echo "The PR must be marked as ready for review first."
            exit 1
        fi
        
        # Set review body (prefer --body over --comment)
        REVIEW_BODY=""
        if [ -n "$BODY" ]; then
            REVIEW_BODY="$BODY"
        elif [ -n "$COMMENT" ]; then
            REVIEW_BODY="$COMMENT"
        fi
        
        # Default messages for different review states
        if [ -z "$REVIEW_BODY" ]; then
            case "$REVIEW_STATE" in
                APPROVE)
                    REVIEW_BODY="Approved via gitRepoUtils.sh"
                    ;;
                REQUEST_CHANGES)
                    REVIEW_BODY="Changes requested via gitRepoUtils.sh"
                    ;;
                COMMENT)
                    REVIEW_BODY="Comment added via gitRepoUtils.sh"
                    ;;
            esac
        fi
        
        # Show what will be done
        echo "Review Action:"
        echo "  State: $REVIEW_STATE"
        if [ -n "$REVIEW_BODY" ]; then
            echo "  Comment: $REVIEW_BODY"
        fi
        
        if [ "$MERGE" = true ]; then
            echo ""
            echo "Post-Approval Actions:"
            echo "  [OK] Will merge PR after approval"
            echo "  Method: $MERGE_METHOD"
            if [ "$DELETE_BRANCH" = true ]; then
                echo "  [OK] Will delete branch after merge"
            fi
            if [ "$BYPASS_RESTRICTIONS" = true ]; then
                echo "  [!] Will bypass branch protection (admin only)"
            fi
        fi
        echo ""
        
        # Confirm unless force flag is set
        if [ "$FORCE" = false ]; then
            echo "=========================================="
            echo "CONFIRMATION REQUIRED"
            echo "=========================================="
            echo ""
            
            case "$REVIEW_STATE" in
                APPROVE)
                    echo "You are about to APPROVE pull request #$PR_NUMBER"
                    ;;
                REQUEST_CHANGES)
                    echo "You are about to REQUEST CHANGES on pull request #$PR_NUMBER"
                    echo "This will block the PR from being merged until changes are made."
                    ;;
                COMMENT)
                    echo "You are about to add a COMMENT to pull request #$PR_NUMBER"
                    ;;
            esac
            
            if [ "$MERGE" = true ]; then
                echo "The PR will be MERGED immediately after approval."
            fi
            
            echo ""
            read -p "Are you sure you want to proceed? (yes/no): " -r
            echo ""
            
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                echo "Operation cancelled."
                exit 0
            fi
        fi
        
        # Submit the review
        echo "Submitting review..."
        
        REVIEW_CMD="gh pr review $PR_NUMBER --$( echo "$REVIEW_STATE" | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')"
        
        if [ -n "$REVIEW_BODY" ]; then
            REVIEW_CMD="$REVIEW_CMD --body \"$REVIEW_BODY\""
        fi
        
        # Execute review command
        if eval "$REVIEW_CMD" 2>&1; then
            echo "[OK] Review submitted successfully"
            
            case "$REVIEW_STATE" in
                APPROVE)
                    echo "[OK] Pull request #$PR_NUMBER approved"
                    ;;
                REQUEST_CHANGES)
                    echo "[OK] Changes requested on pull request #$PR_NUMBER"
                    ;;
                COMMENT)
                    echo "[OK] Comment added to pull request #$PR_NUMBER"
                    ;;
            esac
        else
            echo "[FAIL] Failed to submit review"
            exit 1
        fi
        echo ""
        
        # If merge flag is set and approval was given
        if [ "$MERGE" = true ] && [ "$REVIEW_STATE" = "APPROVE" ]; then
            echo "=========================================="
            echo "Merging Pull Request"
            echo "=========================================="
            echo ""
            
            # Build merge command
            MERGE_CMD="gh pr merge $PR_NUMBER --$MERGE_METHOD"
            
            if [ "$DELETE_BRANCH" = true ]; then
                MERGE_CMD="$MERGE_CMD --delete-branch"
            fi
            
            if [ "$BYPASS_RESTRICTIONS" = true ]; then
                MERGE_CMD="$MERGE_CMD --admin"
            fi
            
            echo "Merging PR #$PR_NUMBER using $MERGE_METHOD method..."
            
            if eval "$MERGE_CMD" 2>&1; then
                echo "[OK] Pull request #$PR_NUMBER merged successfully"
                
                if [ "$DELETE_BRANCH" = true ]; then
                    echo "[OK] Branch '$PR_HEAD' deleted"
                fi
            else
                echo "[FAIL] Failed to merge pull request"
                echo ""
                echo "The PR may not be ready to merge. Check:"
                echo "  - Required status checks"
                echo "  - Branch protection rules"
                echo "  - Merge conflicts"
                echo "  - Other required approvals"
                echo ""
                echo "You can check the status with:"
                echo "  gh pr status"
                echo "  gh pr checks $PR_NUMBER"
                exit 1
            fi
        fi
        
        echo ""
        echo "=========================================="
        echo "Complete!"
        echo "=========================================="
        echo ""
        
        # Show PR URL
        PR_URL=$(gh pr view "$PR_NUMBER" --json url -q .url 2>/dev/null)
        if [ -n "$PR_URL" ]; then
            echo "View PR: $PR_URL"
        fi
        
        # Enable auto-merge if requested
        if [ "$ENABLE_AUTO_MERGE" = true ] && [ "$REVIEW_STATE" = "APPROVE" ]; then
            echo ""
            echo "=========================================="
            echo "Enabling Auto-Merge"
            echo "=========================================="
            echo ""
            
            # Use the same merge method and delete-branch settings
            AUTO_MERGE_CMD="gh pr merge $PR_NUMBER --auto --$MERGE_METHOD"
            
            if [ "$DELETE_BRANCH" = true ]; then
                AUTO_MERGE_CMD="$AUTO_MERGE_CMD --delete-branch"
            fi
            
            echo "Enabling auto-merge with $MERGE_METHOD method..."
            
            if eval "$AUTO_MERGE_CMD" 2>&1; then
                echo "[OK] Auto-merge enabled successfully"
                echo ""
                echo "PR #$PR_NUMBER will automatically merge when all requirements are met."
            else
                echo "[FAIL] Failed to enable auto-merge"
                echo ""
                echo "Note: Auto-merge may not be enabled in repository settings."
                echo "You can enable it manually with:"
                echo "  $0 enable-auto-merge --pr $PR_NUMBER $GIT_DIR"
            fi
        fi
        
        # Show next steps
        if [ "$REVIEW_STATE" = "APPROVE" ] && [ "$MERGE" = false ]; then
            echo ""
            echo "Next steps:"
            echo "  - Wait for required status checks to pass"
            echo "  - Ensure all required approvals are obtained"
            echo "  - Merge the PR when ready:"
            echo "    gh pr merge $PR_NUMBER --$MERGE_METHOD"
        elif [ "$REVIEW_STATE" = "REQUEST_CHANGES" ]; then
            echo ""
            echo "Next steps:"
            echo "  - Author should address the requested changes"
            echo "  - Re-review after changes are made"
            echo "  - Approve when satisfied with changes"
        fi
        
        exit 0
        ;;
        

    my-prs)
        # Handle my-prs command - list your PRs with date range filtering
        
        # Color codes for better readability
        MY_PRS_RED='\033[0;31m'
        MY_PRS_GREEN='\033[0;32m'
        MY_PRS_YELLOW='\033[1;33m'
        MY_PRS_BLUE='\033[0;34m'
        MY_PRS_PURPLE='\033[0;35m'
        MY_PRS_CYAN='\033[0;36m'
        MY_PRS_NC='\033[0m' # No Color
        
        # Default values
        MY_PRS_GIT_DIR=""
        MY_PRS_DAYS=""
        MY_PRS_START_DATE=""
        MY_PRS_END_DATE=""
        MY_PRS_SHOW_SUMMARY=true
        MY_PRS_SHOW_URL=false
        MY_PRS_FORMAT="normal"
        MY_PRS_AUTHOR="@me"
        MY_PRS_STATE="all"
        MY_PRS_LIMIT=100
        MY_PRS_RECURSIVE=false
        MY_PRS_PATTERN=""
        MY_PRS_DATE_FILTER="updated"  # updated or created
        MY_PRS_DEBUG=false
        
        # Helper function to validate date format
        my_prs_validate_date() {
            local date_str="$1"
            if [[ ! "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                echo "Error: Invalid date format '$date_str'. Use YYYY-MM-DD format."
                exit 1
            fi
            
            # Check if date is valid
            if [[ "$OSTYPE" == "darwin"* ]]; then
                date -j -f "%Y-%m-%d" "$date_str" "+%Y-%m-%d" >/dev/null 2>&1 || {
                    echo "Error: Invalid date '$date_str'"
                    exit 1
                }
            else
                date -d "$date_str" "+%Y-%m-%d" >/dev/null 2>&1 || {
                    echo "Error: Invalid date '$date_str'"
                    exit 1
                }
            fi
        }
        
        # Helper function to calculate date based on OS
        my_prs_calculate_date_ago() {
            local days_ago=$1
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                date -v-${days_ago}d '+%Y-%m-%d'
            else
                # Linux
                date -d "${days_ago} days ago" '+%Y-%m-%d'
            fi
        }
        
        # Helper function to get today's date
        my_prs_get_today() {
            date '+%Y-%m-%d'
        }
        
        # Helper function to check if directory is a git repository
        my_prs_is_git_repo() {
            local dir="${1:-.}"
            (cd "$dir" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1)
        }
        
        # Helper function to get repository info
        my_prs_get_repo_info() {
            local dir="${1:-.}"
            (cd "$dir" 2>/dev/null && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || echo ""
        }
        
        # Helper function to find git repositories
        my_prs_find_git_repos() {
            local search_dir="${1:-.}"
            local pattern="${2:-*}"
            
            if [[ "$MY_PRS_RECURSIVE" == "true" ]]; then
                # Find all git repositories recursively
                find "$search_dir" -type d -name ".git" 2>/dev/null | while read -r git_dir; do
                    local repo_dir=$(dirname "$git_dir")
                    local repo_name=$(basename "$repo_dir")
                    
                    # Apply pattern filter if specified
                    if [[ -z "$pattern" ]] || [[ "$repo_name" == $pattern ]]; then
                        if my_prs_is_git_repo "$repo_dir"; then
                            echo "$repo_dir"
                        fi
                    fi
                done
            else
                # Just check the provided directory
                if my_prs_is_git_repo "$search_dir"; then
                    echo "$search_dir"
                fi
            fi
        }
        
        # Helper function to get PRs for a repository
        my_prs_get_prs_for_repo() {
            local repo_dir="$1"
            local repo_name="$2"
            local start_date="$3"
            local end_date="$4"
            
            # Build search query
            local search_query="author:${MY_PRS_AUTHOR}"
            
            # Add date range - use updated filter by default, created for --created-only
            if [[ "$MY_PRS_DATE_FILTER" == "created" ]]; then
                if [[ -n "$start_date" && -n "$end_date" ]]; then
                    if [[ "$start_date" == "$end_date" ]]; then
                        search_query="$search_query created:$start_date"
                    else
                        search_query="$search_query created:>=${start_date} created:<=${end_date}"
                    fi
                elif [[ -n "$start_date" ]]; then
                    search_query="$search_query created:>=${start_date}"
                else
                    local yesterday=$(my_prs_calculate_date_ago 1)
                    search_query="$search_query created:>${yesterday}"
                fi
            else
                # Default: filter by updated date (includes activity)
                if [[ -n "$start_date" && -n "$end_date" ]]; then
                    if [[ "$start_date" == "$end_date" ]]; then
                        search_query="$search_query updated:$start_date"
                    else
                        search_query="$search_query updated:>=${start_date} updated:<=${end_date}"
                    fi
                elif [[ -n "$start_date" ]]; then
                    search_query="$search_query updated:>=${start_date}"
                else
                    local yesterday=$(my_prs_calculate_date_ago 1)
                    search_query="$search_query updated:>${yesterday}"
                fi
            fi
            
            # Add repository filter
            search_query="$search_query repo:${repo_name}"
            
            # Add state filter for search (unless it's "all")
            if [[ "$MY_PRS_STATE" != "all" ]]; then
                if [[ "$MY_PRS_STATE" == "merged" ]]; then
                    search_query="$search_query is:merged"
                else
                    search_query="$search_query is:${MY_PRS_STATE}"
                fi
            fi
            
            # Debug mode - show the query
            if [[ "$MY_PRS_DEBUG" == "true" ]]; then
                echo -e "${MY_PRS_YELLOW}Debug: Search query: $search_query${MY_PRS_NC}" >&2
            fi
            
            # Execute the query
            gh pr list \
                --repo "$repo_name" \
                --search "$search_query" \
                --state all \
                --limit "$MY_PRS_LIMIT" \
                --json number,title,additions,deletions,changedFiles,state,headRepository,url,createdAt,closedAt,mergedAt,updatedAt,author
        }
        
        # Helper function to format PR output
        my_prs_format_pr_output() {
            local json_data="$1"
            local repo_dir="$2"
            
            # Check if there are any PRs
            if [[ -z "$json_data" ]] || [[ "$json_data" == "[]" ]]; then
                return
            fi
            
            if [[ "$MY_PRS_FORMAT" == "compact" ]]; then
                echo "$json_data" | jq -r '.[] |
                    "#\(.number) [\(.state)] +\(.additions)/-\(.deletions) (\(.changedFiles)f) \(.title)"'
            elif [[ "$MY_PRS_FORMAT" == "verbose" ]]; then
                echo "$json_data" | jq -r '.[] |
                    "----------------------------------------\n" +
                    "PR #\(.number): \(.title)\n" +
                    "State: \(.state)\n" +
                    "Author: \(.author.login)\n" +
                    "Created: \(.createdAt)\n" +
                    "Updated: \(.updatedAt)\n" +
                    (if .mergedAt then "Merged: \(.mergedAt)\n" elif .closedAt then "Closed: \(.closedAt)\n" else "" end) +
                    "Changes: +\(.additions) -\(.deletions) (\(.changedFiles) files)\n" +
                    (if "'"$MY_PRS_SHOW_URL"'" == "true" then "URL: \(.url)\n" else "" end)'
            else
                # Normal format
                if [[ "$MY_PRS_SHOW_URL" == "true" ]]; then
                    echo "$json_data" | jq -r '.[] |
                        "#\(.number) [\(.state)] +\(.additions)/-\(.deletions) (\(.changedFiles) files)\n" +
                        "  \(.title)\n" +
                        "  \(.url)"'
                else
                    echo "$json_data" | jq -r '.[] |
                        "#\(.number) [\(.state)] +\(.additions)/-\(.deletions) (\(.changedFiles) files)\n" +
                        "  \(.title)"'
                fi
            fi
        }
        
        # Helper function to show summary
        my_prs_show_summary() {
            local json_data="$1"
            
            if [[ -z "$json_data" ]] || [[ "$json_data" == "[]" ]]; then
                echo "No PRs found"
                return
            fi
            
            echo "$json_data" | jq -r '
                group_by(.state) | 
                map({state: .[0].state, count: length}) | 
                .[] | "\(.state): \(.count)"'
            
            local total=$(echo "$json_data" | jq 'length')
            echo -e "${MY_PRS_GREEN}Total: $total PRs${MY_PRS_NC}"
        }
        
        # Parse command line arguments
        POSITIONAL_ARGS=()
        while [[ $# -gt 0 ]]; do
            case $1 in
                --days)
                    MY_PRS_DAYS="$2"
                    shift 2
                    ;;
                --yesterday)
                    # Set to yesterday's date specifically
                    MY_PRS_START_DATE=$(my_prs_calculate_date_ago 1)
                    MY_PRS_END_DATE=$(my_prs_calculate_date_ago 1)
                    shift
                    ;;
                --start-date)
                    MY_PRS_START_DATE="$2"
                    my_prs_validate_date "$MY_PRS_START_DATE"
                    shift 2
                    ;;
                --end-date)
                    MY_PRS_END_DATE="$2"
                    my_prs_validate_date "$MY_PRS_END_DATE"
                    shift 2
                    ;;
                --no-summary)
                    MY_PRS_SHOW_SUMMARY=false
                    shift
                    ;;
                --with-urls)
                    MY_PRS_SHOW_URL=true
                    shift
                    ;;
                --compact)
                    MY_PRS_FORMAT="compact"
                    shift
                    ;;
                --verbose)
                    MY_PRS_FORMAT="verbose"
                    shift
                    ;;
                --no-color)
                    MY_PRS_RED=''
                    MY_PRS_GREEN=''
                    MY_PRS_YELLOW=''
                    MY_PRS_BLUE=''
                    MY_PRS_PURPLE=''
                    MY_PRS_CYAN=''
                    MY_PRS_NC=''
                    shift
                    ;;
                --created-only)
                    MY_PRS_DATE_FILTER="created"
                    shift
                    ;;
                --debug)
                    MY_PRS_DEBUG=true
                    shift
                    ;;
                --author)
                    MY_PRS_AUTHOR="$2"
                    shift 2
                    ;;
                --state)
                    MY_PRS_STATE="$2"
                    if [[ ! "$MY_PRS_STATE" =~ ^(all|open|closed|merged)$ ]]; then
                        echo "Error: Invalid state '$MY_PRS_STATE'. Must be: all, open, closed, or merged"
                        exit 1
                    fi
                    shift 2
                    ;;
                --limit)
                    MY_PRS_LIMIT="$2"
                    shift 2
                    ;;
                --recursive)
                    MY_PRS_RECURSIVE=true
                    shift
                    ;;
                --pattern)
                    MY_PRS_PATTERN="$2"
                    shift 2
                    ;;
                -h|--help)
                    show_my_prs_usage
                    exit 0
                    ;;
                -*)
                    echo "Unknown option: $1"
                    show_my_prs_usage
                    exit 1
                    ;;
                *)
                    POSITIONAL_ARGS+=("$1")
                    shift
                    ;;
            esac
        done
        
        # Get git directory from positional arguments
        if [[ ${#POSITIONAL_ARGS[@]} -gt 0 ]]; then
            MY_PRS_GIT_DIR="${POSITIONAL_ARGS[0]}"
        else
            MY_PRS_GIT_DIR="."
        fi
        
        # Expand path (handle ~ and environment variables)
        MY_PRS_GIT_DIR=$(eval echo "$MY_PRS_GIT_DIR")
        
        # Strip trailing slash for consistent handling
        MY_PRS_GIT_DIR="${MY_PRS_GIT_DIR%/}"
        
        # Smart path resolution:
        # For non-absolute, non-dot paths, prefer ~/projects/ location if it exists
        if [[ ! "$MY_PRS_GIT_DIR" = /* ]] && [[ ! "$MY_PRS_GIT_DIR" = "." ]] && [[ ! "$MY_PRS_GIT_DIR" = ".." ]] && [[ ! "$MY_PRS_GIT_DIR" = ./* ]]; then
            ORIGINAL_PATH="$MY_PRS_GIT_DIR"
            
            # Check if this looks like a project name (not a relative path with directories)
            if [[ ! "$MY_PRS_GIT_DIR" = */* ]] || [[ "$MY_PRS_GIT_DIR" = */ ]]; then
                BASE_NAME="${MY_PRS_GIT_DIR%%/*}"
                
                # Check ~/projects/ first (canonical location)
                if [[ -d "$HOME/projects/$BASE_NAME" ]]; then
                    MY_PRS_GIT_DIR="$HOME/projects/$BASE_NAME"
                    if [[ "$MY_PRS_DEBUG" == "true" ]]; then
                        echo -e "${MY_PRS_YELLOW}Debug: Using canonical path ~/projects/$BASE_NAME${MY_PRS_NC}" >&2
                    fi
                # Then check ~/
                elif [[ -d "$HOME/$BASE_NAME" ]]; then
                    MY_PRS_GIT_DIR="$HOME/$BASE_NAME"
                    if [[ "$MY_PRS_DEBUG" == "true" ]]; then
                        echo -e "${MY_PRS_YELLOW}Debug: Using home path ~/$BASE_NAME${MY_PRS_NC}" >&2
                    fi
                # Fall back to relative if canonical locations don't have it
                elif [[ -d "$ORIGINAL_PATH" ]]; then
                    MY_PRS_GIT_DIR="$ORIGINAL_PATH"
                    if [[ "$MY_PRS_DEBUG" == "true" ]]; then
                        echo -e "${MY_PRS_YELLOW}Debug: Using relative path $ORIGINAL_PATH${MY_PRS_NC}" >&2
                    fi
                else
                    echo "Error: Directory '$ORIGINAL_PATH' does not exist"
                    echo ""
                    echo "Searched locations:"
                    echo "  - $HOME/projects/$BASE_NAME"
                    echo "  - $HOME/$BASE_NAME"
                    echo "  - $(pwd)/$ORIGINAL_PATH"
                    exit 1
                fi
            else
                # It's a relative path with subdirectories - use as-is if it exists
                if [[ ! -d "$MY_PRS_GIT_DIR" ]]; then
                    echo "Error: Directory '$MY_PRS_GIT_DIR' does not exist"
                    exit 1
                fi
            fi
        elif [[ ! -d "$MY_PRS_GIT_DIR" ]]; then
            echo "Error: Directory '$MY_PRS_GIT_DIR' does not exist"
            exit 1
        fi
        
        # Convert to absolute path
        MY_PRS_GIT_DIR=$(cd "$MY_PRS_GIT_DIR" 2>/dev/null && pwd || echo "$MY_PRS_GIT_DIR")
        
        # Debug: show resolved path
        if [[ "$MY_PRS_DEBUG" == "true" ]]; then
            echo -e "${MY_PRS_YELLOW}Debug: Resolved path: $MY_PRS_GIT_DIR${MY_PRS_NC}" >&2
        fi
        
        # Validate date options (mutually exclusive with --days)
        if [[ -n "$MY_PRS_DAYS" ]] && [[ -n "$MY_PRS_START_DATE" ]]; then
            echo "Error: Cannot use both --days and --start-date/--yesterday options"
            exit 1
        fi
        
        # Determine date range (skip if already set by --yesterday)
        if [[ -z "$MY_PRS_START_DATE" ]]; then
            if [[ -n "$MY_PRS_DAYS" ]]; then
                # Use days ago
                MY_PRS_START_DATE=$(my_prs_calculate_date_ago "$MY_PRS_DAYS")
                MY_PRS_END_DATE=$(my_prs_get_today)
            elif [[ -n "$MY_PRS_END_DATE" ]]; then
                # Only end date provided, error
                echo "Error: --end-date requires --start-date"
                exit 1
            else
                # No date options provided - default to today (last 1 day)
                MY_PRS_START_DATE=$(my_prs_calculate_date_ago 1)
                MY_PRS_END_DATE=$(my_prs_get_today)
            fi
        elif [[ -z "$MY_PRS_END_DATE" ]]; then
            # Start date provided but no end date (and not --yesterday)
            MY_PRS_END_DATE=$(my_prs_get_today)
        fi
        
        # Validate date range
        if [[ "$MY_PRS_START_DATE" > "$MY_PRS_END_DATE" ]]; then
            echo "Error: Start date ($MY_PRS_START_DATE) is after end date ($MY_PRS_END_DATE)"
            exit 1
        fi
        
        # Check for required tools
        if ! command -v gh >/dev/null 2>&1; then
            echo "Error: GitHub CLI (gh) is not installed"
            echo "Please install it from: https://cli.github.com/"
            exit 1
        fi
        
        if ! command -v jq >/dev/null 2>&1; then
            echo "Error: jq is not installed"
            echo "Please install it: https://stedolan.github.io/jq/"
            exit 1
        fi
        
        # Check if gh is authenticated
        if ! gh auth status >/dev/null 2>&1; then
            echo "Error: GitHub CLI is not authenticated"
            echo "Please run: gh auth login"
            exit 1
        fi
        
        # Find repositories
        REPOS=$(my_prs_find_git_repos "$MY_PRS_GIT_DIR" "$MY_PRS_PATTERN")
        
        if [[ -z "$REPOS" ]]; then
            echo "Error: No git repositories found in '$MY_PRS_GIT_DIR'"
            if [[ "$MY_PRS_RECURSIVE" == "true" ]]; then
                echo "Searched recursively with pattern: ${MY_PRS_PATTERN:-*}"
            fi
            exit 1
        fi
        
        # Print header
        echo -e "${MY_PRS_BLUE}=========================================="
        echo "Pull Requests Report"
        echo "=========================================="
        echo -e "Date Range: $MY_PRS_START_DATE to $MY_PRS_END_DATE"
        echo -e "Date Filter: PRs ${MY_PRS_DATE_FILTER} in this range"
        echo -e "Author: $MY_PRS_AUTHOR"
        echo -e "State: $MY_PRS_STATE"
        if [[ "$MY_PRS_RECURSIVE" == "true" ]]; then
            echo -e "Directory: $MY_PRS_GIT_DIR (recursive)"
            [[ -n "$MY_PRS_PATTERN" ]] && echo -e "Pattern: $MY_PRS_PATTERN"
        else
            echo -e "Directory: $MY_PRS_GIT_DIR"
        fi
        echo -e "==========================================${MY_PRS_NC}"
        echo ""
        
        # Process each repository
        ALL_PRS="[]"
        REPO_COUNT=0
        
        while IFS= read -r repo_dir; do
            if [[ -n "$repo_dir" ]]; then
                # Get repository name from GitHub
                REPO_NAME=$(my_prs_get_repo_info "$repo_dir")
                
                if [[ -z "$REPO_NAME" ]]; then
                    echo -e "${MY_PRS_YELLOW}Warning: Skipping $repo_dir (no GitHub remote)${MY_PRS_NC}" >&2
                    continue
                fi
                
                ((REPO_COUNT++))
                
                echo -e "${MY_PRS_PURPLE}Repository: $REPO_NAME${MY_PRS_NC}"
                echo -e "${MY_PRS_PURPLE}Path: $repo_dir${MY_PRS_NC}"
                echo "----------------------------------------"
                
                # Get PRs for this repository
                REPO_PRS=$(my_prs_get_prs_for_repo "$repo_dir" "$REPO_NAME" "$MY_PRS_START_DATE" "$MY_PRS_END_DATE")
                
                if [[ -n "$REPO_PRS" ]] && [[ "$REPO_PRS" != "[]" ]]; then
                    my_prs_format_pr_output "$REPO_PRS" "$repo_dir"
                    # Accumulate for summary
                    ALL_PRS=$(echo "$ALL_PRS $REPO_PRS" | jq -s 'add')
                else
                    echo "  No PRs found"
                fi
                echo ""
            fi
        done <<< "$REPOS"
        
        # Show summary if enabled
        if [[ "$MY_PRS_SHOW_SUMMARY" == "true" ]]; then
            echo -e "${MY_PRS_CYAN}=========================================="
            echo "Summary"
            echo -e "==========================================${MY_PRS_NC}"
            
            if [[ "$REPO_COUNT" -gt 1 ]]; then
                echo "Repositories searched: $REPO_COUNT"
                echo ""
            fi
            
            my_prs_show_summary "$ALL_PRS"
        fi
        
        # Exit with appropriate code
        if [[ "$ALL_PRS" == "[]" ]]; then
            exit 1
        else
            exit 0
        fi
        ;;
        

    enable-auto-merge)
        # Handle enable-auto-merge command
        
        # Default options
        PR_NUMBER=""
        MERGE_METHOD="squash"
        DELETE_BRANCH=true
        NO_DELETE_BRANCH=false
        APPROVE=false
        COMMENT=""
        DISABLE=false
        CHECK_STATUS=false
        LIST_ALL=false
        FORCE=false
        GIT_DIR=""
        
        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --pr)
                    PR_NUMBER="$2"
                    shift 2
                    ;;
                --merge-method)
                    MERGE_METHOD="$2"
                    shift 2
                    ;;
                --delete-branch)
                    DELETE_BRANCH=true
                    NO_DELETE_BRANCH=false
                    shift
                    ;;
                --no-delete-branch)
                    DELETE_BRANCH=false
                    NO_DELETE_BRANCH=true
                    shift
                    ;;
                --approve)
                    APPROVE=true
                    shift
                    ;;
                --comment)
                    COMMENT="$2"
                    shift 2
                    ;;
                --disable)
                    DISABLE=true
                    shift
                    ;;
                --status)
                    CHECK_STATUS=true
                    shift
                    ;;
                --list)
                    LIST_ALL=true
                    shift
                    ;;
                --force)
                    FORCE=true
                    shift
                    ;;
                -h|--help)
                    show_enable_auto_merge_usage
                    exit 0
                    ;;
                -*)
                    echo "Error: Unknown option: $1"
                    echo "Run '$0 enable-auto-merge --help' for usage information."
                    exit 1
                    ;;
                *)
                    if [ -z "$GIT_DIR" ]; then
                        GIT_DIR="$1"
                    else
                        echo "Error: Multiple git directories specified"
                        echo "Usage: $0 enable-auto-merge [options] <git-directory>"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done
        
        # Check if git directory was provided
        if [ -z "$GIT_DIR" ]; then
            echo "Error: No git directory specified"
            echo "Usage: $0 enable-auto-merge [options] <git-directory>"
            echo "Run '$0 enable-auto-merge --help' for more information."
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
        
        # Validate merge method
        if [[ ! "$MERGE_METHOD" =~ ^(merge|squash|rebase)$ ]]; then
            echo "Error: Invalid merge method '$MERGE_METHOD'"
            echo "Must be: merge, squash, or rebase"
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
        
        # If listing all PRs with auto-merge
        if [ "$LIST_ALL" = true ]; then
            echo "=========================================="
            echo "PRs with Auto-Merge Enabled"
            echo "=========================================="
            echo "Repository: $REPO_NAME ($REPO_FULL)"
            echo "=========================================="
            echo ""
            
            echo "Fetching pull requests with auto-merge enabled..."
            
            # Get all open PRs and check their auto-merge status
            PR_LIST=$(gh pr list --repo "$REPO_FULL" --state open --json number,title,author,autoMergeRequest \
                --jq '.[] | select(.autoMergeRequest != null)' 2>/dev/null)
            
            if [ -z "$PR_LIST" ]; then
                echo "No pull requests have auto-merge enabled."
            else
                echo "PR#  | Title | Author | Merge Method"
                echo "-----+-------+--------+-------------"
                
                echo "$PR_LIST" | jq -r '. | "#\(.number) | \(.title[0:40]) | @\(.author.login) | \(.autoMergeRequest.mergeMethod)"'
            fi
            echo ""
            exit 0
        fi
        
        # If no PR number specified, try to find PR for current branch
        if [ -z "$PR_NUMBER" ]; then
            echo "No PR number specified, checking for PR associated with current branch..."
            
            # Get current branch name
            CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
            
            if [ -z "$CURRENT_BRANCH" ]; then
                echo "Error: Could not determine current branch"
                echo "Please specify PR number with --pr NUMBER"
                exit 1
            fi
            
            echo "Current branch: $CURRENT_BRANCH"
            
            # Find PR for this branch
            PR_NUMBER=$(gh pr list --head "$CURRENT_BRANCH" --json number -q '.[0].number' 2>/dev/null || echo "")
            
            if [ -z "$PR_NUMBER" ]; then
                echo "Error: No PR found for branch '$CURRENT_BRANCH'"
                echo "Please specify PR number with --pr NUMBER"
                exit 1
            fi
            
            echo "Found PR #$PR_NUMBER for branch '$CURRENT_BRANCH'"
            echo ""
        fi
        
        # Get PR details
        PR_DETAILS=$(gh pr view "$PR_NUMBER" --json number,title,author,state,isDraft,headRefName,baseRefName,mergeable,autoMergeRequest 2>/dev/null || echo "")
        
        if [ -z "$PR_DETAILS" ]; then
            echo "Error: Pull request #$PR_NUMBER not found"
            exit 1
        fi
        
        # Parse PR details
        PR_TITLE=$(echo "$PR_DETAILS" | jq -r '.title')
        PR_AUTHOR=$(echo "$PR_DETAILS" | jq -r '.author.login')
        PR_STATE=$(echo "$PR_DETAILS" | jq -r '.state')
        PR_IS_DRAFT=$(echo "$PR_DETAILS" | jq -r '.isDraft')
        PR_HEAD=$(echo "$PR_DETAILS" | jq -r '.headRefName')
        PR_BASE=$(echo "$PR_DETAILS" | jq -r '.baseRefName')
        PR_MERGEABLE=$(echo "$PR_DETAILS" | jq -r '.mergeable')
        AUTO_MERGE_REQUEST=$(echo "$PR_DETAILS" | jq -r '.autoMergeRequest')
        
        echo "=========================================="
        if [ "$DISABLE" = true ]; then
            echo "Disable Auto-Merge"
        elif [ "$CHECK_STATUS" = true ]; then
            echo "Auto-Merge Status Check"
        else
            echo "Enable Auto-Merge"
        fi
        echo "=========================================="
        echo "Repository: $REPO_NAME ($REPO_FULL)"
        echo "PR: #$PR_NUMBER - $PR_TITLE"
        echo "Author: @$PR_AUTHOR"
        echo "Branch: $PR_HEAD -> $PR_BASE"
        echo "=========================================="
        echo ""
        
        # Check current auto-merge status
        if [ "$CHECK_STATUS" = true ]; then
            if [ "$AUTO_MERGE_REQUEST" != "null" ]; then
                MERGE_METHOD_CURRENT=$(echo "$AUTO_MERGE_REQUEST" | jq -r '.mergeMethod')
                ENABLED_BY=$(echo "$AUTO_MERGE_REQUEST" | jq -r '.enabledBy.login')
                ENABLED_AT=$(echo "$AUTO_MERGE_REQUEST" | jq -r '.enabledAt // "unknown"')
                
                echo "Auto-merge is ENABLED"
                echo "  Method: $MERGE_METHOD_CURRENT"
                echo "  Enabled by: @$ENABLED_BY"
                if [ "$ENABLED_AT" != "unknown" ] && [ "$ENABLED_AT" != "null" ]; then
                    echo "  Enabled at: $ENABLED_AT"
                fi
                echo ""
                echo "The PR will automatically merge when all requirements are met."
            else
                echo "Auto-merge is DISABLED"
                echo ""
                echo "To enable auto-merge, run:"
                echo "  $0 enable-auto-merge --pr $PR_NUMBER $GIT_DIR"
            fi
            
            # Show merge readiness
            echo ""
            echo "Merge Readiness:"
            echo "  State: $PR_STATE"
            echo "  Draft: $PR_IS_DRAFT"
            echo "  Mergeable: $PR_MERGEABLE"
            
            # Check status checks
            echo ""
            echo "Status Checks:"
            CHECKS=$(gh pr checks "$PR_NUMBER" --json name,status,conclusion 2>/dev/null)
            if [ -n "$CHECKS" ] && [ "$CHECKS" != "[]" ]; then
                echo "$CHECKS" | jq -r '.[] | "  \(.name): \(.status) (\(.conclusion // "pending"))"'
            else
                echo "  No status checks configured"
            fi
            
            exit 0
        fi
        
        # Check PR state
        if [ "$PR_STATE" != "OPEN" ]; then
            echo "Error: PR #$PR_NUMBER is not open (state: $PR_STATE)"
            exit 1
        fi
        
        if [ "$PR_IS_DRAFT" = "true" ]; then
            echo "Error: Cannot enable auto-merge on a draft PR"
            echo "The PR must be marked as ready for review first."
            exit 1
        fi
        
        if [ "$PR_MERGEABLE" = "CONFLICTING" ]; then
            echo "Warning: PR has merge conflicts"
            echo "Auto-merge can be enabled, but won't complete until conflicts are resolved."
            echo ""
        fi
        
        # Disable auto-merge
        if [ "$DISABLE" = true ]; then
            if [ "$AUTO_MERGE_REQUEST" = "null" ]; then
                echo "Auto-merge is already disabled for PR #$PR_NUMBER"
                exit 0
            fi
            
            echo "Disabling auto-merge for PR #$PR_NUMBER..."
            
            if gh pr merge "$PR_NUMBER" --disable-auto --repo "$REPO_FULL" 2>&1; then
                echo "[OK] Auto-merge disabled successfully"
            else
                echo "[FAIL] Failed to disable auto-merge"
                exit 1
            fi
            
            exit 0
        fi
        
        # Check if auto-merge is already enabled
        if [ "$AUTO_MERGE_REQUEST" != "null" ]; then
            CURRENT_METHOD=$(echo "$AUTO_MERGE_REQUEST" | jq -r '.mergeMethod')
            echo "[i] Auto-merge is already enabled with method: $CURRENT_METHOD"
            
            if [ "$CURRENT_METHOD" != "${MERGE_METHOD^^}" ]; then
                echo "Updating merge method to: $MERGE_METHOD"
                
                # Disable first, then re-enable with new method
                echo "Disabling current auto-merge..."
                gh pr merge "$PR_NUMBER" --disable-auto --repo "$REPO_FULL" 2>/dev/null
                
                # Continue to re-enable with new settings
            else
                echo "Auto-merge is already configured as requested."
                exit 0
            fi
        fi
        
        # Approve first if requested
        if [ "$APPROVE" = true ]; then
            echo "Approving PR before enabling auto-merge..."
            
            REVIEW_BODY=""
            if [ -n "$COMMENT" ]; then
                REVIEW_BODY="$COMMENT"
            else
                REVIEW_BODY="Approved and auto-merge enabled via gitRepoUtils.sh"
            fi
            
            if gh pr review "$PR_NUMBER" --approve --body "$REVIEW_BODY" --repo "$REPO_FULL" 2>&1; then
                echo "[OK] PR approved"
            else
                echo "[FAIL] Failed to approve PR"
                echo "Note: You may have already approved this PR"
            fi
            echo ""
        fi
        
        # Confirm unless force flag is set
        if [ "$FORCE" = false ] && [ "$AUTO_MERGE_REQUEST" = "null" ]; then
            echo "=========================================="
            echo "CONFIRMATION REQUIRED"
            echo "=========================================="
            echo ""
            echo "You are about to enable auto-merge for PR #$PR_NUMBER"
            echo ""
            echo "Settings:"
            echo "  Merge method: $MERGE_METHOD"
            if [ "$DELETE_BRANCH" = true ]; then
                echo "  Delete branch after merge: Yes"
            else
                echo "  Delete branch after merge: No"
            fi
            echo ""
            echo "The PR will automatically merge when:"
            echo "  - All required status checks pass"
            echo "  - All required approvals are obtained"
            echo "  - No merge conflicts exist"
            echo ""
            read -p "Are you sure you want to proceed? (yes/no): " -r
            echo ""
            
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                echo "Operation cancelled."
                exit 0
            fi
        fi
        
        # Enable auto-merge
        echo "Enabling auto-merge for PR #$PR_NUMBER..."
        echo "  Method: $MERGE_METHOD"
        if [ "$DELETE_BRANCH" = true ]; then
            echo "  Branch will be deleted after merge"
        fi
        echo ""
        
        # Build the auto-merge command
        AUTO_MERGE_CMD="gh pr merge $PR_NUMBER --auto --$MERGE_METHOD --repo \"$REPO_FULL\""
        
        if [ "$DELETE_BRANCH" = true ]; then
            AUTO_MERGE_CMD="$AUTO_MERGE_CMD --delete-branch"
        fi
        
        # Execute the command
        if eval "$AUTO_MERGE_CMD" 2>&1; then
            echo "[OK] Auto-merge enabled successfully!"
            echo ""
            echo "=========================================="
            echo "Auto-Merge Enabled"
            echo "=========================================="
            echo ""
            echo "PR #$PR_NUMBER will automatically merge when all requirements are met."
            echo ""
            echo "Current status:"
            
            # Check current checks status
            CHECKS=$(gh pr checks "$PR_NUMBER" --json name,status 2>/dev/null)
            PENDING_CHECKS=$(echo "$CHECKS" | jq '[.[] | select(.status != "COMPLETED")] | length' 2>/dev/null || echo "0")
            
            if [ "$PENDING_CHECKS" -gt 0 ]; then
                echo "  - Waiting for $PENDING_CHECKS status check(s) to complete"
            else
                echo "  - All status checks completed"
            fi
            
            # Check review status
            REVIEW_DECISION=$(gh pr view "$PR_NUMBER" --json reviewDecision -q '.reviewDecision' 2>/dev/null || echo "NONE")
            case "$REVIEW_DECISION" in
                APPROVED)
                    echo "  - PR is approved"
                    ;;
                REVIEW_REQUIRED)
                    echo "  - Waiting for review approval"
                    ;;
                CHANGES_REQUESTED)
                    echo "  - Changes requested (auto-merge will be cancelled)"
                    ;;
                *)
                    echo "  - Review status: $REVIEW_DECISION"
                    ;;
            esac
            
            echo ""
            echo "Monitor progress:"
            echo "  gh pr checks $PR_NUMBER --watch"
            echo ""
            echo "Cancel auto-merge if needed:"
            echo "  $0 enable-auto-merge --pr $PR_NUMBER --disable $GIT_DIR"
            
        else
            echo "[FAIL] Failed to enable auto-merge"
            echo ""
            echo "This might be because:"
            echo "  - Auto-merge is not enabled in repository settings"
            echo "  - You don't have permission to merge PRs"
            echo "  - The PR is not in a mergeable state"
            echo ""
            echo "To enable auto-merge in repository settings:"
            echo "  1. Go to: https://github.com/$REPO_FULL/settings"
            echo "  2. Under 'Pull Requests' section"
            echo "  3. Enable 'Allow auto-merge'"
            exit 1
        fi
        
        exit 0
        ;;
        

    *)
        echo "Error: Unknown PR command: $cmd"
        return 1
        ;;
    esac
}
