#!/usr/bin/env bash
#
# bw-secrets.sh - Bitwarden CLI wrapper for secret management and file encryption
#
# Usage: ./bw-secrets.sh <command> [options]
#
# Commands:
#   login           - Log in to Bitwarden
#   unlock          - Unlock the vault and export session
#   lock            - Lock the vault
#   logout          - Log out of Bitwarden
#   status          - Check vault status
#   store           - Store a new secret
#   get             - Retrieve a secret
#   list            - List all secrets
#   delete          - Delete a secret
#   generate        - Generate a random secret key
#   encrypt         - Encrypt a file using a stored secret
#   decrypt         - Decrypt a file using a stored secret
#
# Environment:
#   BW_SESSION      - Bitwarden session key (set automatically by unlock)
#   BW_SECRETS_FOLDER - Folder name for secrets (default: "Encryption Keys")
#

set -euo pipefail

# Configuration
readonly SECRETS_FOLDER="${BW_SECRETS_FOLDER:-Encryption Keys}"
readonly SCRIPT_NAME="$(basename "$0")"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    log_error "$@"
    exit 1
}

check_dependencies() {
    local missing=()
    
    for cmd in bw jq openssl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing required dependencies: ${missing[*]}"
    fi
}

check_session() {
    if [[ -z "${BW_SESSION:-}" ]]; then
        die "Vault is locked. Run '$SCRIPT_NAME unlock' first."
    fi
    
    # Verify session is valid
    if ! bw unlock --check &>/dev/null; then
        die "Session expired. Run '$SCRIPT_NAME unlock' to refresh."
    fi
}

# -----------------------------------------------------------------------------
# Session Management
# -----------------------------------------------------------------------------

cmd_login() {
    local method="${1:-}"
    
    log_info "Logging in to Bitwarden..."
    
    case "$method" in
        apikey)
            bw login --apikey
            ;;
        sso)
            bw login --sso
            ;;
        *)
            bw login
            ;;
    esac
    
    log_success "Login successful. Run '$SCRIPT_NAME unlock' to unlock the vault."
}

cmd_unlock() {
    log_info "Unlocking Bitwarden vault..."
    
    local session
    session=$(bw unlock --raw)
    
    if [[ -n "$session" ]]; then
        export BW_SESSION="$session"
        log_success "Vault unlocked."
        echo ""
        echo "To use in current shell, run:"
        echo -e "  ${GREEN}export BW_SESSION=\"$session\"${NC}"
        echo ""
        echo "Or source this script's output:"
        echo -e "  ${GREEN}eval \$($SCRIPT_NAME unlock 2>/dev/null | grep 'export BW_SESSION')${NC}"
    else
        die "Failed to unlock vault."
    fi
}

cmd_lock() {
    log_info "Locking vault..."
    bw lock
    unset BW_SESSION 2>/dev/null || true
    log_success "Vault locked."
}

cmd_logout() {
    log_info "Logging out..."
    bw logout
    unset BW_SESSION 2>/dev/null || true
    log_success "Logged out."
}

cmd_status() {
    echo "Bitwarden CLI Status:"
    echo "---------------------"
    bw status | jq .
    
    if [[ -n "${BW_SESSION:-}" ]]; then
        if bw unlock --check &>/dev/null; then
            log_success "Session is valid."
        else
            log_warn "Session is expired."
        fi
    else
        log_warn "No session set (BW_SESSION not exported)."
    fi
}

# -----------------------------------------------------------------------------
# Folder Management
# -----------------------------------------------------------------------------

get_or_create_folder() {
    local folder_name="$1"
    local folder_id
    
    # Try to find existing folder
    folder_id=$(bw list folders --session "$BW_SESSION" 2>/dev/null | \
                jq -r ".[] | select(.name==\"$folder_name\") | .id" | head -1)
    
    if [[ -z "$folder_id" || "$folder_id" == "null" ]]; then
        # Create the folder
        log_info "Creating folder: $folder_name"
        local folder_json
        folder_json=$(echo "{\"name\":\"$folder_name\"}" | bw encode)
        folder_id=$(bw create folder "$folder_json" --session "$BW_SESSION" | jq -r '.id')
    fi
    
    echo "$folder_id"
}

