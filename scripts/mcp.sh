#!/usr/bin/env bash
set -e
# @cmd list servers
# @flag --json
list() { echo "mcp list json=${argc_json:-0}"; }
# @cmd start a server
# @arg name![alpha|beta]
start() { echo "mcp start $argc_name"; }
eval "$(argc --argc-eval "$0" "$@")"
