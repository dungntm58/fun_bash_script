#!/bin/bash

# Optimized CSV Standardization Script for Large Files (100k+ rows)
# Uses parallel processing and memory-efficient streaming

set -euo pipefail

usage() {
    echo "Usage: $0 <input_file> [output_file] [chunk_size]"
    echo "  input_file:  Source CSV file to standardize"
    echo "  output_file: Target file (default: input_file.standardized.csv)"
    echo "  chunk_size:  Lines per chunk for parallel processing (default: 10000)"
    echo ""
    echo "Features:"
    echo "  - Memory efficient streaming (no file size limits)"
    echo "  - Parallel processing for faster execution"
    echo "  - Progress reporting"
    echo "  - Error handling and validation"
    exit 1
}

cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# Check arguments
if [[ $# -lt 1 || $# -gt 3 ]]; then
    usage
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-${INPUT_FILE%.csv}.standardized.csv}"
CHUNK_SIZE="${3:-10000}"
TEMP_DIR=$(mktemp -d)

# Validate input
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file '$INPUT_FILE' does not exist"
    exit 1
fi

if ! [[ "$CHUNK_SIZE" =~ ^[0-9]+$ ]] || [[ "$CHUNK_SIZE" -lt 1 ]]; then
    echo "Error: Chunk size must be a positive integer"
    exit 1
fi

# CSV Format Verification Function
verify_csv_format() {
    local file="$1"
    local sample_lines=10

    echo "=== CSV Format Verification ==="

    # Check if file is empty
    if [[ ! -s "$file" ]]; then
        echo "❌ Error: File is empty"
        return 1
    fi

    # Analyze first few lines for format detection
    local header=$(head -n 1 "$file")
    local sample=$(head -n $sample_lines "$file")

    # Check for the problematic format patterns
    local has_double_quotes=$(echo "$sample" | grep -c '"".*""' || true)
    local has_semicolons=$(echo "$sample" | grep -c ';' || true)
    local has_commas=$(echo "$sample" | grep -c ',' || true)
    local has_outer_quotes=$(echo "$sample" | grep -c '^".*"$' || true)
    local total_lines=$(echo "$sample" | wc -l)

    echo "Sample analysis (first $sample_lines lines):"
    echo "  Lines with double quotes (\"\"field\"\"): $has_double_quotes/$total_lines"
    echo "  Lines with semicolons: $has_semicolons/$total_lines"
    echo "  Lines with commas: $has_commas/$total_lines"
    echo "  Lines with outer quotes: $has_outer_quotes/$total_lines"
    echo ""

    # Detect format issues
    local needs_standardization=false
    local issues=()
    local detected_delimiter=""

    if [[ $has_double_quotes -gt 0 ]]; then
        issues+=("Double-quoted fields detected")
        needs_standardization=true
    fi

    # Determine delimiter type
    if [[ $has_semicolons -gt 0 ]] && [[ $has_commas -eq 0 ]]; then
        detected_delimiter="semicolon"
        if [[ $has_outer_quotes -gt 0 ]]; then
            issues+=("Semicolon-delimited with quote wrapping detected")
            needs_standardization=true
        fi
    elif [[ $has_commas -gt 0 ]] && [[ $has_semicolons -eq 0 ]]; then
        detected_delimiter="comma"
        if [[ $has_double_quotes -gt 0 ]]; then
            issues+=("Comma-delimited with double quotes detected")
            needs_standardization=true
        fi
    elif [[ $has_semicolons -gt 0 ]] && [[ $has_commas -gt 0 ]]; then
        detected_delimiter="mixed"
        issues+=("Mixed delimiter format detected (both commas and semicolons)")
        needs_standardization=true
    fi

    echo "Detected delimiter: $detected_delimiter"

    # Check for inconsistent column counts
    local field_counts=$(echo "$sample" | sed 's/[^;,]//g' | awk '{print length}' | sort -nu)
    local unique_counts=$(echo "$field_counts" | wc -l)

    if [[ $unique_counts -gt 2 ]]; then
        issues+=("Inconsistent column counts detected")
        echo "⚠️  Warning: Found varying column counts: $(echo $field_counts | tr '\n' ' ')"
    fi

    # Show sample of problematic lines
    if [[ $needs_standardization == true ]]; then
        echo "Format issues found:"
        for issue in "${issues[@]}"; do
            echo "  ❌ $issue"
        done
        echo ""
        echo "Sample problematic line:"
        echo "  $header"
        echo ""
        echo "This file appears to need standardization."
        return 0
    else
        echo "✅ CSV format appears to be standard"
        echo "   No standardization needed - file uses proper CSV format"
        return 2
    fi
}

# Get system info for optimization
CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
MAX_JOBS=$((CORES - 1))
[[ $MAX_JOBS -lt 1 ]] && MAX_JOBS=1

# Run verification first
verify_csv_format "$INPUT_FILE"
verification_result=$?

case $verification_result in
    1)
        echo "❌ Verification failed - cannot proceed"
        exit 1
        ;;
    2)
        echo ""
        read -p "File appears to be already in standard CSV format. Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            exit 0
        fi
        ;;
    0)
        echo "✅ Verification passed - proceeding with standardization"
        ;;
