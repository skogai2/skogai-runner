#!/usr/bin/env -S usage bash
#USAGE bin "module"
#USAGE about "install modules into the mise conf.d of a level by copying, and list them"
#USAGE long_about """
#USAGE a module is a mise config file (<name>.toml, see docs/module.md). `install` runs the contract checker over the module together with everything already installed at the target level and the broader ones, runs the module's bats tests when it is a directory with a tests/ subdirectory, and only then copies the toml into the conf.d of the level: system (${MISE_SYSTEM_DIR:-/etc/mise}/conf.d), global (the default, ${MISE_CONFIG_DIR:-~/.config/mise}/conf.d) or local (<git root>/.mise/conf.d). see docs/install.md.
#USAGE
#USAGE stdout is JSON lines. exit 0 done (including unchanged and absent), 1 a command line that does not fit the spec (usage's own), 2 bad arguments, path or name, a conflicting target file, the local level outside a git work tree, a checker failure or a missing tool, 3 rejected, 4 the effect failed.
#USAGE """
#USAGE cmd "install" effect="write" help="validate a module, then copy its toml into a level's conf.d" {
#USAGE   flag "--level <level>" default="global" help="where to install" { choices "system" "global" "local" }
#USAGE   arg "<path>" help="a module toml file, or a directory <d> holding <d>.toml (and optionally tests/)"
#USAGE }
#USAGE cmd "uninstall" effect="write" help="remove an installed module's toml from a level's conf.d" {
#USAGE   flag "--level <level>" default="global" help="where to remove from" { choices "system" "global" "local" }
#USAGE   arg "<name>" help="the module's name"
#USAGE }
#USAGE cmd "ls" effect="read" help="list the installed module files, system first, local last"
#
# usage parses the comments above and exports usage_cmd, usage_level, usage_path
# and usage_name. usage itself exits 1 when the command line does not fit the
# spec and 181 when the spec is broken.

# shellcheck shell=bash disable=SC2154 # usage_* are exported by usage
set -euo pipefail
# file lists are enumerated by glob: C-locale order everywhere
export LC_COLLATE=C

# resolve the symlink first: registered with skogai, BASH_SOURCE is the registry link
CONTRACT="$(cd "$(dirname "$(command realpath -- "${BASH_SOURCE[0]}")")/../contract" && pwd)/usage.sh"
LEVELS=(system global local)
NAME_RE='^[a-z][a-z0-9-]*$'
GITROOT=""
STAGE=""
SC_LEVEL=() SC_PATH=() SC_NAME=() SC_DEPS=()

_err() { printf '%s\n' "$*" >&2; }

_ready() {
    local tool version
    for tool in git yq jq; do
        command -v "$tool" >/dev/null || { _err "missing tool: $tool"; return 2; }
    done
    # another program named yq would turn every file into "not a module"
    version="$(command yq --version 2>&1)" || true
    [[ "$version" == *mikefarah* ]] || { _err "wrong yq: need mikefarah/yq, found: ${version%%$'\n'*}"; return 2; }
    GITROOT="$(command git rev-parse --show-toplevel 2>/dev/null)" || GITROOT=""
}

# the conf.d directories of a level, in mise's load order; local is empty outside git
_dirs() {
    case "$1" in
    system) printf '%s\n' "${MISE_SYSTEM_DIR:-/etc/mise}/conf.d" ;;
    global) printf '%s\n' "${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}/conf.d" ;;
    local) [[ -z "$GITROOT" ]] || printf '%s\n%s\n' "$GITROOT/.mise/conf.d" "$GITROOT/.config/mise/conf.d" ;;
    esac
}

_index() {
    local i
    for i in "${!LEVELS[@]}"; do
        [[ "${LEVELS[i]}" != "$1" ]] || { printf '%s' "$i"; return; }
    done
}

