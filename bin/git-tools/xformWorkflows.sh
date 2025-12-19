#!/bin/bash

# Combined script to transform workflow files
# Makes both structural changes and pattern transformations
# Idempotent - won't add changes if they already exist

set -e

# Detect OS for sed compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
    SED_INPLACE=(-i '')
else
    SED_INPLACE=(-i)
fi

# Function to show usage
show_usage() {
    echo "Usage: $0 [options] [input-file] [output-file]"
    echo ""
    echo "Options:"
    echo "  -s, --structure-only     Apply only structural changes"
    echo "  -p, --patterns-only      Apply only pattern transformations"
    echo "  --prefix PREFIX          Prefix for pattern transformation (default: qrk_data-science_dev_)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Input modes:"
    echo "  No arguments             Process all .yml/.yaml files in current directory (in-place)"
    echo "  One argument             Process specific file (in-place)"
    echo "  Two arguments            Process first file, output to second file"
    echo ""
    echo "Examples:"
    echo "  $0                       # Process all .yml/.yaml files in-place"
    echo "  $0 workflow.yml          # Process workflow.yml in-place"
    echo "  $0 input.yml output.yml  # Process input.yml, save to output.yml"
    echo "  $0 -s workflow.yml       # Apply only structural changes to workflow.yml"
    echo "  $0 -p workflow.yml       # Apply only pattern transformations to workflow.yml"
    echo ""
    echo "Structural changes:"
    echo "  1. Add permissions block (contents: read, id-token: write)"
    echo "  2. Replace NAMESPACE_AIRLOCK_HASH with NAMESPACE_GSM_SVC_EMAIL"
    echo "  3. Change NAMESPACE_AIRLOCK_NAME from 'dev' to 'gsm'"
    echo "  4. Add wif-gsm-auth step after 'update fnd'"
    echo ""
    echo "Pattern transformation:"
    echo "  secrets.dev::PATH -> secrets.gsm::PREFIX + PATH"
    echo "  (with / and : in PATH converted to _)"
}

# Default options
APPLY_STRUCTURE=true
APPLY_PATTERNS=true
PREFIX="qrk_data-science_dev_"
YAML_FILES=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--structure-only)
            APPLY_STRUCTURE=true
            APPLY_PATTERNS=false
            shift
            ;;
        -p|--patterns-only)
            APPLY_STRUCTURE=false
            APPLY_PATTERNS=true
            shift
            ;;
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            YAML_FILES+=("$1")
            shift
            ;;
    esac
done

