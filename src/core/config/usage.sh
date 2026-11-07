#!/usr/bin/env -S usage bash
#USAGE bin "config"
#USAGE about "read and write SKOGAI_* settings in mise's own [env] tables"
#USAGE long_about """
#USAGE a setting is a mise [env] entry, so the value a user sets is the value a module's mise task sees. Precedence, later wins: module default, system ($MISE_SYSTEM_DIR/config.toml), global ($MISE_CONFIG_DIR/config.toml), local (<git root>/mise.toml), override (<git root>/mise.local.toml), caller env. See docs/config.md.
#USAGE
#USAGE keys are `.`-separated segments matching ^[a-z][a-z0-9-]*$; hello.greeting is SKOGAI_HELLO_GREETING.
#USAGE
#USAGE exit 0 ok, 1 command line does not fit the spec (usage's parser), 2 bad args, refused value, missing tool or mise failure, 3 get of an undefined key. stdout is machine output, diagnostics go to stderr.
#USAGE """
#USAGE cmd "get" effect="read" help="print the resolved value of a key" {
#USAGE   flag "--show-origin" help="print <origin><TAB><value>"
#USAGE   arg "<key>" help="e.g. hello.greeting"
#USAGE }
#USAGE cmd "list" effect="read" help="print key=value for every SKOGAI_* variable mise resolves" {
#USAGE   flag "--show-origin" help="print <origin><TAB>key=value"
#USAGE }
#USAGE cmd "set" effect="write" help="store a value in a layer file (default local)" {
#USAGE   flag "--system" help="$MISE_SYSTEM_DIR/config.toml"
#USAGE   flag "--global" help="$MISE_CONFIG_DIR/config.toml"
#USAGE   flag "--override" help="<git root>/mise.local.toml"
#USAGE   arg "<key>"
#USAGE   arg "<value>"
#USAGE }
#USAGE cmd "unset" effect="write" help="remove a key from a layer file (default local)" {
#USAGE   flag "--system" help="$MISE_SYSTEM_DIR/config.toml"
#USAGE   flag "--global" help="$MISE_CONFIG_DIR/config.toml"
#USAGE   flag "--override" help="<git root>/mise.local.toml"
#USAGE   arg "<key>"
#USAGE }
#USAGE cmd "files" effect="read" help="list the layer files and the module files"
#
# shellcheck shell=bash disable=SC2154 # usage_* are exported by usage
set -euo pipefail
# C locale: sorted globs, byte-wise [[:cntrl:]], stable sort order
export LC_ALL=C

KEY_RE='^[a-z][a-z0-9-]*(\.[a-z][a-z0-9-]*)*$'
TMP=""

die() { printf '%s\n' "$*" >&2; exit 2; }

_cleanup() { [[ -z "$TMP" ]] || command rm -f -- "$TMP"; }
trap _cleanup EXIT

_tools() {
    local tool
    for tool in git mise jq yq; do
        command -v "$tool" >/dev/null || die "missing tool: $tool"
    done
}

# sets SYS CFG ROOT (ROOT empty outside a git work tree)
_paths() {
    SYS="${MISE_SYSTEM_DIR:-/etc/mise}"
    CFG="${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}"
    ROOT="$(command git rev-parse --show-toplevel 2>/dev/null)" || ROOT=""
}

# key -> env name in $VAR, or exit 2
_envname() {
    [[ "$1" =~ $KEY_RE ]] || die "invalid key: '$1' (segments of ^[a-z][a-z0-9-]*\$ joined by '.')"
    local k="${1^^}"
    k="${k//-/}"
    VAR="SKOGAI_${k//./_}"
}

# the file of a layer (system global local override) in $FILE; empty when there is none
_layer_file() {
    case "$1" in
    system) FILE="$SYS/config.toml" ;;
    global) FILE="$CFG/config.toml" ;;
    local) FILE="${ROOT:+$ROOT/mise.toml}" ;;
    override) FILE="${ROOT:+$ROOT/mise.local.toml}" ;;
    esac
}

# does the [env] table of a toml file define $2? unparseable files do not
_file_has() {
    [[ -f "$1" ]] || return 1
    command yq -p toml -o json -I0 '.' "$1" 2>/dev/null |
        command jq -e --arg n "$2" '(.env | type == "object") and (.env | has($n))' >/dev/null 2>&1
}

# the module files in load order: lines "<name><TAB><path>"
_modules() {
    local dir f name dirs=("$SYS/conf.d" "$CFG/conf.d")
    [[ -z "$ROOT" ]] || dirs+=("$ROOT/.mise/conf.d" "$ROOT/.config/mise/conf.d")
    for dir in "${dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        for f in "$dir"/*.toml; do
            [[ -f "$f" ]] || continue
            name="$(command yq -p toml -o json -I0 '.' "$f" 2>/dev/null | command jq -r '
                try (._.skogai | select(type == "object") | to_entries
                     | select(length == 1 and (.[0].value | type) == "object") | .[0].key) catch empty')" || continue
            [[ -z "$name" ]] || printf '%s\t%s\n' "$name" "$f"
        done
    done
}

_resolve_env() {
    ENVJSON="$(command mise env --json)" || die "mise env failed"
}

# value of $1 in mise's env into $VALUE (raw, newlines kept); returns 1 when undefined
_value() {
    if command jq -e --arg n "$1" 'has($n)' <<<"$ENVJSON" >/dev/null; then
        VALUE="$(command jq -j --arg n "$1" '.[$n] | tostring' <<<"$ENVJSON"; printf x)"
        VALUE="${VALUE%x}"
    elif [[ -v "$1" ]]; then
        VALUE="${!1}"
    else
        return 1
    fi
}

