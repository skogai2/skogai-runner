# the base every module's tests stand on: `load "$SKOGAI_TEST_HELPER"` at the
# top of a .bats file. each test gets an empty sandbox: its repo as cwd, its
# own global and local layers, and mise's system, global and state dirs, so
# nothing outside BATS_TEST_TMPDIR is read or written. a file that defines its
# own setup() calls skogai_setup.
#
# set by `skogai test run`: SKOGAI_BIN, SKOGAI_MODULE_PATH,
# SKOGAI_TEST_MODULE (the module under test), SKOGAI_TEST_HELPER (this file).

skogai_setup() {
    local lines
    # run --separate-stderr
    bats_require_minimum_version 1.5.0
    # mise's config is a layer too: its system, global and state dirs are the test's
    unset MISE_OVERRIDE_CONFIG_FILENAMES MISE_ENV MISE_GLOBAL_CONFIG_FILE MISE_SYSTEM_CONFIG_FILE
    export MISE_SYSTEM_CONFIG_DIR="$BATS_TEST_TMPDIR/system"
    export MISE_CONFIG_DIR="$BATS_TEST_TMPDIR/mise"
    export MISE_STATE_DIR="$BATS_TEST_TMPDIR/state"
    # config from the caller's env would shadow every layer; the sandbox unsets it
    lines="$(skogai sandbox new "$BATS_TEST_TMPDIR/sandbox" --empty --shell bash)" || return 1
    eval "$(grep -v '^unset SKOGAI_TEST_' <<<"$lines")"
    REPO="$PWD"
    LOCAL="$SKOGAI_LOCAL_DIR"
}

setup() { skogai_setup; }

# modules call `skogai <other>`, so it is on PATH as well
PATH="$(dirname "$SKOGAI_BIN"):$PATH"
skogai() { "$SKOGAI_BIN" "$@"; }

# a module source dir of our own, first on the path: fixture <name> <<<"$module_md"
fixture() {
    FIX="$BATS_TEST_TMPDIR/sources"
    export SKOGAI_MODULE_PATH="$FIX:$SKOGAI_MODULE_PATH"
    mkdir -p "$FIX/$1"
    cat >"$FIX/$1/module.md"
}

# the source dir of the module under test, or of $1
module_dir() { skogai module show "${1:-$SKOGAI_TEST_MODULE}" | awk -F"\t" "NR == 1 { print \$2 }"; }

# a manifest field of the module under test, empty if missing
module_field() { yq --front-matter=extract "$1 // \"\"" "$(module_dir)/module.md"; }

assert_status() {
    [[ $status -eq $1 ]] || { printf 'expected exit %s, got %s\n%s\n' "$1" "$status" "$output" >&2; return 1; }
}

assert_output_has() {
    [[ $output == *"$1"* ]] || { printf 'output lacks: %s\n---\n%s\n' "$1" "$output" >&2; return 1; }
}

refute_output_has() {
    [[ $output != *"$1"* ]] || { printf 'output has: %s\n---\n%s\n' "$1" "$output" >&2; return 1; }
}

assert_file() { [[ -f $1 ]] || { echo "no file: $1" >&2; return 1; }; }
