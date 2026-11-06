#!/usr/bin/env bash
# @describe fixture badmeta
set -euo pipefail

main() {
    printf x >"$OUT/out.txt"
}

eval "$(argc --argc-eval "$0" "$@")"
