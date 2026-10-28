#!/usr/bin/env bash
set -e

# @cmd Run mcp command
# @arg args~[?`_choice_script`]
mcp() { _run_script "$@"; }

# @cmd Run memory command
# @arg args~[?`_choice_script`]
memory() { _run_script "$@"; }

_run_script() {
  bash "./scripts/${FUNCNAME[1]}.sh" "$@"
}

_choice_script() {
  [[ "$ARGC_COMPGEN" -eq 1 ]] || return 0
  local args=("${argc__positionals[@]}")
  args[-1]="$ARGC_LAST_ARG"
  argc --argc-compgen generic "scripts/$argc__cmd_fn.sh" "$argc__cmd_fn" "${args[@]}"
}

eval "$(argc --argc-eval "$0" "$@")"
