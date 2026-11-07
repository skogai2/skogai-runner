#!/usr/bin/env bats
# src/core/config/usage.sh: SKOGAI_* settings stored in mise's own [env] tables.
# every test isolates mise (env -i plus MISE_* under $BATS_TEST_TMPDIR), the log
# and HOME, and works in a `git init` project. see docs/config.md.

bats_require_minimum_version 1.5.0

setup() {
    command -v mise >/dev/null || skip "mise is not installed"
    t="$BATS_TEST_TMPDIR"
    ROOT="$BATS_TEST_DIRNAME/.."
    CONFIG="$ROOT/src/core/config/usage.sh"
    P="$t/p"
    SYS="$t/sys"
    CFG="$t/cfg"
    mkdir -p "$t/home" "$t/state" "$t/data" "$t/mstate" "$t/cache" "$SYS" "$CFG" "$P"
    git -C "$P" init -q
    XENV=()
}

# run a program in the project under an isolated mise; XENV holds extra VAR=value
iso() {
    (cd "${DIR:-$P}" && env -i PATH="$PATH" HOME="$t/home" XDG_STATE_HOME="$t/state" \
        MISE_CONFIG_DIR="$CFG" MISE_SYSTEM_DIR="$SYS" MISE_DATA_DIR="$t/data" \
        MISE_STATE_DIR="$t/mstate" MISE_CACHE_DIR="$t/cache" \
        MISE_TRUSTED_CONFIG_PATHS="$t" "${XENV[@]}" "$@")
}

cfg() { iso "$CONFIG" "$@"; }
hello() { iso mise run -q hello world 2>/dev/null; }

install_hello() {
    mkdir -p "$P/.mise/conf.d"
    cp "$ROOT/examples/modules/hello/hello.toml" "$P/.mise/conf.d/"
}

# no leftover temporary files in any layer directory
no_tmp() { [ -z "$(find "$t" -name '.skogai-set-*' 2>/dev/null)" ]; }

TAB=$'\t'

@test "precedence ladder: module, system, global, local, override, caller env" {
    install_hello
    run cfg get --show-origin hello.greeting
    [ "$status" -eq 0 ]
    [ "$output" = "module:hello${TAB}hi" ]
    [ "$(hello)" = "hi world" ]

    run cfg set --system hello.greeting sys
    [ "$status" -eq 0 ]
    [ "$(cfg get --show-origin hello.greeting)" = "system${TAB}sys" ]
    [ "$(hello)" = "sys world" ]

    cfg set --global hello.greeting glob
    [ "$(cfg get --show-origin hello.greeting)" = "global${TAB}glob" ]
    [ "$(hello)" = "glob world" ]

    cfg set hello.greeting loc
    [ "$(cfg get --show-origin hello.greeting)" = "local${TAB}loc" ]
    [ "$(hello)" = "loc world" ]

    cfg set --override hello.greeting ovr
    [ "$(cfg get --show-origin hello.greeting)" = "override${TAB}ovr" ]
    [ "$(hello)" = "ovr world" ]

    XENV=(SKOGAI_HELLO_GREETING=env)
    [ "$(cfg get --show-origin hello.greeting)" = "env${TAB}env" ]
    [ "$(cfg get hello.greeting)" = "env" ]
    [ "$(hello)" = "env world" ]
}

@test "a global setting beats a module installed in the project conf.d" {
    install_hello
    cfg set --global hello.greeting glob
    [ "$(hello)" = "glob world" ]
    [ "$(cfg get hello.greeting)" = "glob" ]
}

@test "set stores the get_env form under [env]" {
    cfg set hello.greeting x
    run cat "$P/mise.toml"
    [[ "$output" == *"[env]"* ]]
    [[ "$output" == *"SKOGAI_HELLO_GREETING = \"{{ get_env(name='SKOGAI_HELLO_GREETING', default='x') }}\""* ]]
}

@test "set keeps a comment and a [tools] table, twice leaves one entry, unset removes it" {
    printf '# keep me\n[tools]\n\n[env]\nOTHER = "1"\n' >"$P/mise.toml"
    run cfg set hello.greeting a
    [ "$status" -eq 0 ]
    run cfg set hello.greeting b
    [ "$status" -eq 0 ]
    [ "$(grep -c SKOGAI_HELLO_GREETING "$P/mise.toml")" -eq 1 ]
    grep -q '^# keep me$' "$P/mise.toml"
    grep -q '^\[tools\]$' "$P/mise.toml"
    grep -q '^OTHER = "1"$' "$P/mise.toml"
    [ "$(cfg get hello.greeting)" = "b" ]
    run cfg unset hello.greeting
    [ "$status" -eq 0 ]
    ! grep -q SKOGAI_HELLO_GREETING "$P/mise.toml"
    grep -q '^# keep me$' "$P/mise.toml"
    grep -q '^OTHER = "1"$' "$P/mise.toml"
    run cfg unset hello.greeting
    [ "$status" -eq 0 ]
    no_tmp
}

