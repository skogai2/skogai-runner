#!/usr/bin/env bats
# module install by copy: src/core/module/usage.sh install|uninstall|ls puts a
# module's toml into the mise conf.d of a level. see docs/install.md.

bats_require_minimum_version 1.5.0

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    FX="$ROOT/tests/fixtures/install"
    MODULE="$ROOT/src/core/module/usage.sh"
    T="$BATS_TEST_TMPDIR"
    export HOME="$T/home" XDG_STATE_HOME="$T/state"
    export MISE_SYSTEM_DIR="$T/sys" MISE_CONFIG_DIR="$T/cfg" MISE_DATA_DIR="$T/data" \
        MISE_STATE_DIR="$T/mstate" MISE_CACHE_DIR="$T/cache"
    P="$T/p"
    export MISE_TRUSTED_CONFIG_PATHS="$P"
    unset SKOGAI_LOG XDG_CONFIG_HOME GIT_DIR GIT_WORK_TREE
    mkdir -p "$HOME" "$XDG_STATE_HOME" "$P"
    git -C "$P" init -q
    cd "$P"
    SYS="$MISE_SYSTEM_DIR/conf.d"
    GLOB="$MISE_CONFIG_DIR/conf.d"
    LOC="$P/.mise/conf.d"
    LOC2="$P/.config/mise/conf.d"
}

mod() { "$MODULE" "$@"; }

# the JSON line install prints on success
ok_line() { jq -cn --arg m "$1" --arg l "$2" --arg p "$3" --arg a "$4" '{module: $m, level: $l, path: $p, action: $a}'; }

@test "install puts the toml into the conf.d of each level and prints the exact JSON" {
    run -0 --separate-stderr mod install --level system "$FX/mods/alpha"
    [ "$output" = "$(ok_line alpha system "$SYS/alpha.toml" installed)" ]
    cmp "$SYS/alpha.toml" "$FX/mods/alpha/alpha.toml"
    run -0 --separate-stderr mod install --level global "$FX/mods/testok/testok.toml"
    [ "$output" = "$(ok_line testok global "$GLOB/testok.toml" installed)" ]
    cmp "$GLOB/testok.toml" "$FX/mods/testok/testok.toml"
    run -0 --separate-stderr mod install --level local "$FX/mods/live"
    [ "$output" = "$(ok_line live local "$LOC/live.toml" installed)" ]
    cmp "$LOC/live.toml" "$FX/mods/live/live.toml"
    [ "$(stat -c %a "$LOC/live.toml")" = 644 ]
}

@test "the default level is global, also from XDG_CONFIG_HOME when MISE_CONFIG_DIR is unset" {
    run -0 --separate-stderr mod install "$FX/mods/alpha"
    [ "$output" = "$(ok_line alpha global "$GLOB/alpha.toml" installed)" ]
    unset MISE_CONFIG_DIR
    export XDG_CONFIG_HOME="$T/xdg"
    run -0 --separate-stderr mod install "$FX/mods/alpha"
    [ "$output" = "$(ok_line alpha global "$T/xdg/mise/conf.d/alpha.toml" installed)" ]
    unset XDG_CONFIG_HOME
    run -0 --separate-stderr mod install "$FX/mods/alpha"
    [ "$output" = "$(ok_line alpha global "$HOME/.config/mise/conf.d/alpha.toml" installed)" ]
}

@test "a second install is unchanged and leaves the mtime alone" {
    mod install "$FX/mods/alpha" >/dev/null
    touch -d '2001-01-01 00:00:00' "$GLOB/alpha.toml"
    local before
    before="$(stat -c %y "$GLOB/alpha.toml")"
    run -0 --separate-stderr mod install "$FX/mods/alpha"
    [ "$output" = "$(ok_line alpha global "$GLOB/alpha.toml" unchanged)" ]
    [ "$(stat -c %y "$GLOB/alpha.toml")" = "$before" ]
}

