#!/usr/bin/env python3
"""
Check that navbar entries in _quarto.yml match session files and schedule.

Verifies:
1. All session files have corresponding navbar entries
2. All navbar entries have corresponding session files
3. Schedule entries match session files
"""

import re
import sys
from pathlib import Path

# Get project root (quarto/ directory)
project_root = Path(__file__).parent.parent
quarto_yml = project_root / "_quarto.yml"
schedule_qmd = project_root / "includes" / "_schedule.qmd"
sessions_dir = project_root / "sessions"

errors = []
warnings = []

# Find all session files
session_files = {}
for session_dir in sorted(sessions_dir.glob("*_*")):
    if session_dir.is_dir():
        session_qmd = session_dir / f"{session_dir.name}.qmd"
        if session_qmd.exists():
            session_num = session_dir.name.split("_")[0]
            session_files[session_num] = {
                "path": session_qmd,
                "dir": session_dir.name,
                "qmd": session_qmd.name
            }

# Parse navbar entries from _quarto.yml
navbar_entries = {}
if quarto_yml.exists():
    content = quarto_yml.read_text()
    # Match navbar entries like: - text: "07 — Semantics"
    # Pattern allows for flexible whitespace between text and href lines
    pattern = r'- text: "(\d+)\s*—\s*([^"]+)"\s*\n\s*href:\s*sessions/([^/]+)/([^"\s]+)'
    for match in re.finditer(pattern, content, re.MULTILINE):
        num = match.group(1)
        title = match.group(2)
        dir_name = match.group(3)
        file_name = match.group(4)
        navbar_entries[num] = {
            "title": title,
            "dir": dir_name,
            "file": file_name
        }
else:
    errors.append(f"Missing: {quarto_yml}")

# Parse schedule entries
schedule_entries = {}
if schedule_qmd.exists():
    content = schedule_qmd.read_text()
    # Match schedule rows like: |  7 | 9 Dec. | [Semantics: ...]({{< meta linkprefix >}}sessions/07_semantics/07_semantics.qmd) |
    # Handle Quarto template syntax: {{< meta linkprefix >}}sessions/...
    # Pattern matches: [Title]({{< meta linkprefix >}}sessions/NN_topic/NN_topic.qmd) or [Title](sessions/NN_topic/NN_topic.qmd)
    # The template syntax {{< meta linkprefix >}} is optional and may appear in the link
    pattern = r'\|\s*(\d+)\s*\|\s*[^|]+\s*\|\s*\[([^\]]+)\]\([^)]*sessions/([^/]+)/([^/\s\)]+\.qmd)\)'
    for match in re.finditer(pattern, content):
        num = match.group(1)
        title = match.group(2)
        dir_name = match.group(3)
        file_name = match.group(4)
        schedule_entries[num] = {
            "title": title,
            "dir": dir_name,
            "file": file_name
        }
else:
    warnings.append(f"Missing: {schedule_qmd}")

# Normalize session numbers for comparison (remove leading zeros)
def normalize_num(num_str):
    """Convert "01" to "1", "02" to "2", etc. for comparison."""
    return str(int(num_str)) if num_str.isdigit() else num_str

# Create normalized lookup dictionaries
session_files_normalized = {normalize_num(k): v for k, v in session_files.items()}
navbar_entries_normalized = {normalize_num(k): v for k, v in navbar_entries.items()}
schedule_entries_normalized = {normalize_num(k): v for k, v in schedule_entries.items()}

# Check for missing navbar entries
for num, session in session_files_normalized.items():
    if num not in navbar_entries_normalized:
        errors.append(f"Session {num} ({session['dir']}) missing from navbar")
    else:
        nav = navbar_entries_normalized[num]
        if nav["dir"] != session["dir"]:
            errors.append(f"Navbar dir mismatch for {num}: navbar={nav['dir']}, actual={session['dir']}")
        if nav["file"] != session["qmd"]:
            errors.append(f"Navbar file mismatch for {num}: navbar={nav['file']}, actual={session['qmd']}")

# Check for missing schedule entries
for num, session in session_files_normalized.items():
    if num not in schedule_entries_normalized:
        warnings.append(f"Session {num} ({session['dir']}) missing from schedule")
    else:
        sched = schedule_entries_normalized[num]
        if sched["dir"] != session["dir"]:
            warnings.append(f"Schedule dir mismatch for {num}: schedule={sched['dir']}, actual={session['dir']}")
        if sched["file"] != session["qmd"]:
            warnings.append(f"Schedule file mismatch for {num}: schedule={sched['file']}, actual={session['qmd']}")

# Check for orphaned navbar entries
for num, nav in navbar_entries_normalized.items():
    if num not in session_files_normalized:
        errors.append(f"Navbar entry {num} ({nav['title']}) has no corresponding session file")

# Check for orphaned schedule entries
for num, sched in schedule_entries_normalized.items():
    if num not in session_files_normalized:
        warnings.append(f"Schedule entry {num} ({sched['title']}) has no corresponding session file")

# Report results
if errors:
    print("❌ Errors found:")
    for error in errors:
        print(f"  - {error}")
    sys.exit(1)

if warnings:
    print("⚠️  Warnings:")
    for warning in warnings:
        print(f"  - {warning}")

if not errors and not warnings:
    print("✓ Navbar and schedule are consistent with session files")

sys.exit(0)
