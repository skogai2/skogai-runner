#!/usr/bin/env bats
# src/core/main.sh: the template ~/Argcfile.sh is generated from

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export ARGC_COMMANDS="$HOME/.config/argc/commands"
    export ARGC_MAIN="$HOME/Argcfile.sh"
    export ARGC_TEMPLATE="$BATS_TEST_DIRNAME/../src/core/main.sh"
    work="$BATS_TEST_TMPDIR/work"
    mkdir -p "$HOME/sub" "$work"
    cat >"$work/hello.sh" <<'EOF'
#!/usr/bin/env bash
# @describe greets people
# second line of the description
# @cmd say hi
# @arg who[alice|bob]
greet() { echo "hi ${argc_who:-}"; }
# @cmd print cwd
where() { pwd; }
eval "$(argc --argc-eval "$0" "$@")"
EOF
    printf '#!/usr/bin/env bash\n# @cmd broken\n# @arg x![\nbroken() { :; }\n' >"$work/broken.sh"
}

template() { argc --argc-run "$ARGC_TEMPLATE" "$@"; }
main() { argc --argc-run "$ARGC_MAIN" "$@"; }

@test "sync with an empty registry writes a main that runs" {
    run template sync
    [ "$status" -eq 0 ]
    run main --help
    [ "$status" -eq 0 ]
    [[ "$output" == *register* && "$output" == *sync* ]]
}

@test "the generated main has exactly one eval, as its last line" {
    template register "$work/hello.sh" hello
    run grep -cxF 'eval "$(argc --argc-eval "$0" "$@")"' "$ARGC_MAIN"
    [ "$output" -eq 1 ]
    run tail -n 1 "$ARGC_MAIN"
    [[ "$output" == 'eval "$(argc --argc-eval "$0" "$@")"' ]]
}

@test "register links the file and adds a recipe" {
    run template register "$work/hello.sh" hello
    [ "$status" -eq 0 ]
    [ "$(readlink "$ARGC_COMMANDS/hello.sh")" = "$work/hello.sh" ]
    run main hello greet bob
    [ "$status" -eq 0 ]
    [ "$output" = "hi bob" ]
}

@test "register resolves a relative file from the caller's directory" {
    cd "$work"
    run template register ./hello.sh hello
    [ "$status" -eq 0 ]
    [ "$(readlink "$ARGC_COMMANDS/hello.sh")" = "$work/hello.sh" ]
}

@test "the recipe is described by the first line of the script's describe" {
    template register "$work/hello.sh" hello
    run main --help
    [[ "$output" == *"hello"*"greets people"* ]]
    [[ "$output" != *"second line"* ]]
}

@test "a registered command runs from the directory argc was called in" {
    template register "$work/hello.sh" hello
    cd "$HOME/sub"
    run argc hello where
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/sub" ]
}

@test "registering the same name again repoints it" {
    template register "$work/hello.sh" hello
    cp "$work/hello.sh" "$work/other.sh"
    run template register "$work/other.sh" hello
    [ "$status" -eq 0 ]
    [ "$(readlink "$ARGC_COMMANDS/hello.sh")" = "$work/other.sh" ]
}

@test "names that are not lowercase single segments are refused" {
    for name in Hello hello.world hello_world -hello 1hello; do
        run template register "$work/hello.sh" "$name"
        [ "$status" -eq 2 ]
    done
    [ ! -e "$ARGC_COMMANDS" ] || [ -z "$(ls -A "$ARGC_COMMANDS")" ]
}

@test "the main's own commands are reserved" {
    for name in register unregister ls sync help; do
        run template register "$work/hello.sh" "$name"
        [ "$status" -eq 2 ]
        [[ "$output" == *reserved* ]]
    done
}

@test "bash builtins and keywords are refused" {
    for name in echo cd printf test exit if then done; do
        run template register "$work/hello.sh" "$name"
        [ "$status" -eq 2 ]
        [[ "$output" == *reserved* ]]
    done
}

