#!/usr/bin/env bats
# core's own behaviour: the module commands, defaults and env.

load "$SKOGAI_TEST_HELPER"

# a module source dir of our own, first on the path
fixture() {
    FIX="$BATS_TEST_TMPDIR/sources"
    export SKOGAI_MODULE_PATH="$FIX:$SKOGAI_MODULE_PATH"
    mkdir -p "$FIX/$1"
    cat >"$FIX/$1/module.md"
}

@test "module defaults: every config: default, mounted under its module's name" {
    run skogai module defaults core
    assert_status 0
    assert_output_has "core.module.install	local"
}

@test "module ls: a source module is listed as source" {
    run skogai module ls
    assert_status 0
    assert_output_has "core         source"
}

@test "module add: a changed installed file is kept, diff shows it" {
    skogai module add core --apply >/dev/null 2>&1
    echo extra >>"$LOCAL/modules/core/module.md"
    run skogai module add core --apply
    assert_status 0
    assert_output_has "keep  module.md"
    [[ $(tail -1 "$LOCAL/modules/core/module.md") == extra ]]
    run skogai module diff core
    assert_status 1
    assert_output_has "+extra"
}

@test "module add: --to global installs into the global dir" {
    run skogai module add core --to global --apply
    assert_status 0
    assert_file "$SKOGAI_CONFIG_DIR/modules/core/module.md"
}

@test "module add: core.module.install picks the default target" {
    SKOGAI_CORE_MODULE_INSTALL=global skogai module add core --apply >/dev/null 2>&1
    assert_file "$SKOGAI_CONFIG_DIR/modules/core/module.md"
}

@test "module add: an unknown source is a usage error" {
    run skogai module add nosuchmodule
    assert_status 2
}

@test "module new: scaffolds a module that passes its own tests" {
    run skogai module new greet "says hello"
    assert_status 0
    assert_file "$LOCAL/modules/greet/tests/greet.bats"
    run skogai module check greet
    assert_status 0
    run skogai greet hello skogix
    assert_output_has "hello, skogix"
    SKOGAI_GREET_GREETING=hej run skogai greet hello skogix
    assert_output_has "hej, skogix"
}

@test "module new: refuses reserved, bad and existing names" {
    run skogai module new module x
    assert_status 2
    run skogai module new Bad x
    assert_status 2
    skogai module new greet x 2>/dev/null
    run skogai module new greet x
    assert_status 2
}

@test "module check: reports every spec problem" {
    fixture bad <<'MD'
---
type: module
name: Bad
description: x
command: nope.sh
files: a
requires: [ghost]
tools: [nosuchtool]
foo: 1
---
MD
    run skogai module check "$FIX/bad"
    assert_status 1
    assert_output_has "name is not the directory name"
    assert_output_has "command nope.sh is missing"
    assert_output_has "files is not a list"
    assert_output_has "does not require core"
    assert_output_has "requires ghost, not found"
    assert_output_has "warn	tool nosuchtool not on PATH"
    assert_output_has "warn	unknown field foo"
}

@test "module: a local module shadows its source" {
    skogai module add core --apply >/dev/null 2>&1
    run skogai module ls
    assert_output_has "core         local"
}

@test "dispatch: a module command gets its env" {
    fixture envy <<'MD'
---
type: module
name: envy
description: prints its env
command: argc.sh
requires: [core]
config:
  some-key: v
---
MD
    cat >"$FIX/envy/argc.sh" <<'SH'
#!/usr/bin/env bash
# @cmd
show() { env | grep '^SKOGAI_' | grep -v 'PATH\|BIN' | sort; }
eval "$(argc --argc-eval "$0" "$@")"
SH
    run skogai envy show
    assert_status 0
    assert_output_has "SKOGAI_MODULE=envy"
    assert_output_has "SKOGAI_MODULE_DIR=$FIX/envy"
    assert_output_has "SKOGAI_LOCAL_DIR=$LOCAL"
    assert_output_has "SKOGAI_ENVY_SOMEKEY=v"
    SKOGAI_ENVY_SOMEKEY=w run skogai envy show
    assert_output_has "SKOGAI_ENVY_SOMEKEY=w"
}

