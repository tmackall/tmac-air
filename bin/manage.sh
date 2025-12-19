#!/bin/bash

# Dotfiles Manager
# Stores config files without dot prefix, symlinks them to home directory with dots

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Dotfiles Manager - Keep configs visible, symlink as dotfiles

Usage: $(basename "$0") <command> [options]

Commands:
    init            Initialize the dotfiles directory
    add <file>      Add an existing dotfile to management (moves & symlinks)
    remove <name>   Stop managing a file (restores to original location)
    link            Create symlinks for all managed dotfiles
    unlink          Remove all symlinks (keeps source files)
    status          Show status of all managed dotfiles
    list            List all managed files

Options:
    -d, --dir DIR   Use DIR as dotfiles directory (default: ~/dotfiles)
    -h, --help      Show this help message

Examples:
    $(basename "$0") init                    # Create ~/dotfiles directory
    $(basename "$0") add ~/.bashrc           # Start managing .bashrc
    $(basename "$0") add ~/.config/nvim      # Works with directories too
    $(basename "$0") remove bashrc           # Stop managing, restore to ~/.bashrc
    $(basename "$0") link                    # Create all symlinks
    $(basename "$0") status                  # Check what's linked

EOF
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Initialize dotfiles directory
cmd_init() {
    if [[ -d "$DOTFILES_DIR" ]]; then
        log_warn "Dotfiles directory already exists: $DOTFILES_DIR"
        return 0
    fi
    
    mkdir -p "$DOTFILES_DIR"
    
    # Create a manifest file to track original locations
    cat > "$DOTFILES_DIR/.manifest" << 'MANIFEST'
# Dotfiles Manifest
# Format: source_name:target_path
# Example: bashrc:~/.bashrc
MANIFEST
    
    log_success "Initialized dotfiles directory: $DOTFILES_DIR"
    log_info "Add files with: $(basename "$0") add <dotfile>"
}

# Get the non-dot name for storage
get_storage_name() {
    local filepath="$1"
    local basename=$(basename "$filepath")
    
    # Remove leading dot if present
    if [[ "$basename" == .* ]]; then
        echo "${basename:1}"
    else
        echo "$basename"
    fi
}

