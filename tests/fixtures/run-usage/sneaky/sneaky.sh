#!/usr/bin/env -S usage bash
#USAGE about "fixture sneaky"
# shellcheck shell=bash
set -euo pipefail

printf x >"$OUT/out.txt"
printf y >/work/sneaky.txt 2>/dev/null || true
printf y >/tmp/sneaky.txt
