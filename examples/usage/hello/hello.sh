#!/usr/bin/env -S usage bash
#USAGE about "write a fixed greeting to $OUT/greeting.txt"
#USAGE flag "--out <dir>" env="OUT" required=#true help="staging directory the runner provides"
# shellcheck shell=bash disable=SC2154 # usage_out is exported by usage
set -euo pipefail

printf 'hello from a staged module\n' >"$usage_out/greeting.txt"
