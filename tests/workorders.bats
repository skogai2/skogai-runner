#!/usr/bin/env bats
# .skogai/workorders/open: the queue must pass the contract checker

bats_require_minimum_version 1.5.0

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    CONTRACT="$ROOT/src/core/contract/argc.sh"
}

@test "every open workorder is valid against the contract checker" {
    cd "$ROOT"
    local files
    shopt -s nullglob
    files=(.skogai/workorders/open/*.md)
    shopt -u nullglob
    [ "${#files[@]}" -gt 0 ] || skip "no open workorders: .skogai/workorders/open has no .md files"
    run --separate-stderr argc --argc-run "$CONTRACT" check "${files[@]}"
    [ "$status" -eq 0 ] || { echo "checker exit $status: $stderr"; return 1; }
    local bad
    bad="$(jq -c 'select(.verdict != "valid")' <<<"$output")"
    [ -z "$bad" ] || { echo "non-valid workorders:"; echo "$bad"; return 1; }
    [ "$(wc -l <<<"$output")" -eq "${#files[@]}" ]
}