# -----------------------------------------------------------------------------
# Secret Management
# -----------------------------------------------------------------------------

cmd_store() {
    local name=""
    local secret=""
    local notes=""
    local from_file=""
    local generate_key=false
    local key_length=32
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            -s|--secret)
                secret="$2"
                shift 2
                ;;
            -f|--file)
                from_file="$2"
                shift 2
                ;;
            --notes)
                notes="$2"
                shift 2
                ;;
            -g|--generate)
                generate_key=true
                shift
                ;;
            -l|--length)
                key_length="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
    
    [[ -z "$name" ]] && die "Secret name required. Use -n/--name."
    
    check_session
    
    # Get or generate the secret
    if [[ "$generate_key" == true ]]; then
        secret=$(openssl rand -base64 "$key_length")
        log_info "Generated $key_length-byte random key."
    elif [[ -n "$from_file" ]]; then
        [[ -f "$from_file" ]] || die "File not found: $from_file"
        secret=$(cat "$from_file")
    elif [[ -z "$secret" ]]; then
        log_info "Enter secret (will not echo):"
        read -rs secret
        echo ""
    fi
    
    [[ -z "$secret" ]] && die "Secret cannot be empty."
    
    # Get or create the secrets folder
    local folder_id
    folder_id=$(get_or_create_folder "$SECRETS_FOLDER")
    
    # Check if secret with this name already exists
    local existing
    existing=$(bw list items --folderid "$folder_id" --session "$BW_SESSION" 2>/dev/null | \
               jq -r ".[] | select(.name==\"$name\") | .id" | head -1)
    
    if [[ -n "$existing" && "$existing" != "null" ]]; then
        die "Secret '$name' already exists. Delete it first or use a different name."
    fi
    
    # Create the secure note item
    local item_json
    item_json=$(jq -n \
        --arg name "$name" \
        --arg notes "${notes:-Encryption key stored by bw-secrets.sh}" \
        --arg secret "$secret" \
        --arg folder "$folder_id" \
        '{
            type: 2,
            secureNote: { type: 0 },
            name: $name,
            notes: $notes,
            folderId: $folder,
            fields: [
                {
                    name: "key",
                    value: $secret,
                    type: 1
                }
            ]
        }')
    
    local encoded
    encoded=$(echo "$item_json" | bw encode)
    
    log_info "Storing secret: $name"
    bw create item "$encoded" --session "$BW_SESSION" > /dev/null
    
    # Sync to ensure it's uploaded
    bw sync --session "$BW_SESSION" > /dev/null
    
    log_success "Secret '$name' stored successfully."
}

cmd_get() {
    local name=""
    local output_file=""
    local quiet=false
    local folder_filter=""
    local field_name=""
    local get_password=false
    local get_username=false
    local get_notes=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -f|--folder)
                folder_filter="$2"
                shift 2
                ;;
            --field)
                field_name="$2"
                shift 2
                ;;
            -p|--password)
                get_password=true
                shift
                ;;
            -u|--username)
                get_username=true
                shift
                ;;
            --notes)
                get_notes=true
                shift
                ;;
            *)
                # Assume positional argument is the name
                name="$1"
                shift
                ;;
        esac
    done
    
    [[ -z "$name" ]] && die "Secret name required."
    
    check_session
    
    # Build the item query
    local items
    if [[ -n "$folder_filter" ]]; then
        local folder_id
        folder_id=$(bw list folders --session "$BW_SESSION" 2>/dev/null | \
                    jq -r ".[] | select(.name==\"$folder_filter\") | .id" | head -1)
        
        if [[ -z "$folder_id" || "$folder_id" == "null" ]]; then
            die "Folder '$folder_filter' not found."
        fi
        items=$(bw list items --folderid "$folder_id" --session "$BW_SESSION" 2>/dev/null)
    else
        items=$(bw list items --session "$BW_SESSION" 2>/dev/null)
    fi
    
    # Find the item by name
    local item
    item=$(echo "$items" | jq -r ".[] | select(.name==\"$name\")")
    
    if [[ -z "$item" || "$item" == "null" ]]; then
        die "Secret '$name' not found."
    fi
    
    # Extract the requested value
    local secret=""
    
    if [[ "$get_password" == true ]]; then
        secret=$(echo "$item" | jq -r '.login.password // empty')
        [[ -z "$secret" ]] && die "No password field found for '$name'."
    elif [[ "$get_username" == true ]]; then
        secret=$(echo "$item" | jq -r '.login.username // empty')
        [[ -z "$secret" ]] && die "No username field found for '$name'."
    elif [[ "$get_notes" == true ]]; then
        secret=$(echo "$item" | jq -r '.notes // empty')
        [[ -z "$secret" ]] && die "No notes found for '$name'."
    elif [[ -n "$field_name" ]]; then
        secret=$(echo "$item" | jq -r ".fields[]? | select(.name==\"$field_name\") | .value" | head -1)
        [[ -z "$secret" ]] && die "Field '$field_name' not found for '$name'."
    else
        # Default: try password, then custom field "key", then notes
        secret=$(echo "$item" | jq -r '.login.password // empty')
        if [[ -z "$secret" ]]; then
            secret=$(echo "$item" | jq -r '.fields[]? | select(.name=="key") | .value' | head -1)
        fi
        if [[ -z "$secret" ]]; then
            secret=$(echo "$item" | jq -r '.notes // empty')
        fi
        [[ -z "$secret" ]] && die "No secret value found for '$name'. Try --password, --field, or --notes."
    fi
    
    if [[ -n "$output_file" ]]; then
        echo -n "$secret" > "$output_file"
        chmod 600 "$output_file"
        [[ "$quiet" != true ]] && log_success "Secret written to: $output_file"
    else
        echo "$secret"
    fi
}

