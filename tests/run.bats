#!/usr/bin/env bats
# src/core/run/argc.sh: check and run one module, writable scope enforced by
# a read-only podman mount and a staged output dir (F002)
# RUN_IMPL=usage runs the same tests against its usage twin, run/usage.sh, with
# the usage example and fixtures (examples/usage/, tests/fixtures/run-usage/)

bats_require_minimum_version 1.5.0

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    case "${RUN_IMPL:-argc}" in
    argc)
        RUN="$ROOT/src/core/run/argc.sh"
        RUNNER=(argc --argc-run "$RUN")
        FIX="$ROOT/tests/fixtures/run"
        EX="$ROOT/examples/hello"
        ;;
    usage)
        RUN="$ROOT/src/core/run/usage.sh"
        RUNNER=("$RUN")
        FIX="$ROOT/tests/fixtures/run-usage"
        EX="$ROOT/examples/usage/hello"
        ;;
    *) echo "unknown RUN_IMPL: $RUN_IMPL" >&2; return 1 ;;
    esac
    # rootless podman keeps its images under the data dir; keep that, isolate the rest
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    export HOME="$BATS_TEST_TMPDIR/home" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/home/.config"
    export TMPDIR="$BATS_TEST_TMPDIR/tmp"
    mkdir -p "$HOME" "$TMPDIR"
    W="$BATS_TEST_TMPDIR/work"
    mkdir -p "$W"
}

# copy a fixture (or the example) into the test dir; prints the module path
copy() {
    local src="$1" name
    name="$(basename "$src")"
    cp -a "$src" "$W/$name"
    printf '%s\n' "$W/$name/$name.md"
}

needs_podman() {
    command -v podman >/dev/null || skip "podman not on PATH"
}

check() { run --separate-stderr "${RUNNER[@]}" check "$@"; }
runmod() { run --separate-stderr "${RUNNER[@]}" run "$@"; }

one_json_line() {
    [ "$(printf '%s\n' "$output" | wc -l)" -eq 1 ]
    jq -ce . <<<"$output" >/dev/null
}

field() { jq -c "$1" <<<"$output"; }

reasons_are() { [ "$(field .reasons)" = "$1" ] || { echo "reasons: $(field .reasons), want $1"; return 1; }; }

# a PATH holding only the tools the runner needs, plus optional extra dirs first
tool_path() {
    local bin="$BATS_TEST_TMPDIR/bin-$1" tool
    shift
    mkdir -p "$bin"
    for tool in argc usage jq yq bash env cat mkdir mktemp rm mv cp cmp find sort ln readlink realpath dirname basename chmod stat; do
        local p
        p="$(command -v "$tool" 2>/dev/null)" && ln -sf "$p" "$bin/$tool"
    done
    printf '%s\n' "$bin"
}

# --- check -------------------------------------------------------------------

@test "check: the hello example is valid" {
    m="$(copy "$EX")"
    check "$m"
    [ "$status" -eq 0 ]
    one_json_line
    [ "$(field .verdict)" = '"valid"' ]
    reasons_are '[]'
    [ "$(field '[.name,.command,.owns,.writes,.f001,.image]')" = '["hello","hello.sh",["greeting.txt"],["greeting.txt"],[],"skogai-runner-dev"]' ]
    [ "$(field 'keys')" = '["command","f001","image","module","name","owns","reasons","verdict","writes"]' ]
}

@test "check: an F001 reason is the only reason, copied into f001" {
    m="$(copy "$FIX/badmeta")"
    check "$m"
    [ "$status" -eq 0 ]
    one_json_line
    [ "$(field .verdict)" = '"invalid"' ]
    reasons_are '["invalid-declaration"]'
    [ "$(field .f001)" = '["unknown-key"]' ]
    [ "$(field '[.name,.command,.owns,.writes]')" = '["badmeta","badmeta.sh",[],[]]' ]
}

@test "check: an invalid name gives null name and command" {
    mkdir -p "$W/x"
    printf -- '---\nname: Bad_Name\nowns: [o]\n---\n' >"$W/x/x.md"
    check "$W/x/x.md"
    [ "$status" -eq 0 ]
    reasons_are '["invalid-declaration"]'
    [ "$(field '[.name,.command]')" = '[null,null]' ]
}

@test "check: depends_on makes the declaration invalid" {
    m="$(copy "$EX")"
    printf -- '---\nname: hello\ndepends_on: [other]\nowns: [greeting.txt]\n---\n' >"$m"
    check "$m"
    reasons_are '["invalid-declaration"]'
    [ "$(field .f001)" = '["missing-dependency"]' ]
}

@test "check: missing-command" {
    m="$(copy "$FIX/nocmd")"
    check "$m"
    [ "$status" -eq 0 ]
    reasons_are '["missing-command"]'
}

