#!/usr/bin/env bats
# src/core/log/usage.sh: the read-only reader of the run event log
# (workorder log-reader, docs/evidence.md).

bats_require_minimum_version 1.5.0

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    LOG_CMD="$ROOT/src/core/log/usage.sh"
    FIX="$ROOT/tests/fixtures/log/run.jsonl"
    export HOME="$BATS_TEST_TMPDIR/home" XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    unset SKOGAI_LOG
    mkdir -p "$HOME"
    L="$BATS_TEST_TMPDIR/run.jsonl"
    cp "$FIX" "$L"
}

reader() { run --separate-stderr "$LOG_CMD" "$@"; }

@test "runs: one object per run in first-seen order, interrupted run has null outcome" {
    reader runs --log "$L"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
    [ "$(jq -r .run <<<"${lines[0]}")" = c0de0001-5cfa-471b-b570-61810db65c39 ]
    [ "$(jq -r .run <<<"${lines[1]}")" = c0de0002-5cfa-471b-b570-61810db65c39 ]
    [ "$(jq -r .run <<<"${lines[2]}")" = d00d0003-5cfa-471b-b570-61810db65c39 ]
    [ "$(jq -r .run <<<"${lines[3]}")" = e1e10004-5cfa-471b-b570-61810db65c39 ]
    jq -e '.outcome == "ok" and .verdict == "applied" and .changed == ["greeting.txt"] and .module == "hello"
        and .started == "2026-11-06T15:49:54.214Z" and .ended == "2026-11-06T15:49:54.774Z"' <<<"${lines[0]}"
    jq -e '.outcome == "unchanged" and .verdict == "unchanged" and .changed == []' <<<"${lines[1]}"
    jq -e '.outcome == "rejected" and .verdict == "invalid" and .changed == []' <<<"${lines[2]}"
    jq -e '.ended == null and .outcome == null and .verdict == null and .changed == [] and .started == "2026-11-06T15:49:57.000Z"' <<<"${lines[3]}"
    [ "$(jq -c 'keys_unsorted' <<<"${lines[0]}")" = '["run","module","revision","started","ended","outcome","verdict","changed"]' ]
    [ "$stderr" = "skipped 1 unreadable lines: $L" ]
}

@test "show: a full id prints only that run's lines, byte-identical" {
    reader show --log "$L" c0de0002-5cfa-471b-b570-61810db65c39
    [ "$status" -eq 0 ]
    [ "$stderr" = "skipped 1 unreadable lines: $L" ]
    [ "$output" = "$(grep -F '"run":"c0de0002-5cfa-471b-b570-61810db65c39"' "$L")" ]
    [ "${#lines[@]}" -eq 4 ]
}

@test "show: a unique prefix works" {
    reader show --log "$L" c0de0001
    [ "$status" -eq 0 ]
    [ "$output" = "$(grep -F '"run":"c0de0001-' "$L")" ]
    [ "${#lines[@]}" -eq 4 ]
}

@test "show: unknown id exits 2" {
    reader show --log "$L" nope
    [ "$status" -eq 2 ]
    [ -z "$output" ]
    [[ "$stderr" == *"no such run: nope"* ]]
}

@test "show: ambiguous prefix exits 2" {
    reader show --log "$L" c0de
    [ "$status" -eq 2 ]
    [ -z "$output" ]
    [[ "$stderr" == *"ambiguous run: c0de"* ]]
}

@test "show without a run is a bad argument" {
    reader show --log "$L"
    [ "$status" -ne 0 ]
}

@test "a missing log: empty answer, exit 0, file and parent still missing" {
    reader runs --log "$BATS_TEST_TMPDIR/none/run.jsonl"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$BATS_TEST_TMPDIR/none" ]
    reader runs
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$XDG_STATE_HOME/skogai" ]
}

@test "show on a missing log: no such run, exit 2, nothing created" {
    reader show --log "$BATS_TEST_TMPDIR/none/run.jsonl" x
    [ "$status" -eq 2 ]
    [ ! -e "$BATS_TEST_TMPDIR/none" ]
}

@test "the default path follows XDG_STATE_HOME" {
    mkdir -p "$XDG_STATE_HOME/skogai"
    cp "$FIX" "$XDG_STATE_HOME/skogai/run.jsonl"
    reader runs
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
}

@test "an empty XDG_STATE_HOME falls back to ~/.local/state" {
    mkdir -p "$HOME/.local/state/skogai"
    cp "$FIX" "$HOME/.local/state/skogai/run.jsonl"
    XDG_STATE_HOME="" reader runs
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
}

@test "--log and SKOGAI_LOG override the default; --log wins" {
    mkdir -p "$XDG_STATE_HOME/skogai"
    : >"$XDG_STATE_HOME/skogai/run.jsonl"
    SKOGAI_LOG="$L" reader runs
    [ "${#lines[@]}" -eq 4 ]
    reader runs --log "$L"
    [ "${#lines[@]}" -eq 4 ]
    : >"$BATS_TEST_TMPDIR/empty.jsonl"
    SKOGAI_LOG="$BATS_TEST_TMPDIR/empty.jsonl" reader runs --log "$L"
    [ "${#lines[@]}" -eq 4 ]
}

@test "neither command changes the log's bytes" {
    before="$(sha256sum <"$L")"
    reader runs --log "$L"
    reader show --log "$L" c0de0001
    [ "$(sha256sum <"$L")" = "$before" ]
}

@test "both commands declare effect=read" {
    run grep -c 'cmd .* effect="read"' "$LOG_CMD"
    [ "$output" -eq 2 ]
}
