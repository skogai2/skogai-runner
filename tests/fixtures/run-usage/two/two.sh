#!/usr/bin/env -S usage bash
#USAGE about "fixture two"
# shellcheck shell=bash
set -euo pipefail

mkdir -p "$OUT/sub"
printf a >"$OUT/a.txt"
printf b >"$OUT/sub/b.txt"
