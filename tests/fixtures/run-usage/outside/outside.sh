#!/usr/bin/env -S usage bash
#USAGE about "fixture outside"
# shellcheck shell=bash
set -euo pipefail

printf x >"$OUT/out.txt"
printf y >"$OUT/extra.txt"
