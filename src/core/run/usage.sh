#!/usr/bin/env -S usage bash
#USAGE bin "run"
#USAGE about "check and run one module with its writable scope enforced"
#USAGE long_about """
#USAGE a module is <dir>/<name>.md (Markdown+, valid under the F001 contract checker) plus its command <dir>/<name>.sh, a usage script. `run` executes the command in podman with <dir> mounted read-only at /work and an empty staging dir at /out. Only staged files that the module owns are moved into <dir>, each by an atomic rename, and only after every check passed. stdout is one JSON line.
#USAGE
#USAGE every check and run also appends JSONL events to a log (--log): check, exec, one apply per staged path, and end with the stdout verdict. See docs/evidence.md.
#USAGE
#USAGE exit 0 valid/applied/unchanged, 1 a tool or the image is missing or the log cannot be appended to, 2 bad arguments, 3 rejected.
#USAGE """
#USAGE flag "--image <image>" env="SKOGAI_IMAGE" default="skogai-runner-dev" global=#true help="podman image that runs module commands"
#USAGE flag "--log <file>" env="SKOGAI_LOG" global=#true help="JSONL event log, only ever appended to (default: $XDG_STATE_HOME/skogai/run.jsonl, else ~/.local/state/skogai/run.jsonl)"
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
declare -A WHY=()

check() {
    _ready "$@" || return
    _open_log || return 1
    _check
    _revision
    CHANGED=()
    _log_check || return 1
    _finish "$(_check_json)"
}

