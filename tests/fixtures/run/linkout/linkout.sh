#!/usr/bin/env bash
# @describe fixture linkout
set -euo pipefail

main() {
    ln -s /etc/passwd "$OUT/out.txt"
}

eval "$(argc --argc-eval "$0" "$@")"
