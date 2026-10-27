#!/usr/bin/env bash
# @describe config layers through mise: skogai.toml and skogai.<module>.toml beside mise.toml
#
# a key is a module's name and its own: runner.model is SKOGAI_RUNNER_MODEL.
# fold order, later wins: module.md `config:` defaults, mise's system and
# global conf.d/skogai.toml, then in each dir from / down: skogai.toml,
# skogai.<module>.toml, mise's own files; then the caller's env.
# @meta require-tools mise,jq
# @meta binname skogai config
# @env MISE_OVERRIDE_CONFIG_FILENAMES  mise's project config files; skogai's are put first when missing

# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval, SKOGAI_* by `skogai module env`
set -euo pipefail

: "${SKOGAI_MODULE_DIR:?run me as \`skogai config\`}"

# mise's own project files, in its order, after skogai's
MISE_FILES='.config/mise/conf.d/*.toml:.config/mise/config.toml:.config/mise.toml:mise/config.toml:mise.toml:.mise/config.toml:.mise.toml:.config/mise/config.local.toml:.config/mise.local.toml:mise/config.local.toml:mise.local.toml:.mise/config.local.toml:.mise.local.toml'
case "${MISE_OVERRIDE_CONFIG_FILENAMES:-}" in
*skogai.toml*) ;;
"") export MISE_OVERRIDE_CONFIG_FILENAMES="skogai.toml:skogai.*.toml:$MISE_FILES" ;;
*) export MISE_OVERRIDE_CONFIG_FILENAMES="skogai.toml:skogai.*.toml:$MISE_OVERRIDE_CONFIG_FILENAMES" ;;
esac

# joins the items of a list value; `get` prints one item per line
SEP=$'\x1f'

# @cmd print the resolved value of a key; a list prints one item per line
# @flag --show-origin  also print where the value came from: a file, module:<name> or env:<VAR>
# @arg key![`_choice_key`]
get() {
    local line
    line="$(_resolve | awk -F'\t' -v k="$argc_key" '$1 == k { print; f = 1 } END { exit !f }')" || exit 1
    if [[ ${argc_show_origin:-} == 1 ]]; then
        printf '%s\t%s\n' "$(cut -f3 <<<"$line")" "$(cut -f2 <<<"$line" | tr "$SEP" ' ')"
    else
        cut -f2 <<<"$line" | tr "$SEP" '\n'
    fi
}

# @cmd set a key in skogai.toml at the git root, the global conf.d/skogai.toml, or a module's skogai.<module>.toml
# @flag --global  write mise's global conf.d instead of the git root
# @option --module[`_choice_module`]  write that module's skogai.<module>.toml; the key must be its own
# @arg key![?`_choice_key`]
# @arg value!
set() {
    local file
    file="$(_target)" || exit 2
    mkdir -p "$(dirname "$file")"
    mise set --quiet --file "$file" "$(_env_name "$argc_key")=$argc_value"
}

# @cmd remove a key from the file set writes; exit 1 if it is not there
# @flag --global  remove from mise's global conf.d instead of the git root
# @option --module[`_choice_module`]  remove from that module's skogai.<module>.toml
# @arg key![`_choice_key`]
unset() {
    local file env
    file="$(_target)" || exit 2
    env="$(_env_name "$argc_key")"
    [[ -f $file ]] && mise config get --file "$file" "env.$env" >/dev/null 2>&1 || exit 1
    mise unset --quiet --file "$file" "$env"
}

# @cmd print every resolved key as key=value; a list prints one line per item
# @flag --show-origin  prefix each line with where it came from
list() {
    local key value origin item
    while IFS=$'\t' read -r key value origin; do
        while IFS= read -r -d "$SEP" item; do
            if [[ ${argc_show_origin:-} == 1 ]]; then
                printf '%s\t%s=%s\n' "$origin" "$key" "$item"
            else
                printf '%s=%s\n' "$key" "$item"
            fi
        done <<<"$value$SEP"
    done < <(_resolve)
}