cmd_list() {
    local folder_filter=""
    local show_folders=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--folder)
                folder_filter="$2"
                shift 2
                ;;
            --folders)
                show_folders=true
                shift
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
    
    check_session
    
    # List folders if requested
    if [[ "$show_folders" == true ]]; then
        echo "Folders:"
        echo "--------"
        bw list folders --session "$BW_SESSION" 2>/dev/null | \
            jq -r '.[] | "  • \(.name)"'
        echo ""
        echo "(Use -f/--folder \"Folder Name\" to list items in a specific folder)"
        return 0
    fi
    
    # List items, optionally filtered by folder
    if [[ -n "$folder_filter" ]]; then
        local folder_id
        folder_id=$(bw list folders --session "$BW_SESSION" 2>/dev/null | \
                    jq -r ".[] | select(.name==\"$folder_filter\") | .id" | head -1)
        
        if [[ -z "$folder_id" || "$folder_id" == "null" ]]; then
            die "Folder '$folder_filter' not found."
        fi
        
        echo "Secrets in '$folder_filter':"
        echo "---------------------------------------"
        bw list items --folderid "$folder_id" --session "$BW_SESSION" 2>/dev/null | \
            jq -r '.[] | "  • \(.name) [\(.type | if . == 1 then "login" elif . == 2 then "note" elif . == 3 then "card" else "identity" end)]"'
    else
        echo "All Secrets:"
        echo "------------"
        bw list items --session "$BW_SESSION" 2>/dev/null | \
            jq -r 'group_by(.folderId) | .[] | .[0].folderId as $fid | "[\(if $fid then "folder" else "No Folder" end)]", (.[] | "  • \(.name) [\(.type | if . == 1 then "login" elif . == 2 then "note" elif . == 3 then "card" else "identity" end)]")'
        
        echo ""
        log_info "Use --folders to list folder names, or -f \"Folder\" to filter."
    fi
}

cmd_delete() {
    local name=""
    local force=false
    local folder_filter=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            --folder)
                folder_filter="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
                ;;
            *)
                name="$1"
                shift
                ;;
        esac
    done
    
    [[ -z "$name" ]] && die "Secret name required."
    
    check_session
    
    local items
    if [[ -n "$folder_filter" ]]; then
        local folder_id
        folder_id=$(bw list folders --session "$BW_SESSION" 2>/dev/null | \
                    jq -r ".[] | select(.name==\"$folder_filter\") | .id" | head -1)
        
        if [[ -z "$folder_id" || "$folder_id" == "null" ]]; then
            die "Folder '$folder_filter' not found."
        fi
        items=$(bw list items --folderid "$folder_id" --session "$BW_SESSION" 2>/dev/null)
    else
        items=$(bw list items --session "$BW_SESSION" 2>/dev/null)
    fi
    
    local item_id
    item_id=$(echo "$items" | jq -r ".[] | select(.name==\"$name\") | .id" | head -1)
    
    if [[ -z "$item_id" || "$item_id" == "null" ]]; then
        die "Secret '$name' not found."
    fi
    
    if [[ "$force" != true ]]; then
        read -rp "Delete secret '$name'? [y/N] " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && die "Aborted."
    fi
    
    bw delete item "$item_id" --session "$BW_SESSION" > /dev/null
    bw sync --session "$BW_SESSION" > /dev/null
    
    log_success "Secret '$name' deleted."
}

