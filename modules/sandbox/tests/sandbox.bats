#!/usr/bin/env bats
# sandbox's own behaviour: new, and the run it leaves.

load "$SKOGAI_TEST_HELPER"

@test "sandbox: every module installed, skogai built, env lines into it" {
    fixture lonely <<<$'---\ntype: module\nname: lonely\ndescription: only found, no command\nrequires: [core]\n---'
    skogai module add "$FIX/lonely" --to global --apply >/dev/null 2>&1
    rm -rf "$FIX/lonely"
    S="$BATS_TEST_TMPDIR/sb"
    run --separate-stderr skogai sandbox new "$S" --shell bash
    assert_status 0
    assert_output_has "export SKOGAI_CONFIG_DIR=$S/global"
    assert_output_has "export SKOGAI_LOCAL_DIR=$S/repo/.skogai"
    assert_output_has "export PATH=$S/repo/.skogai/tmp/skogai/bin:"
    assert_output_has "cd $S/repo"
    assert_file "$S/repo/.skogai/modules/config/module.md"
    assert_file "$S/repo/.skogai/modules/lonely/module.md"
    eval "$output"
    run skogai module ls
    assert_output_has "config       local"
    refute_output_has source
}

@test "sandbox: replaces an earlier sandbox, refuses any other dir" {
    S="$BATS_TEST_TMPDIR/sb"
    skogai sandbox new "$S" >/dev/null 2>&1
    touch "$S/repo/leftover"
    run skogai sandbox new "$S"
    assert_status 0
    [[ ! -e $S/repo/leftover ]]
    mkdir -p "$BATS_TEST_TMPDIR/other"
    run skogai sandbox new "$BATS_TEST_TMPDIR/other"
    assert_status 2
}

@test "sandbox: run runs one command inside it, state kept between runs" {
    S="$BATS_TEST_TMPDIR/sb"
    skogai sandbox new "$S" >/dev/null 2>&1
    run env SKOGAI_CORE_MODULE_INSTALL=leak "$S/run" skogai config get core.module.install --show-origin
    assert_output_has "module:core	local"
    run "$S/run" pwd
    assert_output_has "$S/repo"
    "$S/run" skogai config set core.module.install global
    run "$S/run" skogai config get core.module.install --show-origin
    assert_output_has "$S/repo/skogai.toml	global"
}

@test "sandbox: without a dir it is tmp/sandbox in the local dir, one per repo" {
    run --separate-stderr skogai sandbox new --empty --shell bash
    assert_status 0
    assert_output_has "export SKOGAI_LOCAL_DIR=$LOCAL/tmp/sandbox/repo/.skogai"
    assert_file "$LOCAL/tmp/sandbox/.sandbox"
}
