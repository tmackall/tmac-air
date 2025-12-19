# Dotfiles

Personal configuration files for macOS and Linux.

## Quick Start

```bash
git clone git@github.com:YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## What's Included

| File | Description |
|------|-------------|
| `bash_profile` | macOS login shell config (sources bashrc) |
| `bashrc` | Main shell config - aliases, functions, prompt |
| `vimrc` | Vim configuration |
| `gitconfig` | Git settings and aliases |
| `ssh_config` | SSH host aliases and defaults |

## Installation

The install script creates symlinks from your home directory to this repo:

```
~/.bashrc -> ~/dotfiles/bashrc
~/.vimrc -> ~/dotfiles/vimrc
(etc.)
```

Existing files are backed up to `~/.dotfiles_backup/` before being replaced.

## Machine-Specific Config

For settings that differ between machines, use `~/.bashrc.local`:

```bash
# This file is sourced at the end of .bashrc if it exists
export WORK_ENV="staging"
alias deploy='./scripts/deploy-staging.sh'
```

## Updating

Edit files in this repo, commit, and push. Changes take effect immediately since they're symlinked.

To pull updates on another machine:

```bash
cd ~/dotfiles
git pull
```

## Adding New Files

1. Add the file to this repo (without the leading dot): `vimrc` not `.vimrc`
2. Add an entry to the `FILES` array in `install.sh`
3. Run `./install.sh` again