@test "env: an installed module's env: runs for every command, a found one's does not" {
    fixture hooky <<'MD'
---
type: module
name: hooky
description: sets a key for everyone
command: argc.sh
env: env.sh
requires: [core]
---
MD
    printf '#!/usr/bin/env bash\necho "export SKOGAI_CORE_MODULE_INSTALL=global"\n' >"$FIX/hooky/env.sh"
    cat >"$FIX/hooky/argc.sh" <<'SH'
#!/usr/bin/env bash
# @cmd
show() { echo "install=${SKOGAI_CORE_MODULE_INSTALL:-unset}"; }
eval "$(argc --argc-eval "$0" "$@")"
SH
    run skogai hooky show
    assert_output_has "install=unset"
    skogai module add hooky --apply >/dev/null 2>&1
    assert_file "$LOCAL/modules/hooky/env.sh"
    run skogai hooky show
    assert_output_has "install=global"
    run skogai module env core
    assert_output_has "export SKOGAI_CORE_MODULE_INSTALL=global"
    skogai module new late x >/dev/null 2>&1
    assert_file "$SKOGAI_CONFIG_DIR/modules/late/module.md"
}

@test "module build: the built skogai lists, runs and completes every module" {
    run skogai module build --shell bash
    assert_status 0
    B="$LOCAL/tmp/skogai"
    assert_output_has "export PATH=$B/bin:"
    assert_file "$B/bin/skogai"
    assert_file "$B/completions/skogai.sh"
    assert_file "$B/completions/skogai.fish"
    assert_file "$B/man/man1/skogai.1"
    assert_file "$B/man/man1/skogai-module-build.1"
    run "$B/bin/skogai" --help
    assert_output_has "  config "
    assert_output_has "  module "
    run "$B/bin/skogai" config get core.module.install
    assert_output_has local
    run env ARGC_COMPLETIONS_PATH="$B/completions" argc --argc-compgen generic "" skogai config ""
    assert_output_has unset
    run env ARGC_COMPLETIONS_PATH="$B/completions" argc --argc-compgen generic "" skogai config get ""
    assert_output_has core.module.install
}

@test "module build: a module added after the build still runs" {
    skogai module build >/dev/null 2>&1
    skogai module new late "came later" >/dev/null 2>&1
    run "$LOCAL/tmp/skogai/bin/skogai" late hello you
    assert_status 0
    assert_output_has "hello, you"
}

@test "module build: --shell fish prints fish lines, --to global builds there" {
    run skogai module build --to global --shell fish
    assert_status 0
    assert_output_has "fish_add_path --prepend $SKOGAI_CONFIG_DIR/tmp/skogai/bin"
    assert_file "$SKOGAI_CONFIG_DIR/tmp/skogai/bin/skogai"
}

