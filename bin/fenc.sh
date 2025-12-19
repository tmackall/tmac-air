#!/usr/bin/env bash
#
# fenc - Simple file encryption/decryption using OpenSSL
# Compatible with macOS and Linux
#

set -euo pipefail

# Encryption settings
readonly ENC_CIPHER="aes-256-cbc"
readonly ENC_OPTS="-md sha512 -pbkdf2 -iter 1000000 -salt"

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly NC=''
fi

log_info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> <file> [options]

Commands:
    enc, encrypt    Encrypt a file
    dec, decrypt    Decrypt a file

Options:
    -o, --output    Specify output file (default: <file>.enc for encrypt, 
                    <file> without .enc for decrypt)
    -b, --backup    Create backup copy before processing
    -f, --force     Overwrite output file if it exists
    -h, --help      Show this help message

Environment:
    FENC_PASSWORD   If set, use this password (non-interactive mode)

Examples:
    $(basename "$0") enc secret.txt
    $(basename "$0") dec secret.txt.enc -o decrypted.txt
    FENC_PASSWORD=mypass $(basename "$0") enc data.json

EOF
}

create_backup() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup_dir="${TMPDIR:-/tmp}"
        local backup_file
        backup_file="${backup_dir}/$(basename "$file").backup.$$"
        if cp "$file" "$backup_file"; then
            log_info "Backup created: $backup_file"
        else
            log_error "Failed to create backup"
            return 1
        fi
    fi
}

encrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local do_backup="$3"
    local force="$4"

    # Validate input file
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi

    if [[ ! -r "$input_file" ]]; then
        log_error "Cannot read input file: $input_file"
        return 1
    fi

    # Check output file
    if [[ -e "$output_file" && "$force" != "true" ]]; then
        log_error "Output file exists: $output_file (use -f to overwrite)"
        return 1
    fi

    # Create backup if requested
    if [[ "$do_backup" == "true" ]]; then
        create_backup "$input_file" || return 1
    fi

    # Build openssl command arguments
    local -a cmd_args=("enc" "-${ENC_CIPHER}" ${ENC_OPTS})
    
    if [[ -n "${FENC_PASSWORD:-}" ]]; then
        cmd_args+=("-pass" "pass:${FENC_PASSWORD}")
    fi

    cmd_args+=("-in" "$input_file" "-out" "$output_file")

    log_info "Encrypting: $input_file -> $output_file"
    
    if openssl "${cmd_args[@]}"; then
        log_info "Successfully created: $output_file"
    else
        log_error "Encryption failed"
        [[ -f "$output_file" ]] && rm -f "$output_file"
        return 1
    fi
}

decrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local do_backup="$3"
    local force="$4"

    # Validate input file
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi

    if [[ ! -r "$input_file" ]]; then
        log_error "Cannot read input file: $input_file"
        return 1
    fi

    # Check output file
    if [[ -e "$output_file" && "$force" != "true" ]]; then
        log_error "Output file exists: $output_file (use -f to overwrite)"
        return 1
    fi

    # Create backup if requested
    if [[ "$do_backup" == "true" ]]; then
        create_backup "$input_file" || return 1
    fi

    # Build openssl command arguments
    local -a cmd_args=("enc" "-${ENC_CIPHER}" ${ENC_OPTS} "-d")
    
    if [[ -n "${FENC_PASSWORD:-}" ]]; then
        cmd_args+=("-pass" "pass:${FENC_PASSWORD}")
    fi

    cmd_args+=("-in" "$input_file" "-out" "$output_file")

    log_info "Decrypting: $input_file -> $output_file"
    
    if openssl "${cmd_args[@]}"; then
        log_info "Successfully created: $output_file"
    else
        log_error "Decryption failed (wrong password or corrupted file?)"
        [[ -f "$output_file" ]] && rm -f "$output_file"
        return 1
    fi
}

main() {
    local command=""
    local input_file=""
    local output_file=""
    local do_backup="false"
    local force="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            enc|encrypt)
                command="encrypt"
                shift
                ;;
            dec|decrypt)
                command="decrypt"
                shift
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -b|--backup)
                do_backup="true"
                shift
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -z "$input_file" ]]; then
                    input_file="$1"
                else
                    log_error "Unexpected argument: $1"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Show usage if no arguments provided
    if [[ -z "$command" && -z "$input_file" ]]; then
        usage
        exit 0
    fi

    # Validate required arguments
    if [[ -z "$command" ]]; then
        log_error "No command specified"
        usage
        exit 1
    fi

    if [[ -z "$input_file" ]]; then
        log_error "No input file specified"
        usage
        exit 1
    fi

    # Set default output file if not specified
    if [[ -z "$output_file" ]]; then
        if [[ "$command" == "encrypt" ]]; then
            output_file="${input_file}.enc"
        else
            # Remove .enc extension if present
            if [[ "$input_file" == *.enc ]]; then
                output_file="${input_file%.enc}"
            else
                output_file="${input_file}.dec"
            fi
        fi
    fi

    # Check for openssl
    if ! command -v openssl &>/dev/null; then
        log_error "openssl is required but not found in PATH"
        exit 1
    fi

    # Execute command
    case "$command" in
        encrypt)
            encrypt_file "$input_file" "$output_file" "$do_backup" "$force"
            ;;
        decrypt)
            decrypt_file "$input_file" "$output_file" "$do_backup" "$force"
            ;;
    esac
}

# Allow sourcing for function access or run as script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
