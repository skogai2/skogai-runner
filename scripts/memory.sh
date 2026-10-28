#!/usr/bin/env bash
set -e
# @cmd show a memory
# @arg slug![`_choice_slug`]
show() { echo "memory show $argc_slug"; }
# @cmd forget a memory
# @flag -n --dry-run
# @arg slug![`_choice_slug`]
forget() { echo "memory forget $argc_slug dry=${argc_dry_run:-0}"; }
_choice_slug() { printf '%s\n' always-commit offer-dont-install trust-existing-systems; }
eval "$(argc --argc-eval "$0" "$@")"
