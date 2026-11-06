#!/usr/bin/env -S usage bash
#USAGE about "fixture fails"
# shellcheck shell=bash
set -euo pipefail

printf x >"$OUT/out.txt"
exit 4
