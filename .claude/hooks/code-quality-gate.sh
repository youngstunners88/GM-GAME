#!/bin/bash
# Code Quality Gate Hook
# Validates GDScript, design consistency, and asset specs
# Runs impeccable checks and design-md validation

set -e

# Parse hook input
TOOL_INPUT=$(cat)
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Determine file type
case "$FILE_PATH" in
    *.gd)
        # GDScript validation
        if command -v gdformat &>/dev/null; then
            gdformat --check "$FILE_PATH" 2>/dev/null || echo "{\"systemMessage\": \"⚠️ GDScript formatting issues in $FILE_PATH\"}"
        fi

        # Static analysis
        if command -v pylint &>/dev/null; then
            pylint --disable=all --enable=syntax-error "$FILE_PATH" 2>/dev/null || true
        fi
        ;;

    *.md|*CLAUDE.md|*design.md|*_doc.md)
        # Design markdown validation
        if [ -d ".claude/design" ]; then
            # Check against design consistency rules
            grep -q "^#" "$FILE_PATH" || echo "{\"systemMessage\": \"⚠️ Design doc missing header: $FILE_PATH\"}"
        fi
        ;;

    *.tres|*.tscn)
        # Godot scene/resource validation
        if [ -f "project.godot" ]; then
            # Basic format check
            head -1 "$FILE_PATH" | grep -q "gd_scene\|gd_resource" || echo "{\"systemMessage\": \"⚠️ Invalid Godot file format: $FILE_PATH\"}"
        fi
        ;;
esac

# Check for common issues
if grep -q "TODO\|FIXME\|XXX\|HACK" "$FILE_PATH" 2>/dev/null; then
    echo "{\"systemMessage\": \"ℹ️ Found TODO/FIXME markers in $FILE_PATH - review before commit\"}"
fi

exit 0
