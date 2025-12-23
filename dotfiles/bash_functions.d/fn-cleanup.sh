fn-cleanup() {
    local dry_run=0
    local recursive=0
    local lowercase=0
    local add_date=""
    local files=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run)
                dry_run=1
                shift
                ;;
            -r|--recursive)
                recursive=1
                shift
                ;;
            -l|--lowercase)
                lowercase=1
                shift
                ;;
            -t|--timestamp)
                add_date="timestamp"
                shift
                ;;
            -e|--epoch)
                add_date="epoch"
                shift
                ;;
            -h|--help)
                cat <<EOF
Usage: fn-cleanup [options] <file|dir> [file|dir...]

Cleans up filenames by removing/replacing problematic characters.

Changes made:
    - Spaces, tabs         -> underscores
    - Parentheses ()       -> removed
    - Brackets []{}        -> removed
    - Quotes '"            -> removed
    - Special chars &!?#%  -> removed
    - Multiple underscores -> single underscore
    - Leading/trailing _   -> removed

Options:
    -n, --dry-run     Show what would be renamed
    -r, --recursive   Process directories recursively
    -l, --lowercase   Convert to lowercase
    -t, --timestamp   Add date suffix (YYYYMMDD)
    -e, --epoch       Add epoch timestamp suffix
    -h, --help        Show this help

Examples:
    fn-cleanup "My File (1).pdf"
    fn-cleanup -n *.pdf
    fn-cleanup -r ~/Downloads
    fn-cleanup -rl ~/Documents/Project
    fn-cleanup -t report.pdf          # -> report-20241223.pdf
    fn-cleanup -e screenshot.png      # -> screenshot-1703345678.png
EOF
                return 0
                ;;
            *)
                files+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#files[@]} -eq 0 ]]; then
        fn-cleanup --help
        return 0
    fi

    # Process a single file/directory name
    _fn_cleanup_one() {
        local file="$1"

        if [[ ! -e "$file" ]]; then
            echo "Not found: $file"
            return 1
        fi

        local dir=$(dirname "$file")
        local name=$(basename "$file")
        local new_name="$name"

        # Replace spaces and tabs with underscores
        new_name=$(echo "$new_name" | tr '[:space:]' '_')

        # Remove problematic characters
        new_name=$(echo "$new_name" | tr -d "()[]{}'\"\`&!?#%@")

        # Replace other chars that can cause issues with underscores
        new_name=$(echo "$new_name" | tr ',;=+' '_')

        # Collapse multiple underscores to single
        new_name=$(echo "$new_name" | sed 's/__*/_/g')

        # Remove leading/trailing underscores (but preserve extension)
        local ext=""
        if [[ "$new_name" == *.* && ! -d "$file" ]]; then
            ext=".${new_name##*.}"
            # Strip trailing underscores from extension (from trailing whitespace in original)
            while [[ "$ext" == *_ ]]; do ext="${ext%_}"; done
            new_name="${new_name%.*}"
        fi
        new_name=$(echo "$new_name" | sed 's/^_*//; s/_*$//')
        new_name="${new_name}${ext}"

        # Lowercase if requested
        if [[ $lowercase -eq 1 ]]; then
            new_name=$(echo "$new_name" | tr '[:upper:]' '[:lower:]')
        fi

        # Add date suffix if requested
        if [[ -n "$add_date" ]]; then
            local base_name="${new_name%.*}"
            local ext=""
            if [[ "$new_name" == *.* && ! -d "$file" ]]; then
                ext=".${new_name##*.}"
            fi
            if [[ "$add_date" == "epoch" ]]; then
                base_name="${base_name}-$(date +%s)"
            else
                base_name="${base_name}-$(date +%Y%m%d)"
            fi
            new_name="${base_name}${ext}"
        fi

        # Skip if no change
        if [[ "$name" == "$new_name" ]]; then
            return 0
        fi

        local new_path="$dir/$new_name"

        # Handle collision
        if [[ -e "$new_path" ]]; then
            local base="${new_name%.*}"
            local ext=""
            if [[ "$new_name" == *.* ]]; then
                ext=".${new_name##*.}"
            fi
            local counter=1
            while [[ -e "$dir/${base}_${counter}${ext}" ]]; do
                ((counter++))
            done
            new_name="${base}_${counter}${ext}"
            new_path="$dir/$new_name"
        fi

        if [[ $dry_run -eq 1 ]]; then
            echo "$name -> $new_name"
        else
            mv "$file" "$new_path"
            echo "Renamed: $name -> $new_name"
        fi

        # Return the new path for recursive processing
        echo "$new_path"
    }

    # Process files, optionally recursively
    _fn_cleanup_path() {
        local path="$1"

        if [[ -d "$path" && $recursive -eq 1 ]]; then
            # Process contents first (depth-first)
            for item in "$path"/*; do
                [[ -e "$item" ]] || continue
                _fn_cleanup_path "$item"
            done
            # Process hidden files too
            for item in "$path"/.*; do
                [[ -e "$item" ]] || continue
                [[ "$(basename "$item")" == "." || "$(basename "$item")" == ".." ]] && continue
                _fn_cleanup_path "$item"
            done
        fi

        # Now process the path itself
        _fn_cleanup_one "$path" > /dev/null
    }

    # Main processing with simpler output
    _fn_cleanup_process() {
        local file="$1"

        if [[ ! -e "$file" ]]; then
            echo "Not found: $file"
            return 1
        fi

        if [[ -d "$file" && $recursive -eq 1 ]]; then
            # Process contents first (depth-first)
            for item in "$file"/*; do
                [[ -e "$item" ]] || continue
                _fn_cleanup_process "$item"
            done
            for item in "$file"/.*; do
                [[ -e "$item" ]] || continue
                [[ "$(basename "$item")" == "." || "$(basename "$item")" == ".." ]] && continue
                _fn_cleanup_process "$item"
            done
        fi

        _fn_cleanup_one "$file"
    }

    for file in "${files[@]}"; do
        _fn_cleanup_process "$file" | grep -v "^/"  # Filter out path returns, show only rename messages
    done
}