cmd_generate() {
    local length=32
    local format="base64"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--length)
                length="$2"
                shift 2
                ;;
            --hex)
                format="hex"
                shift
                ;;
            --base64)
                format="base64"
                shift
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
    
    case "$format" in
        base64)
            openssl rand -base64 "$length"
            ;;
        hex)
            openssl rand -hex "$length"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# File Encryption/Decryption
# -----------------------------------------------------------------------------

cmd_encrypt() {
    local input_file=""
    local output_file=""
    local secret_name=""
    local algorithm="aes-256-cbc"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--input)
                input_file="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -k|--key)
                secret_name="$2"
                shift 2
                ;;
            -a|--algorithm)
                algorithm="$2"
                shift 2
                ;;
            *)
                # Positional: input file
                if [[ -z "$input_file" ]]; then
                    input_file="$1"
                else
                    die "Unknown option: $1"
                fi
                shift
                ;;
        esac
    done
    
    [[ -z "$input_file" ]] && die "Input file required. Use -i/--input."
    [[ -f "$input_file" ]] || die "Input file not found: $input_file"
    [[ -z "$secret_name" ]] && die "Secret name required. Use -k/--key."
    
    # Default output filename
    [[ -z "$output_file" ]] && output_file="${input_file}.enc"
    
    check_session
    
    log_info "Retrieving encryption key..."
    local secret
    secret=$(cmd_get -n "$secret_name" -q)
    
    # Derive a proper key from the secret using PBKDF2
    # We use a fixed salt stored with the file for reproducibility
    local salt
    salt=$(openssl rand -hex 16)
    
    log_info "Encrypting: $input_file -> $output_file"
    
    # Create encrypted file with salt prepended
    {
        echo "BWENC1"  # File format marker
        echo "$salt"   # Salt for key derivation
        openssl enc -"$algorithm" -pbkdf2 -iter 100000 \
            -salt -pass "pass:$secret" \
            -in "$input_file"
    } > "$output_file"
    
    chmod 600 "$output_file"
    log_success "File encrypted successfully."
    log_info "Output: $output_file"
}

cmd_decrypt() {
    local input_file=""
    local output_file=""
    local secret_name=""
    local algorithm="aes-256-cbc"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--input)
                input_file="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -k|--key)
                secret_name="$2"
                shift 2
                ;;
            -a|--algorithm)
                algorithm="$2"
                shift 2
                ;;
            *)
                if [[ -z "$input_file" ]]; then
                    input_file="$1"
                else
                    die "Unknown option: $1"
                fi
                shift
                ;;
        esac
    done
    
    [[ -z "$input_file" ]] && die "Input file required. Use -i/--input."
    [[ -f "$input_file" ]] || die "Input file not found: $input_file"
    [[ -z "$secret_name" ]] && die "Secret name required. Use -k/--key."
    
    # Default output filename (remove .enc extension if present)
    if [[ -z "$output_file" ]]; then
        if [[ "$input_file" == *.enc ]]; then
            output_file="${input_file%.enc}"
        else
            output_file="${input_file}.dec"
        fi
    fi
    
    check_session
    
    # Verify file format
    local marker
    marker=$(head -1 "$input_file")
    [[ "$marker" != "BWENC1" ]] && die "Invalid encrypted file format."
    
    log_info "Retrieving decryption key..."
    local secret
    secret=$(cmd_get -n "$secret_name" -q)
    
    log_info "Decrypting: $input_file -> $output_file"
    
    # Skip the header lines and decrypt
    tail -n +3 "$input_file" | \
        openssl enc -d -"$algorithm" -pbkdf2 -iter 100000 \
            -salt -pass "pass:$secret" \
            -out "$output_file"
    
    log_success "File decrypted successfully."
    log_info "Output: $output_file"
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

