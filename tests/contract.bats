#!/usr/bin/env bats
# src/core/contract/argc.sh: relationship contracts, checked by example

bats_require_minimum_version 1.5.0

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    CONTRACT="$BATS_TEST_DIRNAME/../src/core/contract/argc.sh"
    FIXTURES="$BATS_TEST_DIRNAME/fixtures/contract"
}

check() { argc --argc-run "$CONTRACT" check "$@"; }

@test "each valid fixture is valid alone" {
    local f
    for f in "$FIXTURES"/valid/*.md; do
        run check "$f"
        [ "$status" -eq 0 ]
        [ "$(jq -c '[.verdict, .reasons]' <<<"$output")" = '["valid",[]]' ] || { echo "$f: $output"; return 1; }
    done
}

@test "each valid case directory is valid as one call" {
    local d
    for d in "$FIXTURES"/valid/*/; do
        cd "$d"
        run check *.md
        [ "$status" -eq 0 ]
        [ "$(jq -sc 'map(.verdict) | unique' <<<"$output")" = '["valid"]' ] || { echo "$d: $output"; return 1; }
    done
}

@test "each invalid fixture yields exactly its directory's reason" {
    local f reason
    for f in "$FIXTURES"/invalid/*/*.md; do
        reason="$(basename "$(dirname "$f")")"
        run check "$f"
        [ "$status" -eq 0 ]
        [ "$(jq -c '[.verdict, .reasons]' <<<"$output")" = "[\"invalid\",[\"$reason\"]]" ] || { echo "$f: $output"; return 1; }
    done
}

@test "each cross-file case matches its expected.jsonl byte for byte" {
    local d files
    for d in "$FIXTURES"/invalid/*/*/; do
        cd "$d"
        mapfile -t files < <(printf '%s\n' *.md | LC_ALL=C sort)
        run check "${files[@]}"
        [ "$status" -eq 0 ]
        [ "$output" = "$(cat expected.jsonl)" ] || { echo "$d: $output"; return 1; }
    done
}

@test "the same file twice, under two spellings, never conflicts with itself" {
    cd "$FIXTURES/valid"
    run check full.md ./full.md
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = '{"file":"full.md","verdict":"valid","reasons":[]}' ]
    [ "${lines[1]}" = '{"file":"./full.md","verdict":"valid","reasons":[]}' ]
}

@test "verdicts come in argument order, one compact JSON line each" {
    cd "$FIXTURES"
    run check invalid/unknown-key/extra.md valid/minimal.md invalid/no-frontmatter/plain.md
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 3 ]
    [ "$(jq -r .file <<<"${lines[0]}")" = invalid/unknown-key/extra.md ]
    [ "$(jq -r .file <<<"${lines[1]}")" = valid/minimal.md ]
    [ "$(jq -r .file <<<"${lines[2]}")" = invalid/no-frontmatter/plain.md ]
    local line
    for line in "${lines[@]}"; do [ "$(jq -c . <<<"$line")" = "$line" ]; done
}

@test "no arguments is exit 2 with empty stdout" {
    run --separate-stderr check
    [ "$status" -eq 2 ]
    [ -z "$output" ]
    [ -n "$stderr" ]
}

@test "a missing file or a directory is exit 2 with empty stdout" {
    run --separate-stderr check "$FIXTURES/valid/minimal.md" "$FIXTURES/nope.md"
    [ "$status" -eq 2 ]
    [ -z "$output" ]
    run --separate-stderr check "$FIXTURES/valid"
    [ "$status" -eq 2 ]
    [ -z "$output" ]
}

@test "an unreadable file is exit 2 with empty stdout" {
    [ "$(id -u)" -ne 0 ] || skip "root reads everything"
    cp "$FIXTURES/valid/minimal.md" "$BATS_TEST_TMPDIR/locked.md"
    chmod 000 "$BATS_TEST_TMPDIR/locked.md"
    run --separate-stderr check "$BATS_TEST_TMPDIR/locked.md"
    [ "$status" -eq 2 ]
    [ -z "$output" ]
}

@test "missing yq or jq is exit 1, checked before the arguments" {
    local bin="$BATS_TEST_TMPDIR/bin" tool
    mkdir -p "$bin"
    for tool in argc bash env jq; do ln -s "$(command -v "$tool")" "$bin/$tool"; done
    run --separate-stderr env PATH="$bin" argc --argc-run "$CONTRACT" check
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [[ "$stderr" == *yq* ]]
    rm "$bin/jq"
    ln -s "$(command -v yq)" "$bin/yq"
    run --separate-stderr env PATH="$bin" argc --argc-run "$CONTRACT" check "$FIXTURES/valid/minimal.md"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *jq* ]]
}

@test "a check writes nothing and repeats byte for byte" {
    cd "$FIXTURES"
    local before files first
    before="$(find . -printf '%p %s %T@\n' | LC_ALL=C sort)"
    mapfile -t files < <(find valid invalid -maxdepth 2 -name '*.md' | LC_ALL=C sort)
    first="$(check "${files[@]}")"
    [ "$(check "${files[@]}")" = "$first" ]
    [ "$(find . -printf '%p %s %T@\n' | LC_ALL=C sort)" = "$before" ]
}