@test "a changed source is updated" {
    mod install "$FX/mods/alpha" >/dev/null
    mkdir "$T/alpha"
    jq -Rr 'sub("fixture module alpha"; "changed")' "$FX/mods/alpha/alpha.toml" >"$T/alpha/alpha.toml"
    ! cmp -s "$T/alpha/alpha.toml" "$FX/mods/alpha/alpha.toml"
    run -0 --separate-stderr mod install "$T/alpha"
    [ "$output" = "$(ok_line alpha global "$GLOB/alpha.toml" updated)" ]
    cmp "$GLOB/alpha.toml" "$T/alpha/alpha.toml"
}

@test "an invalid module is rejected with its reasons and nothing is written" {
    run -3 --separate-stderr mod install "$FX/mods/bad"
    [ "$output" = '{"module":"bad","level":"global","path":null,"action":"rejected","reasons":["unknown-section"]}' ]
    run -3 --separate-stderr mod install --level system "$FX/mods/broken/broken.toml"
    [ "$output" = '{"module":null,"level":"system","path":null,"action":"rejected","reasons":["invalid-toml"]}' ]
    [ ! -e "$GLOB" ] && [ ! -e "$SYS" ]
}

@test "a missing dependency is rejected, then accepted once the dependency sits at a broader level" {
    run -3 --separate-stderr mod install "$FX/mods/beta"
    [ "$output" = '{"module":"beta","level":"global","path":null,"action":"rejected","reasons":["missing-dependency"]}' ]
    [ ! -e "$GLOB" ]
    mod install --level system "$FX/mods/alpha" >/dev/null
    run -0 --separate-stderr mod install "$FX/mods/beta"
    [ "$output" = "$(ok_line beta global "$GLOB/beta.toml" installed)" ]
}

@test "a dependency installed at the same level is satisfied" {
    mod install "$FX/mods/alpha" >/dev/null
    run -0 --separate-stderr mod install "$FX/mods/beta"
    [ "$output" = "$(ok_line beta global "$GLOB/beta.toml" installed)" ]
}

@test "a dependency at a narrower level does not satisfy missing-dependency" {
    mod install --level local "$FX/mods/alpha" >/dev/null
    run -3 --separate-stderr mod install "$FX/mods/beta"
    [ "$output" = '{"module":"beta","level":"global","path":null,"action":"rejected","reasons":["missing-dependency"]}' ]
}

@test "duplicate-name is rejected when the name sits at a broader level" {
    mod install "$FX/mods/alpha" >/dev/null
    run -3 --separate-stderr mod install --level local "$FX/mods/alpha"
    [ "$output" = '{"module":"alpha","level":"local","path":null,"action":"rejected","reasons":["duplicate-name"]}' ]
    [ ! -e "$LOC" ]
}

@test "duplicate-name is rejected when the name sits at a narrower level" {
    mod install --level local "$FX/mods/alpha" >/dev/null
    run -3 --separate-stderr mod install "$FX/mods/alpha"
    [ "$output" = '{"module":"alpha","level":"global","path":null,"action":"rejected","reasons":["duplicate-name"]}' ]
    [ ! -e "$GLOB" ]
}

@test "duplicate-name also finds the name under another file name" {
    mkdir -p "$SYS"
    cp "$FX/mods/alpha/alpha.toml" "$SYS/50-alpha.toml"
    run -3 --separate-stderr mod install "$FX/mods/alpha"
    [ "$(jq -r '.reasons | index("duplicate-name") != null' <<<"$output")" = true ]
    [ ! -e "$GLOB" ]
}

@test "ownership-conflict with an installed module is rejected" {
    mod install "$FX/mods/alpha" >/dev/null
    run -3 --separate-stderr mod install "$FX/mods/gamma"
    [ "$output" = '{"module":"gamma","level":"global","path":null,"action":"rejected","reasons":["ownership-conflict"]}' ]
    [ ! -e "$GLOB/gamma.toml" ]
}

@test "uninstall of an invalid name is exit 2" {
    run -2 --separate-stderr mod uninstall '../x'
    [ -z "$output" ]
    run -2 --separate-stderr mod uninstall Upper
    [ -z "$output" ]
}

