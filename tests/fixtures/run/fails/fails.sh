#!/usr/bin/env bash
# @describe fixture fails
set -euo pipefail

main() {
    printf x >"$OUT/out.txt"
    exit 4
}

eval "$(argc --argc-eval "$0" "$@")"
