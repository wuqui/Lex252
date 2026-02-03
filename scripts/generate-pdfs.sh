#!/usr/bin/env bash
# Generate PDF versions of RevealJS slides using decktape
# Only regenerates PDFs when slides.html content has changed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="${1:-$PROJECT_ROOT/_site}"

echo "=== Generating PDFs from RevealJS slides ==="
echo "Target dir: $TARGET_DIR"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Target directory not found: $TARGET_DIR"
    exit 1
fi

cd "$TARGET_DIR"

count=0
skipped=0

for html_file in sessions/*/slides.html; do
    [ -e "$html_file" ] || continue

    dir=$(dirname "$html_file")
    pdf_file="$dir/slides.pdf"
    hash_file="$dir/.slides.html.sha256"

    # Calculate current hash of slides.html
    current_hash=$(sha256sum "$html_file" | cut -d' ' -f1)

    # Check if PDF exists and hash matches (no changes)
    if [ -f "$pdf_file" ] && [ -f "$hash_file" ]; then
        stored_hash=$(cat "$hash_file")
        if [ "$current_hash" = "$stored_hash" ]; then
            echo "⊘ Skipping: $pdf_file (unchanged)"
            skipped=$((skipped + 1))
            continue
        fi
    fi

    echo "Processing: $html_file -> $pdf_file"

    npx -y decktape reveal \
        --chrome-arg=--no-sandbox \
        --chrome-arg=--disable-setuid-sandbox \
        "$html_file" \
        "$pdf_file"

    if [ $? -eq 0 ]; then
        # Store hash for next comparison
        echo "$current_hash" > "$hash_file"
        echo "✓ Generated: $pdf_file"
        count=$((count + 1))
    else
        echo "✗ Failed to generate: $pdf_file"
    fi
done

echo "=== PDF generation complete: $count generated, $skipped unchanged ==="
