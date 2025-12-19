#!/bin/bash

# gh-search.sh - General purpose GitHub repository search tool
# Search files across multiple repositories in a GitHub organization

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Default values
ORG="UKGEPIC"
REPO_PATTERN=""
SEARCH_PATTERN=""
FILE_PATH=""
FILE_PATTERN=""
SHOW_MATCHES=false
SHOW_FILES_ONLY=false
CASE_INSENSITIVE=false
CONTEXT_LINES=0
LOCAL_MODE=false
LOCAL_DIR="${HOME}/projects"
LIMIT=100
BRANCH="main"
SHOW_URLS=false
OPEN_IN_BROWSER=false
DOWNLOAD_DIR=""
LIST_REPOS_ONLY=false
LIST_FILES_ONLY=false
DEBUG=false
CODE_SEARCH=auto  # auto, on, off
PLAIN_OUTPUT=false

show_usage() {
    cat << EOF
Usage: $0 [options] [search-pattern]

Search files across multiple GitHub repositories in an organization.

Commands / Modes:
  (default)                Search for pattern in files
  --list-repos             Just list repositories matching pattern (no search)
  --list-files             List files at path in matching repos (no search)

Repository Options:
  -o, --org ORG            GitHub organization (default: UKGEPIC)
  -r, --repo-pattern PAT   Repository name pattern (e.g., 'ds-service-*', 'ds-*')
  -b, --branch BRANCH      Branch to search (default: main, falls back to master)
  --limit N                Max repos to process (default: 100)

File Options:
  -p, --path PATH          Path within repo to search (e.g., '.github/workflows', 'src')
                           Default: searches root, or .github/workflows if pattern looks like YAML
  -f, --file-pattern PAT   File name pattern to match (e.g., '*.yml', '*.py', 'Dockerfile')
                           Supports glob patterns: *, ?

Search Options:
  -m, --show-matches       Show matching lines
  -c, --context N          Show N lines of context around matches (implies -m)
  -i, --ignore-case        Case-insensitive search
  -l, --files-only         Only show filenames with matches, not match count

Output Options:
  -u, --urls               Show GitHub URLs for matching files
  --open                   Open matching files in browser (max 10)
  --download DIR           Download matching files to DIR

Local Mode:
  --local                  Search local clones instead of GitHub API
  --local-dir DIR          Directory containing local clones (default: ~/projects)

Other:
  --code-search            Use GitHub Code Search API (fast, instant results)
  --no-code-search         Disable code search, use per-file API calls (slower)
  --plain                  Plain output (no colors, simplified format for parsing)
  --debug                  Show debug information (API calls, pattern matching)
  -h, --help               Show this help message

Note: By default, --code-search is used when searching text patterns.
      This is MUCH faster for broad searches (seconds vs minutes).
      
      IMPORTANT: GitHub Code Search does NOT index .github/ directory files.
      The script automatically falls back to per-repo search when searching
      workflow files or other .github/ content. This is slower but necessary.

Examples:
  # List all repos matching a pattern
  $0 --list-repos -r 'ds-service-*'

  # List files in .github/workflows across repos
  $0 --list-files -r 'ds-*' -p '.github/workflows'

  # Search for 'develop' in workflow files
  $0 -r 'ds-service-*' -p '.github/workflows' develop

  # Search for 'TODO' in Python files
  $0 -r 'ds-*' -f '*.py' TODO

  # Search Dockerfiles for 'alpine'
  $0 -r 'ds-*' -f 'Dockerfile' alpine

  # Search any YAML file for 'schedule'
  $0 -r 'ds-*' -f '*.yml' schedule

  # Show GitHub URLs for matches
  $0 -r 'ds-service-*' -p '.github/workflows' -u develop

  # Download matching files
  $0 -r 'ds-*' -f '*.yml' --download ./yamls 'branches-ignore'

  # Search with context
  $0 -r 'ds-service-*' -p 'src' -c 3 'import pandas'

  # Case-insensitive search
  $0 -r 'ds-*' -i 'error'

Requirements:
  - GitHub CLI (gh) installed and authenticated
  - Or use --local for local clone searching
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--org)
            ORG="$2"
            shift 2
            ;;
        -r|--repo-pattern)
            REPO_PATTERN="$2"
            shift 2
            ;;
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -p|--path)
            FILE_PATH="$2"
            shift 2
            ;;
        -f|--file-pattern)
            FILE_PATTERN="$2"
            shift 2
            ;;
        -l|--files-only)
            SHOW_FILES_ONLY=true
            shift
            ;;
        -m|--show-matches)
            SHOW_MATCHES=true
            shift
            ;;
        -c|--context)
            CONTEXT_LINES="$2"
            SHOW_MATCHES=true
            shift 2
            ;;
        -i|--ignore-case)
            CASE_INSENSITIVE=true
            shift
            ;;
        -u|--urls)
            SHOW_URLS=true
            shift
            ;;
        --open)
            OPEN_IN_BROWSER=true
            SHOW_URLS=true
            shift
            ;;
        --download)
            DOWNLOAD_DIR="${2%/}"  # Remove trailing slash
            shift 2
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        --local)
            LOCAL_MODE=true
            shift
            ;;
        --local-dir)
            LOCAL_DIR="$2"
            shift 2
            ;;
        --list-repos)
            LIST_REPOS_ONLY=true
            shift
            ;;
        --list-files)
            LIST_FILES_ONLY=true
            shift
            ;;
        --code-search)
            CODE_SEARCH=on
            shift
            ;;
        --no-code-search)
            CODE_SEARCH=off
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --plain)
            PLAIN_OUTPUT=true
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
            if [ -z "$SEARCH_PATTERN" ]; then
                SEARCH_PATTERN="$1"
            else
                echo "Error: Multiple search patterns specified"
                exit 1
            fi
            shift
            ;;
    esac
