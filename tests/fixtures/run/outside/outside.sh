#!/usr/bin/env bash
# @describe fixture outside
set -euo pipefail

main() {
    printf x >"$OUT/out.txt"
    printf y >"$OUT/extra.txt"
}

eval "$(argc --argc-eval "$0" "$@")"
