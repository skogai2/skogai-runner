#!/usr/bin/env -S usage bash
#USAGE bin "skogai"
#USAGE about "skogai main runner: one `skogai` for every registered usage script"
#USAGE long_about """
#USAGE `skogai <name> ...` runs the usage script registered as <name>, from the directory skogai was called in, with that script's own help, parsing and completion. `skogai register <file> <name>` adds one; there is nothing to sync.
#USAGE
#USAGE The registry is a directory of symlinks. $SKOGAI_COMMANDS (default ~/.config/skogai/commands) may list several, separated by `:`, nearest first: a name resolves to the first directory that has it, and register and unregister change only the first. A project can put its own directory in front of the home one, for instance from mise [env]. Registered commands reach usage through a mount, which calls this script by $SKOGAI_MAIN (default: `skogai` on PATH).
#USAGE """
#USAGE cmd "register" effect="write" help="register a usage script as `skogai <name>`" {
#USAGE   arg "<file>" help="the usage script, linked, not copied"
#USAGE   arg "<name>" help="lowercase, one segment"
#USAGE }
#USAGE cmd "unregister" effect="write" help="remove a registered command" {
#USAGE   arg "<name>" help="a registered name"
#USAGE }
#USAGE cmd "ls" effect="read" help="registered commands and where they point"
#USAGE cmd "_mount" hide=#true effect="read" help="the registered commands, as usage KDL"
#USAGE cmd "_spec" hide=#true effect="read" help="one registered script's spec, as usage KDL" {
#USAGE   arg "<name>" help="a registered name"
#USAGE }
#USAGE cmd "_names" hide=#true effect="read" help="registered names, one per line"
#USAGE complete "name" run="\"${SKOGAI_MAIN:-skogai}\" _names"
#USAGE mount run="\"${SKOGAI_MAIN:-skogai}\" _mount"
#
# the usage twin of main.sh. main.sh is a template that `sync` turns into
# ~/Argcfile.sh, with one generated recipe per registered script. here nothing
# is generated: the `mount` above asks `skogai _mount` for the registry on
# demand. usage only runs it when it needs the full command list (help,
# completion) or meets a word it does not know, so `skogai ls` never pays for
# it. `_mount` lists each registered name with a nested mount, `skogai _spec
# <name>`, which hands usage that script's own #USAGE spec. a registered name is
# never a shell function here, so builtins and keywords are fine names.

# shellcheck shell=bash disable=SC2154 # usage_* are exported by usage
set -euo pipefail