# a skogai module file: parses as toml and _.skogai is a table with exactly one key
# whose value is a table. prints the name, then the depends_on strings as a JSON
# array; prints nothing for any other file
_info() {
    local doc
    doc="$(command yq -p toml -o json -I0 '.' "$1" 2>/dev/null)" || return 0
    command jq -r '
        if type == "object" and (._ | type) == "object" and (._.skogai | type) == "object"
           and (._.skogai | length) == 1 and (._.skogai | to_entries[0].value | type) == "object"
        then ._.skogai | to_entries[0]
             | .key, ([.value.depends_on? // [] | if type == "array" then .[] | select(type == "string") else empty end] | tojson)
        else empty end' <<<"$doc" 2>/dev/null || true
}

# every installed module file, levels in order, directories in order, names C-sorted
_scan() {
    SC_LEVEL=() SC_PATH=() SC_NAME=() SC_DEPS=()
    local level dir f info name deps
    for level in "${LEVELS[@]}"; do
        while IFS= read -r dir; do
            [[ -d "$dir" ]] || continue
            for f in "$dir"/*.toml; do
                [[ -f "$f" ]] || continue
                info="$(_info "$f")"
                [[ -n "$info" ]] || continue
                { IFS= read -r name; IFS= read -r deps; } <<<"$info"
                SC_LEVEL+=("$level") SC_PATH+=("$f") SC_NAME+=("$name") SC_DEPS+=("$deps")
            done
        done < <(_dirs "$level")
    done
}

_line() { # module level path action
    command jq -cn --arg m "$1" --arg l "$2" --arg p "$3" --arg a "$4" \
        '{module: $m, level: $l, path: (if $p == "" then null else $p end), action: $a}'
}

_rejected() { # module level reasons-json
    command jq -cn --arg m "$1" --arg l "$2" --argjson r "$3" \
        '{module: (if $m == "" then null else $m end), level: $l, path: null, action: "rejected", reasons: $r}'
}

# target conf.d: the first directory of the level
_target_dir() {
    local dirs
    mapfile -t dirs < <(_dirs "$1")
    ((${#dirs[@]})) || { _err "the local level needs a git work tree"; return 2; }
    printf '%s' "${dirs[0]}"
}

install() {
    local level="$usage_level" path="$usage_path" src src_dir="" base name="" info tdir ti i files f out verdict reasons
    local action=installed target tname tmp
    _ready || return 2
    if [[ -d "$path" ]]; then
        src_dir="$(cd "$path" && pwd)"
        src="$src_dir/${src_dir##*/}.toml"
        [[ -f "$src" ]] || { _err "no ${src_dir##*/}.toml in $path"; return 2; }
    elif [[ -f "$path" && "${path##*/}" == ?*.toml ]]; then
        src="$path"
    else
        _err "not a module toml file or a module directory: $path"
        return 2
    fi
    base="${src##*/}"
    [[ "$base" != [-.]* ]] || { _err "unusable file name: $base"; return 2; }
    tdir="$(_target_dir "$level")" || return 2
    ti="$(_index "$level")"
    if [[ -n "$src_dir" ]] && compgen -G "$src_dir/tests/*.bats" >/dev/null; then
        command -v bats >/dev/null || { _err "missing tool: bats"; return 2; }
    fi
    info="$(_info "$src")"
    [[ -z "$info" ]] || IFS= read -r name <<<"$info"

    # 1. rules: the module among the installed ones, in one checker call
    _scan
    STAGE="$(command mktemp -d)"
    trap 'command rm -rf -- "$STAGE"' EXIT
    for i in "${!SC_PATH[@]}"; do
        (($(_index "${SC_LEVEL[i]}") <= ti)) || continue
        # the file this install would replace takes no part in the rules
        [[ -n "$name" && "$name" =~ $NAME_RE && "${SC_PATH[i]}" == "$tdir/$name.toml" ]] && continue
        command cp -- "${SC_PATH[i]}" "$STAGE/${SC_PATH[i]##*/}"
    done
    command cp -- "$src" "$STAGE/$base"
    files=()
    for f in "$STAGE"/*.toml; do files+=("${f##*/}"); done
    out="$(cd "$STAGE" && "$CONTRACT" check "${files[@]}")" || { _err "the contract checker failed"; return 2; }
    [[ "$(command jq -s 'length' <<<"$out" 2>/dev/null)" == "${#files[@]}" ]] ||
        { _err "unexpected output from the contract checker"; return 2; }
    verdict="$(command jq -r --arg f "$base" 'select(.file == $f) | .verdict' <<<"$out")"
    reasons="$(command jq -c --arg f "$base" 'select(.file == $f) | .reasons' <<<"$out")"
    if [[ "$verdict" != valid ]]; then
        _rejected "$name" "$level" "$reasons"
        return 3
    fi
    # 1b. the same name anywhere else, narrower levels included
    for i in "${!SC_PATH[@]}"; do
        if [[ "${SC_NAME[i]}" == "$name" && "${SC_PATH[i]}" != "$tdir/$name.toml" ]]; then
            _rejected "$name" "$level" '["duplicate-name"]'
            return 3
        fi
    done
    # 2. tests
    if [[ -n "$src_dir" ]] && compgen -G "$src_dir/tests/*.bats" >/dev/null; then
        (cd "$src_dir" && command bats "$src_dir/tests") >&2 || {
            _rejected "$name" "$level" '["tests-failed"]'
            return 3
        }
    fi
    # 3. target
    target="$tdir/$name.toml"
    if [[ -e "$target" || -L "$target" ]]; then
        info="$(_info "$target")"
        tname=""
        [[ -z "$info" ]] || IFS= read -r tname <<<"$info"
        [[ "$tname" == "$name" ]] || { _err "$target exists and is not the module $name"; return 2; }
        if command cmp -s -- "$src" "$target"; then
            _line "$name" "$level" "$target" unchanged
            return 0
        fi
        action=updated
    fi
    command mkdir -p -- "$tdir" || { _err "cannot create $tdir"; return 4; }
    # a name mise does not load, so a half-written file is never read
    tmp="$(command mktemp "$tdir/.install-XXXXXX")" || { _err "cannot write in $tdir"; return 4; }
    command cat -- "$src" >"$tmp" && command chmod 0644 -- "$tmp" && command mv -T -- "$tmp" "$target" || {
        command rm -f -- "$tmp"
        _err "cannot install $target"
        return 4
    }
    _line "$name" "$level" "$target" "$action"
}

