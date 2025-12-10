#!/usr/bin/env python3
"""
Verify session files follow NN_topic.qmd naming convention.

Checks:
1. Session directories follow NN_topic pattern
2. Session files are named NN_topic.qmd (matching directory)
3. No leading zeros in filenames (but navbar may use them)
"""

import re
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent
sessions_dir = project_root / "sessions"

errors = []
warnings = []

# Find all session directories
for session_dir in sorted(sessions_dir.iterdir()):
    if not session_dir.is_dir():
        continue
    
    dir_name = session_dir.name
    
    # Check directory naming: should be NN_topic (no leading zero in NN)
    # Allow letters, numbers, and hyphens in topic part (case-insensitive)
    if not re.match(r'^\d+_[a-zA-Z0-9-]+$', dir_name):
        warnings.append(f"Directory '{dir_name}' doesn't match NN_topic pattern")
        continue
    
    parts = dir_name.split("_", 1)
    if len(parts) != 2:
        warnings.append(f"Directory '{dir_name}' doesn't have topic part")
        continue
    
    num_str = parts[0]
    topic = parts[1]
    
    # Check for leading zeros in directory name (should not have them)
    if num_str.startswith("0") and len(num_str) > 1:
        warnings.append(f"Directory '{dir_name}' has leading zero (should be {int(num_str)}_{topic})")
    
    # Check that session file exists and matches directory name
    expected_file = session_dir / f"{dir_name}.qmd"
    if not expected_file.exists():
        errors.append(f"Missing session file: {expected_file}")
        continue
    
    # Check for other .qmd files in directory
    other_qmd = [f for f in session_dir.glob("*.qmd") if f.name != expected_file.name]
    if other_qmd:
        warnings.append(f"Extra .qmd files in {dir_name}: {[f.name for f in other_qmd]}")

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
    print("✓ All session files follow naming convention")

sys.exit(1 if errors else 0)