@test "check: invalid-command" {
    m="$(copy "$FIX/badcmd")"
    check "$m"
    reasons_are '["invalid-command"]'
}

@test "check: no-owns" {
    m="$(copy "$FIX/noowns")"
    check "$m"
    reasons_are '["no-owns"]'
}

@test "check: target-dir-missing" {
    m="$(copy "$FIX/nodir")"
    check "$m"
    reasons_are '["target-dir-missing"]'
}

@test "check: target-is-symlink, on the target and on a parent" {
    m="$(copy "$EX")"
    ln -s /etc/hostname "$W/hello/greeting.txt"
    check "$m"
    reasons_are '["target-is-symlink"]'
    m="$(copy "$FIX/nodir")"
    ln -s "$BATS_TEST_TMPDIR" "$W/nodir/sub"
    check "$m"
    reasons_are '["target-is-symlink"]'
}

@test "check: target-not-regular-file" {
    m="$(copy "$EX")"
    mkdir "$W/hello/greeting.txt"
    check "$m"
    reasons_are '["target-not-regular-file"]'
}

@test "check: dir-contains-home" {
    m="$(copy "$EX")"
    HOME="$W/hello" check "$m"
    reasons_are '["dir-contains-home"]'
    HOME="$W/hello/deeper" check "$m"
    reasons_are '["dir-contains-home"]'
}

@test "check: reasons are collected, sorted and unique" {
    m="$(copy "$FIX/nodir")"
    rm "$W/nodir/nodir.sh"
    check "$m"
    reasons_are '["missing-command","target-dir-missing"]'
}

@test "check: writes nothing and repeats byte-identically" {
    m="$(copy "$EX")"
    before="$(find "$W" -printf '%p %s %T@\n' | sort)"
    check "$m"; first="$output"
    [ "$status" -eq 0 ] && [ "$(field .verdict)" = '"valid"' ]
    check "$m"
    [ "$output" = "$first" ]
    [ "$(find "$W" -printf '%p %s %T@\n' | sort)" = "$before" ]
}

@test "check and run: exit 2 on bad arguments, empty stdout" {
    m="$(copy "$EX")"
    for cmd in check run; do
        run --separate-stderr "${RUNNER[@]}" "$cmd"
        [ "$status" -eq 2 ] && [ -z "$output" ]
        run --separate-stderr "${RUNNER[@]}" "$cmd" "$m" "$m"
        [ "$status" -eq 2 ] && [ -z "$output" ]
        run --separate-stderr "${RUNNER[@]}" "$cmd" "$W/missing.md"
        [ "$status" -eq 2 ] && [ -z "$output" ] && [ -n "$stderr" ]
        run --separate-stderr "${RUNNER[@]}" "$cmd" "$W"
        [ "$status" -eq 2 ] && [ -z "$output" ]
    done
}

@test "check and run: exit 2 on an unreadable module" {
    [ "$(id -u)" -ne 0 ] || skip "root reads everything"
    m="$(copy "$EX")"
    chmod 000 "$m"
    for cmd in check run; do
        run --separate-stderr "${RUNNER[@]}" "$cmd" "$m"
        [ "$status" -eq 2 ] && [ -z "$output" ]
    done
}

@test "check and run: exit 1 when jq is missing, before arguments" {
    bin="$(tool_path nojq)"
    rm "$bin/jq"
    for cmd in check run; do
        PATH="$bin" run --separate-stderr "${RUNNER[@]}" "$cmd"
        [ "$status" -eq 1 ] && [ -z "$output" ] && [[ "$stderr" == *jq* ]]
    done
}

@test "check: does not need podman" {
    m="$(copy "$EX")"
    bin="$(tool_path nopodman)"
    PATH="$bin" run --separate-stderr "${RUNNER[@]}" check "$m"
    [ "$status" -eq 0 ]
    [ "$(field .verdict)" = '"valid"' ]
}

# --- run without real podman -------------------------------------------------

@test "run: a rejected declaration never invokes podman" {
    m="$(copy "$FIX/badmeta")"
    bin="$(tool_path stub)"
    log="$BATS_TEST_TMPDIR/podman.log"
    : >"$log"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>%q\n' "$log" >"$bin/podman"
    chmod +x "$bin/podman"
    PATH="$bin" run --separate-stderr "${RUNNER[@]}" run "$m"
    [ "$status" -eq 3 ]
    one_json_line
    [ "$(field .verdict)" = '"rejected"' ]
    reasons_are '["invalid-declaration"]'
    [ "$(field '[.f001,.changed]')" = '[["unknown-key"],[]]' ]
    [ "$(field 'keys')" = '["changed","f001","module","name","reasons","verdict"]' ]
    [ ! -s "$log" ]
}

@test "run: exit 1 without podman on PATH" {
    m="$(copy "$EX")"
    bin="$(tool_path nopodman)"
    PATH="$bin" run --separate-stderr "${RUNNER[@]}" run "$m"
    [ "$status" -eq 1 ] && [ -z "$output" ] && [[ "$stderr" == *podman* ]]
    [ ! -e "$W/hello/greeting.txt" ]
}

