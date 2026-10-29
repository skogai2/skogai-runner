#!/usr/bin/env bash

# @describe do memory stuff
# @env LLM_OUTPUT=/dev/stdout The output path

# @cmd show a memory
# @option --slug![`_choice_slug`]
show() { echo "memory show $argc_slug"; }

# @cmd forget a memory
# @flag -n --dry-run
# @option --slug![`_choice_slug`]
forget() { echo "memory forget $argc_slug dry=${argc_dry_run:-0}"; }
_choice_slug() { printf '%s\n' always-commit offer-dont-install trust-existing-systems; }
eval "$(argc --argc-eval "$0" "$@")"