@test "unset of an absent file is exit 0 and creates nothing" {
    run cfg unset --global hello.greeting
    [ "$status" -eq 0 ]
    [ ! -e "$CFG/config.toml" ]
    run cfg unset hello.greeting
    [ "$status" -eq 0 ]
    [ ! -e "$P/mise.toml" ]
}

@test "set creates the missing file and directory, and the empty value is allowed" {
    rm -rf "$CFG"
    run cfg set --global hello.greeting ""
    [ "$status" -eq 0 ]
    [ -f "$CFG/config.toml" ]
    run cfg get --show-origin hello.greeting
    [ "$status" -eq 0 ]
    [ "$output" = "global${TAB}" ]
}

@test "a value may start with a dash after --" {
    run cfg set hello.greeting -- -x
    [ "$status" -eq 0 ]
    [ "$(cfg get hello.greeting)" = "-x" ]
}

@test "refused values exit 2 and leave the file byte-identical" {
    printf '[env]\nOTHER = "1"\n' >"$P/mise.toml"
    local before v
    before="$(cat "$P/mise.toml")"
    for v in "a'b" 'a"b' 'a\b' $'a\nb' $'a\tb' $'a\rb' $'a\001b' 'a{{b' 'a}}b' 'a{%b' 'a%}b' 'a{#b' 'a#}b'; do
        run cfg set hello.greeting "$v"
        [ "$status" -eq 2 ] || { printf 'not refused: %q\n' "$v"; return 1; }
        [ "$(cat "$P/mise.toml")" = "$before" ]
    done
    no_tmp
}

@test "an unparseable mise.toml makes set and unset exit 2 and stays byte-identical" {
    printf 'garbage = = \n' >"$P/mise.toml"
    run cfg set hello.greeting x
    [ "$status" -eq 2 ]
    run cfg unset hello.greeting
    [ "$status" -eq 2 ]
    [ "$(cat "$P/mise.toml")" = "garbage = = " ]
    no_tmp
}

@test "a failing write leaves no temporary file" {
    chmod 555 "$CFG"
    run cfg set --global hello.greeting x
    chmod 755 "$CFG"
    [ "$status" -eq 2 ]
    no_tmp
}

@test "more than one level flag is exit 2" {
    run cfg set --global --system hello.greeting x
    [ "$status" -eq 2 ]
    run cfg unset --system --override hello.greeting
    [ "$status" -eq 2 ]
}

@test "invalid keys are exit 2" {
    local k
    for k in Hello a..b .a a. 1a "" a_b -a; do
        run cfg get -- "$k"
        [ "$status" -eq 2 ] || { printf 'get accepted: %q\n' "$k"; return 1; }
        run cfg set -- "$k" v
        [ "$status" -eq 2 ] || { printf 'set accepted: %q\n' "$k"; return 1; }
        run cfg unset -- "$k"
        [ "$status" -eq 2 ] || { printf 'unset accepted: %q\n' "$k"; return 1; }
    done
}

@test "a missing key or an unknown flag is exit 1 from usage's parser" {
    run cfg get
    [ "$status" -eq 1 ]
    run cfg get --bogus x
    [ "$status" -eq 1 ]
}

@test "the key maps to the env name, dashes dropped" {
    cfg set a.b-c.d v
    grep -q '^SKOGAI_A_BC_D = ' "$P/mise.toml"
    [ "$(cfg get a.b-c.d)" = "v" ]
}

@test "get of an unset key is exit 3 with empty stdout" {
    run --separate-stderr cfg get hello.greeting
    [ "$status" -eq 3 ]
    [ -z "$output" ]
}

@test "get falls back to a caller env value mise does not define" {
    XENV=(SKOGAI_ONLY_ENV=e)
    run cfg get --show-origin only.env
    [ "$status" -eq 0 ]
    [ "$output" = "env${TAB}e" ]
}

@test "get origin is mise for an [env] value outside the ladder" {
    printf '[env]\nSKOGAI_PLAIN = "p"\n' >"$P/.mise.toml"
    run cfg get --show-origin plain
    [ "$status" -eq 0 ]
    [ "$output" = "mise${TAB}p" ]
}

@test "get origin: the earliest-loaded module default wins" {
    mkdir -p "$SYS/conf.d" "$P/.mise/conf.d"
    printf "[env]\nSKOGAI_D = \"{{ env.SKOGAI_D | default(value='one') }}\"\n[_.skogai.aaa]\n" >"$SYS/conf.d/aaa.toml"
    printf "[env]\nSKOGAI_D = \"{{ env.SKOGAI_D | default(value='two') }}\"\n[_.skogai.bbb]\n" >"$P/.mise/conf.d/bbb.toml"
    run cfg get --show-origin d
    [ "$output" = "module:aaa${TAB}one" ]
}

