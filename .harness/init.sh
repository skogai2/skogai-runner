#!/bin/bash
# Harness init.sh for skogai-runner (bash + argc, tested with bats via mise)
# Usage: .harness/init.sh [smoke_test|full_test|focused_test <test_file>]
# Default: full_test
#
# smoke_test   - bash -n on project scripts, shellcheck errors when installed (<15s)
# focused_test - bats on exactly one file; exit 3 = skipped (file missing),
#                a runner's own exit 3 is remapped to 1
# full_test    - bats over tests/ (no coverage tooling for bash yet)

set -e

TARGET=${1:-full_test}
FOCUS_FILE="${2:-}"

if [ "$TARGET" = "focused_test" ] && [ -z "$FOCUS_FILE" ]; then
    echo "focused_test requires a test file argument" >&2
    exit 2
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== Harness ${TARGET} ==="
echo "Project: $PROJECT_ROOT"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

project_scripts() {
    git ls-files -- 'src/*.sh' 'scripts/*.sh' '*.sh' ':!:best-version-so-far/**' ':!:docs/**' ':!:agents/**'
}

case "$TARGET" in
    smoke_test)
        echo "--- bash -n ---"
        project_scripts | while read -r f; do bash -n "$f"; done
        if command -v shellcheck &>/dev/null; then
            echo "--- shellcheck (errors only) ---"
            project_scripts | xargs -r shellcheck -S error
        fi
        ;;
    focused_test)
        if [ ! -f "$FOCUS_FILE" ]; then
            echo "focused_test: test file '$FOCUS_FILE' does not exist -- skipped (exit 3)."
            exit 3
        fi
        rc=0
        bats "$FOCUS_FILE" || rc=$?
        [ "$rc" -eq 3 ] && rc=1
        [ "$rc" -eq 0 ] || exit "$rc"
        ;;
    full_test)
        bats tests
        ;;
    *)
        echo "unknown target: $TARGET" >&2
        exit 2
        ;;
esac

echo ""
echo "=== ${TARGET} Complete ==="
