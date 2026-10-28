#!/usr/bin/env bats
# core's own behaviour: the module commands, defaults and env.

load "$SKOGAI_TEST_HELPER"

@test "system defaults: every config: default, mounted under its module's name" {
    run skogai system defaults core
    assert_status 0
    assert_output_has "core.module.install	local"
}

@test "system ls: a source module is listed as source" {
    run skogai system ls
    assert_status 0
    assert_output_has "core         source"
}

@test "system add: a changed installed file is kept, diff shows it" {
    skogai system add core --apply >/dev/null 2>&1
    echo extra >>"$LOCAL/modules/core/module.md"
    run skogai system add core --apply
    assert_status 0
    assert_output_has "keep  module.md"
    [[ $(tail -1 "$LOCAL/modules/core/module.md") == extra ]]
    run skogai system diff core
    assert_status 1
    assert_output_has "+extra"
}

@test "system add: --to global installs into the global dir" {
    run skogai system add core --to global --apply
    assert_status 0
    assert_file "$SKOGAI_CONFIG_DIR/modules/core/module.md"
}

@test "system add: core.module.install picks the default target" {
    SKOGAI_CORE_MODULE_INSTALL=global skogai system add core --apply >/dev/null 2>&1
    assert_file "$SKOGAI_CONFIG_DIR/modules/core/module.md"
}

@test "system add: an unknown source is a usage error" {
    run skogai system add nosuchmodule
    assert_status 2
}

@test "system new: scaffolds a module that passes its own tests" {
    run skogai system new greet "says hello"
    assert_status 0
    assert_file "$LOCAL/modules/greet/tests/greet.bats"
    run skogai system check greet
    assert_status 0
    run skogai greet hello skogix
    assert_output_has "hello, skogix"
    SKOGAI_GREET_GREETING=hej run skogai greet hello skogix
    assert_output_has "hej, skogix"
}

@test "system new: refuses reserved, bad and existing names" {
    run skogai system new system x
    assert_status 2
    run skogai system new Bad x
    assert_status 2
    skogai system new greet x 2>/dev/null
    run skogai system new greet x
    assert_status 2
}

@test "system check: reports every spec problem" {
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
    run skogai system check "$FIX/bad"
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
    skogai system add core --apply >/dev/null 2>&1
    run skogai system ls
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
    skogai system add hooky --apply >/dev/null 2>&1
    assert_file "$LOCAL/modules/hooky/env.sh"
    run skogai hooky show
    assert_output_has "install=global"
    run skogai system env core
    assert_output_has "export SKOGAI_CORE_MODULE_INSTALL=global"
    skogai system new late x >/dev/null 2>&1
    assert_file "$SKOGAI_CONFIG_DIR/modules/late/module.md"
}

@test "system build: the built skogai lists, runs and completes every module" {
    run skogai system build --shell bash
    assert_status 0
    B="$LOCAL/tmp/skogai"
    assert_output_has "export PATH=$LOCAL/bin:"
    assert_file "$LOCAL/bin/skogai"
    assert_file "$B/completions/skogai.sh"
    assert_file "$B/completions/skogai.fish"
    assert_file "$B/man/man1/skogai.1"
    assert_file "$B/man/man1/skogai-system-build.1"
    run "$LOCAL/bin/skogai" --help
    assert_output_has "  config "
    assert_output_has "  system "
    run "$LOCAL/bin/skogai" config get core.module.install
    assert_output_has local
    run env ARGC_COMPLETIONS_PATH="$B/completions" argc --argc-compgen generic "" skogai config ""
    assert_output_has unset
    run env ARGC_COMPLETIONS_PATH="$B/completions" argc --argc-compgen generic "" skogai config get ""
    assert_output_has core.module.install
}

@test "system build: a module added after the build still runs" {
    skogai system build >/dev/null 2>&1
    skogai system new late "came later" >/dev/null 2>&1
    run "$LOCAL/bin/skogai" late hello you
    assert_status 0
    assert_output_has "hello, you"
}

@test "system build: --shell fish prints fish lines, --to global builds there" {
    run skogai system build --to global --shell fish
    assert_status 0
    assert_output_has "fish_add_path --path --prepend $SKOGAI_CONFIG_DIR/bin"
    assert_file "$SKOGAI_CONFIG_DIR/bin/skogai"
}

@test "system env: a list default is one key, one item per line" {
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
    run skogai system defaults tagged
    assert_status 0
    [[ $output == $'tagged.tags\ta\x1fb' ]]
    run skogai system env tagged
    assert_output_has "export SKOGAI_TAGGED_TAGS=$'a\\nb'"
}

@test "local dir: the git root's .skogai from a subdir, pwd's outside git" {
    # the default, not the sandbox's
    unset SKOGAI_LOCAL_DIR
    mkdir -p sub/deeper
    run bash -c 'cd sub/deeper && "$SKOGAI_BIN" system env config'
    assert_output_has "export SKOGAI_LOCAL_DIR=$LOCAL"
    mkdir "$BATS_TEST_TMPDIR/nogit"
    cd "$BATS_TEST_TMPDIR/nogit"
    run skogai system env config
    assert_output_has "export SKOGAI_LOCAL_DIR=$BATS_TEST_TMPDIR/nogit/.skogai"
}

@test "dispatch: an unknown command fails and names the known ones" {
    run skogai nosuch
    [[ $status -ne 0 ]]
    assert_output_has "subcommands: system"
}