@test "a module in .config/mise/conf.d shows in ls as level local, after .mise/conf.d" {
    mkdir -p "$LOC2" "$LOC"
    cp "$FX/mods/alpha/alpha.toml" "$LOC2/"
    cp "$FX/mods/beta/beta.toml" "$LOC/"
    cp "$FX/mods/live/live.toml" "$LOC2/"
    run -0 --separate-stderr mod ls
    [ "${lines[0]}" = "{\"module\":\"beta\",\"level\":\"local\",\"path\":\"$LOC/beta.toml\"}" ]
    [ "${lines[1]}" = "{\"module\":\"alpha\",\"level\":\"local\",\"path\":\"$LOC2/alpha.toml\"}" ]
    [ "${lines[2]}" = "{\"module\":\"live\",\"level\":\"local\",\"path\":\"$LOC2/live.toml\"}" ]
    [ "${#lines[@]}" -eq 3 ]
}

@test "ls lists system, global, local, files C-locale sorted" {
    mkdir -p "$SYS" "$GLOB" "$LOC"
    cp "$FX/mods/live/live.toml" "$LOC/"
    cp "$FX/mods/beta/beta.toml" "$GLOB/"
    cp "$FX/mods/alpha/alpha.toml" "$GLOB/"
    cp "$FX/mods/testok/testok.toml" "$SYS/Z-testok.toml"
    cp "$FX/mods/gamma/gamma.toml" "$SYS/a-gamma.toml"
    run -0 --separate-stderr mod ls
    [ "$(jq -sr 'map(.level + ":" + .module) | join(" ")' <<<"$output")" = "system:testok system:gamma global:alpha global:beta local:live" ]
}

@test "ls with no modules prints nothing" {
    run -0 --separate-stderr mod ls
    [ -z "$output" ]
}

@test "a read-only conf.d gives exit 4 and leaves no temporary file" {
    [ "$(id -u)" -ne 0 ] || skip "root ignores directory permissions"
    mkdir -p "$GLOB"
    chmod 555 "$GLOB"
    run -4 --separate-stderr mod install "$FX/mods/alpha"
    chmod 755 "$GLOB"
    [ -z "$output" ]
    [ -n "$stderr" ]
    [ -z "$(ls -A "$GLOB")" ]
}

@test "a missing conf.d under an unwritable parent gives exit 4" {
    [ "$(id -u)" -ne 0 ] || skip "root ignores directory permissions"
    mkdir -p "$MISE_SYSTEM_DIR"
    chmod 555 "$MISE_SYSTEM_DIR"
    run -4 --separate-stderr mod install --level system "$FX/mods/alpha"
    chmod 755 "$MISE_SYSTEM_DIR"
    [ -z "$output" ]
    [ -n "$stderr" ]
}

@test "a module directory whose bats test fails is rejected with tests-failed" {
    run -3 --separate-stderr mod install "$FX/mods/testfail"
    [ "$output" = '{"module":"testfail","level":"global","path":null,"action":"rejected","reasons":["tests-failed"]}' ]
    [ ! -e "$GLOB" ]
    [ -n "$stderr" ]
}

@test "a module directory whose bats test passes is installed" {
    run -0 --separate-stderr mod install "$FX/mods/testok"
    [ "$output" = "$(ok_line testok global "$GLOB/testok.toml" installed)" ]
}

@test "the tests run with the module directory as working directory, after the rules" {
    mkdir -p "$T/wd/wd/tests"
    jq -Rr 'sub("testok"; "wd"; "g") | sub("TESTOK"; "WD"; "g")' "$FX/mods/testok/testok.toml" >"$T/wd/wd/wd.toml"
    printf '#!/usr/bin/env bats\n@test "cwd" {\n    [ "$PWD" = "%s" ]\n}\n' "$T/wd/wd" >"$T/wd/wd/tests/cwd.bats"
    run -0 --separate-stderr mod install "$T/wd/wd"
    [ "$(jq -r .action <<<"$output")" = installed ]
}