done

# Disable colors if plain output requested
if [ "$PLAIN_OUTPUT" = true ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
    NC=''
fi

# Validate: search pattern required unless listing
if [ -z "$SEARCH_PATTERN" ] && [ "$LIST_REPOS_ONLY" = false ] && [ "$LIST_FILES_ONLY" = false ]; then
    echo "Error: No search pattern specified"
    echo "Usage: $0 [options] <search-pattern>"
    echo "Or use --list-repos or --list-files to list without searching"
    echo "Run '$0 --help' for more information."
    exit 1
fi

# Check for gh CLI (unless local mode)
if [ "$LOCAL_MODE" = false ]; then
    if ! command -v gh >/dev/null 2>&1; then
        echo "Error: GitHub CLI (gh) is not installed"
        echo "Please install it from: https://cli.github.com/"
        echo ""
        echo "Or use --local to search local clones instead"
        exit 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
        echo "Error: GitHub CLI is not authenticated"
        echo "Please run: gh auth login"
        exit 1
    fi
fi

# ============================================
# HELPER FUNCTIONS
# ============================================

# Check if a filename matches a glob pattern
matches_file_pattern() {
    local filename="$1"
    local pattern="$2"
    
    if [ -z "$pattern" ]; then
        return 0  # No pattern = match all
    fi
    
    # Convert glob to regex
    local regex=$(echo "$pattern" | sed 's/\./\\./g' | sed 's/\*/.*/g' | sed 's/\?/./g')
    
    if echo "$filename" | grep -qE "^${regex}$" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get repos from GitHub
get_repos() {
    local repos
    
    # If we have a pattern, use the search API (much faster)
    if [ -n "$REPO_PATTERN" ]; then
        # Convert glob pattern to search term
        # GitHub search doesn't support full glob, so we extract the prefix
        local search_term=$(echo "$REPO_PATTERN" | sed 's/\*.*$//' | sed 's/\?.*$//')
        
        if [ "$DEBUG" = true ]; then
            echo "[DEBUG] Using search API with term: '$search_term'" >&2
            echo "[DEBUG] Running: gh search repos --owner $ORG '$search_term' in:name --limit $LIMIT" >&2
        fi
        
        # Use gh search repos (faster than listing all)
        repos=$(gh search repos --owner "$ORG" "$search_term" --match name --limit "$LIMIT" --json name --jq '.[].name' 2>&1)
        local gh_exit_code=$?
        
        if [ "$DEBUG" = true ]; then
            echo "[DEBUG] gh exit code: $gh_exit_code" >&2
            echo "[DEBUG] Search returned: $(echo "$repos" | grep -v '^$' | wc -l) repos" >&2
        fi
        
        if [ $gh_exit_code -ne 0 ]; then
            echo "Error: Failed to search repositories in $ORG" >&2
            echo "$repos" >&2
            exit 1
        fi
        
        # Now filter with the full glob pattern (search API doesn't support full glob)
        local grep_pattern=$(echo "$REPO_PATTERN" | sed 's/\*/.*/g' | sed 's/\?/./g')
        
        if [ "$DEBUG" = true ]; then
            echo "[DEBUG] Filtering with grep pattern: '^${grep_pattern}\$'" >&2
        fi
        
        repos=$(echo "$repos" | grep -E "^${grep_pattern}$" 2>/dev/null | sort || echo "")
        
        if [ "$DEBUG" = true ]; then
            echo "[DEBUG] After filtering: $(echo "$repos" | grep -v '^$' | wc -l) repos" >&2
        fi
        
        if [ -z "$repos" ]; then
            echo "Error: No repositories matching pattern '$REPO_PATTERN'" >&2
            exit 1
        fi
    else
        # No pattern - list all repos (slower, needs higher limit)
        if [ "$DEBUG" = true ]; then
            echo "[DEBUG] No pattern - listing all repos" >&2
            echo "[DEBUG] Running: gh repo list $ORG --limit $LIMIT --json name --jq '.[].name'" >&2
        fi
        
        repos=$(gh repo list "$ORG" --limit "$LIMIT" --json name --jq '.[].name' 2>&1)
        local gh_exit_code=$?
        
        if [ "$DEBUG" = true ]; then
            echo "[DEBUG] gh exit code: $gh_exit_code" >&2
            echo "[DEBUG] Total repos returned: $(echo "$repos" | grep -v '^$' | wc -l)" >&2
        fi
        
        # Check for errors in output
        if [ $gh_exit_code -ne 0 ] || echo "$repos" | grep -q "^gh:"; then
            echo "Error: Failed to fetch repositories from $ORG" >&2
            echo "$repos" >&2
            exit 1
        fi
        
        repos=$(echo "$repos" | sort)
        
        if [ -z "$repos" ]; then
            echo "Error: No repositories found in $ORG" >&2
            exit 1
        fi
    fi
    
    echo "$repos"
}

# Get files from a path in a repo
get_files_at_path() {
    local repo="$1"
    local path="$2"
    local branch="$3"
    
    local api_path="repos/$ORG/$repo/contents"
    if [ -n "$path" ]; then
        api_path="$api_path/$path"
    fi
    
    gh api "$api_path?ref=$branch" --jq '.[] | select(.type == "file") | .name' 2>/dev/null || echo ""
}

# Get file content
get_file_content() {
    local repo="$1"
    local path="$2"
    local filename="$3"
    local branch="$4"
    
    local full_path="$filename"
    if [ -n "$path" ]; then
        full_path="$path/$filename"
    fi
    
    gh api "repos/$ORG/$repo/contents/$full_path?ref=$branch" \
        --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || echo ""
}

# Determine active branch (main or master)
get_active_branch() {
    local repo="$1"
    local preferred="$2"
    
    # Try preferred branch first
    if gh api "repos/$ORG/$repo/branches/$preferred" >/dev/null 2>&1; then
        echo "$preferred"
        return
    fi
    
    # Fall back to master if main was preferred
    if [ "$preferred" = "main" ]; then
        if gh api "repos/$ORG/$repo/branches/master" >/dev/null 2>&1; then
            echo "master"
            return
        fi
    fi
    
    # Return preferred even if not found (will fail later with clearer error)
    echo "$preferred"
}

# ============================================
# HEADER
# ============================================
if [ "$PLAIN_OUTPUT" = false ]; then
    echo -e "${BLUE}=========================================="
    if [ "$LIST_REPOS_ONLY" = true ]; then
        echo "List Repositories"
    elif [ "$LIST_FILES_ONLY" = true ]; then
        echo "List Files"
    else
        echo "GitHub Repository Search"
    fi
    echo "=========================================="
    if [ "$LOCAL_MODE" = true ]; then
        echo -e "Mode: Local (${LOCAL_DIR})"
    else
        echo -e "Organization: $ORG"
        echo -e "Branch: $BRANCH"
    fi
    echo -e "Repo Pattern: ${REPO_PATTERN:-"(all)"}"
    if [ -n "$FILE_PATH" ]; then
        echo -e "Path: $FILE_PATH"
    fi
    if [ -n "$FILE_PATTERN" ]; then
        echo -e "File Pattern: $FILE_PATTERN"
    fi
    if [ -n "$SEARCH_PATTERN" ]; then
        echo -e "Search: $SEARCH_PATTERN"
    fi
    echo -e "==========================================${NC}"
    echo ""
fi

# ============================================
# LOCAL MODE
# ============================================
if [ "$LOCAL_MODE" = true ]; then
    if [ ! -d "$LOCAL_DIR" ]; then
        echo "Error: Local directory not found: $LOCAL_DIR"
        exit 1
    fi
    
    # Find matching repos locally
    REPOS=""
    if [ -n "$REPO_PATTERN" ]; then
        GREP_PATTERN=$(echo "$REPO_PATTERN" | sed 's/\*/.*/g' | sed 's/\?/./g')
        REPOS=$(ls -1 "$LOCAL_DIR" | grep -E "^${GREP_PATTERN}$" 2>/dev/null || echo "")
    else
        REPOS=$(ls -1 "$LOCAL_DIR")
    fi
    
    # Filter to only git repos
    FILTERED_REPOS=""
    while IFS= read -r repo; do
        if [ -d "$LOCAL_DIR/$repo/.git" ]; then
            FILTERED_REPOS="$FILTERED_REPOS$repo"$'\n'
        fi
    done <<< "$REPOS"
    REPOS=$(echo "$FILTERED_REPOS" | grep -v '^$' | sort)
    
    if [ -z "$REPOS" ]; then
        echo "Error: No git repositories found in $LOCAL_DIR"
        exit 1
    fi
    
    REPO_COUNT=$(echo "$REPOS" | wc -l | tr -d ' ')
    echo -e "Found ${GREEN}$REPO_COUNT${NC} local repositories"
    echo ""
    
    # List repos only mode
    if [ "$LIST_REPOS_ONLY" = true ]; then
        echo "$REPOS"
        echo ""
        echo -e "${BLUE}Total: $REPO_COUNT repositories${NC}"
        exit 0
    fi
    
    REPOS_WITH_MATCHES=0
    FILES_WITH_MATCHES=0
    REPOS_SCANNED=0
    
    while IFS= read -r repo_name; do
        [ -z "$repo_name" ] && continue
        
        REPOS_SCANNED=$((REPOS_SCANNED + 1))
        # Use echo for color support, -ne for no newline (unless plain output)
        [ "$PLAIN_OUTPUT" = false ] && echo -ne "\r${MAGENTA}Scanning [$REPOS_SCANNED/$REPO_COUNT]: ${repo_name:0:40}${NC}                    "
        
        REPO_DIR="$LOCAL_DIR/$repo_name"
        SEARCH_DIR="$REPO_DIR"
        
        if [ -n "$FILE_PATH" ]; then
            SEARCH_DIR="$REPO_DIR/$FILE_PATH"
            if [ ! -d "$SEARCH_DIR" ]; then
                continue
            fi
        fi
        
        # Build find command for files - exclude common large/binary directories
        FIND_CMD="find \"$SEARCH_DIR\" -type f"
        # Exclude .git, node_modules, vendor, __pycache__, etc.
        FIND_CMD="$FIND_CMD -not -path '*/.git/*'"
        FIND_CMD="$FIND_CMD -not -path '*/node_modules/*'"
        FIND_CMD="$FIND_CMD -not -path '*/vendor/*'"
        FIND_CMD="$FIND_CMD -not -path '*/__pycache__/*'"
        FIND_CMD="$FIND_CMD -not -path '*/.venv/*'"
        FIND_CMD="$FIND_CMD -not -path '*/venv/*'"
        FIND_CMD="$FIND_CMD -not -path '*/.idea/*'"
        FIND_CMD="$FIND_CMD -not -path '*/.vscode/*'"
        FIND_CMD="$FIND_CMD -not -path '*/target/*'"
        FIND_CMD="$FIND_CMD -not -path '*/build/*'"
        FIND_CMD="$FIND_CMD -not -path '*/dist/*'"
        if [ -n "$FILE_PATTERN" ]; then
            FIND_CMD="$FIND_CMD -name \"$FILE_PATTERN\""
        fi
        
        FILES=$(eval $FIND_CMD 2>/dev/null || echo "")
        [ -z "$FILES" ] && continue
        
        REPO_HAS_MATCH=false
        GREP_OPTS="-I"  # Skip binary files
        [ "$CASE_INSENSITIVE" = true ] && GREP_OPTS="$GREP_OPTS -i"
        
        # Limit files to search per repo (performance safeguard)
        FILE_COUNT=0
        MAX_FILES_PER_REPO=5000
        
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            [ ! -f "$file" ] && continue
            
            FILE_COUNT=$((FILE_COUNT + 1))
            if [ $FILE_COUNT -gt $MAX_FILES_PER_REPO ]; then
                echo -ne "\r                                                                    \r"
                echo -e "${YELLOW}Warning: $repo_name has >$MAX_FILES_PER_REPO files, skipping rest${NC}"
                break
            fi
            
            if grep -q $GREP_OPTS "$SEARCH_PATTERN" "$file" 2>/dev/null; then
                if [ "$REPO_HAS_MATCH" = false ]; then
                    echo -ne "\r                                                                    \r"  # Clear progress line
                    echo -e "${GREEN}$repo_name${NC}"
                    REPO_HAS_MATCH=true
                    REPOS_WITH_MATCHES=$((REPOS_WITH_MATCHES + 1))
                fi
                
                FILES_WITH_MATCHES=$((FILES_WITH_MATCHES + 1))
                REL_PATH="${file#$REPO_DIR/}"
                
                if [ "$SHOW_FILES_ONLY" = true ]; then
                    echo -e "  ${CYAN}$REL_PATH${NC}"
                elif [ "$SHOW_MATCHES" = true ]; then
                    echo -e "  ${CYAN}$REL_PATH:${NC}"
                    if [ "$CONTEXT_LINES" -gt 0 ]; then
                        grep -n $GREP_OPTS -C "$CONTEXT_LINES" "$SEARCH_PATTERN" "$file" 2>/dev/null | sed 's/^/    /'
                    else
                        grep -n $GREP_OPTS "$SEARCH_PATTERN" "$file" 2>/dev/null | sed 's/^/    /'
                    fi
                    echo ""
                else
                    MATCH_COUNT=$(grep -c $GREP_OPTS "$SEARCH_PATTERN" "$file" 2>/dev/null || echo "0")
                    echo -e "  ${CYAN}$REL_PATH${NC} (${YELLOW}$MATCH_COUNT matches${NC})"
                fi
            fi
        done <<< "$FILES"
        
        [ "$REPO_HAS_MATCH" = true ] && echo ""
    done <<< "$REPOS"
    
    # Clear any remaining progress line
    echo -ne "\r                                                                    \r"
    
    echo -e "${BLUE}=========================================="
    echo "Summary"
    echo -e "==========================================${NC}"
    echo "Repositories with matches: $REPOS_WITH_MATCHES"
    echo "Files with matches: $FILES_WITH_MATCHES"
    exit 0
fi

# ============================================
# GITHUB API MODE
# ============================================

# ============================================
# DETERMINE IF CODE SEARCH SHOULD BE USED
# ============================================
# Check this FIRST before fetching repos (code search doesn't need repo list)
USE_CODE_SEARCH=false

if [ -n "$SEARCH_PATTERN" ] && [ "$LIST_FILES_ONLY" = false ] && [ "$LIST_REPOS_ONLY" = false ]; then
    if [ "$CODE_SEARCH" = "on" ]; then
        USE_CODE_SEARCH=true
    elif [ "$CODE_SEARCH" = "auto" ]; then
        # Auto mode: use code search for text searches (supports path: filter too)
        USE_CODE_SEARCH=true
    fi
fi

# IMPORTANT: GitHub Code Search doesn't index .github/workflows files
# Fall back to per-repo mode when searching workflow files
if [ "$USE_CODE_SEARCH" = true ] && [ -n "$FILE_PATH" ]; then
    if echo "$FILE_PATH" | grep -qE '^\.github(/|$)'; then
        if [ "$CODE_SEARCH" != "on" ]; then
            # Only auto-fallback in auto mode; respect explicit --code-search on
            echo -e "${YELLOW}Note: .github/ files are not indexed by GitHub Code Search${NC}"
            echo -e "${YELLOW}Falling back to per-repository search...${NC}"
            echo ""
            USE_CODE_SEARCH=false
        fi
    fi
fi

# ============================================
# CODE SEARCH MODE (FAST) - Skip repo fetch!
# ============================================
if [ "$USE_CODE_SEARCH" = true ]; then
    [ "$PLAIN_OUTPUT" = false ] && echo -e "${CYAN}Using GitHub Code Search (fast mode)...${NC}"
    [ "$PLAIN_OUTPUT" = false ] && echo ""
    
    # Build the search query
    SEARCH_QUERY="$SEARCH_PATTERN org:$ORG"
    
    # Add repo filter if pattern specified
    if [ -n "$REPO_PATTERN" ]; then
        # GitHub code search uses 'repo:' prefix, we need to expand the pattern
        # For simple prefixes like "ds-*", we can use "repo:UKGEPIC/ds-"
        search_prefix=$(echo "$REPO_PATTERN" | sed 's/\*.*$//')
        if [ -n "$search_prefix" ]; then
            SEARCH_QUERY="$SEARCH_PATTERN repo:$ORG/$search_prefix"
        fi
    fi
    
    # NOTE: We intentionally do NOT add extension: or filename: filters here.
    # GitHub Code Search has a bug where these filters often return empty results
    # even when matching files exist. Instead, we filter results client-side.
    # See: file pattern filtering in the results processing loop below.
    
    # Add path filter if specified
    if [ -n "$FILE_PATH" ]; then
        SEARCH_QUERY="$SEARCH_QUERY path:$FILE_PATH"
    fi
    
    # GitHub Code Search API has a max limit of 1000 results
    CODE_SEARCH_LIMIT="$LIMIT"
    if [ "$CODE_SEARCH_LIMIT" -gt 1000 ] 2>/dev/null; then
        [ "$PLAIN_OUTPUT" = false ] && echo -e "${YELLOW}Note: GitHub Code Search limit capped at 1000 (requested: $LIMIT)${NC}"
        CODE_SEARCH_LIMIT=1000
    fi
    
    if [ "$DEBUG" = true ]; then
        echo "[DEBUG] Code search query: $SEARCH_QUERY" >&2
        echo "[DEBUG] Running: gh search code \"$SEARCH_QUERY\" --limit $CODE_SEARCH_LIMIT --json repository,path,textMatches" >&2
    fi
    
    # Execute code search
    # Capture stdout (JSON) and stderr separately to avoid mixing warnings with JSON
    [ "$PLAIN_OUTPUT" = false ] && echo "Searching..."
    GH_STDERR_FILE=$(mktemp)
    SEARCH_RESULTS=$(gh search code "$SEARCH_QUERY" --limit "$CODE_SEARCH_LIMIT" --json repository,path,textMatches 2>"$GH_STDERR_FILE") || true
    GH_EXIT=$?
    GH_STDERR=$(cat "$GH_STDERR_FILE" 2>/dev/null)
    rm -f "$GH_STDERR_FILE"
    
    if [ "$DEBUG" = true ]; then
        echo "[DEBUG] gh exit code: $GH_EXIT" >&2
        echo "[DEBUG] Response length: ${#SEARCH_RESULTS} chars" >&2
        [ -n "$GH_STDERR" ] && echo "[DEBUG] stderr: $GH_STDERR" >&2
    fi
    
    if [ $GH_EXIT -ne 0 ]; then
        echo -e "${YELLOW}Warning: Code search failed (exit $GH_EXIT): $GH_STDERR${NC}"
        echo -e "${YELLOW}Falling back to per-repo search (slower)...${NC}"
        USE_CODE_SEARCH=false
    elif [ -z "$SEARCH_RESULTS" ]; then
        echo "No matches found."
        exit 0
    elif ! echo "$SEARCH_RESULTS" | jq -e '.' >/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: Invalid response from code search${NC}"
        if [ "$DEBUG" = true ]; then
            echo "[DEBUG] Response: ${SEARCH_RESULTS:0:500}" >&2
        fi
        echo -e "${YELLOW}Falling back to per-repo search (slower)...${NC}"
        USE_CODE_SEARCH=false
    else
        RESULT_COUNT=$(echo "$SEARCH_RESULTS" | jq 'length' 2>/dev/null) || RESULT_COUNT=0
        
        # Handle empty or invalid result count
        if [ -z "$RESULT_COUNT" ] || [ "$RESULT_COUNT" = "null" ]; then
            RESULT_COUNT=0
        fi
        
        if [ "$RESULT_COUNT" = "0" ] || [ "$RESULT_COUNT" -eq 0 ] 2>/dev/null; then
            [ "$PLAIN_OUTPUT" = false ] && echo "No matches found."
            exit 0
        fi
        
        [ "$PLAIN_OUTPUT" = false ] && echo -e "Found ${GREEN}$RESULT_COUNT${NC} matches"
        [ "$PLAIN_OUTPUT" = false ] && echo ""
        
        # Create download directory if specified
        if [ -n "$DOWNLOAD_DIR" ]; then
            mkdir -p "$DOWNLOAD_DIR"
            [ "$PLAIN_OUTPUT" = false ] && echo -e "${CYAN}Download directory: $DOWNLOAD_DIR${NC}"
            [ "$PLAIN_OUTPUT" = false ] && echo ""
        fi
        
        # Track unique repos (bash 3.x compatible - no associative arrays)
        SEEN_REPOS=""
        REPOS_WITH_MATCHES=0
        FILES_WITH_MATCHES=0
        
        # Process results - use process substitution to avoid subshell
        while read -r result; do
            [ -z "$result" ] && continue
            
            repo_full=$(echo "$result" | jq -r '.repository.nameWithOwner')
            repo_name="${repo_full#*/}"  # Extract repo name from "org/repo"
            file_path=$(echo "$result" | jq -r '.path')
            
            # Apply repo pattern filter (code search doesn't support full glob)
            if [ -n "$REPO_PATTERN" ]; then
                grep_pattern=$(echo "$REPO_PATTERN" | sed 's/\*/.*/g' | sed 's/\?/./g')
                if ! echo "$repo_name" | grep -qE "^${grep_pattern}$"; then
                    continue
                fi
            fi
            
            # Apply file pattern filter (extension:/filename: don't work reliably in Code Search)
            if [ -n "$FILE_PATTERN" ]; then
                filename=$(basename "$file_path")
                if ! matches_file_pattern "$filename" "$FILE_PATTERN"; then
                    continue
                fi
            fi
            
            # Track repo (bash 3.x compatible string-based check)
            if ! echo "$SEEN_REPOS" | grep -q "|${repo_name}|"; then
                SEEN_REPOS="${SEEN_REPOS}|${repo_name}|"
                REPOS_WITH_MATCHES=$((REPOS_WITH_MATCHES + 1))
            fi
            
            FILES_WITH_MATCHES=$((FILES_WITH_MATCHES + 1))
            
            # Output
            echo -e "${GREEN}$repo_name${NC}: ${CYAN}$file_path${NC}"
            
            # Show URL if requested
            if [ "$SHOW_URLS" = true ]; then
                echo -e "  ${YELLOW}https://github.com/$repo_full/blob/HEAD/$file_path${NC}"
            fi
            
            # Show matches if requested
            if [ "$SHOW_MATCHES" = true ]; then
                echo "$result" | jq -r '.textMatches[]?.fragment // empty' 2>/dev/null | while read -r fragment; do
                    [ -n "$fragment" ] && echo -e "  ${MAGENTA}$fragment${NC}"
                done
            fi
            
            # Download if requested
            if [ -n "$DOWNLOAD_DIR" ]; then
                safe_name="${repo_name}__$(basename "$file_path")"
                full_path="$DOWNLOAD_DIR/$safe_name"
                if gh api "repos/$repo_full/contents/$file_path" --jq '.content' 2>/dev/null | base64 -d > "$full_path" 2>/dev/null; then
                    echo -e "  ${CYAN}Downloaded: $full_path${NC}"
                else
                    echo -e "  ${YELLOW}Download failed: $full_path${NC}"
                fi
            fi
        done < <(echo "$SEARCH_RESULTS" | jq -c '.[]' 2>/dev/null)
        
        if [ "$PLAIN_OUTPUT" = false ]; then
            echo ""
            echo -e "${BLUE}=========================================="
            echo "Search Complete (Code Search)"
            echo "=========================================="
            echo -e "Repos with matches: $REPOS_WITH_MATCHES"
            echo -e "Files matched: $FILES_WITH_MATCHES"
            echo -e "==========================================${NC}"
        fi
        exit 0
    fi
fi

# ============================================
# FETCH REPOS (only if not using code search)
# ============================================
[ "$PLAIN_OUTPUT" = false ] && echo "Fetching repositories from $ORG..."
REPOS=$(get_repos)

REPO_COUNT=$(echo "$REPOS" | wc -l | tr -d ' ')
[ "$PLAIN_OUTPUT" = false ] && echo -e "Found ${GREEN}$REPO_COUNT${NC} repositories"
[ "$PLAIN_OUTPUT" = false ] && echo ""

# ============================================
# LIST REPOS ONLY MODE
# ============================================
if [ "$LIST_REPOS_ONLY" = true ]; then
    echo "$REPOS"
    echo ""
    echo -e "${BLUE}=========================================="
    echo "Total: $REPO_COUNT repositories"
    echo -e "==========================================${NC}"
    exit 0
fi

# Warn about slow search
if [ -n "$SEARCH_PATTERN" ] && [ -z "$FILE_PATH" ]; then
    echo -e "${YELLOW}Note: Per-repo search is slow without -p/--path. Use --code-search for faster results.${NC}"
    echo ""
fi

# ============================================
# INITIALIZE COUNTERS AND ARRAYS
# ============================================
REPOS_SCANNED=0
REPOS_WITH_MATCHES=0
FILES_WITH_MATCHES=0
REPOS_NO_FILES=0
declare -a URLS_TO_OPEN=()

# Create download directory if specified
if [ -n "$DOWNLOAD_DIR" ]; then
    mkdir -p "$DOWNLOAD_DIR"
    echo -e "${CYAN}Download directory: $DOWNLOAD_DIR${NC}"
    echo ""
fi

# ============================================
# MAIN SEARCH LOOP
# ============================================
while IFS= read -r repo_name; do
    [ -z "$repo_name" ] && continue
    
    ((REPOS_SCANNED++))
    
    # Show progress with count (unless plain output)
    [ "$PLAIN_OUTPUT" = false ] && printf "\r${MAGENTA}Scanning [%d/%d]: %-40s${NC}" "$REPOS_SCANNED" "$REPO_COUNT" "$repo_name"
    
    # Determine active branch
    ACTIVE_BRANCH=$(get_active_branch "$repo_name" "$BRANCH")
    
    # Get files at the specified path
    FILES=$(get_files_at_path "$repo_name" "$FILE_PATH" "$ACTIVE_BRANCH")
    
    # If no files at path with main, try master
    if [ -z "$FILES" ] && [ "$BRANCH" = "main" ] && [ "$ACTIVE_BRANCH" = "main" ]; then
        ACTIVE_BRANCH="master"
        FILES=$(get_files_at_path "$repo_name" "$FILE_PATH" "$ACTIVE_BRANCH")
    fi
    
    if [ -z "$FILES" ]; then
        ((REPOS_NO_FILES++))
        continue
    fi
    
    # List files only mode
    if [ "$LIST_FILES_ONLY" = true ]; then
        printf "\r%-60s\r" " "
        echo -e "${GREEN}$repo_name${NC} ${MAGENTA}($ACTIVE_BRANCH)${NC}"
        
        while IFS= read -r filename; do
            [ -z "$filename" ] && continue
            
            # Apply file pattern filter
            if [ -n "$FILE_PATTERN" ] && ! matches_file_pattern "$filename" "$FILE_PATTERN"; then
                continue
            fi
            
            echo -e "  ${CYAN}$filename${NC}"
            
            if [ "$SHOW_URLS" = true ]; then
                local_path="$filename"
                [ -n "$FILE_PATH" ] && local_path="$FILE_PATH/$filename"
                echo -e "    ${YELLOW}https://github.com/$ORG/$repo_name/blob/$ACTIVE_BRANCH/$local_path${NC}"
            fi
        done <<< "$FILES"
        echo ""
        continue
    fi
    
    # Search mode
    REPO_HAS_MATCH=false
    
    while IFS= read -r filename; do
        [ -z "$filename" ] && continue
        
        # Apply file pattern filter
        if [ -n "$FILE_PATTERN" ] && ! matches_file_pattern "$filename" "$FILE_PATTERN"; then
            continue
        fi
        
        # Get file content
        CONTENT=$(get_file_content "$repo_name" "$FILE_PATH" "$filename" "$ACTIVE_BRANCH")
        [ -z "$CONTENT" ] && continue
        
        # Search for pattern
        GREP_OPTS=""
        [ "$CASE_INSENSITIVE" = true ] && GREP_OPTS="-i"
        
        if echo "$CONTENT" | grep -q $GREP_OPTS "$SEARCH_PATTERN" 2>/dev/null; then
            if [ "$REPO_HAS_MATCH" = false ]; then
                printf "\r%-60s\r" " "
                echo -e "${GREEN}$repo_name${NC} ${MAGENTA}($ACTIVE_BRANCH)${NC}"
                REPO_HAS_MATCH=true
                ((REPOS_WITH_MATCHES++))
            fi
            
            ((FILES_WITH_MATCHES++))
            
            # Build URLs
            FILE_URL_PATH="$filename"
            [ -n "$FILE_PATH" ] && FILE_URL_PATH="$FILE_PATH/$filename"
            FILE_URL="https://github.com/$ORG/$repo_name/blob/$ACTIVE_BRANCH/$FILE_URL_PATH"
            
            if [ "$SHOW_FILES_ONLY" = true ]; then
                echo -e "  ${CYAN}$filename${NC}"
                [ "$SHOW_URLS" = true ] && echo -e "    ${YELLOW}$FILE_URL${NC}"
            elif [ "$SHOW_MATCHES" = true ]; then
                echo -e "  ${CYAN}$filename:${NC}"
                [ "$SHOW_URLS" = true ] && echo -e "    ${YELLOW}URL: $FILE_URL${NC}"
                if [ "$CONTEXT_LINES" -gt 0 ]; then
                    echo "$CONTENT" | grep -n $GREP_OPTS -C "$CONTEXT_LINES" "$SEARCH_PATTERN" 2>/dev/null | sed 's/^/    /'
                else
                    echo "$CONTENT" | grep -n $GREP_OPTS "$SEARCH_PATTERN" 2>/dev/null | sed 's/^/    /'
                fi
                echo ""
            else
                MATCH_COUNT=$(echo "$CONTENT" | grep -c $GREP_OPTS "$SEARCH_PATTERN" 2>/dev/null || echo "0")
                echo -e "  ${CYAN}$filename${NC} (${YELLOW}$MATCH_COUNT matches${NC})"
                [ "$SHOW_URLS" = true ] && echo -e "    ${YELLOW}$FILE_URL${NC}"
            fi
            
            # Track URL for browser opening
            [ "$OPEN_IN_BROWSER" = true ] && URLS_TO_OPEN+=("$FILE_URL")
            
            # Download file if requested
            if [ -n "$DOWNLOAD_DIR" ]; then
                DOWNLOAD_FILE="$DOWNLOAD_DIR/${repo_name}__${filename}"
                echo "$CONTENT" > "$DOWNLOAD_FILE"
                echo -e "    ${GREEN}Downloaded: $DOWNLOAD_FILE${NC}"
            fi
        fi
    done <<< "$FILES"
    
    [ "$REPO_HAS_MATCH" = true ] && echo ""
done <<< "$REPOS"

# Clear progress line
printf "\r%-60s\r" " "

# ============================================
# SUMMARY
# ============================================
if [ "$PLAIN_OUTPUT" = false ]; then
    echo -e "${BLUE}=========================================="
    echo "Summary"
    echo -e "==========================================${NC}"
    echo "Repositories scanned: $REPOS_SCANNED"
    echo "Repositories with files at path: $((REPOS_SCANNED - REPOS_NO_FILES))"
    
    if [ "$LIST_FILES_ONLY" = false ]; then
        echo "Repositories with matches: $REPOS_WITH_MATCHES"
        echo "Files with matches: $FILES_WITH_MATCHES"
    fi
    
    if [ -n "$DOWNLOAD_DIR" ]; then
        DOWNLOADED_COUNT=$(ls -1 "$DOWNLOAD_DIR" 2>/dev/null | wc -l | tr -d ' ')
        echo "Files downloaded: $DOWNLOADED_COUNT (to $DOWNLOAD_DIR)"
    fi
    
    if [ "$LIST_FILES_ONLY" = false ] && [ $REPOS_WITH_MATCHES -eq 0 ]; then
        echo ""
        echo -e "${YELLOW}No matches found for '$SEARCH_PATTERN'${NC}"
    fi
fi

if [ "$LIST_FILES_ONLY" = false ] && [ $REPOS_WITH_MATCHES -eq 0 ]; then
    exit 1
fi

# Open URLs in browser if requested
if [ "$OPEN_IN_BROWSER" = true ] && [ ${#URLS_TO_OPEN[@]} -gt 0 ]; then
    echo ""
    echo -e "${CYAN}Opening ${#URLS_TO_OPEN[@]} files in browser...${NC}"
    
    MAX_OPEN=10
    OPENED=0
    
    for url in "${URLS_TO_OPEN[@]}"; do
        if [ $OPENED -ge $MAX_OPEN ]; then
            REMAINING=$((${#URLS_TO_OPEN[@]} - MAX_OPEN))
            echo -e "${YELLOW}Stopped after $MAX_OPEN files. $REMAINING more available.${NC}"
            echo "Use -u to see all URLs."
            break
        fi
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open "$url" 2>/dev/null
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            xdg-open "$url" 2>/dev/null &
        elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
            start "$url" 2>/dev/null
        fi
        
        ((OPENED++))
        sleep 0.3
    done
    
    echo -e "${GREEN}Opened $OPENED files in browser${NC}"
fi

exit 0
