#!/usr/bin/env bats
# run with `skogai test run {{name}}`: what it requires first, then its contract and these.

load "$SKOGAI_TEST_HELPER"

@test "{{name}}: hello reads its greeting from config, the env first" {
    run skogai {{name}} hello skogix
    assert_status 0
    assert_output_has "hello, skogix"
    SKOGAI_{{NAME}}_GREETING=hej run skogai {{name}} hello skogix
    assert_output_has "hej, skogix"
}
