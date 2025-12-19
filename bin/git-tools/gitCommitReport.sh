#!/bin/bash

# Script to report recent Git commits from the develop branch
# Shows commit date, author, and commit message

set -e

# Function to show usage
show_usage() {
    echo "Usage: $0 [options] <git-directory>"
    echo ""
    echo "Options:"
    echo "  -n, --number NUM         Number of commits to show (default: 10)"
    echo "  -b, --branch BRANCH      Branch to check (default: develop)"
    echo "  -f, --format FORMAT      Output format: 'default', 'oneline', 'detailed' (default: default)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 ~/projects/my-project                    # Show last 10 commits from develop"
    echo "  $0 -n 20 ~/projects/my-project              # Show last 20 commits"
    echo "  $0 -b main ~/projects/my-project            # Show commits from main branch"
    echo "  $0 -f oneline ~/projects/my-project         # Show compact one-line format"
    echo "  $0 -f detailed ~/projects/my-project        # Show detailed format with hash"
    echo ""
    echo "Output formats:"
    echo "  default   - Date, Author, Message"
    echo "  oneline   - Compact single-line per commit"
    echo "  detailed  - Includes commit hash and full details"
}

# Default options
NUM_COMMITS=10
BRANCH="develop"
FORMAT="default"
GIT_DIR=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--number)
            NUM_COMMITS="$2"
            if ! [[ "$NUM_COMMITS" =~ ^[0-9]+$ ]]; then
                echo "Error: Number of commits must be a positive integer"
                exit 1
            fi
            shift 2
            ;;
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            if [[ "$FORMAT" != "default" && "$FORMAT" != "oneline" && "$FORMAT" != "detailed" ]]; then
                echo "Error: Format must be 'default', 'oneline', or 'detailed'"
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
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

# Change to git directory
cd "$GIT_DIR"

# Fetch latest changes from remote (if remote exists)
if git remote | grep -q "origin"; then
    echo "Fetching latest changes from remote..."
    if git fetch origin 2>&1; then
        echo "✓ Fetched latest commits"
    else
        echo "Warning: Failed to fetch from remote, showing local commits only..."
    fi
    echo ""
else
    echo "Note: No remote 'origin' configured, showing local commits only..."
    echo ""
fi

# Check if branch exists
if ! git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    echo "Error: Branch '$BRANCH' does not exist in this repository"
    echo ""
    echo "Available branches:"
    git branch -a
    exit 1
fi

# Get repository name (last component of path)
REPO_NAME=$(basename "$GIT_DIR")

# Get the last commit date on this branch
LAST_UPDATE=$(git log "$BRANCH" -1 --pretty=format:"%ad" --date=format:"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown")

# Get the last committer name
LAST_COMMITTER=$(git log "$BRANCH" -1 --pretty=format:"%an" 2>/dev/null || echo "Unknown")

echo "=========================================="
echo "Git Commit Report"
echo "=========================================="
echo "Repository: $REPO_NAME"
echo "Path: $GIT_DIR"
echo "Branch: $BRANCH"
echo "Last Updated: $LAST_UPDATE"
echo "Last Committer: $LAST_COMMITTER"
echo "Showing last $NUM_COMMITS commits"
echo "=========================================="
echo ""
echo "repo:$REPO_NAME:$LAST_UPDATE:$LAST_COMMITTER"
echo ""

# Generate report based on format
case $FORMAT in
    oneline)
        # Compact one-line format
        git log "$BRANCH" -n "$NUM_COMMITS" --pretty=format:"%C(yellow)%h%C(reset) - %C(cyan)%ad%C(reset) - %C(green)%an%C(reset) - %s" --date=short
        ;;
    
    detailed)
        # Detailed format with full hash and stats
        git log "$BRANCH" -n "$NUM_COMMITS" --pretty=format:"%C(yellow)Commit: %H%C(reset)%nAuthor: %C(green)%an <%ae>%C(reset)%nDate:   %C(cyan)%ad%C(reset)%n%n    %s%n%n%b" --date=format:"%Y-%m-%d %H:%M:%S" --stat
        ;;
    
    default|*)
        # Default format: Date, Author, Message
        git log "$BRANCH" -n "$NUM_COMMITS" --pretty=format:"%C(cyan)%ad%C(reset) | %C(green)%an%C(reset) | %s" --date=format:"%Y-%m-%d %H:%M"
        ;;
esac

echo ""
echo ""
echo "=========================================="
echo "Report complete"
echo "=========================================="
echo ""
echo "To see more details about a specific commit, use:"
echo "  cd $GIT_DIR"
echo "  git show <commit-hash>"