@test "module sandbox: every module installed, skogai built, env lines into it" {
    fixture lonely <<<$'---\ntype: module\nname: lonely\ndescription: only found, no command\nrequires: [core]\n---'
    skogai module add "$FIX/lonely" --to global --apply >/dev/null 2>&1
    rm -rf "$FIX/lonely"
    S="$BATS_TEST_TMPDIR/sb"
    run --separate-stderr skogai module sandbox "$S" --shell bash
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

@test "module sandbox: replaces an earlier sandbox, refuses any other dir" {
    S="$BATS_TEST_TMPDIR/sb"
    skogai module sandbox "$S" >/dev/null 2>&1
    touch "$S/repo/leftover"
    run skogai module sandbox "$S"
    assert_status 0
    [[ ! -e $S/repo/leftover ]]
    mkdir -p "$BATS_TEST_TMPDIR/other"
    run skogai module sandbox "$BATS_TEST_TMPDIR/other"
    assert_status 2
}

@test "module sandbox: run runs one command inside it, state kept between runs" {
    S="$BATS_TEST_TMPDIR/sb"
    skogai module sandbox "$S" >/dev/null 2>&1
    run env SKOGAI_CORE_MODULE_INSTALL=leak "$S/run" skogai config get core.module.install --show-origin
    assert_output_has "module:core	local"
    run "$S/run" pwd
    assert_output_has "$S/repo"
    "$S/run" skogai config set core.module.install global
    run "$S/run" skogai config get core.module.install --show-origin
    assert_output_has "$S/repo/skogai.toml	global"
}

@test "module env: a list default is one key, one item per line" {
    fixture tagged <<'MD'
---
type: module
name: tagged
description: has a list default
requires: [core]
config:
  tags: [a, b]
---
MD
    run skogai module defaults tagged
    assert_status 0
    [[ $output == $'tagged.tags\ta\x1fb' ]]
    run skogai module env tagged
    assert_output_has "export SKOGAI_TAGGED_TAGS=$'a\\nb'"
}

@test "local dir: the git root's .skogai from a subdir, pwd's outside git" {
    mkdir -p sub/deeper
    run bash -c 'cd sub/deeper && "$SKOGAI_BIN" module env config'
    assert_output_has "export SKOGAI_LOCAL_DIR=$LOCAL"
    mkdir "$BATS_TEST_TMPDIR/nogit"
    cd "$BATS_TEST_TMPDIR/nogit"
    run skogai module env config
    assert_output_has "export SKOGAI_LOCAL_DIR=$BATS_TEST_TMPDIR/nogit/.skogai"
}

@test "dispatch: an unknown command fails and names the known ones" {
    run skogai nosuch
    [[ $status -ne 0 ]]
    assert_output_has "subcommands: module"
}

@test "module show and command: where it is, its manifest, its argc script" {
    run skogai module show config
    assert_status 0
    [[ ${lines[0]} == source$'\t'*/config ]]
    assert_output_has "name: config"
    run skogai module command config
    [[ $output == */config/argc.sh ]]
    fixture bare <<<$'---\ntype: module\nname: bare\ndescription: no command\nrequires: [core]\n---'
    run skogai module command bare
    assert_status 1
    run skogai module show nosuch
    assert_status 1
}

@test "module diff: an unchanged copy is exit 0, one without a source is exit 2" {
    skogai module add core --apply >/dev/null 2>&1
    run skogai module diff core
    assert_status 0
    [[ -z $output ]]
    fixture gone <<<$'---\ntype: module\nname: gone\ndescription: x\nrequires: [core]\n---'
    skogai module add "$FIX/gone" --apply >/dev/null 2>&1
    rm -rf "$FIX/gone"
    run skogai module diff gone
    assert_status 2
}

@test "module add: the installed copy itself is already installed, exit 0" {
    skogai module add core --apply >/dev/null 2>&1
    run skogai module add "$LOCAL/modules/core"
    assert_status 0
    assert_output_has "already installed"
}

@test "module add: only module.md, the command and files: are copied" {
    fixture shipped <<<$'---\ntype: module\nname: shipped\ndescription: x\nrequires: [core]\nfiles: [templates/]\n---'
    mkdir -p "$FIX/shipped/templates/sub" "$FIX/shipped/tests"
    touch "$FIX/shipped/templates/sub/t.md" "$FIX/shipped/tests/shipped.bats" "$FIX/shipped/notes.md"
    skogai module add shipped --apply >/dev/null 2>&1
    assert_file "$LOCAL/modules/shipped/templates/sub/t.md"
    [[ ! -e $LOCAL/modules/shipped/tests && ! -e $LOCAL/modules/shipped/notes.md ]]
}

@test "module check: the rest of the spec problems" {
    fixture worse <<'MD'
---
type: thing
name: worse
description: |
  two
  lines
command: argc.sh
files: [gone.txt]
config: [1]
requires: [core]
---
MD
    printf '#!/usr/bin/env bash\n# @cmd\n# @option --x[`\nfoo() { :; }\n' >"$FIX/worse/argc.sh"
    fixture help <<<$'---\ntype: module\nname: help\ndescription: x\nrequires: [core]\n---'
    fixture plain <<<'# no frontmatter'
    run skogai module check "$FIX/worse" "$FIX/help" "$FIX/plain"
    assert_status 1
    assert_output_has "worse	error	type is not module"
    assert_output_has "worse	error	description is not one line"
    assert_output_has "worse	error	command argc.sh does not parse with argc"
    assert_output_has "worse	error	file gone.txt is missing"
    assert_output_has "worse	error	config is not a map"
    assert_output_has "worse	warn	no tests/*.bats"
    assert_output_has "help	error	name is reserved"
    assert_output_has "plain	error	module.md has no frontmatter map"
}

@test "module test: a failing test fails the run, --filter picks tests, an unknown module fails" {
    fixture flaky <<<$'---\ntype: module\nname: flaky\ndescription: one test fails\nrequires: [core]\n---'
    mkdir "$FIX/flaky/tests"
    cat >"$FIX/flaky/tests/flaky.bats" <<'BATS'
load "$SKOGAI_TEST_HELPER"
@test "flaky: passes" { true; }
@test "flaky: fails" { false; }
BATS
    run skogai module test flaky
    assert_status 1
    assert_output_has "not ok"
    assert_output_has "flaky: fails"
    run skogai module test flaky --filter "^flaky: passes"
    assert_status 0
    refute_output_has "contract:"
    run skogai module test nosuch
    assert_status 1
    assert_output_has "invalid value `nosuch`"
}