# the registry layers, nearest first; empty entries are skipped
LAYERS=()
IFS=: read -ra _split <<<"${SKOGAI_COMMANDS:-${XDG_CONFIG_HOME:-$HOME/.config}/skogai/commands}"
for _dir in ${_split[@]+"${_split[@]}"}; do [[ -z "$_dir" ]] || LAYERS+=("$_dir"); done
unset _split _dir
((${#LAYERS[@]})) || { printf 'SKOGAI_COMMANDS names no directory\n' >&2; exit 2; }
COMMANDS="${LAYERS[0]}"

# the link a name resolves to: the first layer that has it, gone or not;
# the nearest layer's path when none does
_resolve() {
    local dir
    for dir in "${LAYERS[@]}"; do
        [[ ! -e "$dir/$1.sh" && ! -L "$dir/$1.sh" ]] || { printf '%s\n' "$dir/$1.sh"; return 0; }
    done
    printf '%s\n' "$COMMANDS/$1.sh"
}

# names usage or this script already answer to
_reserved() {
    case "$1" in register | unregister | ls | help) return 0 ;; esac
    return 1
}

register() {
    local name="$usage_name" file
    [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] || { printf 'bad name: %s\n' "$name" >&2; return 2; }
    ! _reserved "$name" || { printf 'reserved: %s\n' "$name" >&2; return 2; }
    file="$(command realpath -e -- "$usage_file")" || return 1
    command usage lint "$file" >/dev/null || { printf 'not a valid usage script: %s\n' "$file" >&2; return 1; }
    command mkdir -p -- "$COMMANDS"
    command ln -sfn -- "$file" "$COMMANDS/$name.sh"
}

unregister() {
    local still
    command rm -f -- "$COMMANDS/$usage_name.sh"
    still="$(_resolve "$usage_name")"
    [[ ! -e "$still" && ! -L "$still" ]] || printf '%s: still registered in %s\n' "$usage_name" "${still%/*}" >&2
}

list() {
    local name width=0 names=() file
    while IFS= read -r name; do
        names+=("$name")
        ((${#name} <= width)) || width=${#name}
    done < <(_names)
    for name in ${names[@]+"${names[@]}"}; do
        file="$(_resolve "$name")"
        printf '%-*s  %s' "$width" "$name" "$(command readlink -- "$file" || printf '%s' "$file")"
        [[ -e "$file" ]] && printf '\n' || printf ' (gone)\n'
    done
}

# every name once, in name order, across all layers
_names() {
    local dir file name
    local -A seen=()
    for dir in "${LAYERS[@]}"; do
        for file in "$dir"/*.sh; do
            [[ -e "$file" || -L "$file" ]] || continue
            name="${file##*/}"
            seen["${name%.sh}"]=1
        done
    done
    ((${#seen[@]})) || return 0
    printf '%s\n' "${!seen[@]}" | LC_ALL=C command sort
}

# one cmd per registered name. a gone target stays listed, hidden and taking
# any arguments, so running it reaches _delegate's clear error instead of
# usage's "unknown subcommand"
_mount() {
    local name file about
    while IFS= read -r name; do
        file="$(_resolve "$name")"
        if [[ ! -e "$file" ]]; then
            printf 'cmd "%s" hide=#true help="gone" {\n  arg "[args]..." var=#true\n}\n' "$name"
            continue
        fi
        about="$(_about "$file")"
        # shellcheck disable=SC2016 # ${SKOGAI_MAIN...} is for the sh -c that runs the mount
        printf 'cmd "%s"%s {\n  mount run="\\"${SKOGAI_MAIN:-skogai}\\" _spec %s"\n}\n' \
            "$name" "${about:+ help=$about}" "$name"
    done < <(_names)
}

# the script's spec, or, when it no longer lints, a catch-all so the script
# still runs and reports its own problem
_spec() {
    local file
    file="$(_resolve "$usage_name")"
    if [[ -e "$file" ]] && command usage lint "$file" >/dev/null 2>&1; then
        _extract "$file"
    else
        printf 'arg "[args]..." var=#true\n'
    fi
}

# the #USAGE lines of a script, as usage reads them: a line marked #USAGE,
# //USAGE or ::USAGE (or [USAGE]) gives its trimmed rest; once one was found,
# blank comment lines continue and any other line ends the spec
_extract() {
    local line found="" re='^(#|//|::)(USAGE| ?\[USAGE\])(.*)$' blank='^(#|//|::)[[:space:]]*$' rest
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ $re ]]; then
            found=1
            rest="${BASH_REMATCH[3]}"
            rest="${rest#"${rest%%[![:space:]]*}"}"
            rest="${rest%"${rest##*[![:space:]]}"}"
            printf '%s\n' "$rest"
        elif [[ -n "$found" ]]; then
            [[ "$line" =~ $blank ]] || break
        fi
    done <"$1"
}

# a top-level single-line `about "..."` as its KDL string, verbatim; anything
# fancier (a """ block) gives no help line rather than a parse
_about() {
    local line re='^about[[:space:]]+("([^"\\]|\\.)*")[[:space:]]*$'
    while IFS= read -r line; do
        [[ "$line" =~ $re ]] && { printf '%s\n' "${BASH_REMATCH[1]}"; return 0; }
    done < <(_extract "$1")
    return 0
}

# a registered script, run with the rest of the arguments from the caller's
# directory; usage already validated them against the script's spec, and the
# script parses them again itself. none of this parse's usage_* reach it
_delegate() {
    local name="$1" file
    file="$(_resolve "$1")"
    shift
    [[ -e "$file" ]] || {
        printf '%s: %s is gone, register it again or unregister it\n' \
            "$name" "$(command readlink -- "$file" || printf '%s' "$file")" >&2
        return 1
    }
    unset "${!usage_@}"
    exec usage bash "$file" "$@"
}

# usage_cmd is the chosen path for this script's own commands; a mounted
# script's commands are named after that script's `bin`, so the registered name
# is read from argv instead
case "${usage_cmd:-}" in
register) register ;;
unregister) unregister ;;
ls) list ;;
_mount) _mount ;;
_spec) _spec ;;
_names) _names ;;
"") exec "$0" --help ;;
*) _delegate "$@" ;;
esac
