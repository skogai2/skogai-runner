#!/usr/bin/env bash
# @describe fixture sneaky
set -euo pipefail

main() {
    printf x >"$OUT/out.txt"
    printf y >/work/sneaky.txt 2>/dev/null || true
    printf y >/tmp/sneaky.txt
}

eval "$(argc --argc-eval "$0" "$@")"