uninstall() {
    local level="$usage_level" name="$usage_name" tdir target info tname="" i by=() required
    _ready || return 2
    [[ "$name" =~ $NAME_RE ]] || { _err "bad module name: $name"; return 2; }
    tdir="$(_target_dir "$level")" || return 2
    target="$tdir/$name.toml"
    if [[ ! -e "$target" && ! -L "$target" ]]; then
        _line "$name" "$level" "" absent
        return 0
    fi
    info="$(_info "$target")"
    [[ -z "$info" ]] || IFS= read -r tname <<<"$info"
    [[ "$tname" == "$name" ]] || { _err "$target is not the module $name"; return 2; }
    _scan
    for i in "${!SC_PATH[@]}"; do
        [[ "${SC_PATH[i]}" != "$target" ]] || continue
        [[ "$(command jq -r --arg n "$name" 'index($n) != null' <<<"${SC_DEPS[i]}")" == true ]] && by+=("${SC_NAME[i]}")
    done
    if ((${#by[@]})); then
        required="$(printf '%s\n' "${by[@]}" | command jq -Rcs 'split("\n") | map(select(. != "")) | unique')"
        command jq -cn --arg m "$name" --arg l "$level" --argjson r "$required" \
            '{module: $m, level: $l, path: null, action: "rejected", reasons: ["required-by"], required_by: $r}'
        return 3
    fi
    command rm -f -- "$target" || { _err "cannot remove $target"; return 4; }
    _line "$name" "$level" "$target" removed
}

ls() {
    local i
    _ready || return 2
    _scan
    for i in "${!SC_PATH[@]}"; do
        command jq -cn --arg m "${SC_NAME[i]}" --arg l "${SC_LEVEL[i]}" --arg p "${SC_PATH[i]}" \
            '{module: $m, level: $l, path: $p}'
    done
}

# usage hands over the chosen subcommand instead of calling a function for it
case "${usage_cmd:-}" in
install) install ;;
uninstall) uninstall ;;
ls) ls ;;
*) exec "$0" --help ;;
esac
