#!/usr/bin/env bats
# test's own behaviour: run and closure.

load "$SKOGAI_TEST_HELPER"

# fixture <name> <requires> <test body>: a module with one test of its own
testee() {
    fixture "$1" <<<$'---\ntype: module\nname: '"$1"$'\ndescription: x\nrequires: ['"$2"$']\n---'
    mkdir "$FIX/$1/tests"
    printf 'load "$SKOGAI_TEST_HELPER"\n@test "%s: own" { %s; }\n' "$1" "$3" >"$FIX/$1/tests/$1.bats"
}

@test "run: a failing test fails the run, --filter picks tests, an unknown module fails" {
    fixture flaky <<<$'---\ntype: module\nname: flaky\ndescription: one test fails\nrequires: [core]\n---'
    mkdir "$FIX/flaky/tests"
    cat >"$FIX/flaky/tests/flaky.bats" <<'BATS'
load "$SKOGAI_TEST_HELPER"
@test "flaky: passes" { true; }
@test "flaky: fails" { false; }
BATS
    run skogai test run flaky --only
    assert_status 1
    assert_output_has "not ok"
    assert_output_has "flaky: fails"
    run skogai test run flaky --only --filter "^flaky: passes"
    assert_status 0
    refute_output_has "contract:"
    run skogai test run nosuch
    assert_status 1
    assert_output_has "invalid value `nosuch`"
}

@test "closure: what a module requires comes first, each once" {
    run skogai test closure test
    assert_status 0
    [[ $output == $'core\nsandbox\ntest' ]]
    testee base "" true
    testee mid base true
    testee top "mid, base" true
    run skogai test closure top mid
    [[ $output == $'base\nmid\ntop' ]]
}

@test "closure: a cycle is cut where it closes" {
    testee ping pong true
    testee pong ping true
    run skogai test closure ping
    assert_status 0
    [[ $output == $'pong\nping' ]]
}

@test "run: what it requires is tested first; a failed requirement skips the module" {
    testee base "" true
    testee top base true
    run skogai test run top --filter "^(base|top): "
    assert_status 0
    [[ $output == *"base: own"*"top: own"* ]]
    testee broke "" false
    testee after broke true
    run skogai test run after --filter "^(broke|after): "
    assert_status 1
    assert_output_has "after: skipped, broke failed"
    refute_output_has "after: own"
}
