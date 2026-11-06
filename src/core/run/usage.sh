#!/usr/bin/env -S usage bash
#USAGE bin "run"
#USAGE about "check and run one module with its writable scope enforced"
#USAGE long_about """
#USAGE a module is <dir>/<name>.md (Markdown+, valid under the F001 contract checker) plus its command <dir>/<name>.sh, a usage script. `run` executes the command in podman with <dir> mounted read-only at /work and an empty staging dir at /out. Only staged files that the module owns are moved into <dir>, each by an atomic rename, and only after every check passed. stdout is one JSON line.
#USAGE
#USAGE exit 0 valid/applied/unchanged, 1 a tool or the image is missing, 2 bad arguments, 3 rejected.
#USAGE """
#USAGE flag "--image <image>" env="SKOGAI_IMAGE" default="skogai-runner-dev" global=#true help="podman image that runs module commands"
#USAGE cmd "check" effect="read" help="validate one module without any effect" {
#USAGE   arg "[module]..." help="the module's Markdown file" var=#true
#USAGE }
#USAGE cmd "run" effect="write" help="validate, then run the module's command and apply its owned outputs" {
#USAGE   arg "[module]..." help="the module's Markdown file" var=#true
#USAGE }
#
# the usage twin of argc.sh: same checks, output and exit codes. differences:
# the module command must be a usage script (`usage lint` instead of
# `argc --argc-export`, `usage bash` in the container instead of
# `argc --argc-run`), the contract checker is contract/usage.sh, and the image
# is also settable as --image. usage itself exits 1 on a command line that does
# not fit the spec and 181 on a broken spec.

# shellcheck shell=bash disable=SC2154 # usage_* are exported by usage
set -euo pipefail

CONTRACT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../contract" && pwd)/usage.sh"
SKOGAI_IMAGE="$usage_image"

check() {
    _ready "$@" || return
    _check
    _check_json
}