# Add a dotfile to management
cmd_add() {
    local filepath="$1"
    
    if [[ -z "$filepath" ]]; then
        log_error "Please specify a file to add"
        return 1
    fi
    
    # Expand path
    filepath=$(cd "$(dirname "$filepath")" && pwd)/$(basename "$filepath")
    
    if [[ ! -e "$filepath" ]]; then
        log_error "File does not exist: $filepath"
        return 1
    fi
    
    if [[ -L "$filepath" ]]; then
        log_error "File is already a symlink: $filepath"
        return 1
    fi
    
    # Ensure dotfiles dir exists
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        cmd_init
    fi
    
    local storage_name=$(get_storage_name "$filepath")
    local storage_path="$DOTFILES_DIR/$storage_name"
    
    # Handle nested paths (like .config/nvim)
    if [[ "$filepath" == */.config/* ]]; then
        local config_subpath="${filepath#*/.config/}"
        storage_name="config/$config_subpath"
        storage_path="$DOTFILES_DIR/$storage_name"
        mkdir -p "$(dirname "$storage_path")"
    fi
    
    if [[ -e "$storage_path" ]]; then
        log_error "Already managing a file named: $storage_name"
        return 1
    fi
    
    # Move file to dotfiles directory
    mv "$filepath" "$storage_path"
    
    # Create symlink
    ln -s "$storage_path" "$filepath"
    
    # Add to manifest
    echo "$storage_name:$filepath" >> "$DOTFILES_DIR/.manifest"
    
    log_success "Added: $filepath -> $storage_path"
}

# Create symlinks for all managed files
cmd_link() {
    if [[ ! -f "$DOTFILES_DIR/.manifest" ]]; then
        log_error "No manifest found. Run 'init' first."
        return 1
    fi
    
    local count=0
    while IFS=: read -r storage_name target_path; do
        # Skip comments and empty lines
        [[ "$storage_name" =~ ^#.*$ || -z "$storage_name" ]] && continue
        
        # Expand ~ in target path
        target_path="${target_path/#\~/$HOME}"
        local storage_path="$DOTFILES_DIR/$storage_name"
        
        if [[ ! -e "$storage_path" ]]; then
            log_warn "Source missing: $storage_path"
            continue
        fi
        
        # Create parent directory if needed
        mkdir -p "$(dirname "$target_path")"
        
        if [[ -L "$target_path" ]]; then
            local current_link=$(readlink "$target_path")
            if [[ "$current_link" == "$storage_path" ]]; then
                log_info "Already linked: $target_path"
                continue
            else
                log_warn "Symlink exists but points elsewhere: $target_path -> $current_link"
                continue
            fi
        elif [[ -e "$target_path" ]]; then
            log_warn "File exists (not a symlink): $target_path"
            log_info "  Backup and remove it, then run link again"
            continue
        fi
        
        ln -s "$storage_path" "$target_path"
        log_success "Linked: $target_path -> $storage_path"
        ((count++))
    done < "$DOTFILES_DIR/.manifest"
    
    log_info "Created $count symlink(s)"
}

# Remove a file from management (restore to original location)
cmd_remove() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        log_error "Please specify a file to remove from management"
        log_info "Use 'list' to see managed files"
        return 1
    fi
    
    # Strip leading dot if user provided it
    name="${name#.}"
    
    if [[ ! -f "$DOTFILES_DIR/.manifest" ]]; then
        log_error "No manifest found."
        return 1
    fi
    
    # Find the entry in manifest
    local found=0
    local target_path=""
    local storage_path=""
    
    while IFS=: read -r storage_name manifest_target; do
        [[ "$storage_name" =~ ^#.*$ || -z "$storage_name" ]] && continue
        
        if [[ "$storage_name" == "$name" ]]; then
            found=1
            target_path="${manifest_target/#\~/$HOME}"
            storage_path="$DOTFILES_DIR/$storage_name"
            break
        fi
    done < "$DOTFILES_DIR/.manifest"
    
    if [[ $found -eq 0 ]]; then
        log_error "File not managed: $name"
        log_info "Use 'list' to see managed files"
        return 1
    fi
    
    if [[ ! -e "$storage_path" ]]; then
        log_error "Source file missing: $storage_path"
        return 1
    fi
    
    # Remove symlink if it exists and points to our file
    if [[ -L "$target_path" ]]; then
        local link_target=$(readlink "$target_path")
        if [[ "$link_target" == "$storage_path" ]]; then
            rm "$target_path"
        else
            log_error "Symlink points elsewhere: $target_path -> $link_target"
            return 1
        fi
    elif [[ -e "$target_path" ]]; then
        log_error "Target exists and is not a symlink: $target_path"
        return 1
    fi
    
    # Move file back to original location
    mv "$storage_path" "$target_path"
    
    # Remove from manifest (create temp file, exclude the line, replace original)
    grep -v "^${name}:" "$DOTFILES_DIR/.manifest" > "$DOTFILES_DIR/.manifest.tmp"
    mv "$DOTFILES_DIR/.manifest.tmp" "$DOTFILES_DIR/.manifest"
    
    log_success "Restored: $storage_path -> $target_path"
    log_info "File is no longer managed by dotfiles"
}

# Remove all symlinks
cmd_unlink() {
    if [[ ! -f "$DOTFILES_DIR/.manifest" ]]; then
        log_error "No manifest found."
        return 1
    fi
    
    local count=0
    while IFS=: read -r storage_name target_path; do
        [[ "$storage_name" =~ ^#.*$ || -z "$storage_name" ]] && continue
        
        target_path="${target_path/#\~/$HOME}"
        
        if [[ -L "$target_path" ]]; then
            rm "$target_path"
            log_success "Unlinked: $target_path"
            ((count++))
        fi
    done < "$DOTFILES_DIR/.manifest"
    
    log_info "Removed $count symlink(s)"
}

# Show status of all managed files
cmd_status() {
    if [[ ! -f "$DOTFILES_DIR/.manifest" ]]; then
        log_error "No manifest found. Run 'init' first."
        return 1
    fi
    
    echo ""
    echo "Dotfiles Directory: $DOTFILES_DIR"
    echo "=================================="
    echo ""
    
    while IFS=: read -r storage_name target_path; do
        [[ "$storage_name" =~ ^#.*$ || -z "$storage_name" ]] && continue
        
        target_path="${target_path/#\~/$HOME}"
        local storage_path="$DOTFILES_DIR/$storage_name"
        
        printf "%-30s " "$storage_name"
        
        if [[ ! -e "$storage_path" ]]; then
            echo -e "${RED}[MISSING SOURCE]${NC}"
        elif [[ -L "$target_path" ]]; then
            local link_target=$(readlink "$target_path")
            if [[ "$link_target" == "$storage_path" ]]; then
                echo -e "${GREEN}[LINKED]${NC} $target_path"
            else
                echo -e "${YELLOW}[WRONG LINK]${NC} $target_path -> $link_target"
            fi
        elif [[ -e "$target_path" ]]; then
            echo -e "${YELLOW}[CONFLICT]${NC} $target_path exists (not symlink)"
        else
            echo -e "${BLUE}[UNLINKED]${NC} $target_path"
        fi
    done < "$DOTFILES_DIR/.manifest"
    echo ""
}

# List all managed files
cmd_list() {
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_error "Dotfiles directory not found: $DOTFILES_DIR"
        return 1
    fi
    
    echo ""
    echo "Managed dotfiles in: $DOTFILES_DIR"
    echo ""
    
    find "$DOTFILES_DIR" -maxdepth 2 -type f ! -name ".manifest" | while read -r file; do
        local name=$(basename "$file")
        echo "  $name"
    done
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            DOTFILES_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        init|add|remove|link|unlink|status|list)
            COMMAND="$1"
            shift
            break
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Execute command
case "${COMMAND:-}" in
    init)   cmd_init ;;
    add)    cmd_add "$1" ;;
    remove) cmd_remove "$1" ;;
    link)   cmd_link ;;
    unlink) cmd_unlink ;;
    status) cmd_status ;;
    list)   cmd_list ;;
    *)
        usage
        exit 1
        ;;
esac