show_help() {
    cat << 'EOF'
bw-secrets.sh - Bitwarden CLI wrapper for secret management and file encryption

USAGE:
    ./bw-secrets.sh <command> [options]

SESSION COMMANDS:
    login [method]      Log in to Bitwarden (methods: apikey, sso, or interactive)
    unlock              Unlock vault and display session export command
    lock                Lock the vault
    logout              Log out of Bitwarden
    status              Show vault and session status

SECRET MANAGEMENT:
    store [options]     Store a new secret
        -n, --name      Secret name (required)
        -s, --secret    Secret value (or use -f or -g)
        -f, --file      Read secret from file
        -g, --generate  Generate a random secret
        -l, --length    Key length in bytes (default: 32)
        --notes         Add notes to the secret

    get [options]       Retrieve a secret
        -n, --name      Secret name (required)
        -o, --output    Write to file instead of stdout
        -q, --quiet     Suppress status messages
        -f, --folder    Search only in this folder
        -p, --password  Get the password field (for login items)
        -u, --username  Get the username field (for login items)
        --field NAME    Get a specific custom field
        --notes         Get the notes field

    list [options]      List secrets
        --folders       List all folders
        -f, --folder    List items in a specific folder
        (no options)    List all items grouped by folder

    delete [options]    Delete a secret
        -n, --name      Secret name (required)
        -f, --force     Skip confirmation

    generate [options]  Generate a random key (does not store it)
        -l, --length    Key length in bytes (default: 32)
        --hex           Output in hexadecimal
        --base64        Output in base64 (default)

FILE ENCRYPTION:
    encrypt [options]   Encrypt a file using a stored secret
        -i, --input     Input file (required)
        -o, --output    Output file (default: input.enc)
        -k, --key       Secret name to use (required)
        -a, --algorithm OpenSSL cipher (default: aes-256-cbc)

    decrypt [options]   Decrypt a file using a stored secret
        -i, --input     Input file (required)
        -o, --output    Output file (default: removes .enc)
        -k, --key       Secret name to use (required)
        -a, --algorithm OpenSSL cipher (default: aes-256-cbc)

ENVIRONMENT:
    BW_SESSION          Bitwarden session key
    BW_SECRETS_FOLDER   Folder name for new secrets (default: "Encryption Keys")

EXAMPLES:
    # Initial setup
    ./bw-secrets.sh login
    eval $(./bw-secrets.sh unlock 2>/dev/null | grep 'export BW_SESSION')

    # List all secrets
    ./bw-secrets.sh list

    # List folders
    ./bw-secrets.sh list --folders

    # List secrets in a specific folder
    ./bw-secrets.sh list -f "My Folder"

    # Get a password from a login item
    ./bw-secrets.sh get "GitHub" --password

    # Get a custom field
    ./bw-secrets.sh get "API Keys" --field "production-key"

    # Store a generated encryption key
    ./bw-secrets.sh store -n "backup-key" -g -l 32

    # Encrypt a file
    ./bw-secrets.sh encrypt -i document.pdf -k "backup-key"

    # Decrypt a file
    ./bw-secrets.sh decrypt -i document.pdf.enc -k "backup-key"
EOF
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    check_dependencies
    
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        login)      cmd_login "$@" ;;
        unlock)     cmd_unlock "$@" ;;
        lock)       cmd_lock "$@" ;;
        logout)     cmd_logout "$@" ;;
        status)     cmd_status "$@" ;;
        store)      cmd_store "$@" ;;
        get)        cmd_get "$@" ;;
        list)       cmd_list "$@" ;;
        delete)     cmd_delete "$@" ;;
        generate)   cmd_generate "$@" ;;
        encrypt)    cmd_encrypt "$@" ;;
        decrypt)    cmd_decrypt "$@" ;;
        help|--help|-h)
            show_help
            ;;
        *)
            die "Unknown command: $command. Use '$SCRIPT_NAME help' for usage."
            ;;
    esac
}

main "$@"
