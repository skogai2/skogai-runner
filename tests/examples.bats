#!/usr/bin/env bats
# every usage example module is a live test: each examples/usage/<name>/<name>.md
# is checked, then run twice through src/core/run/usage.sh, in a temp copy of
# its directory. Adding an example adds its tests; no test code changes.

bats_require_minimum_version 1.11.0

ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
RUN="$ROOT/src/core/run/usage.sh"

setup() {
    # rootless podman keeps its images under the data dir; keep that, isolate the rest
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    export HOME="$BATS_TEST_TMPDIR/home" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/home/.config"
    export TMPDIR="$BATS_TEST_TMPDIR/tmp"
    mkdir -p "$HOME" "$TMPDIR"
    W="$BATS_TEST_TMPDIR/work"
    mkdir -p "$W"
}

# copy example <name> into the test dir; sets M to its module path
copy_example() {
    cp -a "$ROOT/examples/usage/$1" "$W/$1"
    M="$W/$1/$1.md"
}

field() { jq -c "$1" <<<"$output"; }

verdict_is() {
    [ "$(field .verdict)" = "\"$1\"" ] || {
        echo "verdict: $(field .verdict), want $1; reasons: $(field .reasons)"
        echo "stderr: $stderr"
        return 1
    }
}

# every regular file under the module dir with its content hash, sorted
snapshot() { (cd "$W/$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum); }

example_check() {
    copy_example "$1"
    run --separate-stderr "$RUN" check "$M"
    [ "$status" -eq 0 ]
    verdict_is valid
}

example_run() {
    command -v podman >/dev/null || skip "podman not on PATH"
    podman image exists "${SKOGAI_IMAGE:-skogai-runner-dev}" || skip "no ${SKOGAI_IMAGE:-skogai-runner-dev} image (mise run image)"
    copy_example "$1"

    run --separate-stderr "$RUN" check "$M"
    [ "$status" -eq 0 ]
    local -a owns
    mapfile -t owns < <(jq -r '.owns[]' <<<"$output")
    [ "${#owns[@]}" -gt 0 ]

    run --separate-stderr "$RUN" run "$M"
    [ "$status" -eq 0 ]
    verdict_is applied
    local path
    for path in "${owns[@]}"; do
        [ -f "$W/$1/$path" ] || { echo "owned path missing after run: $path"; return 1; }
    done
    local before
    before="$(snapshot "$1")"

    run --separate-stderr "$RUN" run "$M"
    [ "$status" -eq 0 ]
    verdict_is unchanged
    [ "$(field .changed)" = '[]' ]
    [ "$(snapshot "$1")" = "$before" ] || { echo "files changed on the second run"; return 1; }
}

for md in "$ROOT"/examples/usage/*/*.md; do
    name="$(basename "$(dirname "$md")")"
    [ "$md" = "$ROOT/examples/usage/$name/$name.md" ] || continue
    bats_test_function --description "example $name: check is valid" -- example_check "$name"
    bats_test_function --description "example $name: run applies, a second run is unchanged" -- example_run "$name"
done