@test "an invalid declaration is rejected before its tests run" {
    mkdir -p "$T/bt/bt/tests"
    cp "$FX/mods/bad/bad.toml" "$T/bt/bt/bt.toml"
    printf '#!/usr/bin/env bats\n@test "x" {\n    touch "%s/ran"\n}\n' "$T" >"$T/bt/bt/tests/x.bats"
    run -3 --separate-stderr mod install "$T/bt/bt"
    [ ! -e "$T/ran" ]
}

@test "a foreign non-module file at the target name is exit 2 and untouched" {
    mkdir -p "$GLOB"
    cp "$FX/foreign/alpha.toml" "$GLOB/alpha.toml"
    run -2 --separate-stderr mod install "$FX/mods/alpha"
    [ -z "$output" ]
    cmp "$GLOB/alpha.toml" "$FX/foreign/alpha.toml"
}

@test "a module file of another name at the target name is exit 2 and untouched" {
    mkdir -p "$GLOB"
    cp "$FX/mods/live/live.toml" "$GLOB/alpha.toml"
    run -2 --separate-stderr mod install "$FX/mods/alpha"
    cmp "$GLOB/alpha.toml" "$FX/mods/live/live.toml"
}

@test "foreign files in conf.d are ignored by ls, by the rules and by uninstall" {
    mkdir -p "$SYS"
    cp "$FX/foreign/10-host.toml" "$SYS/"
    printf '[_.skogai.a]\nx = {}\n[_.skogai.b]\ny = {}\n' >"$SYS/multi.toml"
    printf 'not [ toml\n' >"$SYS/broken.toml"
    printf '[_.skogai]\nx = "str"\n' >"$SYS/notable.toml"
    run -0 --separate-stderr mod ls
    [ -z "$output" ]
    run -0 --separate-stderr mod install "$FX/mods/alpha"
    [ "$(jq -r .action <<<"$output")" = installed ]
    cp "$FX/foreign/10-host.toml" "$SYS/host.toml"
    run -2 --separate-stderr mod uninstall --level system host
    cmp "$SYS/host.toml" "$FX/foreign/10-host.toml"
}

@test "uninstall removes the file, then reports absent" {
    mod install "$FX/mods/alpha" >/dev/null
    run -0 --separate-stderr mod uninstall alpha
    [ "$output" = "$(ok_line alpha global "$GLOB/alpha.toml" removed)" ]
    [ ! -e "$GLOB/alpha.toml" ]
    run -0 --separate-stderr mod uninstall alpha
    [ "$output" = '{"module":"alpha","level":"global","path":null,"action":"absent"}' ]
}

@test "uninstall of a foreign file at the name is exit 2 and untouched" {
    mkdir -p "$GLOB"
    cp "$FX/foreign/alpha.toml" "$GLOB/alpha.toml"
    run -2 --separate-stderr mod uninstall alpha
    cmp "$GLOB/alpha.toml" "$FX/foreign/alpha.toml"
}

@test "uninstall is refused while another installed module depends on it" {
    mod install "$FX/mods/alpha" >/dev/null
    mod install --level local "$FX/mods/beta" >/dev/null
    run -3 --separate-stderr mod uninstall alpha
    [ "$output" = '{"module":"alpha","level":"global","path":null,"action":"rejected","reasons":["required-by"],"required_by":["beta"]}' ]
    [ -e "$GLOB/alpha.toml" ]
    mod uninstall --level local beta >/dev/null
    run -0 --separate-stderr mod uninstall alpha
    [ "$(jq -r .action <<<"$output")" = removed ]
}

@test "uninstall at the local level only touches .mise/conf.d" {
    mkdir -p "$LOC2"
    cp "$FX/mods/alpha/alpha.toml" "$LOC2/"
    run -0 --separate-stderr mod uninstall --level local alpha
    [ "$(jq -r .action <<<"$output")" = absent ]
    [ -e "$LOC2/alpha.toml" ]
}

@test "a failing removal is exit 4" {
    [ "$(id -u)" -ne 0 ] || skip "root ignores directory permissions"
    mod install "$FX/mods/alpha" >/dev/null
    chmod 555 "$GLOB"
    run -4 --separate-stderr mod uninstall alpha
    chmod 755 "$GLOB"
    [ -z "$output" ]
    [ -n "$stderr" ]
    [ -e "$GLOB/alpha.toml" ]
}

