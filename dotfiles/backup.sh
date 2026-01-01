backup() {
    local dest=""
    local use_epoch=0
    local sources=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                dest="$2"
                shift 2
                ;;
            -e|--epoch)
                use_epoch=1
                shift
                ;;
            -h|--help)
                cat <<EOF
Usage: backup [options] <path> [path...]

Options:
    -o, --output FILE    Output filename (default: auto-generated)
    -e, --epoch          Use epoch timestamp in filename
    -h, --help           Show this help

Examples:
    backup ~/.ssh
    backup ~/.ssh ~/.gnupg
    backup -o secrets.age ~/.ssh ~/.gnupg ~/.config/gh
    backup -e ~/.ssh                # -> backup-ssh-1703345678.age
EOF
                return 0
                ;;
            *)
                sources+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#sources[@]} -eq 0 ]]; then
        backup --help
        return 0
    fi

    # Validate all sources exist
    for src in "${sources[@]}"; do
        if [[ ! -e "$src" ]]; then
            echo "Not found: $src"
            return 1
        fi
    done

    # Generate default filename
    if [[ -z "$dest" ]]; then
        local timestamp
        if [[ $use_epoch -eq 1 ]]; then
            timestamp=$(date +%s)
        else
            timestamp=$(date +%Y%m%d)
        fi
        if [[ ${#sources[@]} -eq 1 ]]; then
            dest="backup-$(basename "${sources[0]}")-${timestamp}.age"
        else
            if [[ $use_epoch -eq 1 ]]; then
                dest="backup-${timestamp}.age"
            else
                dest="backup-$(date +%Y%m%d-%H%M%S).age"
            fi
        fi
    fi

    # Build tar arguments - store paths relative to home where possible
    local tar_args=()
    for src in "${sources[@]}"; do
        local abs_path=$(cd "$(dirname "$src")" && pwd)/$(basename "$src")
        if [[ "$abs_path" == "$HOME"/* ]]; then
            tar_args+=(-C "$HOME" ".${abs_path#$HOME}")
        else
            tar_args+=(-C "$(dirname "$abs_path")" "$(basename "$abs_path")")
        fi
    done

    tar -czf - "${tar_args[@]}" | age -p > "$dest"
    echo "Created: $dest"
    echo "Contents:"
    backup-list "$dest" 2>/dev/null | head -20
}

backup-list() {
    local backup_file="$1"

    if [[ -z "$backup_file" ]]; then
        echo "Usage: backup-list <backup.age>"
        return 0
    fi

    if [[ ! -f "$backup_file" ]]; then
        echo "Not found: $backup_file"
        return 1
    fi

    age -d "$backup_file" | tar -tzvf -
}

restore() {
    local dest="$HOME"
    local backup_file=""
    local dry_run=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dest)
                dest="$2"
                shift 2
                ;;
            -n|--dry-run)
                dry_run=1
                shift
                ;;
            -h|--help)
                cat <<EOF
Usage: restore [options] <backup.age>

Options:
    -d, --dest DIR    Destination directory (default: ~/)
    -n, --dry-run     List contents without extracting
    -h, --help        Show this help

Examples:
    restore backup-ssh.age
    restore -d /tmp backup-ssh.age
    restore --dry-run backup.age
EOF
                return 0
                ;;
            *)
                backup_file="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$backup_file" ]]; then
        restore --help
        return 0
    fi

    if [[ ! -f "$backup_file" ]]; then
        echo "Not found: $backup_file"
        return 1
    fi

    if [[ $dry_run -eq 1 ]]; then
        echo "Contents of $backup_file:"
        backup-list "$backup_file"
        return 0
    fi

    mkdir -p "$dest"
    age -d "$backup_file" | tar -xzvf - -C "$dest"
    echo "Restored to: $dest"
}
