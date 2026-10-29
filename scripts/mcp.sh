#!/usr/bin/env bash

# @describe server-stuffs
# @env LLM_OUTPUT=/dev/stdout The output path

# @cmd list servers
# @option --json
list() { echo "mcp list json=${argc_json:-0}"; }

# @cmd start a server
# @option --name![alpha|beta]
start() { echo "mcp start $argc_name"; }

eval "$(argc --argc-eval "$0" "$@")"