# Function to transform a single file
transform_file() {
    local INPUT_FILE="$1"
    local OUTPUT_FILE="${2:-$INPUT_FILE}"
    
    echo "Processing $INPUT_FILE..."
    
    # Create a temporary file for processing
    local TEMP_FILE=$(mktemp)
    cp "$INPUT_FILE" "$TEMP_FILE"
    
    local TOTAL_CHANGES=0
    
    # Apply structural changes if requested
    if [ "$APPLY_STRUCTURE" = true ]; then
        echo "  [Structural Changes]"
        local STRUCT_CHANGES=0
        
        # 1. Add permissions section after the build job line (only if not already present)
        if ! grep -q "id-token: write" "$TEMP_FILE"; then
            sed "${SED_INPLACE[@]}" '/^  build:$/a\
    permissions:\
      contents: read\
      id-token: write
' "$TEMP_FILE"
            echo "  ✓ Added permissions block"
            STRUCT_CHANGES=$((STRUCT_CHANGES + 1))
        else
            echo "  - Permissions block already exists, skipping"
        fi
        
        # 2. Replace NAMESPACE_AIRLOCK_HASH with NAMESPACE_GSM_SVC_EMAIL (if present)
        if grep -q "NAMESPACE_AIRLOCK_HASH:" "$TEMP_FILE"; then
            sed "${SED_INPLACE[@]}" 's/NAMESPACE_AIRLOCK_HASH: '\''\${{ secrets\.AIRLOCK_HASH }}'\''/NAMESPACE_GSM_SVC_EMAIL: svc-gcp-datascience-gsm@d-ulti-ml-ds-dev-9561.iam.gserviceaccount.com/' "$TEMP_FILE"
            sed "${SED_INPLACE[@]}" 's/NAMESPACE_AIRLOCK_HASH: "\${{ secrets\.AIRLOCK_HASH }}"/NAMESPACE_GSM_SVC_EMAIL: svc-gcp-datascience-gsm@d-ulti-ml-ds-dev-9561.iam.gserviceaccount.com/' "$TEMP_FILE"
            echo "  ✓ Replaced NAMESPACE_AIRLOCK_HASH with NAMESPACE_GSM_SVC_EMAIL"
            STRUCT_CHANGES=$((STRUCT_CHANGES + 1))
        else
            echo "  - NAMESPACE_AIRLOCK_HASH not found or already replaced"
        fi
        
        # 3. Change NAMESPACE_AIRLOCK_NAME from dev to gsm (if present)
        if grep -q "NAMESPACE_AIRLOCK_NAME: dev" "$TEMP_FILE"; then
            sed "${SED_INPLACE[@]}" 's/NAMESPACE_AIRLOCK_NAME: dev/NAMESPACE_AIRLOCK_NAME: gsm/' "$TEMP_FILE"
            echo "  ✓ Changed NAMESPACE_AIRLOCK_NAME from 'dev' to 'gsm'"
            STRUCT_CHANGES=$((STRUCT_CHANGES + 1))
        else
            echo "  - NAMESPACE_AIRLOCK_NAME already set to 'gsm' or not found"
        fi
        
        # 4. Add wif-gsm-auth step after "update fnd" step (only if not already present)
        if ! grep -q "name: wif-gsm-auth" "$TEMP_FILE"; then
            # Check if "update fnd" step exists
            if grep -q "name: update fnd" "$TEMP_FILE"; then
                sed "${SED_INPLACE[@]}" '/name: update fnd/,/run: fnd update/{
    /run: fnd update/a\
      - name: wif-gsm-auth\
        uses: UKGEPIC/sl-actions/gcp-util/svc-wif-gsm-foundry@v0+svc-wif-gsm-foundry
}' "$TEMP_FILE"
                echo "  ✓ Added wif-gsm-auth step"
                STRUCT_CHANGES=$((STRUCT_CHANGES + 1))
            else
                echo "  - 'update fnd' step not found, cannot add wif-gsm-auth"
            fi
        else
            echo "  - wif-gsm-auth step already exists, skipping"
        fi
        
        TOTAL_CHANGES=$((TOTAL_CHANGES + STRUCT_CHANGES))
    fi
    
    # Apply pattern transformations if requested
    if [ "$APPLY_PATTERNS" = true ]; then
        echo "  [Pattern Transformations]"
        
        # Check if file contains secrets.dev:: patterns
        if ! grep -q "secrets\.dev::" "$TEMP_FILE"; then
            echo "  - No secrets.dev:: patterns found"
        else
            # Count occurrences before transformation
            local COUNT=$(grep -o "secrets\.dev::[^\"' ]*" "$TEMP_FILE" 2>/dev/null | wc -l | tr -d ' ')
            
            if [ "$COUNT" -gt 0 ]; then
                # Create a backup for the transformation
                local BACKUP_FILE=$(mktemp)
                cp "$TEMP_FILE" "$BACKUP_FILE"
                
                # Use Perl for the transformation (works on both macOS and Linux)
                perl -pe 's/secrets\.dev::([^"'\'' \n]+)/
                    my $path = $1;
                    $path =~ s{\/|:}{_}g;  # Replace \/ and : with _
                    "secrets.gsm::'"$PREFIX"'" . $path;
                /ge' "$BACKUP_FILE" > "$TEMP_FILE"
                
                rm "$BACKUP_FILE"
                
                echo "  ✓ Transformed $COUNT secrets.dev:: pattern(s) to secrets.gsm::"
                TOTAL_CHANGES=$((TOTAL_CHANGES + COUNT))
            fi
        fi
    fi
    
    # Move the temporary file to the output file
    mv "$TEMP_FILE" "$OUTPUT_FILE"
    
    if [ "$OUTPUT_FILE" != "$INPUT_FILE" ]; then
        echo "  → Output saved to: $OUTPUT_FILE"
    fi
    
    if [ $TOTAL_CHANGES -gt 0 ]; then
        echo "  ✓ Total changes: $TOTAL_CHANGES"
    else
        echo "  - No changes needed (file already transformed)"
    fi
}

# Print configuration
echo "Configuration:"
if [ "$APPLY_STRUCTURE" = true ] && [ "$APPLY_PATTERNS" = true ]; then
    echo "  Mode: Both structural changes and pattern transformations"
elif [ "$APPLY_STRUCTURE" = true ]; then
    echo "  Mode: Structural changes only"
else
    echo "  Mode: Pattern transformations only"
fi
if [ "$APPLY_PATTERNS" = true ]; then
    echo "  Pattern prefix: $PREFIX"
fi
echo ""

# Determine which files to process
if [ ${#YAML_FILES[@]} -eq 0 ]; then
    # No files specified - process all .yml and .yaml files in current directory (in-place)
    echo "No files specified. Processing all .yml and .yaml files in current directory..."
    echo ""
    
    FILES_FOUND=0
    for file in *.yml *.yaml; do
        if [ -f "$file" ]; then
            transform_file "$file"
            echo ""
            FILES_FOUND=$((FILES_FOUND + 1))
        fi
    done
    
    if [ $FILES_FOUND -eq 0 ]; then
        echo "No .yml or .yaml files found in current directory."
        exit 1
    fi
    
    echo "Transformation complete! Processed $FILES_FOUND file(s)."
    
elif [ ${#YAML_FILES[@]} -eq 1 ]; then
    # One file specified - process it in-place
    INPUT_FILE="${YAML_FILES[0]}"
    
    if [ ! -f "$INPUT_FILE" ]; then
        echo "Error: File '$INPUT_FILE' not found"
        exit 1
    fi
    
    transform_file "$INPUT_FILE"
    echo ""
    echo "Transformation complete!"
    
elif [ ${#YAML_FILES[@]} -eq 2 ]; then
    # Two files specified - process first file, output to second file
    INPUT_FILE="${YAML_FILES[0]}"
    OUTPUT_FILE="${YAML_FILES[1]}"
    
    if [ ! -f "$INPUT_FILE" ]; then
        echo "Error: Input file '$INPUT_FILE' not found"
        exit 1
    fi
    
    transform_file "$INPUT_FILE" "$OUTPUT_FILE"
    echo ""
    echo "Transformation complete!"
    
else
    # More than 2 files - show error
    echo "Error: Too many file arguments. Please specify 0, 1, or 2 files."
    echo "Usage: $0 [options] [input-file] [output-file]"
    echo "Run '$0 --help' for more information."
    exit 1
fi
