#!/usr/bin/env bash
# @describe skogai config, folded from layers by mise
# @meta require-tools mise,jq,yq,git
# @env SKOGAI_CONFIG_SYSTEM=./system   config.system
# @env SKOGAI_CONFIG_GLOBAL=./global   config.global
# @env SKOGAI_CONFIG_LOCAL=./local     config.local
# @env SKOGAI_CONFIG_FILE=skogai.toml  config.file

set -euo pipefail

prefix=SKOGAI_

# @cmd a key's value and the layer it came from, or every key under a module
# @option --layer[default|system|global|local|env] only this layer
# @arg key![?`_choice_key`] module or module.name
get() {
  _layers | _only "${argc_layer:-}" | _fold | jq -r --arg k "$argc_key" '
    if .key == $k then "\(.value)\t\(.origin)"
    elif (.key | startswith($k + ".")) then "\(.key)\t\(.value)\t\(.origin)"
    else empty end'
}

# @cmd write a key's value into a layer's file
# @option --layer[=local|global|system] which file to write
# @arg key![?`_choice_key`] module.name
# @arg value! the value
set() {
  local file=()
  case $argc_layer in
    global) file=(--file "$(_global_file)") ;;
    system) file=(--file "$(_system_file)") ;;
  esac
  _mise set "${file[@]}" "$(_env_name "$argc_key")=$argc_value"
}

# @cmd every key, its value and the layer it came from
# @option --layer[default|system|global|local|env] only this layer
list() {
  _layers | _only "${argc_layer:-}" | _fold | jq -r '"\(.key)\t\(.value)\t\(.origin)"'
}

_choice_key() {
  _layers | _fold | jq -r '"\(.key)\t\(.value) (\(.origin))"'
}

_path() { (cd "${ARGC_PWD:-$PWD}" && realpath -m "${1/#\~/$HOME}"); }
_system_file() { _path "$SKOGAI_CONFIG_SYSTEM/$SKOGAI_CONFIG_FILE"; }
_global_file() { _path "$SKOGAI_CONFIG_GLOBAL/$SKOGAI_CONFIG_FILE"; }
_local_dir() { _path "$SKOGAI_CONFIG_LOCAL"; }
_env_name() { echo "$prefix$1" | tr '[:lower:].' '[:upper:]_' | tr -d -- -; }

# mise, looking only at skogai's files
_mise() {
  local here root
  here=$(_local_dir)
  mkdir -p "$here"
  root=$(git -C "$here" rev-parse --show-toplevel 2>/dev/null || echo "$here")
  MISE_OVERRIDE_CONFIG_FILENAMES=$SKOGAI_CONFIG_FILE \
    MISE_DEFAULT_CONFIG_FILENAME=$SKOGAI_CONFIG_FILE \
    MISE_SYSTEM_CONFIG_FILE=$(_system_file) \
    MISE_GLOBAL_CONFIG_FILE=$(_global_file) \
    MISE_CEILING_PATHS=$(dirname "$root") \
    mise -C "$here" "$@"
}

# _layers :: [{name, value, origin}], lowest layer first
_layers() {
  argc --argc-export "$0" |
    jq -c --arg p "$prefix" '.envs[] | select(.default.type == "Value" and (.id | startswith($p)))
      | {name: .id, value: .default.value, origin: "default"}'
  local file
  _mise config ls --json | jq -r 'reverse[].path' | while read -r file; do
    yq -p toml -o json -I0 '.env // {}' "$file" |
      jq -c --arg p "$prefix" --arg f "$file" --arg s "$(_system_file)" --arg g "$(_global_file)" '
        to_entries[] | select(.key | startswith($p)) | {
          name: .key,
          value: (.value | tostring),
          origin: (if $f == $s then "system" elif $f == $g then "global" else "local" end)
        }'
  done
  echo "$_caller_env" |
    jq -c --arg p "$prefix" 'to_entries[] | select(.key | startswith($p)) | {name: .key, value, origin: "env"}'
}

# _only :: layer -> [entry] -> [entry]
_only() {
  jq -c --arg l "$1" 'select($l == "" or .origin == $l)'
}

# _fold :: [{name, value, origin}] -> [{key, value, origin}], later wins
_fold() {
  jq -sc --arg p "$prefix" 'group_by(.name)[] | last
    | {key: (.name | ltrimstr($p) | ascii_downcase | sub("_"; ".")), value, origin}'
}

_caller_env=$(jq -nc env)

eval "$(argc --argc-eval "$0" "$@")"
