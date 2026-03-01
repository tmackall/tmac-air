#!/usr/bin/env bash
# install.sh - Symlink dotfiles to home directory
# Usage: ./install.sh
#
# Files in this directory get linked as dotfiles in $HOME:
#   gitconfig  -> ~/.gitconfig
#   bashrc     -> ~/.bashrc
#   npmrc      -> ~/.npmrc
#
# Special cases (subdirectories) are handled separately:
#   ssh_config -> ~/.ssh/config

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
# Relative path from $HOME to dotfiles dir (e.g. "dotfiles")
DOTFILES_REL="${DOTFILES_DIR#"$HOME/"}"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# Files to skip (not dotfiles)
SKIP_FILES="install.sh README.md LICENSE .gitignore .git"

# Special mappings: source -> relative-from-dest-dir/source
# ssh_config lives one level deeper (~/.ssh/config), so prefix with ../
declare -A SPECIAL=(
    ["ssh_config"]="$HOME/.ssh/config"
)

echo "Installing dotfiles from $DOTFILES_DIR"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Ensure .ssh directory exists
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Function to link a file/directory using a relative symlink
link_file() {
    local rel_source="$1"
    local dest="$2"

    # Backup existing file if it exists and isn't a symlink
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "↗ Backing up existing $dest"
        cp -r "$dest" "$BACKUP_DIR/"
    fi

    # Remove existing file or symlink
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        rm -f "$dest"
    fi

    # Create relative symlink
    ln -s "$rel_source" "$dest"
    echo "✓ Linked $rel_source -> $dest"
}

# Process all files in dotfiles directory
for file in "$DOTFILES_DIR"/*; do
    [ -f "$file" ] || continue  # Skip if not a file

    name=$(basename "$file")

    # Skip non-dotfiles
    if [[ " $SKIP_FILES " == *" $name "* ]]; then
        continue
    fi

    # Skip hidden files
    if [[ "$name" == .* ]]; then
        continue
    fi

    # Check for special mapping
    if [[ -v "SPECIAL[$name]" ]]; then
        dest="${SPECIAL[$name]}"
        # Special destinations are one dir deeper, so need ../
        link_file "../$DOTFILES_REL/$name" "$dest"
    else
        dest="$HOME/.$name"
        link_file "$DOTFILES_REL/$name" "$dest"
    fi
done

# Link subdirectories (e.g. bash_functions.d)
for dir in "$DOTFILES_DIR"/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    [[ "$name" == .* ]] && continue
    link_file "$DOTFILES_REL/$name" "$HOME/.$name"
done

# Set permissions on ssh config
if [ -f "$HOME/.ssh/config" ]; then
    chmod 600 "$HOME/.ssh/config"
fi

echo ""
echo "Done! Backup of any existing files saved to:"
echo "  $BACKUP_DIR"
echo ""
echo "Restart your terminal or run: source ~/.bash_profile"
