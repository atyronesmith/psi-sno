#!/bin/bash

# Script to extract and decode ignition.config.merge from a JSON file
# Default operation: Loop through array, decode/decompress base64 content, and pretty-print JSON
# Usage: ./extract-ignition-merge.sh [OPTIONS] <json_file> [output_dir]

set -euo pipefail

# Default options
RAW_MODE=false
OUTPUT_PREFIX="merge-item"

# Check if required tools are installed
check_dependencies() {
    local missing_tools=()

    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi

    if [ "$RAW_MODE" = false ]; then
        if ! command -v base64 &> /dev/null; then
            missing_tools+=("base64")
        fi
        if ! command -v gzip &> /dev/null; then
            missing_tools+=("gzip")
        fi
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "Error: Missing required tools: ${missing_tools[*]}" >&2
        echo "Please install the missing tools first." >&2
        exit 1
    fi
}

# Show usage information
show_usage() {
    cat << 'EOF'
Usage: extract-ignition-merge.sh [OPTIONS] <json_file> [output_dir]

OPTIONS:
  -r, --raw        Output raw JSON array instead of decoding content
  -h, --help       Show this help message

ARGUMENTS:
  json_file        Input JSON file containing ignition configuration
  output_dir       Optional output directory (default: current directory)

MODES:
  Default mode: Process each array item, decode base64 and decompress
  Raw mode:     Extract raw ignition.config.merge array to stdout

Examples:
  ./extract-ignition-merge.sh ignition.json                    # Decode to current directory
  ./extract-ignition-merge.sh ignition.json ./decoded          # Decode to ./decoded directory
  ./extract-ignition-merge.sh --raw ignition.json              # Output raw JSON to stdout
  ./extract-ignition-merge.sh build/projects/my-project/ignition.json ./output

DESCRIPTION:
  This script processes ignition.config.merge arrays containing objects like:
  [{"compression": "gzip", "source": "data:;base64,..."}, ...]

  By default, it decodes the base64 content, decompresses if needed, and
  pretty-prints the resulting JSON using jq. Output files are saved as .json.
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--raw)
                RAW_MODE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                echo "Error: Unknown option $1" >&2
                show_usage
                exit 1
                ;;
            *)
                if [ -z "${INPUT_FILE:-}" ]; then
                    INPUT_FILE="$1"
                elif [ -z "${OUTPUT_DIR:-}" ]; then
                    OUTPUT_DIR="$1"
                else
                    echo "Error: Too many arguments" >&2
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "${INPUT_FILE:-}" ]; then
        echo "Error: Missing required argument: json_file" >&2
        show_usage
        exit 1
    fi

    OUTPUT_DIR="${OUTPUT_DIR:-.}"
}

# Decode base64 data, decompress if needed, and pretty-print JSON
decode_and_decompress() {
    local source_data="$1"
    local compression="$2"
    local output_file="$3"

    # Remove data URI prefix (data:;base64,)
    local base64_data="${source_data#data:;base64,}"

    # Decode base64, handle compression, and pretty-print JSON
    if [ "$compression" = "gzip" ]; then
        # Decode, decompress gzip, and pretty-print JSON
        echo "$base64_data" | base64 -d | gzip -d | jq '.' > "$output_file"
    else
        # Decode base64 and pretty-print JSON
        echo "$base64_data" | base64 -d | jq '.' > "$output_file"
    fi
}

# Process merge array - decode and decompress (default operation)
process_decode_mode() {
    local merge_array_length
    merge_array_length=$(jq '.ignition.config.merge | length' "$INPUT_FILE" 2>/dev/null)

    if [ "$merge_array_length" = "null" ] || [ "$merge_array_length" = "0" ]; then
        echo "Warning: ignition.config.merge field not found or is empty in '$INPUT_FILE'" >&2
        exit 1
    fi

    echo "Processing $merge_array_length merge items from '$INPUT_FILE'..."

    # Create output directory if it doesn't exist
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        echo "Created output directory: $OUTPUT_DIR"
    fi

    # Process each item in the merge array
    for ((i=0; i<merge_array_length; i++)); do
        local compression
        local source
        local output_file

        # Extract compression and source from current array item
        compression=$(jq -r ".ignition.config.merge[$i].compression // \"none\"" "$INPUT_FILE")
        source=$(jq -r ".ignition.config.merge[$i].source" "$INPUT_FILE")

        if [ "$source" = "null" ]; then
            echo "Warning: Item $i has no source data, skipping..." >&2
            continue
        fi

        # Determine output filename - all output is pretty-printed JSON
        output_file="$OUTPUT_DIR/${OUTPUT_PREFIX}-${i}.json"

        echo "Processing item $i (compression: $compression) -> $output_file"

        # Decode and decompress
        if decode_and_decompress "$source" "$compression" "$output_file"; then
            echo "  ✓ Successfully processed item $i"

            # Show content preview for verification
            if [ -s "$output_file" ]; then
                local file_size=$(wc -c < "$output_file")
                echo "  File size: $file_size bytes"
                echo "  Preview (first 3 lines):"
                head -3 "$output_file" 2>/dev/null | sed 's/^/    /' || echo "    [Binary or unreadable content]"
                if [ $(wc -l < "$output_file" 2>/dev/null || echo 0) -gt 3 ]; then
                    echo "    ..."
                fi
            fi
        else
            echo "  ✗ Failed to process item $i" >&2
            rm -f "$output_file" 2>/dev/null || true
        fi
    done

    echo ""
    echo "Completed processing merge items. Output saved to: $OUTPUT_DIR"
    echo "Files created:"
    ls -la "$OUTPUT_DIR"/${OUTPUT_PREFIX}-* 2>/dev/null || echo "  No files were created"
}

# Extract raw merge data (optional mode)
extract_raw_merge() {
    echo "Extracting raw ignition.config.merge from '$INPUT_FILE'..." >&2

    if ! jq '.ignition.config.merge // empty' "$INPUT_FILE"; then
        echo "Error: Failed to extract ignition.config.merge from '$INPUT_FILE'" >&2
        exit 1
    fi
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"

    # Check dependencies
    check_dependencies

    # Validate input file
    if [ ! -f "$INPUT_FILE" ]; then
        echo "Error: Input file '$INPUT_FILE' does not exist." >&2
        exit 1
    fi

    if [ ! -r "$INPUT_FILE" ]; then
        echo "Error: Cannot read input file '$INPUT_FILE'." >&2
        exit 1
    fi

    # Main processing logic - decode is the default operation
    if [ "$RAW_MODE" = true ]; then
        extract_raw_merge
    else
        process_decode_mode
    fi
}

# Run main function with all arguments
main "$@"