run() {
    _ready "$@" || return
    _open_log || return 1
    _check
    _revision
    CHANGED=()
    _log_check || return 1
    ((${#REASONS[@]} == 0)) || { _finish "$(_run_json rejected)" || return 1; return 3; }

    command -v podman >/dev/null || { _fail 'missing tool: podman'; return 1; }
    command podman image exists "$SKOGAI_IMAGE" ||
        { _fail "missing image: $SKOGAI_IMAGE (mise run image builds it)"; return 1; }

    STAGE="$(command mktemp -d)"
    trap 'command rm -rf -- "$STAGE"' EXIT
    _execute || return 1
    if ((${#REASONS[@]})); then
        _log_unapplied ${ALL[@]+"${ALL[@]}"} || return 1
        _finish "$(_run_json rejected)" || return 1
        return 3
    fi
    _apply || return 1
    ((${#REASONS[@]} == 0)) || { _finish "$(_run_json rejected)" || return 1; return 3; }
    if ((${#CHANGED[@]})); then _finish "$(_run_json applied)"; else _finish "$(_run_json unchanged)"; fi
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

# run the command in the container, then judge what it staged. sets ALL
# (every staged path, sorted), STAGED (the owned regular files among them) and
# WHY (path -> reason for the rest), and logs one exec event. returns 1 only
# when the log cannot be appended to
_execute() {
    local entry rel path status=0
    local -a missing=()
    ALL=() STAGED=() WHY=()
    command podman run --rm --network=none --userns=keep-id \
        -v "$DIR:/work:ro" -v "$STAGE:/out:rw" -e OUT=/out -w /work \
        "$SKOGAI_IMAGE" usage bash "/work/$NAME.sh" >&2 || status=$?
    if ((status != 0)); then
        REASONS+=(command-failed)
        _log exec failed "" "$(command jq -cn --argjson exit "$status" --arg image "$SKOGAI_IMAGE" \
            '{exit: $exit, image: $image}')"
        return
    fi

    while IFS= read -r -d '' entry; do
        rel="${entry#"$STAGE"/}"
        ALL+=("$rel")
        if [[ -L "$entry" || ! -f "$entry" ]]; then
            REASONS+=(output-not-regular-file)
            WHY[$rel]=output-not-regular-file
        elif ! _owned "$rel"; then
            REASONS+=(output-outside-owns)
            WHY[$rel]=output-outside-owns
        else
            STAGED+=("$rel")
        fi
    done < <(command find "$STAGE" -mindepth 1 ! -type d -print0 | LC_ALL=C command sort -z)
    for path in ${WRITES[@]+"${WRITES[@]}"}; do
        [[ -e "$STAGE/$path" || -L "$STAGE/$path" ]] || { REASONS+=(missing-output); missing+=("$path"); }
    done
    _log exec ok "" "$(command jq -cn --argjson exit 0 --arg image "$SKOGAI_IMAGE" \
        --argjson staged "$(_list ${ALL[@]+"${ALL[@]}"})" --argjson missing "$(_list ${missing[@]+"${missing[@]}"})" \
        '{exit: $exit, image: $image, staged: $staged, missing: $missing}')"
}

_owned() {
    local own
    for own in ${OWNS[@]+"${OWNS[@]}"}; do [[ "$own" == "$1" ]] && return 0; done
    return 1
}

# move each staged file over its target: skip identical content, keep an
# existing target's mode, write beside the target and rename. one apply event
# per path (STAGED is sorted); after a failure the remaining paths are logged
# as not applied. returns 1 only when the log cannot be appended to
_apply() {
    local rel target tmp mode i
    mode="$(printf '%o' $((0666 & ~$(umask))))"
    for ((i = 0; i < ${#STAGED[@]}; i++)); do
        rel="${STAGED[i]}"
        target="$DIR/$rel"
        if [[ -f "$target" ]] && command cmp -s -- "$STAGE/$rel" "$target"; then
            _log apply unchanged "" "$(_path_json "$rel")" || return 1
            continue
        fi
        tmp=""
        if tmp="$(command mktemp -- "$(dirname "$target")/.$(basename "$target").XXXXXX" 2>/dev/null)" &&
            command cat -- "$STAGE/$rel" >"$tmp" &&
            if [[ -f "$target" ]]; then command chmod --reference="$target" -- "$tmp"; else command chmod "$mode" -- "$tmp"; fi &&
            command mv -fT -- "$tmp" "$target"; then
            CHANGED+=("$rel")
            _log apply ok "applied $rel" "$(_path_json "$rel")" || return 1
        else
            [[ -z "$tmp" ]] || command rm -f -- "$tmp"
            printf 'apply failed: %s\n' "$rel" >&2
            REASONS+=(apply-failed)
            _log apply failed "" "$(_path_json "$rel" apply-failed)" || return 1
            _log_unapplied "${STAGED[@]:i+1}"
            return
        fi
    done
}

# --- evidence (docs/evidence.md) ---------------------------------------------

# LOG from --log/SKOGAI_LOG or the XDG state dir. its parent is created and the
# file must take an append before anything else happens. sets RUN and FILE
_open_log() {
    LOG="${usage_log:-${XDG_STATE_HOME:-${HOME:?}/.local/state}/skogai/run.jsonl}"
    if ! { command mkdir -p -- "$(command dirname -- "$LOG")" && : >>"$LOG"; } 2>/dev/null; then
        printf 'cannot append to log: %s\n' "$LOG" >&2
        return 1
    fi
    _uuid RUN
    FILE="$(basename "$MODULE")"
}

# the sha256 of `sha256sum <name>.md <name>.sh` run in the module dir (the .sh
# only when it exists); empty, with a note, when sha256sum is not on PATH
_revision() {
    local -a files=("$FILE")
    local sum
    REVISION=""
    [[ -z "$NAME" || ! -f "$DIR/$NAME.sh" ]] || files+=("$NAME.sh")
    command -v sha256sum >/dev/null || { printf 'no sha256sum: revision not recorded\n' >&2; return 0; }
    sum="$(cd "$DIR" && command sha256sum -- "${files[@]}" | command sha256sum)" ||
        { printf 'revision not recorded\n' >&2; return 0; }
    REVISION="${sum%% *}"
}

# append one event line: _log <event> <outcome> <action or ""> <input json>
_log() {
    local ts id line
    _now ts
    _uuid id
    line="$(command jq -cn --arg ts "$ts" --arg event "$1" --arg outcome "$2" --arg action "$3" --argjson input "$4" \
        --arg id "$id" --arg run "$RUN" --arg module "$NAME" --arg revision "$REVISION" \
        '{ts: $ts, event: $event} + (if $action == "" then {} else {action: $action} end)
         + {input: $input, id: $id, run: $run,
            module: (if $module == "" then null else $module end),
            revision: (if $revision == "" then null else $revision end), outcome: $outcome}')" &&
        { printf '%s\n' "$line" >>"$LOG"; } 2>/dev/null ||
        { printf 'cannot append to log: %s\n' "$LOG" >&2; return 1; }
}

_log_check() {
    local outcome=ok
    ((${#REASONS[@]} == 0)) || outcome=rejected
    _log check "$outcome" "" "$(command jq -cn --arg file "$FILE" --argjson f001 "$F001" \
        --argjson reasons "$(_list ${REASONS[@]+"${REASONS[@]}"})" \
        '{file: $file, verdict: (if ($reasons | length) == 0 then "valid" else "invalid" end),
          reasons: ($reasons | unique), f001: $f001}')"
}

# a rejected apply event per path: its own reason, else not-applied
_log_unapplied() {
    local rel
    for rel in "$@"; do
        _log apply rejected "" "$(_path_json "$rel" "${WHY[$rel]:-not-applied}")" || return 1
    done
}

# a run stopped by a missing tool or image: the message goes to stderr and
# into a failed end event; stdout stays empty
_fail() {
    printf '%s\n' "$1" >&2
    _log end failed "" "$(command jq -cn --arg error "$1" '{exit: 1, error: $error}')" || true
}

# log the end event, then print the same verdict on stdout
_finish() {
    local json="$1" outcome action="" rel
    case "$(command jq -r .verdict <<<"$json")" in
    valid | applied) outcome=ok ;;
    unchanged) outcome=unchanged ;;
    *) outcome=rejected ;;
    esac
    for rel in ${CHANGED[@]+"${CHANGED[@]}"}; do action="${action:+$action, }$rel"; done
    action="${action:+applied $action}"
    _log end "$outcome" "$action" "$(command jq -c --arg file "$FILE" '.module = $file' <<<"$json")" || return 1
    printf '%s\n' "$json"
}

_path_json() {
    command jq -cn --arg path "$1" --arg reason "${2:-}" '{path: $path} + (if $reason == "" then {} else {reason: $reason} end)'
}

# UTC, ISO 8601 with milliseconds, from bash alone
_now() {
    local t="${EPOCHREALTIME/[.,]/ }"
    TZ=UTC0 printf -v "$1" '%(%Y-%m-%dT%H:%M:%S)T.%.3sZ' "${t% *}" "${t#* }"
}

# a random uuid from the kernel, else an id from time, pid and $RANDOM
_uuid() {
    local u
    if ! { read -r u </proc/sys/kernel/random/uuid; } 2>/dev/null; then
        printf -v u '%s-%s-%04x%04x' "${EPOCHREALTIME/[.,]/}" "$$" "$RANDOM" "$RANDOM"
    fi
    printf -v "$1" '%s' "$u"
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