# @cmd print the mise layers as export lines, MISE_OVERRIDE_CONFIG_FILENAMES first
#
# defaults are not in it, core gives those. eval it to see what skogai sees.
env() {
    local name value
    printf 'export MISE_OVERRIDE_CONFIG_FILENAMES=%q\n' "$MISE_OVERRIDE_CONFIG_FILENAMES"
    while IFS=$'\t' read -r name value _; do
        printf 'export %s=%q\n' "$name" "${value//$SEP/$'\n'}"
    done < <(_mise)
}

# @cmd print each skogai layer file, and whether it is there
files() {
    local name
    _present system "$(_system_dir)/conf.d/skogai.toml"
    _present global "$(_global_dir)/conf.d/skogai.toml"
    _present local "$(_root)/skogai.toml"
    while read -r name _; do
        _present "module:$name" "$(_root)/skogai.$name.toml"
    done < <("$SKOGAI_BIN" module ls)
}

# "VAR<TAB>value<TAB>file" for every SKOGAI_* the mise layers set here
_mise() {
    (cd "$(_pwd)" && mise env --json-extended) |
        jq -r --arg sep "$SEP" 'to_entries[] | select(.key | startswith("SKOGAI_")) |
            [.key, (.value.value | gsub("\n"; $sep)), .value.source] | join("\t")'
}

# "key<TAB>value<TAB>origin" for every key: defaults, then the mise layers,
# then the caller's env where it says something else
_resolve() {
    local -A key val origin
    local k v src e
    while IFS=$'\t' read -r k v; do
        e="$(_env_name "$k")"
        key[$e]="$k" val[$e]="$v" origin[$e]="module:${k%%.*}"
    done < <("$SKOGAI_BIN" module defaults)
    while IFS=$'\t' read -r e v src; do
        key[$e]="${key[$e]:-$(_key "$e")}" val[$e]="$v" origin[$e]="$src"
    done < <(_mise)
    for e in "${!val[@]}"; do
        [[ -n ${!e+x} && ${!e} != "${val[$e]//$SEP/$'\n'}" ]] || continue
        v="${!e}"
        val[$e]="${v//$'\n'/$SEP}" origin[$e]="env:$e"
    done
    for e in "${!val[@]}"; do
        printf '%s\t%s\t%s\n' "${key[$e]}" "${val[$e]}" "${origin[$e]}"
    done | sort
}

# the file set and unset write: skogai.toml or skogai.<module>.toml, at the git root or in mise's global conf.d
_target() {
    local dir name=skogai.toml
    if [[ -n ${argc_module:-} ]]; then
        [[ $argc_key == "$argc_module".* ]] || { echo "key $argc_key is outside $argc_module" >&2; return 2; }
        name="skogai.$argc_module.toml"
    fi
    if [[ ${argc_global:-} == 1 ]]; then dir="$(_global_dir)/conf.d"; else dir="$(_root)"; fi
    echo "$dir/$name"
}

_pwd() { echo "${ARGC_PWD:-$PWD}"; }
_root() { git -C "$(_pwd)" rev-parse --show-toplevel 2>/dev/null || _pwd; }
_global_dir() { echo "${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}"; }
_system_dir() { echo "${MISE_SYSTEM_CONFIG_DIR:-/etc/mise}"; }
_present() { printf '%s\t%s\t%s\n' "$1" "$2" "$([[ -f $2 ]] && echo present || echo missing)"; }

# `.` is a relation, `-` is part of a name: stage.on-stop -> SKOGAI_STAGE_ONSTOP
_env_name() {
    local k="${1^^}"
    k="${k//-/}"
    echo "SKOGAI_${k//./_}"
}

# a var no default names, back to a key: SKOGAI_RUNNER_MODEL -> runner.model
_key() {
    local k="${1#SKOGAI_}"
    k="${k,,}"
    echo "${k//_/.}"
}

# every resolved key, only --module's own if given; described by value when completing
_choice_key() {
    local keys
    keys="$(_resolve | awk -F'\t' -v m="${argc_module:-}" 'm == "" || index($1, m ".") == 1')"
    if [[ ${ARGC_COMPGEN:-0} == 1 ]]; then cut -f1,2 <<<"$keys" | tr "$SEP" ' '; else cut -f1 <<<"$keys"; fi
}

_choice_module() { "$SKOGAI_BIN" module ls | cut -d' ' -f1; }

eval "$(argc --argc-eval "$0" "$@")"
