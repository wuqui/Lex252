#!/usr/bin/env python3
"""
Check for unused/obsolete files in the Lex252 project.

Identifies files that may be obsolete based on:
1. Files mentioned in changelog as removed
2. Filters not referenced in _quarto.yml
3. CSS files not referenced in configuration
4. Legacy session files (old naming patterns)
"""

import re
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent
quarto_yml = project_root / "_quarto.yml"
filters_dir = project_root / "filters"
sessions_dir = project_root / "sessions"

warnings = []
obsolete_candidates = []

# Known obsolete files from changelog
known_obsolete = [
    "filters/hide-solutions.lua",
    "filters/solution-blocks.lua",
    "_quarto-afterclass.yml",
    "html-overrides.css",
]

# Check for known obsolete files
for filepath in known_obsolete:
    full_path = project_root / filepath
    if full_path.exists():
        obsolete_candidates.append(str(filepath))

# Check filters directory
referenced_filters = set()

# Check _quarto.yml
if quarto_yml.exists():
    content = quarto_yml.read_text()
    # Find all filter references
    filter_refs = re.findall(r'filters?:\s*\n(?:\s*-\s*[^\n]+\n?)+', content, re.MULTILINE)
    for ref_block in filter_refs:
        # Extract filter names
        filters = re.findall(r'-\s*([^\s]+)', ref_block)
        for f in filters:
            # Remove path prefixes but keep track of full paths
            if '/' in f:
                referenced_filters.add(f.split('/')[-1])  # Just filename
                referenced_filters.add(f)  # Full path
            else:
                referenced_filters.add(f)
    # Also check for direct references in content
    for lua_file in filters_dir.glob("*.lua"):
        filter_name = lua_file.name
        if filter_name in content or f"filters/{filter_name}" in content:
            referenced_filters.add(filter_name)

# Check session files for filter references
if sessions_dir.exists():
    for session_dir in sessions_dir.glob("*_*"):
        if not session_dir.is_dir():
            continue
        session_qmd = session_dir / f"{session_dir.name}.qmd"
        if session_qmd.exists():
            session_content = session_qmd.read_text()
            # Look for filter references (e.g., ../../filters/strip-revealjs-html.lua)
            filter_matches = re.findall(r'filters?:\s*\n(?:\s*-\s*[^\n]+\n?)+', session_content, re.MULTILINE)
            for ref_block in filter_matches:
                filters = re.findall(r'-\s*([^\s]+)', ref_block)
                for f in filters:
                    if '/' in f:
                        referenced_filters.add(f.split('/')[-1])  # Just filename
                        referenced_filters.add(f)  # Full path
                    else:
                        referenced_filters.add(f)
            # Also check for direct mentions
            for lua_file in filters_dir.glob("*.lua"):
                filter_name = lua_file.name
                if filter_name in session_content:
                    referenced_filters.add(filter_name)

# Check all Lua files in filters directory
if filters_dir.exists():
    for lua_file in filters_dir.glob("*.lua"):
        filter_name = lua_file.name
        # Check if referenced
        is_referenced = (
            filter_name in referenced_filters or
            f"filters/{filter_name}" in referenced_filters or
            any(filter_name in ref for ref in referenced_filters)
        )
        
        if not is_referenced:
            obsolete_candidates.append(f"filters/{filter_name}")

# Check for legacy session files (old index.qmd or slides.qmd in session directories)
if sessions_dir.exists():
    for session_dir in sessions_dir.glob("*_*"):
        if not session_dir.is_dir():
            continue
        
        # Check for old index.qmd (should be removed after multi-format migration)
        old_index = session_dir / "index.qmd"
        if old_index.exists():
            # Check if there's also a NN_topic.qmd (new format)
            session_qmd = session_dir / f"{session_dir.name}.qmd"
            if session_qmd.exists():
                obsolete_candidates.append(f"sessions/{session_dir.name}/index.qmd")
        
        # Check for old slides.qmd (should be renamed to NN_topic.qmd)
        old_slides = session_dir / "slides.qmd"
        if old_slides.exists():
            session_qmd = session_dir / f"{session_dir.name}.qmd"
            if session_qmd.exists():
                obsolete_candidates.append(f"sessions/{session_dir.name}/slides.qmd")

# Check custom.css (documented as unused)
custom_css = project_root / "custom.css"
if custom_css.exists():
    # Check if it's referenced in _quarto.yml
    if quarto_yml.exists():
        content = quarto_yml.read_text()
        if "custom.css" not in content:
            # Check session files
            css_referenced = False
            for session_dir in sessions_dir.glob("*_*"):
                if session_dir.is_dir():
                    session_qmd = session_dir / f"{session_dir.name}.qmd"
                    if session_qmd.exists():
                        session_content = session_qmd.read_text()
                        if "custom.css" in session_content:
                            css_referenced = True
                            break
            
            if not css_referenced:
                warnings.append("custom.css - Documented as unused in project configuration (kept for potential future use)")

# Report results
if obsolete_candidates:
    print("🗑️  Obsolete files found (candidates for removal):")
    for filepath in obsolete_candidates:
        print(f"  - {filepath}")
    print("\n⚠️  Review these files before trashing. Use: trash path/to/file")
    sys.exit(1)

if warnings:
    print("⚠️  Warnings:")
    for warning in warnings:
        print(f"  - {warning}")

if not obsolete_candidates and not warnings:
    print("✓ No obvious obsolete files found")

sys.exit(0)