run() {
    _ready "$@" || return
    _check
    CHANGED=()
    ((${#REASONS[@]} == 0)) || { _run_json rejected; return 3; }

    command -v podman >/dev/null || { printf 'missing tool: podman\n' >&2; return 1; }
    command podman image exists "$SKOGAI_IMAGE" || {
        printf 'missing image: %s (mise run image builds it)\n' "$SKOGAI_IMAGE" >&2
        return 1
    }

    STAGE="$(command mktemp -d)"
    trap 'command rm -rf -- "$STAGE"' EXIT
    _execute
    ((${#REASONS[@]} == 0)) || { _run_json rejected; return 3; }
    _apply
    ((${#REASONS[@]} == 0)) || { _run_json rejected; return 3; }
    if ((${#CHANGED[@]})); then _run_json applied; else _run_json unchanged; fi
}

# tools first (exit 1), then exactly one readable file (exit 2)
_ready() {
    local tool version
    for tool in yq jq; do
        command -v "$tool" >/dev/null || { printf 'missing tool: %s\n' "$tool" >&2; return 1; }
    done
    version="$(command yq --version 2>&1)" || true
    version="${version%%$'\n'*}"
    [[ "$version" =~ ^yq\ \(https://github\.com/mikefarah/yq/?\)\ version\ v?([0-9]+)\. ]] &&
        ((BASH_REMATCH[1] >= 4)) ||
        { printf 'wrong yq: need mikefarah/yq v4 or newer, found: %s\n' "$version" >&2; return 1; }
    (($# == 1)) || { printf 'usage: check|run <module.md>\n' >&2; return 2; }
    [[ -e "$1" ]] || { printf 'no such file: %s\n' "$1" >&2; return 2; }
    [[ ! -d "$1" ]] || { printf 'is a directory: %s\n' "$1" >&2; return 2; }
    [[ -r "$1" ]] || { printf 'unreadable: %s\n' "$1" >&2; return 2; }
    MODULE="$1"
    DIR="$(cd "$(dirname "$MODULE")" && pwd)"
}

# sets NAME, F001, OWNS, WRITES, REASONS
_check() {
    local verdict fm path
    NAME="" OWNS=() WRITES=() REASONS=()
    verdict="$("$CONTRACT" check "$DIR/$(basename "$MODULE")")" ||
        { printf 'contract checker failed\n' >&2; return 1; }
    F001="$(command jq -c '.reasons' <<<"$verdict")"
    fm="$(_frontmatter "$MODULE")"
    NAME="$(command jq -r 'if (.name | type) == "string" and (.name | test("^[a-z][a-z0-9-]*$")) then .name else "" end' <<<"$fm")"
    [[ "$F001" == "[]" ]] || { REASONS=(invalid-declaration); return 0; }

    mapfile -t OWNS < <(command jq -r "$NORM"' (.owns // [])[] | norm' <<<"$fm")
    mapfile -t WRITES < <(command jq -r "$NORM"' (.writes // [])[] | norm' <<<"$fm")

    local cmd="$DIR/$NAME.sh"
    if [[ ! -f "$cmd" ]]; then
        REASONS+=(missing-command)
    elif ! command usage lint "$cmd" >/dev/null 2>&1; then
        REASONS+=(invalid-command)
    fi
    ((${#OWNS[@]})) || REASONS+=(no-owns)
    for path in ${OWNS[@]+"${OWNS[@]}"}; do _check_target "$path"; done
    _contains_home && REASONS+=(dir-contains-home) || true
}

# one owns entry, relative to DIR and already normalised
_check_target() {
    local rel="$1" at="$DIR" part linked=""
    local -a parts
    IFS=/ read -ra parts <<<"$rel"
    for part in "${parts[@]}"; do
        at="$at/$part"
        [[ ! -L "$at" ]] || linked=1
    done
    if [[ -n "$linked" ]]; then
        REASONS+=(target-is-symlink)
    elif [[ -e "$at" && ! -f "$at" ]]; then
        REASONS+=(target-not-regular-file)
    fi
    [[ -d "$(dirname "$at")" ]] || REASONS+=(target-dir-missing)
}

_contains_home() {
    local dir home
    dir="$(command realpath -- "$DIR")"
    home="$(command realpath -m -- "$HOME")"
    [[ "$dir" == / || "$home" == "$dir" || "$home" == "$dir"/* ]]
}

# the frontmatter as JSON, or null when there is none to read
_frontmatter() {
    local lines i data
    mapfile -t lines <"$1"
    [[ ${#lines[@]} -gt 0 && "${lines[0]}" == --- ]] || { printf 'null\n'; return; }
    for ((i = 1; i < ${#lines[@]}; i++)); do [[ "${lines[i]}" != --- ]] || break; done
    ((i < ${#lines[@]})) || { printf 'null\n'; return; }
    data="$(printf '%s\n' "${lines[@]:1:i-1}" | command yq -p yaml -o json -I0 '.' 2>/dev/null)" || data=null
    command jq -c 'if type == "object" then . else null end' <<<"$data" 2>/dev/null || printf 'null\n'
}

# run the command in the container, then judge what it staged
_execute() {
    local entry rel path status=0
    command podman run --rm --network=none --userns=keep-id \
        -v "$DIR:/work:ro" -v "$STAGE:/out:rw" -e OUT=/out -w /work \
        "$SKOGAI_IMAGE" usage bash "/work/$NAME.sh" >&2 || status=$?
    ((status == 0)) || { REASONS+=(command-failed); return 0; }

    STAGED=()
    while IFS= read -r -d '' entry; do
        rel="${entry#"$STAGE"/}"
        if [[ -L "$entry" || ! -f "$entry" ]]; then
            REASONS+=(output-not-regular-file)
        elif ! _owned "$rel"; then
            REASONS+=(output-outside-owns)
        else
            STAGED+=("$rel")
        fi
    done < <(command find "$STAGE" -mindepth 1 ! -type d -print0)
    for path in ${WRITES[@]+"${WRITES[@]}"}; do
        [[ -e "$STAGE/$path" || -L "$STAGE/$path" ]] || REASONS+=(missing-output)
    done
}

_owned() {
    local own
    for own in ${OWNS[@]+"${OWNS[@]}"}; do [[ "$own" == "$1" ]] && return 0; done
    return 1
}

# move each staged file over its target: skip identical content, keep an
# existing target's mode, write beside the target and rename
_apply() {
    local rel target tmp mode
    mode="$(printf '%o' $((0666 & ~$(umask))))"
    while IFS= read -r -d '' rel; do
        target="$DIR/$rel"
        if [[ -f "$target" ]] && command cmp -s -- "$STAGE/$rel" "$target"; then continue; fi
        tmp=""
        if tmp="$(command mktemp -- "$(dirname "$target")/.$(basename "$target").XXXXXX" 2>/dev/null)" &&
            command cat -- "$STAGE/$rel" >"$tmp" &&
            if [[ -f "$target" ]]; then command chmod --reference="$target" -- "$tmp"; else command chmod "$mode" -- "$tmp"; fi &&
            command mv -fT -- "$tmp" "$target"; then
            CHANGED+=("$rel")
        else
            [[ -z "$tmp" ]] || command rm -f -- "$tmp"
            printf 'apply failed: %s\n' "$rel" >&2
            REASONS+=(apply-failed)
            return 0
        fi
    done < <(printf '%s\0' ${STAGED[@]+"${STAGED[@]}"} | LC_ALL=C command sort -z)
}

_check_json() {
    command jq -cn --arg module "$MODULE" --arg name "$NAME" --argjson f001 "$F001" --arg image "$SKOGAI_IMAGE" \
        --argjson reasons "$(_list ${REASONS[@]+"${REASONS[@]}"})" \
        --argjson owns "$(_list ${OWNS[@]+"${OWNS[@]}"})" --argjson writes "$(_list ${WRITES[@]+"${WRITES[@]}"})" \
        '{module: $module, name: (if $name == "" then null else $name end),
          verdict: (if ($reasons | length) == 0 then "valid" else "invalid" end),
          reasons: ($reasons | unique), f001: $f001,
          command: (if $name == "" then null else $name + ".sh" end),
          owns: $owns, writes: $writes, image: $image}'
}

_run_json() {
    command jq -cn --arg module "$MODULE" --arg name "$NAME" --argjson f001 "$F001" --arg verdict "$1" \
        --argjson reasons "$(_list ${REASONS[@]+"${REASONS[@]}"})" \
        --argjson changed "$(_list ${CHANGED[@]+"${CHANGED[@]}"})" \
        '{module: $module, name: (if $name == "" then null else $name end), verdict: $verdict,
          reasons: ($reasons | unique), f001: $f001, changed: ($changed | sort)}'
}

_list() { command jq -cn '$ARGS.positional' --args "$@"; }

# the F001 checker's lexical normalisation
NORM='
def norm:
  startswith("/") as $abs
  | reduce (split("/")[] | select(. != "" and . != ".")) as $s ([];
      if $s != ".." then . + [$s]
      elif length > 0 and .[-1] != ".." then .[:-1]
      elif $abs then .
      else . + [".."] end)
  | if $abs then "/" + join("/") elif length == 0 then "." else join("/") end;
'

# usage hands over the subcommand and a shell-quoted module list
eval "set -- ${usage_module:-}"
case "${usage_cmd:-}" in
check) check "$@" ;;
run) run "$@" ;;
*) exec "$0" --help ;;
esac
