#!/usr/bin/env bash
# @describe fixture badcmd
# @arg a
# @arg a
set -euo pipefail

main() {
    :
}

eval "$(argc --argc-eval "$0" "$@")"
