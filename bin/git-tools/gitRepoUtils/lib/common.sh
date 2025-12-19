#!/bin/bash

# common.sh - Shared utilities for gitRepoUtils
# This file is sourced by the main script and command modules

# Color codes for output
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_PURPLE='\033[0;35m'
export COLOR_CYAN='\033[0;36m'
export COLOR_NC='\033[0m' # No Color

# Disable colors if requested
disable_colors() {
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_PURPLE=''
    COLOR_CYAN=''
    COLOR_NC=''
}

# Print colored output
print_info() {
    echo -e "${COLOR_BLUE}$1${COLOR_NC}"
}

print_success() {
    echo -e "${COLOR_GREEN}$1${COLOR_NC}"
}

print_warning() {
    echo -e "${COLOR_YELLOW}$1${COLOR_NC}"
}

print_error() {
    echo -e "${COLOR_RED}$1${COLOR_NC}"
}

print_header() {
    echo -e "${COLOR_CYAN}==========================================${COLOR_NC}"
    echo -e "${COLOR_CYAN}$1${COLOR_NC}"
    echo -e "${COLOR_CYAN}==========================================${COLOR_NC}"
}

# Validate that a directory exists
validate_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        print_error "Error: Directory '$dir' not found"
        exit 1
    fi
}

# Validate that a directory is a git repository
validate_git_repo() {
    local dir="$1"
    if [ ! -d "$dir/.git" ]; then
        print_error "Error: '$dir' is not a git repository"
        exit 1
    fi
}

# Check if GitHub CLI is installed
check_gh_installed() {
    if ! command -v gh >/dev/null 2>&1; then
        print_error "Error: GitHub CLI (gh) is not installed"
        echo "Please install it from: https://cli.github.com/"
        exit 1
    fi
}

# Check if GitHub CLI is authenticated
check_gh_authenticated() {
    if ! gh auth status >/dev/null 2>&1; then
        print_error "Error: GitHub CLI is not authenticated"
        echo "Please run: gh auth login"
        exit 1
    fi
}

# Check if jq is installed
check_jq_installed() {
    if ! command -v jq >/dev/null 2>&1; then
        print_error "Error: jq is not installed"
        echo "Please install it: https://stedolan.github.io/jq/"
        exit 1
    fi
}

# Get GitHub repository full name (owner/repo)
get_repo_full_name() {
    local dir="${1:-.}"
    (cd "$dir" 2>/dev/null && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || echo ""
}

# Expand and validate a git directory path
expand_git_dir() {
    local git_dir="$1"
    
    # Expand path (handle ~ and environment variables)
    git_dir=$(eval echo "$git_dir")
    
    # Convert to absolute path if possible
    if [ -d "$git_dir" ]; then
        git_dir=$(cd "$git_dir" 2>/dev/null && pwd || echo "$git_dir")
    fi
    
    echo "$git_dir"
}

# Smart path resolution for project names
# Prefers ~/projects/ location if it exists
resolve_project_path() {
    local path="$1"
    local debug="${2:-false}"
    
    # Expand path
    path=$(eval echo "$path")
    
    # Strip trailing slash
    path="${path%/}"
    
    # Handle absolute paths and explicit relative paths
    if [[ "$path" = /* ]] || [[ "$path" = "." ]] || [[ "$path" = ".." ]] || [[ "$path" = ./* ]]; then
        if [[ ! -d "$path" ]]; then
            print_error "Error: Directory '$path' does not exist"
            exit 1
        fi
        echo "$(cd "$path" && pwd)"
        return
    fi
    
    # For simple names, check canonical locations
    local original_path="$path"
    if [[ ! "$path" = */* ]] || [[ "$path" = */ ]]; then
        local base_name="${path%%/*}"
        
        # Check ~/projects/ first
        if [[ -d "$HOME/projects/$base_name" ]]; then
            [[ "$debug" == "true" ]] && print_warning "Debug: Using canonical path ~/projects/$base_name" >&2
            echo "$HOME/projects/$base_name"
            return
        fi
        
        # Then check ~/
        if [[ -d "$HOME/$base_name" ]]; then
            [[ "$debug" == "true" ]] && print_warning "Debug: Using home path ~/$base_name" >&2
            echo "$HOME/$base_name"
            return
        fi
        
        # Fall back to relative
        if [[ -d "$original_path" ]]; then
            [[ "$debug" == "true" ]] && print_warning "Debug: Using relative path $original_path" >&2
            echo "$(cd "$original_path" && pwd)"
            return
        fi
        
        print_error "Error: Directory '$original_path' does not exist"
        echo ""
        echo "Searched locations:"
        echo "  - $HOME/projects/$base_name"
        echo "  - $HOME/$base_name"  
        echo "  - $(pwd)/$original_path"
        exit 1
    fi
    
    # Relative path with subdirectories
    if [[ ! -d "$path" ]]; then
        print_error "Error: Directory '$path' does not exist"
        exit 1
    fi
    
    echo "$(cd "$path" && pwd)"
}

# Validate date format (YYYY-MM-DD)
validate_date() {
    local date_str="$1"
    if [[ ! "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        print_error "Error: Invalid date format '$date_str'. Use YYYY-MM-DD format."
        exit 1
    fi
    
    # Check if date is valid (OS-specific)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        date -j -f "%Y-%m-%d" "$date_str" "+%Y-%m-%d" >/dev/null 2>&1 || {
            print_error "Error: Invalid date '$date_str'"
            exit 1
        }
    else
        date -d "$date_str" "+%Y-%m-%d" >/dev/null 2>&1 || {
            print_error "Error: Invalid date '$date_str'"
            exit 1
        }
    fi
}

# Calculate date N days ago (OS-specific)
calculate_date_ago() {
    local days_ago=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        date -v-${days_ago}d '+%Y-%m-%d'
    else
        date -d "${days_ago} days ago" '+%Y-%m-%d'
    fi
}

# Get today's date
get_today() {
    date '+%Y-%m-%d'
}

# Check if directory is a git repository
is_git_repo() {
    local dir="${1:-.}"
    (cd "$dir" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1)
}

# Get current git user
get_current_gh_user() {
    gh auth status 2>&1 | grep "Logged in" | sed 's/.*account \(.*\) (.*/\1/'
}
