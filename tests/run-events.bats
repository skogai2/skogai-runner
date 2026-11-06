#!/usr/bin/env bats
# src/core/run/usage.sh: the JSONL event log (workorder run-events,
# docs/evidence.md). stdout and exit codes are covered by tests/run.bats.

bats_require_minimum_version 1.5.0

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    RUN="$ROOT/src/core/run/usage.sh"
    FIX="$ROOT/tests/fixtures/run-usage"
    EX="$ROOT/examples/usage/hello"
    # rootless podman keeps its images under the data dir; keep that, isolate the rest
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    export HOME="$BATS_TEST_TMPDIR/home" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/home/.config"
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    export SKOGAI_LOG="$BATS_TEST_TMPDIR/log/run.jsonl"
    export TMPDIR="$BATS_TEST_TMPDIR/tmp"
    mkdir -p "$HOME" "$TMPDIR"
    W="$BATS_TEST_TMPDIR/work"
    mkdir -p "$W"
}

copy() {
    local src="$1" name
    name="$(basename "$src")"
    cp -a "$src" "$W/$name"
    printf '%s\n' "$W/$name/$name.md"
}

needs_podman() {
    command -v podman >/dev/null || skip "podman not on PATH"
}

runner() { run --separate-stderr "$RUN" "$@"; }

# the events of one run id, or of the whole log, as compact JSON
events() { jq -c "${1:-.}" "$SKOGAI_LOG"; }
names() { jq -r .event "$SKOGAI_LOG" | paste -sd' '; }
last_run() { jq -r .run "$SKOGAI_LOG" | tail -n 1; }
of_run() { jq -c --arg run "$1" "select(.run == \$run) | ${2:-.}" "$SKOGAI_LOG"; }