esac

echo ""
echo "=== CSV Standardization (Optimized) ==="
echo "Input:      $INPUT_FILE"
echo "Output:     $OUTPUT_FILE"
echo "Chunk size: $CHUNK_SIZE lines"
echo "CPU cores:  $CORES (using $MAX_JOBS parallel jobs)"
echo ""

# Get total lines for progress
echo "Analyzing file..."
TOTAL_LINES=$(wc -l < "$INPUT_FILE")
TOTAL_CHUNKS=$(((TOTAL_LINES + CHUNK_SIZE - 1) / CHUNK_SIZE))

echo "File size:  $(ls -lh "$INPUT_FILE" | awk '{print $5}')"
echo "Lines:      $TOTAL_LINES"
echo "Chunks:     $TOTAL_CHUNKS"
echo ""

# Function to process a single chunk
process_chunk() {
    local chunk_file="$1"
    local output_file="$2"

    sed -E '
        # Remove outer quotes from entire line
        s/^"(.*)"/\1/

        # Handle comma-delimited double quotes: ,""field"" -> ,"field"
        s/,""([^"]*)""/,"\1"/g

        # Handle semicolon-delimited double quotes: ;""field"" -> ,"field"
        s/;""([^"]*)""/,"\1"/g

        # Handle the first field that starts with ""
        s/^""([^"]*)""/"\1"/

        # Replace remaining semicolons with commas (for semicolon-delimited files)
        s/;/,/g
    ' "$chunk_file" > "$output_file"
}

export -f process_chunk

echo "Processing chunks..."
start_time=$(date +%s)

# Split file into chunks and process in parallel
split -l "$CHUNK_SIZE" -a 6 "$INPUT_FILE" "$TEMP_DIR/chunk_"

# Process chunks in parallel with progress reporting
processed=0
for chunk in "$TEMP_DIR"/chunk_*; do
    while [[ $(jobs -r | wc -l) -ge $MAX_JOBS ]]; do
        sleep 0.1
    done

    chunk_num=$(basename "$chunk" | sed 's/chunk_//')
    output_chunk="$TEMP_DIR/output_$chunk_num"

    process_chunk "$chunk" "$output_chunk" &

    ((processed++))
    if ((processed % 10 == 0)) || ((processed == TOTAL_CHUNKS)); then
        progress=$((processed * 100 / TOTAL_CHUNKS))
        echo "Progress: $processed/$TOTAL_CHUNKS chunks ($progress%)"
    fi
done

# Wait for all background jobs to complete
wait

echo "Combining chunks..."

# Combine processed chunks in correct order
> "$OUTPUT_FILE"
for chunk in "$TEMP_DIR"/chunk_*; do
    chunk_num=$(basename "$chunk" | sed 's/chunk_//')
    output_chunk="$TEMP_DIR/output_$chunk_num"
    if [[ -f "$output_chunk" ]]; then
        cat "$output_chunk" >> "$OUTPUT_FILE"
    fi
done

end_time=$(date +%s)
duration=$((end_time - start_time))

echo ""
echo "✓ Standardization complete!"
echo "Processing time: ${duration}s"
echo "Original format: semicolon-delimited with double quotes"
echo "New format:      comma-delimited with proper quoting"
echo ""
echo "File sizes:"
echo "  Original:    $(ls -lh "$INPUT_FILE" | awk '{print $5}')"
echo "  Standardized: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}')"

# Validate output
output_lines=$(wc -l < "$OUTPUT_FILE")
if [[ $output_lines -eq $TOTAL_LINES ]]; then
    echo "✓ Line count verified: $output_lines lines"
else
    echo "⚠ Warning: Line count mismatch (input: $TOTAL_LINES, output: $output_lines)"
fi