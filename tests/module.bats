#!/usr/bin/env bats
# module format v1: a module's declaration is a mise config file (<name>.toml),
# and src/core/contract/usage.sh reads it. see docs/module.md.
# usage.sh only: contract/argc.sh is frozen and does not know .toml files.

bats_require_minimum_version 1.5.0

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    unset SKOGAI_LOG
    mkdir -p "$HOME" "$XDG_STATE_HOME"
    FIXTURES="$BATS_TEST_DIRNAME/fixtures/module"
    ROOT="$BATS_TEST_DIRNAME/.."
    CONTRACT="$ROOT/src/core/contract/usage.sh"
}

check() { "$CONTRACT" check "$@"; }

# the files of a case directory, *.md and *.toml together, C-locale sorted
case_files() { printf '%s\n' *.md *.toml 2>/dev/null | grep -v '[*]' | LC_ALL=C sort; }

@test "each valid fixture is valid alone" {
    local f
    for f in "$FIXTURES"/valid/*.toml; do
        run check "$f"
        [ "$status" -eq 0 ]
        [ "$(jq -c '[.verdict, .reasons]' <<<"$output")" = '["valid",[]]' ] || { echo "$f: $output"; return 1; }
    done
}

@test "each valid case directory is valid as one call" {
    local d files
    for d in "$FIXTURES"/valid/*/; do
        cd "$d"
        mapfile -t files < <(case_files)
        run check "${files[@]}"
        [ "$status" -eq 0 ]
        [ "$(jq -sc 'map(.verdict) | unique' <<<"$output")" = '["valid"]' ] || { echo "$d: $output"; return 1; }
    done
}

@test "each invalid fixture yields exactly its directory's reason" {
    local f reason n=0
    for f in "$FIXTURES"/invalid/*/*.toml; do
        reason="$(basename "$(dirname "$f")")"
        run check "$f"
        [ "$status" -eq 0 ]
        [ "$(jq -c '[.verdict, .reasons]' <<<"$output")" = "[\"invalid\",[\"$reason\"]]" ] || { echo "$f: $output"; return 1; }
        n=$((n + 1))
    done
    [ "$n" -gt 30 ]
}

@test "every collected and parse reason has a fixture directory" {
    local r
    for r in invalid-toml no-declaration multiple-declarations not-a-mapping invalid-name name-mismatch \
        unknown-key env-outside-prefix missing-task task-outside-prefix unknown-section wrong-type; do
        [ -d "$FIXTURES/invalid/$r" ] || { echo "no fixture directory for $r"; return 1; }
    done
}

@test "each multi-file case matches its expected.jsonl byte for byte" {
    local d files
    for d in "$FIXTURES"/invalid/*/*/; do
        cd "$d"
        mapfile -t files < <(case_files)
        run check "${files[@]}"
        [ "$status" -eq 0 ]
        [ "$output" = "$(cat expected.jsonl)" ] || { echo "$d: $output"; return 1; }
    done
}

@test "a Hello key in hello.toml is invalid-name and name-mismatch" {
    cd "$FIXTURES/invalid/name-mismatch/upper-key"
    run check hello.toml
    [ "$status" -eq 0 ]
    [ "$(jq -c .reasons <<<"$output")" = '["invalid-name","name-mismatch"]' ]
}

@test "the overlap cases each give their one reason" {
    cd "$FIXTURES/invalid"
    run check no-declaration/skogai-string.toml no-declaration/underscore-string.toml no-declaration/empty.toml \
        multiple-declarations/stem-and-other.toml unknown-key/name-key.toml
    [ "$status" -eq 0 ]
    [ "$(jq -sc 'map(.reasons)' <<<"$output")" = '[["no-declaration"],["no-declaration"],["no-declaration"],["multiple-declarations"],["unknown-key"]]' ]
}

@test "a zero-byte fixture really is zero bytes" {
    [ ! -s "$FIXTURES/invalid/no-declaration/empty.toml" ]
    [ -f "$FIXTURES/invalid/no-declaration/empty.toml" ]
}

@test "only a case-sensitive .toml suffix with a stem is a module" {
    cd "$BATS_TEST_TMPDIR"
    printf -- '---\nname: upper\n---\n' >upper.TOML
    printf -- '---\nname: bare\n---\n' >.toml
    printf -- '---\nname: tomlish\n---\n' >notes.toml.md
    run check upper.TOML .toml notes.toml.md
    [ "$status" -eq 0 ]
    [ "$(jq -sc 'map([.verdict, .reasons])' <<<"$output")" = '[["valid",[]],["valid",[]],["valid",[]]]' ]
}

@test "a .toml file whose content is Markdown frontmatter is invalid-toml" {
    cd "$BATS_TEST_TMPDIR"
    printf -- '---\nname: x\n---\n' >x.toml
    run check x.toml
    [ "$(jq -c .reasons <<<"$output")" = '["invalid-toml"]' ]
}

@test "Markdown and TOML verdicts share one output shape, in argument order" {
    cd "$FIXTURES"
    run check valid/mixed/thing.toml valid/mixed/order.md
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[0]}" = '{"file":"valid/mixed/thing.toml","verdict":"valid","reasons":[]}' ]
    [ "${lines[1]}" = '{"file":"valid/mixed/order.md","verdict":"valid","reasons":[]}' ]
}

@test "a check writes nothing and repeats byte for byte" {
    cd "$FIXTURES"
    local before files first
    before="$(find . -printf '%p %s %T@\n' | LC_ALL=C sort)"
    mapfile -t files < <(find valid invalid -maxdepth 2 -name '*.toml' | LC_ALL=C sort)
    first="$(check "${files[@]}")"
    [ "$(check "${files[@]}")" = "$first" ]
    [ "$(find . -printf '%p %s %T@\n' | LC_ALL=C sort)" = "$before" ]
}

@test "the example module hello is valid" {
    run check "$ROOT/examples/modules/hello/hello.toml"
    [ "$status" -eq 0 ]
    [ "$(jq -c '[.verdict, .reasons]' <<<"$output")" = '["valid",[]]' ]
}

@test "the example module hello runs under an isolated mise, caller env beating the default" {
    command -v mise >/dev/null || skip "mise is not installed"
    local t="$BATS_TEST_TMPDIR" p="$BATS_TEST_TMPDIR/p" out
    mkdir -p "$p/.mise/conf.d" "$t/cfg" "$t/sys" "$t/data" "$t/state" "$t/cache"
    cp "$ROOT/examples/modules/hello/hello.toml" "$p/.mise/conf.d/"
    cd "$p"
    mise_run() {
        env -i PATH="$PATH" HOME="$t/home" MISE_CONFIG_DIR="$t/cfg" MISE_SYSTEM_DIR="$t/sys" \
            MISE_DATA_DIR="$t/data" MISE_STATE_DIR="$t/state" MISE_CACHE_DIR="$t/cache" \
            MISE_TRUSTED_CONFIG_PATHS="$p" "$@" mise run -q hello world
    }
    out="$(mise_run 2>/dev/null)"
    [ "$out" = "hi world" ]
    [ "$(cat greeting.txt)" = "hi world" ]
    rm greeting.txt
    out="$(mise_run SKOGAI_HELLO_GREETING=yo 2>/dev/null)"
    [ "$out" = "yo world" ]
    [ "$(cat greeting.txt)" = "yo world" ]
}
