#!/usr/bin/env bash
# @describe an empty skogai to try things in: its own install dirs and git repo
#
# a sandbox is a dir with global/ (the global install dir), a git repo repo/
# and run, which runs one command inside it. nothing from outside is read or
# written there: no SKOGAI_* config from the caller, only its own layers.
# mise's own config is not swapped out: the config module's layers are mise's.
# @meta binname skogai sandbox

# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval, SKOGAI_* by `skogai module env`
set -euo pipefail

: "${SKOGAI_MODULE_DIR:?run me as \`skogai sandbox\`}"

# @cmd make a sandbox: every module found from here installed into it, skogai built there
#
# installs every module into repo/.skogai/modules (as `module add --apply`
# would, from its source when it has one, else from where it was found) and
# builds skogai there. prints the env lines that switch a shell into it: no
# SKOGAI_* config from outside, the two install dirs, the built skogai first
# on PATH, cd to repo.
# a dir made by an earlier sandbox is replaced; any other existing one is refused.
# @arg dir  default $TMPDIR/skogai
# @flag --empty  only the dirs and layers: no module installed, nothing built
# @option --shell[bash|zsh|fish]  env lines for this shell, default from $SHELL
new() {
    local dir shell name src v lines=""
    dir="${argc_dir:-${TMPDIR:-/tmp}/skogai}"
    [[ $dir == /* ]] || dir="${ARGC_PWD:-$PWD}/$dir"
    if [[ -f $dir/.sandbox ]]; then
        rm -rf "$dir"
    elif [[ -e $dir ]]; then
        echo "exists and is not a sandbox: $dir" >&2
        exit 2
    fi
    mkdir -p "$dir/global" "$dir/repo"
    touch "$dir/.sandbox"
    git -C "$dir/repo" init -q
    shell="${argc_shell:-$(basename "${SHELL:-bash}")}"
    # every run below sees only the sandbox's install dirs
    sandboxed() {
        (cd "$dir/repo" && SKOGAI_CONFIG_DIR="$dir/global" \
            SKOGAI_LOCAL_DIR="$dir/repo/.skogai" "$SKOGAI_BIN" "$@")
    }
    if [[ ${argc_empty:-} != 1 ]]; then
        while read -r name _; do
            src="$("$SKOGAI_BIN" module source "$name")" ||
                src="$("$SKOGAI_BIN" module show "$name" | awk -F"\t" "NR == 1 { print \$2 }")"
            sandboxed module add "$src" --to local --apply >/dev/null
        done < <("$SKOGAI_BIN" module ls)
        lines="$(sandboxed module build --to local --shell "$shell")"
    fi
    _run "$dir" >"$dir/run"
    chmod +x "$dir/run"
    for v in $(compgen -e SKOGAI_); do
        case "$v" in SKOGAI_BIN | SKOGAI_MODULE_PATH | SKOGAI_CONFIG_DIR | SKOGAI_LOCAL_DIR) continue ;; esac
        if [[ $shell == fish ]]; then echo "set -e $v"; else echo "unset $v"; fi
    done
    for v in CONFIG_DIR:global LOCAL_DIR:repo/.skogai; do
        if [[ $shell == fish ]]; then
            printf 'set -gx SKOGAI_%s %q\n' "${v%%:*}" "$dir/${v#*:}"
        else
            printf 'export SKOGAI_%s=%q\n' "${v%%:*}" "$dir/${v#*:}"
        fi
    done
    [[ -z $lines ]] || echo "$lines"
    printf 'cd %q\n' "$dir/repo"
}

# <dir>/run of a sandbox: the same switch for one command, for callers whose
# env does not persist between commands
# shellcheck disable=SC2016 # generated code, expanded when it runs
_run() {
    local b="$1/repo/.skogai/tmp/skogai"
    printf '#!/usr/bin/env bash\n# run <cmd>... in the sandbox %s, a shell if none; made by skogai sandbox new\n' "$1"
    printf 'for v in $(compgen -e SKOGAI_); do unset "$v"; done\n'
    printf 'export SKOGAI_CONFIG_DIR=%q SKOGAI_LOCAL_DIR=%q\n' "$1/global" "$1/repo/.skogai"
    printf 'export PATH=%q:"$PATH" MANPATH=%q:"${MANPATH:-}" ARGC_COMPLETIONS_PATH=%q:"${ARGC_COMPLETIONS_PATH:-}"\n' "$b/bin" "$b/man" "$b/completions"
    printf 'cd %q || exit 2\n' "$1/repo"
    printf 'exec "${@:-${SHELL:-bash}}"\n'
}

eval "$(argc --argc-eval "$0" "$@")"
