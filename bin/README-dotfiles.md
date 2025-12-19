# Dotfiles Manager

A simple tool to manage your dotfiles without the hassle of hidden files.

## The Problem

macOS hides dotfiles by default, making them annoying to:
- Browse in Finder
- Edit in some applications
- Version control effectively

## The Solution

Store your configs **without** the dot prefix in a visible `~/dotfiles/` directory, and use symlinks to connect them to their expected locations.

```
~/dotfiles/bashrc      →  ~/.bashrc (symlink)
~/dotfiles/gitconfig   →  ~/.gitconfig (symlink)
~/dotfiles/config/nvim →  ~/.config/nvim (symlink)
```

## Installation

```bash
# Copy the script somewhere in your PATH
cp manage.sh /usr/local/bin/dotfiles
chmod +x /usr/local/bin/dotfiles
```

Or create an alias in your shell config:
```bash
alias dotfiles="$HOME/dotfiles-manager/manage.sh"
```

## Usage

### Initialize

```bash
dotfiles init
```

Creates `~/dotfiles/` directory with a manifest file.

### Add existing dotfiles

```bash
# Add your shell config
dotfiles add ~/.bashrc
dotfiles add ~/.zshrc

# Add git config
dotfiles add ~/.gitconfig

# Add vim/neovim
dotfiles add ~/.vimrc
dotfiles add ~/.config/nvim
```

This **moves** the file to `~/dotfiles/` and creates a symlink in its place.

### Import existing dotfiles directory

If you already have a `~/dotfiles/` directory with config files:

```bash
dotfiles init                  # Creates manifest file
dotfiles import --all          # Imports all files and creates symlinks
```

Or import files individually:

```bash
dotfiles import bashrc                    # Imports as ~/.bashrc
dotfiles import nvim ~/.config/nvim       # Custom target path
```

### Check status

```bash
dotfiles status
```

Shows which files are linked, missing, or have conflicts.

### Link all files

```bash
dotfiles link
```

Creates symlinks for all managed files (useful after cloning your dotfiles repo on a new machine).

### Unlink all files

```bash
dotfiles unlink
```

Removes symlinks but keeps your source files safe in `~/dotfiles/`.

## Version Control

Since your files are now in a normal visible directory, you can easily:

```bash
cd ~/dotfiles
git init
git add .
git commit -m "Initial dotfiles"
git remote add origin git@github.com:you/dotfiles.git
git push -u origin main
```

### Setting up on a new machine

```bash
git clone git@github.com:you/dotfiles.git ~/dotfiles
dotfiles link
```

## Directory Structure

```
~/dotfiles/
├── .manifest          # Tracks file locations
├── bashrc             # Your .bashrc (no dot!)
├── zshrc              # Your .zshrc
├── gitconfig          # Your .gitconfig
├── vimrc              # Your .vimrc
└── config/
    └── nvim/          # Your ~/.config/nvim
        ├── init.lua
        └── ...
```

## Custom Directory

Use a different directory:

```bash
dotfiles -d ~/.config/dotfiles add ~/.bashrc
```

Or set the environment variable:

```bash
export DOTFILES_DIR="$HOME/.config/dotfiles"
```

## Tips

1. **Show hidden files in Finder**: Press `Cmd + Shift + .`
2. **Backup first**: The script moves files, so have a backup
3. **Git ignore the manifest**: Add `.manifest` to `.gitignore` if you want location-agnostic configs
