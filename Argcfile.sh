#!/usr/bin/env bash
set -e


# @cmd Run mcp command
# @meta binname mcp
# @arg args~[?`_choice_script`]
mcp() { _run_script "$@"; }

# @cmd Run memory command
# @meta binname memory
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

# @cmd Call a tool through the tool bridge
# @env TOOLS_URL=http://localhost:8808/tools
# @arg name![`_choice_tool`] The tool name
# @arg json The arguments as a JSON object
call() {
  curl -fsS -X POST "$TOOLS_URL/$argc_name" -H 'content-type: application/json' -d "${argc_json:-{\}}"
}

_choice_tool() {
  curl -fsS "$TOOLS_URL" | jq -r --arg d "$ARGC_COMPGEN" '.[] | if $d == "1" then "\(.name)\t\(.description)" else .name end'
}

eval "$(argc --argc-eval "$0" "$@")"