# --- run with podman ---------------------------------------------------------

@test "run: exit 1 when the image is missing" {
    needs_podman
    m="$(copy "$EX")"
    SKOGAI_IMAGE=skogai-no-such-image-f002 runmod "$m"
    [ "$status" -eq 1 ] && [ -z "$output" ]
    [[ "$stderr" == *skogai-no-such-image-f002* && "$stderr" == *"mise run image"* ]]
}

@test "run: hello is applied, then unchanged with mtime preserved" {
    needs_podman
    m="$(copy "$EX")"
    runmod "$m"
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    one_json_line
    [ "$(field '[.verdict,.reasons,.changed]')" = '["applied",[],["greeting.txt"]]' ]
    [ "$(cat "$W/hello/greeting.txt")" = "hello from a staged module" ]
    touch -d '2001-01-01' "$W/hello/greeting.txt"
    before="$(stat -c '%Y %a' "$W/hello/greeting.txt")"
    runmod "$m"
    [ "$status" -eq 0 ]
    [ "$(field '[.verdict,.changed]')" = '["unchanged",[]]' ]
    [ "$(stat -c '%Y %a' "$W/hello/greeting.txt")" = "$before" ]
    [ -z "$(ls -A "$TMPDIR")" ]
}

@test "run: an existing target keeps its mode when replaced" {
    needs_podman
    m="$(copy "$EX")"
    printf old >"$W/hello/greeting.txt"
    chmod 0640 "$W/hello/greeting.txt"
    runmod "$m"
    [ "$(field .verdict)" = '"applied"' ]
    [ "$(stat -c '%a' "$W/hello/greeting.txt")" = 640 ]
}

@test "run: command-failed" {
    needs_podman
    m="$(copy "$FIX/fails")"
    runmod "$m"
    [ "$status" -eq 3 ]
    [ "$(field '[.verdict,.reasons,.changed]')" = '["rejected",["command-failed"],[]]' ]
    [ ! -e "$W/fails/out.txt" ]
    [ -z "$(ls -A "$TMPDIR")" ]
}

@test "run: output-outside-owns leaves the module dir byte-identical" {
    needs_podman
    m="$(copy "$FIX/outside")"
    before="$(find "$W/outside" -printf '%p %s %T@\n' | sort)"
    runmod "$m"
    [ "$status" -eq 3 ]
    [ "$(field '[.verdict,.reasons,.changed]')" = '["rejected",["output-outside-owns"],[]]' ]
    [ "$(find "$W/outside" -printf '%p %s %T@\n' | sort)" = "$before" ]
    [ -z "$(ls -A "$TMPDIR")" ]
}

@test "run: output-not-regular-file for a staged symlink" {
    needs_podman
    m="$(copy "$FIX/linkout")"
    runmod "$m"
    [ "$status" -eq 3 ]
    reasons_are '["output-not-regular-file"]'
    [ ! -e "$W/linkout/out.txt" ] && [ ! -L "$W/linkout/out.txt" ]
}

@test "run: missing-output" {
    needs_podman
    m="$(copy "$FIX/nooutput")"
    runmod "$m"
    [ "$status" -eq 3 ]
    reasons_are '["missing-output"]'
}

@test "run: a write to /work cannot reach the module dir" {
    needs_podman
    m="$(copy "$FIX/sneaky")"
    runmod "$m"
    [ "$status" -eq 0 ] || { echo "$stderr"; return 1; }
    [ "$(field .changed)" = '["out.txt"]' ]
    [ ! -e "$W/sneaky/sneaky.txt" ]
    [ ! -e "$TMPDIR/sneaky.txt" ]
}

@test "run: apply-failed lists only the files applied before the failure" {
    needs_podman
    [ "$(id -u)" -ne 0 ] || skip "root writes into read-only dirs"
    m="$(copy "$FIX/two")"
    chmod 0555 "$W/two/sub"
    runmod "$m"
    chmod 0755 "$W/two/sub"
    [ "$status" -eq 3 ]
    [ "$(field '[.verdict,.reasons,.changed]')" = '["rejected",["apply-failed"],["a.txt"]]' ]
    [ "$(cat "$W/two/a.txt")" = a ]
    [ ! -e "$W/two/sub/b.txt" ]
    [ -z "$(find "$W/two" -name '.*' -newer "$m" ! -name .keep)" ]
    [ -z "$(ls -A "$TMPDIR")" ]
}

@test "run: two owned files are both applied" {
    needs_podman
    m="$(copy "$FIX/two")"
    runmod "$m"
    [ "$status" -eq 0 ]
    [ "$(field '[.verdict,.changed]')" = '["applied",["a.txt","sub/b.txt"]]' ]
}
