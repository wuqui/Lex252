#!/usr/bin/env python3
"""
Check speaker notes placement and format in session files.

Verifies:
1. Speaker notes appear after content (not before)
2. Timing notes follow format: - HH:MM–HH:MM
3. Notes blocks are properly formatted
"""

import re
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent
sessions_dir = project_root / "sessions"

errors = []
warnings = []

# Find all session files
for session_dir in sorted(sessions_dir.glob("*_*")):
    if not session_dir.is_dir():
        continue
    
    session_qmd = session_dir / f"{session_dir.name}.qmd"
    if not session_qmd.exists():
        continue
    
    content = session_qmd.read_text()
    lines = content.split("\n")
    
    # Find all notes blocks
    in_notes = False
    notes_start_line = 0
    notes_content = []
    
    for i, line in enumerate(lines, 1):
        if re.match(r'^::: \{\.notes\}', line):
            in_notes = True
            notes_start_line = i
            notes_content = []
        elif in_notes and line.strip() == ":::":
            # Check notes content
            notes_text = "\n".join(notes_content)
            
            # Check if first bullet is timing
            if notes_content and notes_content[0].strip().startswith("-"):
                first_bullet = notes_content[0].strip()
                # Check timing format: - HH:MM–HH:MM
                if not re.search(r'-\s*\d{1,2}:\d{2}–\d{1,2}:\d{2}', first_bullet):
                    warnings.append(f"{session_dir.name}:{notes_start_line} - First bullet may not be timing: {first_bullet[:50]}")
            
            # Check for empty line at start of notes block
            if notes_content and notes_content[0].strip() == "":
                warnings.append(f"{session_dir.name}:{notes_start_line} - Empty line at start of notes block (should start directly with bullet)")
            
            in_notes = False
            notes_start_line = 0
            notes_content = []
        elif in_notes:
            notes_content.append(line)
    
    # Check that notes appear after content (simplified check)
    # Look for notes blocks that appear very early in file (before first heading)
    first_heading_line = None
    first_notes_line = None
    
    for i, line in enumerate(lines, 1):
        if line.startswith("#") and first_heading_line is None:
            first_heading_line = i
        if re.match(r'^::: \{\.notes\}', line) and first_notes_line is None:
            first_notes_line = i
    
    if first_notes_line and first_heading_line and first_notes_line < first_heading_line:
        warnings.append(f"{session_dir.name} - Notes block appears before first heading (should be after content)")

# Report results
if errors:
    print("❌ Errors found:")
    for error in errors:
        print(f"  - {error}")

if warnings:
    print("⚠️  Warnings:")
    for warning in warnings:
        print(f"  - {warning}")

if not errors and not warnings:
    print("✓ Speaker notes formatting looks good")

sys.exit(1 if errors else 0)
