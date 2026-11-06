#!/usr/bin/env -S usage bash
#USAGE about "fixture linkout"
# shellcheck shell=bash
set -euo pipefail

ln -s /etc/passwd "$OUT/out.txt"