@test "list output is exact, with and without --show-origin" {
    install_hello
    cfg set --global a.b-c value
    printf '[env]\nSKOGAI_TABBED = "x\\ty\\\\z"\nSKOGAI_A__B = "bad"\nSKOGAI_1A = "bad"\nSKOGAI_ZED = "z"\nOTHER = "o"\n' >"$P/mise.local.toml"
    run cfg list
    [ "$status" -eq 0 ]
    [ "$output" = "a.bc=value
hello.greeting=hi
tabbed=x\\ty\\\\z
zed=z" ]
    run cfg list --show-origin
    [ "$status" -eq 0 ]
    [ "$output" = "global${TAB}a.bc=value
module:hello${TAB}hello.greeting=hi
override${TAB}tabbed=x\\ty\\\\z
override${TAB}zed=z" ]
}

@test "get --show-origin escapes, plain get prints the raw value" {
    printf '[env]\nSKOGAI_TABBED = "x\\ty"\n' >"$P/mise.toml"
    [ "$(cfg get --show-origin tabbed)" = "local${TAB}x\\ty" ]
    [ "$(cfg get tabbed)" = "x${TAB}y" ]
}

@test "list with nothing defined prints nothing" {
    run cfg list
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "files output is exact inside a git dir, host-style files not listed" {
    install_hello
    mkdir -p "$SYS/conf.d"
    printf '[env]\nHOST = "1"\n' >"$SYS/conf.d/omarchy.toml"
    printf '[_.skogai.a]\n[_.skogai.b]\n' >"$SYS/conf.d/two.toml"
    printf 'not = = toml\n' >"$SYS/conf.d/bad.toml"
    printf '[env]\nA = "1"\n' >"$P/mise.toml"
    run cfg files
    [ "$status" -eq 0 ]
    [ "$output" = "system${TAB}$SYS/config.toml${TAB}missing
global${TAB}$CFG/config.toml${TAB}missing
local${TAB}$P/mise.toml${TAB}present
override${TAB}$P/mise.local.toml${TAB}missing
module:hello${TAB}$P/.mise/conf.d/hello.toml${TAB}present" ]
}

@test "files output is exact outside a git dir" {
    mkdir -p "$CFG/conf.d" "$t/plain"
    cp "$ROOT/examples/modules/hello/hello.toml" "$CFG/conf.d/"
    printf '[env]\nA = "1"\n' >"$SYS/config.toml"
    DIR="$t/plain" run cfg files
    [ "$status" -eq 0 ]
    [ "$output" = "system${TAB}$SYS/config.toml${TAB}present
global${TAB}$CFG/config.toml${TAB}missing
local${TAB}-${TAB}missing
override${TAB}-${TAB}missing
module:hello${TAB}$CFG/conf.d/hello.toml${TAB}present" ]
}

@test "outside a git dir set and unset need --system or --global" {
    mkdir -p "$t/plain"
    DIR="$t/plain" run cfg set a v
    [ "$status" -eq 2 ]
    DIR="$t/plain" run cfg unset --override a
    [ "$status" -eq 2 ]
    DIR="$t/plain" run cfg set --global a v
    [ "$status" -eq 0 ]
    DIR="$t/plain" run cfg get --show-origin a
    [ "$output" = "global${TAB}v" ]
}

@test "an untrusted config makes mise fail and get exit 2 with mise's stderr" {
    printf '[env]\nSKOGAI_X = "x"\n' >"$P/mise.toml"
    run --separate-stderr env -i PATH="$PATH" HOME="$t/home" XDG_STATE_HOME="$t/state" \
        MISE_CONFIG_DIR="$CFG" MISE_SYSTEM_DIR="$SYS" MISE_DATA_DIR="$t/data" \
        MISE_STATE_DIR="$t/mstate" MISE_CACHE_DIR="$t/cache" \
        MISE_TRUSTED_CONFIG_PATHS="$t/elsewhere" bash -c "cd '$P' && '$CONFIG' get x"
    [ "$status" -eq 2 ]
    [ -n "$stderr" ]
}

@test "a missing tool is exit 2 with a message" {
    local bin="$t/bin"
    mkdir -p "$bin"
    ln -s "$(command -v bash)" "$bin/bash"
    ln -s "$(command -v env)" "$bin/env"
    ln -s "$(command -v usage)" "$bin/usage"
    run --separate-stderr env -i PATH="$bin" HOME="$t/home" "$CONFIG" files
    [ "$status" -eq 2 ]
    [[ "$stderr" == *"missing tool"* ]]
}

@test "through the registry: skogai config set and get" {
    export SKOGAI_MAIN="$ROOT/src/core/main-usage.sh"
    XENV=(SKOGAI_MAIN="$SKOGAI_MAIN" SKOGAI_COMMANDS="$t/commands")
    run iso "$SKOGAI_MAIN" register "$CONFIG" config
    [ "$status" -eq 0 ]
    run iso "$SKOGAI_MAIN" config set --global hello.greeting x
    [ "$status" -eq 0 ]
    run iso "$SKOGAI_MAIN" config get --show-origin hello.greeting
    [ "$status" -eq 0 ]
    [ "$output" = "global${TAB}x" ]
}

@test "the example module hello uses the env default form" {
    grep -qF "SKOGAI_HELLO_GREETING = \"{{ env.SKOGAI_HELLO_GREETING | default(value='hi') }}\"" \
        "$ROOT/examples/modules/hello/hello.toml"
}
