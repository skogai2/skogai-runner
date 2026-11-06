#!/usr/bin/env bash
# @describe fixture two
set -euo pipefail

main() {
    mkdir -p "$OUT/sub"
    printf a >"$OUT/a.txt"
    printf b >"$OUT/sub/b.txt"
}

eval "$(argc --argc-eval "$0" "$@")"