# origin of variable $1 whose resolved value is $2, into $ORIGIN
_origin() {
    local layer name path
    if [[ -v "$1" && "${!1}" == "$2" ]]; then ORIGIN=env; return; fi
    for layer in override local global system; do
        _layer_file "$layer"
        if [[ -n "$FILE" ]] && _file_has "$FILE" "$1"; then ORIGIN="$layer"; return; fi
    done
    while IFS=$'\t' read -r name path; do
        if _file_has "$path" "$1"; then ORIGIN="module:$name"; return; fi
    done < <(_modules)
    ORIGIN=mise
}

# backslash, newline and tab escaped, into $ESC
_escape() {
    ESC="${1//\\/\\\\}"
    ESC="${ESC//$'\n'/\\n}"
    ESC="${ESC//$'\t'/\\t}"
}

get() {
    local value
    _tools
    _paths
    _envname "$usage_key"
    _resolve_env
    _value "$VAR" || return 3
    value="$VALUE"
    if [[ "${usage_show_origin:-}" == true ]]; then
        _origin "$VAR" "$value"
        _escape "$value"
        printf '%s\t%s\n' "$ORIGIN" "$ESC"
    else
        printf '%s\n' "$value"
    fi
}

list() {
    local name key lines=()
    _tools
    _paths
    _resolve_env
    while IFS= read -r name; do
        [[ "$name" =~ ^SKOGAI_[A-Z0-9_]+$ ]] || continue
        key="${name#SKOGAI_}"
        key="${key,,}"
        key="${key//_/.}"
        [[ "$key" =~ $KEY_RE ]] || continue
        lines+=("$key"$'\t'"$name")
    done < <(command jq -r 'keys[]' <<<"$ENVJSON")
    ((${#lines[@]})) || return 0
    while IFS=$'\t' read -r key name; do
        _value "$name"
        _escape "$VALUE"
        if [[ "${usage_show_origin:-}" == true ]]; then
            _origin "$name" "$VALUE"
            printf '%s\t%s=%s\n' "$ORIGIN" "$key" "$ESC"
        else
            printf '%s=%s\n' "$key" "$ESC"
        fi
    done < <(printf '%s\n' "${lines[@]}" | command sort -t$'\t' -k1,1)
}

files() {
    local layer name path
    _tools
    _paths
    for layer in system global local override; do
        _layer_file "$layer"
        if [[ -z "$FILE" ]]; then
            printf '%s\t-\tmissing\n' "$layer"
        elif [[ -f "$FILE" ]]; then
            printf '%s\t%s\tpresent\n' "$layer" "$FILE"
        else
            printf '%s\t%s\tmissing\n' "$layer" "$FILE"
        fi
    done
    while IFS=$'\t' read -r name path; do
        printf 'module:%s\t%s\tpresent\n' "$name" "$path"
    done < <(_modules)
}

# the level flags -> $LEVEL, or exit 2
_level() {
    local n=0
    LEVEL=local
    [[ "${usage_system:-}" != true ]] || { LEVEL=system; n=$((n + 1)); }
    [[ "${usage_global:-}" != true ]] || { LEVEL=global; n=$((n + 1)); }
    [[ "${usage_override:-}" != true ]] || { LEVEL=override; n=$((n + 1)); }
    ((n <= 1)) || die "at most one of --system, --global, --override"
    _layer_file "$LEVEL"
    [[ -n "$FILE" ]] || die "not in a git work tree: the $LEVEL layer needs one (use --system or --global)"
}

# edit a copy of $FILE with the mise arguments in "$@", then rename it over $FILE.
# a no-op edit (same bytes) leaves $FILE alone
_edit() {
    local dir="${FILE%/*}"
    if [[ -e "$FILE" ]]; then
        command yq -p toml -o json -I0 '.' "$FILE" >/dev/null 2>&1 || die "cannot parse $FILE as TOML"
    fi
    command mkdir -p -- "$dir" || die "cannot create $dir"
    TMP="$(command mktemp "$dir/.skogai-set-XXXXXX.toml")" || die "cannot write in $dir"
    if [[ -e "$FILE" ]]; then
        command cp -p -- "$FILE" "$TMP" || die "cannot copy $FILE"
    else
        command chmod 644 -- "$TMP"
    fi
    command mise "$@" --file "$TMP" >/dev/null || die "mise edit failed for $FILE"
    if [[ -e "$FILE" ]] && command cmp -s -- "$FILE" "$TMP"; then return 0; fi
    command mv -f -- "$TMP" "$FILE" || die "cannot replace $FILE"
    TMP=""
}

set_() {
    local value="$usage_value"
    _tools
    _paths
    _envname "$usage_key"
    if [[ "$value" == *[\'\"\\[:cntrl:]]* || "$value" == *'{{'* || "$value" == *'}}'* ||
        "$value" == *'{%'* || "$value" == *'%}'* || "$value" == *'{#'* || "$value" == *'#}'* ]]; then
        die "refused value: it holds a quote, backslash, control character or template delimiter"
    fi
    _level
    # mise set takes --file after its arguments; the template keeps the caller env winning
    _edit set "$VAR={{ get_env(name='$VAR', default='$value') }}"
}

unset_() {
    _tools
    _paths
    _envname "$usage_key"
    _level
    [[ -e "$FILE" ]] || return 0
    _edit unset "$VAR"
}

# usage hands over the chosen subcommand instead of calling a function for it
case "${usage_cmd:-}" in
get) get ;;
list) list ;;
set) set_ ;;
unset) unset_ ;;
files) files ;;
*) exec "$0" --help ;;
esac
