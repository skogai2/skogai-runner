#!/usr/bin/env bash
# @describe write a fixed greeting to $OUT/greeting.txt
# @env OUT!                            staging directory the runner provides
set -euo pipefail

main() {
    printf 'hello from a staged module\n' >"$OUT/greeting.txt"
}

eval "$(argc --argc-eval "$0" "$@")"