@test "a name shadowing an external tool keeps sync and unregister working" {
    for name in sed mv ln jq realpath mktemp readlink rm mkdir; do
        run template register "$work/hello.sh" "$name"
        [ "$status" -eq 0 ]
    done
    run main sync
    [ "$status" -eq 0 ]
    run main sed greet alice
    [ "$output" = "hi alice" ]
    run main unregister sed
    [ "$status" -eq 0 ]
    [ ! -e "$ARGC_COMMANDS/sed.sh" ]
}

@test "a script that does not parse is refused and not linked" {
    run template register "$work/broken.sh" broken
    [ "$status" -ne 0 ]
    [ ! -L "$ARGC_COMMANDS/broken.sh" ]
}

@test "a missing file is refused" {
    run template register "$work/nope.sh" nope
    [ "$status" -ne 0 ]
    [ ! -L "$ARGC_COMMANDS/nope.sh" ]
}

@test "unregister removes the link and the recipe" {
    template register "$work/hello.sh" hello
    run main unregister hello
    [ "$status" -eq 0 ]
    [ ! -L "$ARGC_COMMANDS/hello.sh" ]
    run main --help
    [[ "$output" != *hello* ]]
}

@test "sync skips a command whose file is gone, with a warning" {
    template register "$work/hello.sh" hello
    rm "$work/hello.sh"
    run main sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello"*"gone"* ]]
    run main --help
    [[ "$output" != *greets* ]]
}

@test "running a command whose file is gone fails with a clear error" {
    template register "$work/hello.sh" hello
    rm "$work/hello.sh"
    run main hello greet
    [ "$status" -eq 1 ]
    [[ "$output" == "hello: $work/hello.sh is gone"* ]]
}

@test "ls marks gone targets" {
    template register "$work/hello.sh" hello
    cp "$work/hello.sh" "$work/kept.sh"
    template register "$work/kept.sh" kept
    rm "$work/hello.sh"
    run main ls
    [[ "${lines[0]}" == hello*"$work/hello.sh (gone)" ]]
    [[ "${lines[1]}" == kept*"$work/kept.sh" ]]
    [[ "${lines[1]}" != *gone* ]]
}

@test "ls lines up targets past the longest name" {
    template register "$work/hello.sh" a-rather-long-command-name
    template register "$work/hello.sh" b
    run main ls
    local first="${lines[0]%%/*}" second="${lines[1]%%/*}"
    [ "${#first}" -eq "${#second}" ]
}

@test "completion of a registered command comes from its own script" {
    template register "$work/hello.sh" hello
    run argc --argc-compgen generic "$ARGC_MAIN" argc hello ""
    [[ "$output" == *greet* && "$output" == *where* ]]
    run argc --argc-compgen generic "$ARGC_MAIN" argc hello greet ""
    [[ "$output" == *alice* && "$output" == *bob* ]]
}

@test "completion keeps the description, not the inner script's color field" {
    template register "$work/hello.sh" hello
    run argc --argc-compgen generic "$ARGC_MAIN" argc hello ""
    [[ "${lines[0]}" == $'greet\t/color:'*$'\tsay hi' ]]
    local line
    for line in "${lines[@]}"; do [[ "$line" != *"/color:"*"/color:"* ]]; done
}

@test "a missing template fails sync and leaves the main untouched" {
    template sync
    cp "$ARGC_MAIN" "$BATS_TEST_TMPDIR/before"
    ARGC_TEMPLATE="$work/nope.sh" run main sync
    [ "$status" -ne 0 ]
    [[ "$output" == *"$work/nope.sh"* ]]
    cmp "$ARGC_MAIN" "$BATS_TEST_TMPDIR/before"
}

@test "a sync that fails leaves no temp files beside the main" {
    template sync
    { cat "$work/broken.sh"; printf '%s\n' 'eval "$(argc --argc-eval "$0" "$@")"'; } >"$work/broken-template.sh"
    ARGC_TEMPLATE="$work/broken-template.sh" run main sync
    [ "$status" -ne 0 ]
    run compgen -G "$ARGC_MAIN.*"
    [ "$status" -ne 0 ]
}

@test "the template uses no sed or awk" {
    run grep -nwE 'sed|awk' "$ARGC_TEMPLATE"
    [ "$status" -eq 1 ]
}