# every line carries the envelope with a well-formed ts, id, run and outcome
envelope_ok() {
    jq -e -s '
        all(.[];
            (.ts | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z$"))
            and (.event | IN("check", "exec", "apply", "end"))
            and (.input | type == "object")
            and (.id | type == "string") and (.run | type == "string")
            and has("module") and has("revision")
            and (.outcome | IN("ok", "rejected", "failed", "unchanged"))
            and ((has("action") | not) or (.action | type == "string" and length > 0)))
        and ([.[].id] | length == (unique | length))' "$SKOGAI_LOG" >/dev/null
}

# nothing in the log names the module dir, HOME or the test tree
no_absolute_paths() {
    ! grep -qF -- "$BATS_TEST_TMPDIR" "$SKOGAI_LOG"
}

# --- without podman ----------------------------------------------------------

@test "events: check logs check and end, with the stdout verdict" {
    m="$(copy "$EX")"
    runner check "$m"
    [ "$status" -eq 0 ]
    [ "$(names)" = "check end" ]
    envelope_ok
    no_absolute_paths
    [ "$(events 'select(.event == "check") | [.outcome, .input]')" = '["ok",{"file":"hello.md","verdict":"valid","reasons":[],"f001":[]}]' ]
    [ "$(events 'select(.event == "end") | .input')" = "$(jq -c '.module = "hello.md"' <<<"$output")" ]
    [ "$(events 'select(.event == "end") | [.outcome, has("action")]')" = '["ok",false]' ]
    [ "$(jq -r .run "$SKOGAI_LOG" | sort -u | wc -l)" -eq 1 ]
    [ "$(events '.module' | sort -u)" = '"hello"' ]
}

@test "events: revision is the sha256 of sha256sum over the .md and .sh" {
    m="$(copy "$EX")"
    runner check "$m"
    want="$(cd "$W/hello" && sha256sum hello.md hello.sh | sha256sum)"
    [ "$(jq -r .revision "$SKOGAI_LOG" | sort -u)" = "${want%% *}" ]
    printf '\n' >>"$W/hello/hello.sh"
    runner check "$m"
    [ "$(jq -r .revision "$SKOGAI_LOG" | sort -u | wc -l)" -eq 2 ]
}

@test "events: a declaration rejected at check time logs check and end only" {
    m="$(copy "$FIX/badmeta")"
    runner run "$m"
    [ "$status" -eq 3 ]
    [ "$(names)" = "check end" ]
    envelope_ok
    [ "$(events '[.event, .outcome]' | paste -sd' ')" = '["check","rejected"] ["end","rejected"]' ]
    [ "$(events 'select(.event == "check") | .input | [.verdict, .reasons, .f001]')" = '["invalid",["invalid-declaration"],["unknown-key"]]' ]
    [ "$(events 'select(.event == "end") | .input')" = "$(jq -c '.module = "badmeta.md"' <<<"$output")" ]
}

@test "events: --log and SKOGAI_LOG name the log; XDG_STATE_HOME, then HOME, is the default" {
    m="$(copy "$EX")"
    before="$(find "$W" -printf '%p %s %T@\n' | sort)"
    runner --log "$BATS_TEST_TMPDIR/flag/a.jsonl" check "$m"
    [ "$status" -eq 0 ] && [ "$(wc -l <"$BATS_TEST_TMPDIR/flag/a.jsonl")" -eq 2 ]
    [ ! -e "$SKOGAI_LOG" ]
    runner check "$m"
    [ "$(wc -l <"$SKOGAI_LOG")" -eq 2 ]
    unset SKOGAI_LOG
    runner check "$m"
    [ "$status" -eq 0 ] && [ "$(wc -l <"$XDG_STATE_HOME/skogai/run.jsonl")" -eq 2 ]
    unset XDG_STATE_HOME
    runner check "$m"
    [ "$status" -eq 0 ] && [ "$(wc -l <"$HOME/.local/state/skogai/run.jsonl")" -eq 2 ]
    [ "$(find "$W" -printf '%p %s %T@\n' | sort)" = "$before" ]
}

@test "events: an unwritable log stops check and run with exit 1 before any effect" {
    [ "$(id -u)" -ne 0 ] || skip "root writes everywhere"
    m="$(copy "$EX")"
    mkdir -p "$BATS_TEST_TMPDIR/ro"
    chmod 0555 "$BATS_TEST_TMPDIR/ro"
    before="$(find "$W" -printf '%p %s %T@\n' | sort)"
    for log in "$BATS_TEST_TMPDIR/ro/run.jsonl" "$BATS_TEST_TMPDIR/ro/sub/run.jsonl"; do
        for cmd in check run; do
            SKOGAI_LOG="$log" runner "$cmd" "$m"
            [ "$status" -eq 1 ] && [ -z "$output" ] && [[ "$stderr" == *"cannot append to log"* ]]
        done
    done
    chmod 0755 "$BATS_TEST_TMPDIR/ro"
    [ -z "$(ls -A "$BATS_TEST_TMPDIR/ro")" ]
    [ "$(find "$W" -printf '%p %s %T@\n' | sort)" = "$before" ]
    [ ! -e "$W/hello/greeting.txt" ]
    [ -z "$(ls -A "$TMPDIR")" ]
}

@test "events: a log that is a directory stops the run with exit 1" {
    m="$(copy "$EX")"
    mkdir -p "$SKOGAI_LOG"
    runner run "$m"
    [ "$status" -eq 1 ] && [ -z "$output" ]
    [ ! -e "$W/hello/greeting.txt" ]
}

# --- with podman -------------------------------------------------------------

@test "events: hello twice: applied then unchanged, two run ids, append-only" {
    needs_podman
    m="$(copy "$EX")"
    runner run "$m"
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    first="$(cat "$SKOGAI_LOG")"
    run1="$(last_run)"
    [ "$(names)" = "check exec apply end" ]
    [ "$(of_run "$run1" 'select(.event == "exec") | [.outcome, .input]')" = '["ok",{"exit":0,"image":"skogai-runner-dev","staged":["greeting.txt"],"missing":[]}]' ]
    [ "$(of_run "$run1" 'select(.event == "apply") | [.outcome, .action, .input]')" = '["ok","applied greeting.txt",{"path":"greeting.txt"}]' ]
    [ "$(of_run "$run1" 'select(.event == "end") | [.outcome, .action, .input.verdict, .input.changed]')" = '["ok","applied greeting.txt","applied",["greeting.txt"]]' ]

    runner run "$m"
    [ "$status" -eq 0 ]
    run2="$(last_run)"
    [ "$run1" != "$run2" ]
    [ "$(wc -l <"$SKOGAI_LOG")" -eq 8 ]
    [ "$(head -n 4 "$SKOGAI_LOG")" = "$first" ]
    [ "$(of_run "$run2" '.event' | paste -sd' ')" = '"check" "exec" "apply" "end"' ]
    [ "$(of_run "$run2" 'select(.event == "apply") | [.outcome, has("action"), .input]')" = '["unchanged",false,{"path":"greeting.txt"}]' ]
    [ "$(of_run "$run2" 'select(.event == "end") | [.outcome, has("action"), .input.verdict]')" = '["unchanged",false,"unchanged"]' ]
    [ "$(of_run "$run2" 'select(.event == "end") | .input')" = "$(jq -c '.module = "hello.md"' <<<"$output")" ]
    envelope_ok
    no_absolute_paths
}

@test "events: a failed command is explained by its exec exit code" {
    needs_podman
    m="$(copy "$FIX/fails")"
    runner run "$m"
    [ "$status" -eq 3 ]
    [ "$(names)" = "check exec end" ]
    [ "$(events 'select(.event == "exec") | [.outcome, .input.exit]')" = '["failed",4]' ]
    [ "$(events 'select(.event == "end") | [.outcome, .input.verdict, .input.reasons]')" = '["rejected","rejected",["command-failed"]]' ]
    envelope_ok
}

@test "events: an output outside owns is named, and nothing else was applied" {
    needs_podman
    m="$(copy "$FIX/outside")"
    runner run "$m"
    [ "$status" -eq 3 ]
    [ "$(names)" = "check exec apply apply end" ]
    [ "$(events 'select(.event == "exec") | .input.staged')" = '["extra.txt","out.txt"]' ]
    [ "$(events 'select(.event == "apply") | [.outcome, .input.path, .input.reason]' | paste -sd' ')" = '["rejected","extra.txt","output-outside-owns"] ["rejected","out.txt","not-applied"]' ]
    [ "$(events 'select(has("action"))')" = "" ]
    [ "$(events 'select(.event == "end") | .input.reasons')" = '["output-outside-owns"]' ]
    envelope_ok
    no_absolute_paths
}

@test "events: missing-output names the missing path in exec" {
    needs_podman
    m="$(copy "$FIX/nooutput")"
    runner run "$m"
    [ "$status" -eq 3 ]
    [ "$(events 'select(.event == "exec") | .input.missing | length')" -eq 1 ]
    [ "$(events 'select(.event == "end") | .input.reasons')" = '["missing-output"]' ]
}

@test "events: apply-failed: one applied, one failed, end carries the partial effect" {
    needs_podman
    [ "$(id -u)" -ne 0 ] || skip "root writes into read-only dirs"
    m="$(copy "$FIX/two")"
    chmod 0555 "$W/two/sub"
    runner run "$m"
    chmod 0755 "$W/two/sub"
    [ "$status" -eq 3 ]
    [ "$(events 'select(.event == "apply") | [.outcome, .input.path, (.input.reason // null)]' | paste -sd' ')" = '["ok","a.txt",null] ["failed","sub/b.txt","apply-failed"]' ]
    [ "$(events 'select(.event == "end") | [.outcome, .action]')" = '["rejected","applied a.txt"]' ]
}

@test "events: a torn last line is ended, kept as is, and named on stderr" {
    m="$(copy "$EX")"
    mkdir -p "$(dirname "$SKOGAI_LOG")"
    printf '{"ts":"2026' >"$SKOGAI_LOG"
    runner check "$m"
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"log had a partial last line, ended it: $SKOGAI_LOG"* ]]
    [ "$(head -n 1 "$SKOGAI_LOG")" = '{"ts":"2026' ]
    [ "$(wc -l <"$SKOGAI_LOG")" -eq 3 ]
    tail -n +2 "$SKOGAI_LOG" | jq -e . >/dev/null
    [ "$(tail -n +2 "$SKOGAI_LOG" | jq -r .event | paste -sd' ')" = "check end" ]
}

