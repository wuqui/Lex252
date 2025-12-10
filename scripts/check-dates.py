#!/usr/bin/env python3
"""
Check date format consistency in documentation files.

Verifies dates follow YYYY-MM-DD format in:
- inf/index.md (changelog)
- inf/project-notes.md
- inf/agenda.md
"""

import re
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent.parent
inf_dir = project_root / "inf"

warnings = []

# Files to check
files_to_check = [
    "index.md",
    "project-notes.md",
    "agenda.md"
]

# Date patterns to check
date_patterns = [
    (r'(\d{4}-\d{2}-\d{2})', "YYYY-MM-DD"),  # ISO format
    (r'(\d{1,2}\s+\w+\s+\d{4})', "DD Month YYYY"),  # Alternative format
    (r'(\d{1,2}[/-]\d{1,2}[/-]\d{4})', "DD/MM/YYYY or MM/DD/YYYY"),  # Ambiguous format
]

for filename in files_to_check:
    filepath = inf_dir / filename
    if not filepath.exists():
        warnings.append(f"Missing: {filepath}")
        continue
    
    content = filepath.read_text()
    lines = content.split("\n")
    
    # Check for dates that don't match YYYY-MM-DD
    for i, line in enumerate(lines, 1):
        # Skip YYYY-MM-DD dates (correct format)
        if re.search(r'\d{4}-\d{2}-\d{2}', line):
            continue
        
        # Check for other date formats
        for pattern, desc in date_patterns[1:]:
            if re.search(pattern, line):
                warnings.append(f"{filename}:{i} - Possible non-standard date format: {line.strip()[:60]}")

# Report results
if warnings:
    print("⚠️  Warnings:")
    for warning in warnings:
        print(f"  - {warning}")
    sys.exit(1)

print("✓ Date formats are consistent (YYYY-MM-DD)")
sys.exit(0)
