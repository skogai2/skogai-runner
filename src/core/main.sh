#!/usr/bin/env bash
# @describe skogai main runner: one `argc` for every registered command file
#
# `argc <name> ...` runs the argc script registered as <name>, from the directory
# argc was called in. `argc register <file> <name>` adds one, `argc sync` rebuilds.
# this file is a template: `sync` writes ~/Argcfile.sh from it plus one recipe
# per registered command, so argc finds it from anywhere under ~.
# @meta require-tools argc,jq
# @meta binname argc
# @env ARGC_COMMANDS                                  registry dir, default ~/.config/argc/commands
# @env ARGC_MAIN                                      the generated main file, default ~/Argcfile.sh
# @env ARGC_TEMPLATE=/usr/share/skogai/core/main.sh   the template sync writes the main from

# shellcheck disable=SC2154,SC2016 # argc_* are assigned by --argc-eval; generated code stays quoted
set -euo pipefail

COMMANDS="${ARGC_COMMANDS:-${XDG_CONFIG_HOME:-$HOME/.config}/argc/commands}"
MAIN="${ARGC_MAIN:-$HOME/Argcfile.sh}"
EVAL='eval "$(argc --argc-eval "$0" "$@")"'

# a registered command becomes a function in the main, so it can't be one of
# the main's own commands or anything bash resolves before functions.
# external tools are fine: the main calls them through `command`.
_reserved() {
    case "$1" in register | unregister | ls | sync | help) return 0 ;; esac
    case "$(type -t "$1")" in builtin | keyword) return 0 ;; esac
    return 1
}

# @cmd register an argc script as `argc <name>`, then sync
# @arg file!                           the argc script, linked, not copied
# @arg name!                           lowercase, one segment
register() {
    [[ "$argc_name" =~ ^[a-z][a-z0-9-]*$ ]] || { printf 'bad name: %s\n' "$argc_name" >&2; return 2; }
    ! _reserved "$argc_name" || { printf 'reserved: %s\n' "$argc_name" >&2; return 2; }
    local file
    file="$(cd "${ARGC_PWD:-$PWD}" && command realpath -e "$argc_file")"
    command argc --argc-export "$file" >/dev/null
    command mkdir -p "$COMMANDS"
    command ln -sfn "$file" "$COMMANDS/$argc_name.sh"
    sync
}

# @cmd remove a registered command, then sync
# @arg name![`_choice_command`]
unregister() {
    command rm -f "$COMMANDS/$argc_name.sh"
    sync
}

# @cmd registered commands and where they point
ls() {
    local name width=0 names=() file
    while IFS= read -r name; do
        names+=("$name")
        ((${#name} <= width)) || width=${#name}
    done < <(_choice_command)
    for name in "${names[@]}"; do
        file="$COMMANDS/$name.sh"
        printf '%-*s  %s' "$width" "$name" "$(command readlink "$file" || printf '%s' "$file")"
        [[ -e "$file" ]] && printf '\n' || printf ' (gone)\n'
    done
}

# @cmd rebuild the main file from the template and the registry
#
# a command whose file is gone or doesn't parse is skipped with a warning.
sync() {
    local lines file name describe out
    [[ -f "$ARGC_TEMPLATE" ]] || { printf 'template %s is missing\n' "$ARGC_TEMPLATE" >&2; return 1; }
    mapfile -t lines <"$ARGC_TEMPLATE"
    [[ "${lines[-1]}" == "$EVAL" ]] || { printf 'template %s does not end in: %s\n' "$ARGC_TEMPLATE" "$EVAL" >&2; return 1; }
    command mkdir -p "${MAIN%/*}"
    out="$(command mktemp "$MAIN.XXXXXX")"
    # shellcheck disable=SC2064 # out is local, gone by the time EXIT fires
    trap "command rm -f $(printf '%q' "$out")" EXIT
    {
        printf '%s\n' "${lines[@]:0:${#lines[@]}-1}"
        for file in "$COMMANDS"/*.sh; do
            name="${file##*/}"
            name="${name%.sh}"
            [[ -e "$file" ]] || { [[ -L "$file" ]] && printf 'skip  %s: %s is gone\n' "$name" "$(command readlink "$file")" >&2; continue; }
            describe="$(command argc --argc-export "$file" 2>/dev/null | command jq -r '(.describe // "") | split("\n")[0] // ""')" ||
                { printf 'skip  %s: does not parse\n' "$name" >&2; continue; }
            printf '\n# @cmd %s\n# @arg args~[?`_choice_delegate`]\n%s() { _delegate %s "${argc_args[@]}"; }\n' \
                "${describe:-$name}" "$name" "$name"
        done
        printf '\n%s\n' "$EVAL"
    } >"$out"
    command argc --argc-export "$out" >/dev/null
    command mv "$out" "$MAIN"
    printf 'wrote %s\n' "$MAIN" >&2
}

# registered command <name> with the rest of the args, from the caller's directory
_delegate() {
    local name="$1" file="$COMMANDS/$1.sh"
    shift
    [[ -e "$file" ]] || {
        printf '%s: %s is gone, register it again or unregister it\n' "$name" "$(command readlink "$file" || printf '%s' "$file")" >&2
        return 1
    }
    (cd "${ARGC_PWD:-$PWD}" && command argc --argc-run "$file" "$@")
}

# completion for a forwarded command: ask its own script and drop its color
# field, argc adds its own
_choice_delegate() {
    local name="$argc__cmd_fn" line value rest
    command argc --argc-compgen generic "$COMMANDS/$name.sh" "$name" "${argc__args[@]:argc__cmd_arg_index+1}" |
        while IFS= read -r line; do
            value="${line%%$'\t'*}"
            rest="${line#"$value"}"
            rest="${rest#$'\t'}"
            case "$value" in
            __argc_value=*) printf '%s\n' "${value,,}" ;;
            __argc_*) printf '%s\n' "$value" ;;
            *)
                case "$rest" in
                /color:*$'\t'*) printf '%s\t%s\n' "$value" "${rest#*$'\t'}" ;;
                /color:*) printf '%s\n' "$value" ;;
                *) printf '%s\n' "$line" ;;
                esac
                ;;
            esac
        done
}

_choice_command() {
    local file name
    for file in "$COMMANDS"/*.sh; do
        [[ -e "$file" || -L "$file" ]] || continue
        name="${file##*/}"
        printf '%s\n' "${name%.sh}"
    done
}

eval "$(argc --argc-eval "$0" "$@")"