@test "events: a repaired log gets no second newline" {
    m="$(copy "$EX")"
    mkdir -p "$(dirname "$SKOGAI_LOG")"
    printf '{"ts":"2026' >"$SKOGAI_LOG"
    runner check "$m"
    runner check "$m"
    [ "$status" -eq 0 ]
    [[ "$stderr" != *"partial last line"* ]]
    [ "$(grep -c '^$' "$SKOGAI_LOG" || true)" -eq 0 ]
    [ "$(wc -l <"$SKOGAI_LOG")" -eq 5 ]
}

@test "events: a log ending in a newline is untouched and silent" {
    m="$(copy "$EX")"
    mkdir -p "$(dirname "$SKOGAI_LOG")"
    printf '{"old":1}\n' >"$SKOGAI_LOG"
    runner check "$m"
    [ "$status" -eq 0 ]
    [[ "$stderr" != *"partial last line"* ]]
    [ "$(head -n 1 "$SKOGAI_LOG")" = '{"old":1}' ]
    [ "$(wc -l <"$SKOGAI_LOG")" -eq 3 ]
}

@test "events: a missing image ends the run as failed with the message" {
    needs_podman
    m="$(copy "$EX")"
    SKOGAI_IMAGE=skogai-no-such-image-events runner run "$m"
    [ "$status" -eq 1 ] && [ -z "$output" ]
    [ "$(names)" = "check end" ]
    [ "$(events 'select(.event == "end") | [.outcome, .input.exit]')" = '["failed",1]' ]
    [[ "$(events 'select(.event == "end") | .input.error')" == *skogai-no-such-image-events* ]]
}
