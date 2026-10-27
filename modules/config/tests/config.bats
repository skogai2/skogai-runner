#!/usr/bin/env bats
# config's own behaviour: the mise layers, and what installing it changes.

load "$SKOGAI_TEST_HELPER"

# a module source dir of our own, first on the path
fixture() {
    FIX="$BATS_TEST_TMPDIR/sources"
    export SKOGAI_MODULE_PATH="$FIX:$SKOGAI_MODULE_PATH"
    mkdir -p "$FIX/$1"
    cat >"$FIX/$1/module.md"
}

@test "config: a module default resolves with its origin" {
    run skogai config get core.module.install --show-origin
    assert_status 0
    assert_output_has "module:core	local"
}

@test "config: fold order default < system < global < skogai.toml < skogai.<module>.toml < mise.toml < env" {
    mkdir -p "$MISE_SYSTEM_CONFIG_DIR/conf.d"
    printf '[env]\nSKOGAI_CORE_MODULE_INSTALL = "system"\n' >"$MISE_SYSTEM_CONFIG_DIR/conf.d/skogai.toml"
    run skogai config get core.module.install --show-origin
    assert_output_has "$MISE_SYSTEM_CONFIG_DIR/conf.d/skogai.toml	system"
    skogai config set --global core.module.install global
    run skogai config get core.module.install --show-origin
    assert_output_has "$MISE_CONFIG_DIR/conf.d/skogai.toml	global"
    skogai config set core.module.install local
    run skogai config get core.module.install --show-origin
    assert_output_has "$REPO/skogai.toml	local"
    skogai config set --module core core.module.install module
    run skogai config get core.module.install --show-origin
    assert_output_has "$REPO/skogai.core.toml	module"
    printf '[env]\nSKOGAI_CORE_MODULE_INSTALL = "user"\n' >mise.toml
    run skogai config get core.module.install --show-origin
    assert_output_has "$REPO/mise.toml	user"
    SKOGAI_CORE_MODULE_INSTALL=env run skogai config get core.module.install --show-origin
    assert_output_has "env:SKOGAI_CORE_MODULE_INSTALL	env"
}

@test "config: get of an unset key exits 1" {
    run skogai config get no.such.key
    assert_status 1
}

@test "config: set writes skogai.toml at the git root, never mise.toml" {
    mkdir -p sub/deeper
    (cd sub/deeper && skogai config set some.key v)
    assert_file "$REPO/skogai.toml"
    [[ ! -e $REPO/mise.toml ]]
    run yq -p toml .env.SKOGAI_SOME_KEY "$REPO/skogai.toml"
    assert_output_has v
}

@test "config: set --module refuses a key outside the module" {
    run skogai config set --module core other.key x
    assert_status 2
    [[ ! -e $REPO/skogai.core.toml ]]
}

@test "config: unset removes a key from its layer, a missing one exits 1" {
    skogai config set some.key v
    skogai config set --global some.key g
    skogai config unset some.key
    run skogai config get some.key --show-origin
    assert_output_has "$MISE_CONFIG_DIR/conf.d/skogai.toml	g"
    skogai config unset --global some.key
    run skogai config get some.key
    assert_status 1
    run skogai config unset some.key
    assert_status 1
}

@test "config: list and env print every key, env only the mise layers" {
    skogai config set some.key v
    run skogai config list --show-origin
    assert_status 0
    assert_output_has "$REPO/skogai.toml	some.key=v"
    assert_output_has "module:core	core.module.install=local"
    run skogai config env
    assert_output_has "export MISE_OVERRIDE_CONFIG_FILENAMES=skogai.toml:skogai.\*.toml:"
    assert_output_has "export SKOGAI_SOME_KEY=v"
    refute_output_has "SKOGAI_CORE_MODULE_INSTALL"
}

@test "config: a list default is one key, one item per line" {
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
    run skogai config get tagged.tags
    assert_status 0
    [[ $output == $'a\nb' ]]
    run skogai config list
    assert_output_has $'tagged.tags=a\ntagged.tags=b'
}

@test "config: a dashed key keeps its name when a layer sets it" {
    fixture dashed <<<$'---\ntype: module\nname: dashed\ndescription: x\nrequires: [core]\nconfig:\n  on-stop: d\n---'
    skogai config set dashed.on-stop s
    run skogai config get dashed.on-stop --show-origin
    assert_output_has "$REPO/skogai.toml	s"
}

@test "config: files lists every skogai layer and whether it is there" {
    skogai config set some.key v
    run skogai config files
    assert_status 0
    assert_output_has "local	$REPO/skogai.toml	present"
    assert_output_has "global	$MISE_CONFIG_DIR/conf.d/skogai.toml	missing"
    assert_output_has "system	$MISE_SYSTEM_CONFIG_DIR/conf.d/skogai.toml	missing"
    assert_output_has "module:core	$REPO/skogai.core.toml	missing"
}

@test "config: is opt-in; installed, every command runs with its layers, the caller's env first" {
    fixture envy <<'MD'
---
type: module
name: envy
description: prints a key
command: argc.sh
requires: [core]
config:
  some-key: default
---
MD
    cat >"$FIX/envy/argc.sh" <<'SH'
#!/usr/bin/env bash
# @cmd
show() { echo "key=$SKOGAI_ENVY_SOMEKEY"; }
eval "$(argc --argc-eval "$0" "$@")"
SH
    skogai config set envy.some-key layered
    run skogai envy show
    assert_output_has "key=default"
    skogai module add config --apply >/dev/null 2>&1
    run skogai envy show
    assert_output_has "key=layered"
    SKOGAI_ENVY_SOMEKEY=caller run skogai envy show
    assert_output_has "key=caller"
    skogai config set core.module.install global
    skogai module new late x >/dev/null 2>&1
    assert_file "$SKOGAI_CONFIG_DIR/modules/late/module.md"
}