@test "system show and command: where it is, its manifest, its argc script" {
    run skogai system show config
    assert_status 0
    [[ ${lines[0]} == source$'\t'*/config ]]
    assert_output_has "name: config"
    run skogai system command config
    [[ $output == */config/argc.sh ]]
    fixture bare <<<$'---\ntype: module\nname: bare\ndescription: no command\nrequires: [core]\n---'
    run skogai system command bare
    assert_status 1
    run skogai system show nosuch
    assert_status 1
}

@test "system diff: an unchanged copy is exit 0, one without a source is exit 2" {
    skogai system add core --apply >/dev/null 2>&1
    run skogai system diff core
    assert_status 0
    [[ -z $output ]]
    fixture gone <<<$'---\ntype: module\nname: gone\ndescription: x\nrequires: [core]\n---'
    skogai system add "$FIX/gone" --apply >/dev/null 2>&1
    rm -rf "$FIX/gone"
    run skogai system diff gone
    assert_status 2
}

@test "system add: the installed copy itself is already installed, exit 0" {
    skogai system add core --apply >/dev/null 2>&1
    run skogai system add "$LOCAL/modules/core"
    assert_status 0
    assert_output_has "already installed"
}

@test "system add: only module.md, the command and files: are copied" {
    fixture shipped <<<$'---\ntype: module\nname: shipped\ndescription: x\nrequires: [core]\nfiles: [templates/]\n---'
    mkdir -p "$FIX/shipped/templates/sub" "$FIX/shipped/tests"
    touch "$FIX/shipped/templates/sub/t.md" "$FIX/shipped/tests/shipped.bats" "$FIX/shipped/notes.md"
    skogai system add shipped --apply >/dev/null 2>&1
    assert_file "$LOCAL/modules/shipped/templates/sub/t.md"
    [[ ! -e $LOCAL/modules/shipped/tests && ! -e $LOCAL/modules/shipped/notes.md ]]
}

@test "system check: the rest of the spec problems" {
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
    run skogai system check "$FIX/worse" "$FIX/help" "$FIX/plain"
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

@test "system source: where a module is installed from, exit 1 without one" {
    run skogai system source core
    assert_status 0
    [[ $output == "$(dirname "$SKOGAI_BIN")/../modules/core" || $output == "$(realpath "$(dirname "$SKOGAI_BIN")/../modules/core")" ]]
    fixture lonely <<<$'---\ntype: module\nname: lonely\ndescription: x\nrequires: [core]\n---'
    skogai system add "$FIX/lonely" --apply >/dev/null 2>&1
    rm -rf "$FIX/lonely"
    run skogai system source lonely
    assert_status 1
}

@test "system add: a module with a command gets bin/skogai-<name>, core and a bare one don't" {
    run skogai system add config
    assert_output_has "add   $LOCAL/bin/skogai-config"
    [[ ! -e $LOCAL/bin/skogai-config ]]
    skogai system add config --apply >/dev/null 2>&1
    run env -u SKOGAI_BIN "$LOCAL/bin/skogai-config" get core.module.install
    assert_status 0
    assert_output_has local
    run skogai system add config
    assert_output_has "same  $LOCAL/bin/skogai-config"
    skogai system add core --apply >/dev/null 2>&1
    [[ ! -e $LOCAL/bin/skogai-core ]]
    fixture bare <<<$'---\ntype: module\nname: bare\ndescription: no command\nrequires: [core]\n---'
    skogai system add bare --apply >/dev/null 2>&1
    [[ ! -e $LOCAL/bin/skogai-bare ]]
}

@test "system new: writes bin/skogai-<name> beside the install dir" {
    skogai system new greet "says hello" --to global >/dev/null 2>&1
    run "$SKOGAI_CONFIG_DIR/bin/skogai-greet" hello you
    assert_status 0
    assert_output_has "hello, you"
}

@test "dispatch: skogai <name> is skogai-<name> on PATH first, any executable" {
    mkdir -p "$LOCAL/bin"
    printf '#!/usr/bin/env bash\necho "plain $*"\n' >"$LOCAL/bin/skogai-plain"
    chmod +x "$LOCAL/bin/skogai-plain"
    run skogai plain a b
    assert_status 0
    [[ $output == "plain a b" ]]
    printf '#!/usr/bin/env bash\necho shadowed\n' >"$LOCAL/bin/skogai-config"
    chmod +x "$LOCAL/bin/skogai-config"
    run skogai config get core.module.install
    [[ $output == shadowed ]]
    printf '#!/usr/bin/env bash\necho never\n' >"$LOCAL/bin/skogai-system"
    chmod +x "$LOCAL/bin/skogai-system"
    run skogai system ls
    refute_output_has never
}

@test "runner: the nearest .skogai/bin/skogai is handed off to, and is the local dir" {
    unset SKOGAI_LOCAL_DIR
    mkdir -p near/.skogai/bin near/sub
    printf '#!/usr/bin/env bash\necho "near $SKOGAI_LOCAL_DIR $*"\n' >near/.skogai/bin/skogai
    chmod +x near/.skogai/bin/skogai
    run bash -c 'cd near/sub && "$SKOGAI_BIN" system ls'
    assert_status 0
    [[ $output == "near $REPO/near/.skogai system ls" ]]
    run bash -c 'cd near/sub && SKOGAI_RUNNER=1 "$SKOGAI_BIN" system ls'
    assert_output_has "core         source"
}

@test "runner: the built runner on PATH hands back without a loop" {
    skogai system build >/dev/null 2>&1
    run env PATH="$LOCAL/bin:$PATH" skogai system ls
    assert_status 0
    assert_output_has "core         source"
    run env PATH="$LOCAL/bin:$PATH" "$LOCAL/bin/skogai" config get core.module.install
    assert_output_has local
}
