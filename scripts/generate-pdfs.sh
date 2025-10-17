#!/usr/bin/env bash
# Post-render script to generate PDF versions of RevealJS slides using decktape
# This script is called automatically by Quarto after rendering the website

set -e  # Exit on error

# Get the script directory (should be quarto/scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Generating PDFs from RevealJS slides ==="
echo "Project root: $PROJECT_ROOT"

# Find all slides.html files in the _site directory
cd "$PROJECT_ROOT/_site"

# Counter for processed files
count=0

# Process each slides.html file
for html_file in sessions/*/slides.html; do
    # Check if file exists (in case no matches)
    [ -e "$html_file" ] || continue

    # Get directory and base name
    dir=$(dirname "$html_file")
    pdf_file="$dir/slides.pdf"

    echo "Processing: $html_file -> $pdf_file"

    # Use npx to run decktape (downloads if needed)
    # --chrome-arg flags: compatibility with various environments
    # --fragments: capture all fragment states in the slides
    npx -y decktape reveal \
        --chrome-arg=--no-sandbox \
        --chrome-arg=--disable-setuid-sandbox \
        --fragments \
        "$html_file" \
        "$pdf_file"

    if [ $? -eq 0 ]; then
        echo "✓ Generated: $pdf_file"
        count=$((count + 1))
    else
        echo "✗ Failed to generate: $pdf_file"
    fi
done

if [ $count -eq 0 ]; then
    echo "No slides.html files found to process."
else
    echo "=== PDF generation complete: $count file(s) processed ==="
fi