@test "the local level outside a git work tree is exit 2, ls leaves it out" {
    mkdir -p "$T/nogit"
    cd "$T/nogit"
    run -2 --separate-stderr mod install --level local "$FX/mods/alpha"
    [ -z "$output" ]
    run -2 --separate-stderr mod uninstall --level local alpha
    run -0 --separate-stderr mod install "$FX/mods/alpha"
    run -0 --separate-stderr mod ls
    [ "$(jq -r .level <<<"$output")" = global ]
    [ ! -e "$T/nogit/.mise" ]
}

@test "bad paths are exit 2 and write nothing" {
    run -2 --separate-stderr mod install "$T/nonexistent"
    run -2 --separate-stderr mod install "$FX/mods/nofile"
    run -2 --separate-stderr mod install "$FX/mods/alpha/README.md"
    printf 'x' >"$T/notes.txt"
    run -2 --separate-stderr mod install "$T/notes.txt"
    [ -z "$output" ]
    [ ! -e "$GLOB" ]
}

@test "a level or flag outside the spec is usage's exit 1" {
    run -1 --separate-stderr mod install --level bogus "$FX/mods/alpha"
    run -1 --separate-stderr mod install
    [ ! -e "$GLOB" ]
}

@test "a missing tool is exit 2 naming the tool" {
    local bin="$T/bin"
    mkdir -p "$bin"
    ln -s "$(command -v usage)" "$bin/usage"
    ln -s "$(command -v env)" "$bin/env"
    ln -s "$(command -v bash)" "$bin/bash"
    ln -s "$(command -v realpath)" "$bin/realpath"
    ln -s "$(command -v dirname)" "$bin/dirname"
    run -2 --separate-stderr env PATH="$bin" "$MODULE" ls
    [ -z "$output" ]
    [[ "$stderr" == *"missing tool"* ]]
}

@test "install, ls and uninstall write nothing outside the conf.d files" {
    mod install "$FX/mods/alpha" >/dev/null
    mod ls >/dev/null
    mod uninstall alpha >/dev/null
    [ -z "$(find "$GLOB" -type f)" ]
    [ ! -e "$XDG_STATE_HOME/skogai" ]
    [ -z "$(find "$P" -path "$P/.git" -prune -o -type f -print)" ]
}

@test "live: an installed module's task runs under mise, and is gone after uninstall" {
    command -v mise >/dev/null || skip "mise is not installed"
    mod install "$FX/mods/live" >/dev/null
    mise_run() {
        env -i PATH="$PATH" HOME="$HOME" MISE_CONFIG_DIR="$MISE_CONFIG_DIR" MISE_SYSTEM_DIR="$MISE_SYSTEM_DIR" \
            MISE_DATA_DIR="$MISE_DATA_DIR" MISE_STATE_DIR="$MISE_STATE_DIR" MISE_CACHE_DIR="$MISE_CACHE_DIR" \
            MISE_TRUSTED_CONFIG_PATHS="$P:$MISE_CONFIG_DIR" mise run -q live world
    }
    run -0 --separate-stderr mise_run
    [ "$output" = "live world" ]
    mod uninstall live >/dev/null
    run --separate-stderr mise_run
    [ "$status" -ne 0 ]
}

@test "through the registry: skogai module install prints the installed line" {
    export SKOGAI_COMMANDS="$T/registry" SKOGAI_MAIN="$ROOT/src/core/main-usage.sh"
    run -0 --separate-stderr "$SKOGAI_MAIN" register "$MODULE" module
    run -0 --separate-stderr "$SKOGAI_MAIN" module install "$FX/mods/alpha"
    [ "$output" = "$(ok_line alpha global "$GLOB/alpha.toml" installed)" ]
    run -0 --separate-stderr "$SKOGAI_MAIN" module ls
    [ "$(jq -r .module <<<"$output")" = alpha ]
}
