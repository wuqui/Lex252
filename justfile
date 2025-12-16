# Justfile for Lex252 course project automation
# Repository root is quarto/ directory

# Default recipe: show available commands
default:
    @just --list

# ============================================================================
# Session Management
# ============================================================================

# Check that navbar and schedule are updated for all sessions
session-check:
    @echo "Checking navbar and schedule consistency..."
    @uv run --script scripts/check-navbar-schedule.py

# ============================================================================
# Documentation
# ============================================================================

# Check date format consistency in documentation
docs-dates:
    @echo "Checking date format consistency (YYYY-MM-DD)..."
    @uv run --script scripts/check-dates.py

# Check that all documentation files exist
docs-files:
    @echo "Checking documentation files..."
    @test -f ../inf/index.md || (echo "Missing: inf/index.md" && exit 1)
    @test -f ../inf/best-practices.md || (echo "Missing: inf/best-practices.md" && exit 1)
    @test -f ../inf/agenda.md || (echo "Missing: inf/agenda.md" && exit 1)
    @test -f ../inf/project-notes.md || (echo "Missing: inf/project-notes.md" && exit 1)
    @echo "✓ All documentation files present"

# ============================================================================
# Testing
# ============================================================================

# Render project and verify outputs
test-render:
    @echo "Rendering project..."
    @quarto render
    @echo "✓ Render complete"

# Check speaker notes are stripped in production builds
test-notes:
    @echo "Checking speaker notes in production builds..."
    @uv run --script scripts/check-speaker-notes.py

# Verify project structure
test-structure:
    @echo "Checking project structure..."
    @test -f _quarto.yml || (echo "Missing: _quarto.yml" && exit 1)
    @test -f index.qmd || (echo "Missing: index.qmd" && exit 1)
    @test -f references.bib || (echo "Missing: references.bib" && exit 1)
    @test -d filters || (echo "Missing: filters/" && exit 1)
    @test -d sessions || (echo "Missing: sessions/" && exit 1)
    @echo "✓ Project structure OK"

# Verify session file naming convention
test-naming:
    @echo "Checking session file naming..."
    @uv run --script scripts/check-session-naming.py

# Full test suite
test: test-structure test-naming test-render
    @echo "✓ All tests passed"

# ============================================================================
# Publishing
# ============================================================================

# Render before publishing
push-render:
    @echo "Rendering project before publish..."
    @quarto render
    @echo "✓ Render complete"

# Show git status summary
push-status:
    @echo "Git status:"
    @git status -sb

# Basic pre-push verification
push-verify: test-structure push-status
    @echo "✓ Pre-push checks complete"

# ============================================================================
# Cleanup
# ============================================================================

# Check for obsolete files
tidy-obsolete:
    @echo "Checking for obsolete files..."
    @uv run --script scripts/check-obsolete-files.py

# Remove rendered output files
clean:
    @echo "Cleaning rendered files..."
    @rm -rf _site
    @find sessions -name "*.html" -type f -delete
    @find sessions -name "*.pdf" -type f -delete
    @echo "✓ Clean complete"
